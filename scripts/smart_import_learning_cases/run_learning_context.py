#!/usr/bin/env python3
"""Validate Smart Import learning-memory context without calling an LLM.

The runner is intentionally read-only. It checks that dev can return the
Catalog Agent lessons that `parse-recipe-caption` uses as advisory context
before targeted ingredient-resolution prompts.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_FIXTURE = Path(__file__).with_name("learning_cases.json")


@dataclass(frozen=True)
class CheckResult:
    case_id: str
    term: str
    ok: bool
    detail: str


def load_fixture(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload.get("cases"), list):
        raise ValueError("Fixture must contain a cases array.")
    return payload


def schema_check(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    seen_ids: set[str] = set()

    for case in payload["cases"]:
        case_id = str(case.get("id") or "<missing id>")
        if case_id in seen_ids:
            errors.append(f"duplicate case id {case_id}")
        seen_ids.add(case_id)

        if not case.get("term"):
            errors.append(f"case {case_id}: missing term")
        if not case.get("caption"):
            errors.append(f"case {case_id}: missing caption")

        expected = case.get("expected")
        if not isinstance(expected, dict):
            errors.append(f"case {case_id}: missing expected object")
            continue

        if int(expected.get("min_term_learnings", 0) or 0) < 1:
            errors.append(f"case {case_id}: min_term_learnings must be >= 1")
        for key in ("status_any_of", "must_contain_all", "must_contain_any", "must_not_contain"):
            if key in expected and not isinstance(expected[key], list):
                errors.append(f"case {case_id}: {key} must be a list")

    return errors


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def build_learning_sql(terms: list[str], limit_per_term: int) -> str:
    terms_sql = ", ".join(sql_literal(term) for term in terms)
    return (
        "select set_config('request.jwt.claim.role','service_role',true); "
        "select public.get_catalog_agent_learning_context("
        f"array[{terms_sql}]::text[], {int(limit_per_term)}"
        ") as learning_context;"
    )


def extract_json_object(raw: str) -> dict[str, Any]:
    decoder = json.JSONDecoder()
    for index, character in enumerate(raw):
        if character != "{":
            continue
        try:
            payload, _ = decoder.raw_decode(raw[index:])
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict) and "rows" in payload:
            return payload
    raise ValueError("Could not find a Supabase JSON response object in command output.")


def fetch_learning_context(terms: list[str], limit_per_term: int) -> dict[str, Any]:
    sql = build_learning_sql(terms, limit_per_term)
    completed = subprocess.run(
        ["supabase", "db", "query", "--linked", sql],
        check=False,
        text=True,
        capture_output=True,
    )
    if completed.returncode != 0:
        hint = (
            "\nHint: this runner shells out to Supabase CLI. If your CLI session is "
            "not available to subprocesses, rerun with SUPABASE_ACCESS_TOKEN set "
            "or run supabase login first. The check is read-only and no-LLM."
        )
        raise RuntimeError(
            "supabase db query failed\n"
            f"STDOUT:\n{completed.stdout}\n"
            f"STDERR:\n{completed.stderr}"
            f"{hint}"
        )
    payload = extract_json_object(completed.stdout + completed.stderr)
    rows = payload.get("rows")
    if not rows:
        raise RuntimeError("Supabase query returned no rows.")
    context = rows[0].get("learning_context")
    if not isinstance(context, dict):
        raise RuntimeError("Supabase query did not return a learning_context object.")
    return context


def compact_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True).lower()


def evaluate_case(context: dict[str, Any], case: dict[str, Any]) -> CheckResult:
    case_id = str(case["id"])
    term = str(case["term"])
    expected = case["expected"]
    learnings = ((context.get("term_learnings") or {}).get(term) or [])

    if len(learnings) < int(expected.get("min_term_learnings", 1)):
        return fail(case_id, term, f"found {len(learnings)} lessons")

    statuses = set(expected.get("status_any_of") or [])
    if statuses and statuses.isdisjoint({str(row.get("status") or "") for row in learnings}):
        return fail(case_id, term, f"missing status in {sorted(statuses)}")

    haystack = compact_json(learnings)
    for needle in expected.get("must_contain_all") or []:
        if str(needle).lower() not in haystack:
            return fail(case_id, term, f"missing required fragment {needle!r}")

    any_fragments = [str(value).lower() for value in expected.get("must_contain_any") or []]
    if any_fragments and not any(fragment in haystack for fragment in any_fragments):
        return fail(case_id, term, f"missing any fragment in {any_fragments}")

    for forbidden in expected.get("must_not_contain") or []:
        if str(forbidden).lower() in haystack:
            return fail(case_id, term, f"forbidden fragment present {forbidden!r}")

    return CheckResult(case_id, term, True, f"{len(learnings)} lesson(s) available")


def fail(case_id: str, term: str, detail: str) -> CheckResult:
    return CheckResult(case_id, term, False, detail)


def print_text_results(results: list[CheckResult]) -> None:
    for result in results:
        marker = "PASS" if result.ok else "FAIL"
        print(f"{marker} {result.case_id} {result.term}: {result.detail}")
    passed = sum(1 for result in results if result.ok)
    print(f"\n{passed}/{len(results)} Smart Import learning cases passed.")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, default=DEFAULT_FIXTURE)
    parser.add_argument("--schema-only", action="store_true")
    parser.add_argument("--limit-per-term", type=int, default=2)
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args(argv)

    fixture = load_fixture(args.fixture)
    schema_errors = schema_check(fixture)
    if schema_errors:
        for error in schema_errors:
            print(f"SCHEMA FAIL {error}", file=sys.stderr)
        return 2

    if args.schema_only:
        if args.json_output:
            print(json.dumps({"ok": True, "mode": "schema_only", "cases": len(fixture["cases"])}, indent=2))
        else:
            print(f"Schema OK: {len(fixture['cases'])} Smart Import learning cases.")
        return 0

    terms = [str(case["term"]) for case in fixture["cases"]]
    context = fetch_learning_context(terms, args.limit_per_term)
    results = [evaluate_case(context, case) for case in fixture["cases"]]

    if args.json_output:
        print(json.dumps(
            {
                "ok": all(result.ok for result in results),
                "results": [result.__dict__ for result in results],
                "metadata": context.get("metadata") or {},
            },
            indent=2,
        ))
    else:
        print_text_results(results)

    return 0 if all(result.ok for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
