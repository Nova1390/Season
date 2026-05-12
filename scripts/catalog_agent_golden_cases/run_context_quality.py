#!/usr/bin/env python3
"""Check pre-LLM catalog context for golden cases.

This runner is deliberately read-only and does not call an LLM. It answers a
simple question: before the agent spends tokens, does the work packet have the
catalog candidates needed to make a good decision?
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from run_golden_cases import SupabaseReadOnly, build_client, expected_values, load_fixture


@dataclass(frozen=True)
class ContextMatch:
    slug: str
    source: str
    reason: str


@dataclass(frozen=True)
class ContextCheckResult:
    case_id: str
    normalized_text: str
    ok: bool
    detail: str
    lexical_terms: list[str]
    candidate_slugs: list[str]


def compact(value: str | None) -> str:
    return re.sub(r"[^a-z0-9]+", "", (value or "").strip().lower())


def lowered(value: str | None) -> str:
    return (value or "").strip().lower()


class ContextReplay:
    def __init__(self, client: SupabaseReadOnly) -> None:
        self.client = client
        self.catalog_rows = client.select_all(
            "ingredient_catalog_app_summary",
            {
                "select": "ingredient_id,slug,quality_status,parent_slug,it_name,en_name,specificity_rank,variant_kind",
                "quality_status": "neq.deprecated_duplicate",
                "order": "slug.asc",
            },
        )
        self.alias_rows = client.select_all(
            "ingredient_alias_app_summary",
            {
                "select": "alias_id,normalized_alias_text,ingredient_slug,status,is_active,confidence_score,approved_at",
                "is_active": "is.true",
                "order": "normalized_alias_text.asc",
            },
        )

    def lexical_terms(self, normalized_text: str) -> list[dict[str, str]]:
        rows = self.client.rpc("catalog_agent_lexical_candidate_terms", {"p_normalized_text": normalized_text})
        if not isinstance(rows, list):
            raise RuntimeError("catalog_agent_lexical_candidate_terms returned a non-list payload")
        return [
            {
                "term": lowered(row.get("term")),
                "source": str(row.get("expansion_source") or "unknown"),
            }
            for row in rows
            if lowered(row.get("term"))
        ]

    def matches_for(self, normalized_text: str) -> tuple[list[dict[str, str]], list[ContextMatch]]:
        terms_payload = self.lexical_terms(normalized_text)
        terms = {row["term"] for row in terms_payload}
        compact_terms = {compact(term) for term in terms if compact(term)}
        matches: list[ContextMatch] = []

        for row in self.catalog_rows:
            slug = str(row.get("slug") or "")
            haystacks = [
                ("it_name", lowered(row.get("it_name"))),
                ("en_name", lowered(row.get("en_name"))),
                ("slug", lowered(slug.replace("_", " "))),
            ]
            reason = first_catalog_reason(normalized_text, terms, compact_terms, haystacks)
            if reason:
                matches.append(ContextMatch(slug=slug, source="canonical", reason=reason))

        normalized_compact = compact(normalized_text)
        for row in self.alias_rows:
            alias_text = lowered(row.get("normalized_alias_text"))
            alias_compact = compact(alias_text)
            reason = None
            if alias_text in terms:
                reason = "alias_lexical_variant" if alias_text != normalized_text else "alias_exact"
            elif alias_compact and alias_compact in compact_terms:
                reason = "alias_compact_lexical_variant"
            elif len(normalized_text) >= 5 and normalized_text in alias_text:
                reason = "alias_contains"
            elif normalized_compact and normalized_compact == alias_compact:
                reason = "alias_compact_key"
            if reason:
                matches.append(
                    ContextMatch(
                        slug=str(row.get("ingredient_slug") or ""),
                        source="alias",
                        reason=reason,
                    )
                )

        return terms_payload, dedupe_matches(matches)


def first_catalog_reason(
    normalized_text: str,
    terms: set[str],
    compact_terms: set[str],
    haystacks: list[tuple[str, str]],
) -> str | None:
    normalized_compact = compact(normalized_text)
    for label, value in haystacks:
        if not value:
            continue
        if value == normalized_text:
            return f"{label}_exact"
        if value in terms:
            return f"{label}_lexical_variant"
        value_compact = compact(value)
        if value_compact and value_compact == normalized_compact:
            return "compact_key"
        if value_compact and value_compact in compact_terms:
            return "compact_lexical_variant"
        if len(normalized_text) >= 5 and normalized_text in value:
            return f"{label}_contains"
    return None


def dedupe_matches(matches: list[ContextMatch]) -> list[ContextMatch]:
    seen: set[tuple[str, str, str]] = set()
    deduped: list[ContextMatch] = []
    for match in matches:
        key = (match.slug, match.source, match.reason)
        if match.slug and key not in seen:
            deduped.append(match)
            seen.add(key)
    return deduped


def context_expected_values(expected: dict[str, Any], key: str) -> set[Any]:
    return expected_values(expected, key) or set()


def evaluate_context_case(replay: ContextReplay, case: dict[str, Any]) -> ContextCheckResult | None:
    expected = case.get("context_target")
    if not expected:
        return None

    normalized_text = case["normalized_text"]
    terms_payload, matches = replay.matches_for(normalized_text)
    lexical_terms = sorted({row["term"] for row in terms_payload})
    candidate_slugs = sorted({match.slug for match in matches})

    required_terms = context_expected_values(expected, "required_lexical_term")
    if required_terms and required_terms.isdisjoint(lexical_terms):
        return fail_context(case, f"missing lexical term in {sorted(required_terms)}", lexical_terms, candidate_slugs)

    forbidden_slugs = context_expected_values(expected, "forbidden_target_slug")
    if forbidden_slugs and not forbidden_slugs.isdisjoint(candidate_slugs):
        return fail_context(case, f"forbidden candidate present: {sorted(forbidden_slugs & set(candidate_slugs))}", lexical_terms, candidate_slugs)

    allowed_sources = context_expected_values(expected, "source")
    target_slugs = context_expected_values(expected, "target_slug")
    if target_slugs:
        scoped_matches = [
            match for match in matches
            if not allowed_sources or match.source in allowed_sources
        ]
        scoped_slugs = {match.slug for match in scoped_matches}
        if target_slugs.isdisjoint(scoped_slugs):
            return fail_context(
                case,
                f"missing target candidate in {sorted(target_slugs)} from sources {sorted(allowed_sources) or ['any']}",
                lexical_terms,
                candidate_slugs,
            )

    candidate_slug_any = context_expected_values(expected, "candidate_slug")
    if candidate_slug_any and candidate_slug_any.isdisjoint(candidate_slugs):
        return fail_context(case, f"missing candidate in {sorted(candidate_slug_any)}", lexical_terms, candidate_slugs)

    min_candidate_count = int(expected.get("min_candidate_count", 0) or 0)
    if min_candidate_count and len(candidate_slugs) < min_candidate_count:
        return fail_context(case, f"only {len(candidate_slugs)} candidates, expected >= {min_candidate_count}", lexical_terms, candidate_slugs)

    max_existing_target_count = expected.get("max_existing_target_count")
    if max_existing_target_count is not None and len(candidate_slugs) > int(max_existing_target_count):
        return fail_context(
            case,
            f"{len(candidate_slugs)} candidates, expected <= {int(max_existing_target_count)}",
            lexical_terms,
            candidate_slugs,
        )

    kind = str(expected.get("kind") or "context")
    return ok_context(case, f"{kind}: candidates={candidate_slugs or ['none']}", lexical_terms, candidate_slugs)


def ok_context(case: dict[str, Any], detail: str, lexical_terms: list[str], candidate_slugs: list[str]) -> ContextCheckResult:
    return ContextCheckResult(case["id"], case["normalized_text"], True, detail, lexical_terms, candidate_slugs)


def fail_context(case: dict[str, Any], detail: str, lexical_terms: list[str], candidate_slugs: list[str]) -> ContextCheckResult:
    return ContextCheckResult(case["id"], case["normalized_text"], False, detail, lexical_terms, candidate_slugs)


def schema_check(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    valid_kinds = {"existing_target", "meaningful_variant_target", "ambiguous_target_set", "catalog_gap", "policy_gap"}
    for case in payload["cases"]:
        expected = case.get("context_target")
        if not expected:
            continue
        case_id = case.get("id", "<missing id>")
        if expected.get("kind") not in valid_kinds:
            errors.append(f"case {case_id}: unsupported context_target kind {expected.get('kind')!r}")
        for key in (
            "target_slug_any_of",
            "source_any_of",
            "required_lexical_term_any_of",
            "forbidden_target_slug_any_of",
            "candidate_slug_any_of",
        ):
            if key in expected and not isinstance(expected[key], list):
                errors.append(f"case {case_id}: {key} must be a list")
    return errors


def parse_args() -> argparse.Namespace:
    default_fixture = Path(__file__).with_name("golden_cases.json")
    parser = argparse.ArgumentParser(description="Run no-LLM Season catalog-agent context-quality checks.")
    parser.add_argument("--fixture", type=Path, default=default_fixture)
    parser.add_argument("--schema-only", action="store_true", help="Validate context fixture shape without contacting Supabase.")
    parser.add_argument("--json", action="store_true", help="Print machine-readable JSON.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    payload = load_fixture(args.fixture)
    schema_errors = schema_check(payload)
    if schema_errors:
        print("\n".join(schema_errors), file=sys.stderr)
        return 2
    cases = [case for case in payload["cases"] if case.get("context_target")]
    if args.schema_only:
        print(json.dumps({"ok": True, "profile": "context_target", "cases": len(cases)}, indent=2))
        return 0

    replay = ContextReplay(build_client())
    results = [
        result
        for case in cases
        if (result := evaluate_context_case(replay, case)) is not None
    ]
    passed = sum(1 for result in results if result.ok)
    failed = len(results) - passed
    if args.json:
        print(json.dumps({
            "ok": failed == 0,
            "profile": "context_target",
            "passed": passed,
            "failed": failed,
            "results": [result.__dict__ for result in results],
        }, indent=2))
    else:
        print(f"Catalog agent context quality [context_target]: {passed}/{len(results)} passed")
        for result in results:
            marker = "PASS" if result.ok else "FAIL"
            print(f"{marker} {result.case_id} ({result.normalized_text}): {result.detail}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
