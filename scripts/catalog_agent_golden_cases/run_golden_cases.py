#!/usr/bin/env python3
"""Evaluate Season catalog-agent golden cases without calling an LLM.

The runner is deliberately read-only. It checks the current Supabase catalog
state and latest agent proposals against the selected profile in
golden_cases.json.
"""

from __future__ import annotations

import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

REQUEST_TIMEOUT = 20
RISK_ORDER = {"low": 1, "medium": 2, "high": 3}


@dataclass(frozen=True)
class CheckResult:
    case_id: str
    normalized_text: str
    ok: bool
    detail: str


class SupabaseReadOnly:
    def __init__(self, url: str, key: str) -> None:
        self.url = url.rstrip("/")
        self.key = key
        self.rest_base = f"{self.url}/rest/v1"
        self.ssl_context = build_ssl_context()

    def _headers(self) -> dict[str, str]:
        return {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}",
            "Accept": "application/json",
        }

    def select(self, table: str, params: dict[str, str]) -> list[dict[str, Any]]:
        query = urllib.parse.urlencode(params)
        request = urllib.request.Request(
            f"{self.rest_base}/{table}?{query}",
            method="GET",
            headers=self._headers(),
        )
        try:
            with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT, context=self.ssl_context) as response:
                raw = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Supabase GET {table} failed: HTTP {exc.code}: {body}") from exc
        return json.loads(raw) if raw else []

    def select_all(self, table: str, params: dict[str, str], page_size: int = 1000) -> list[dict[str, Any]]:
        rows: list[dict[str, Any]] = []
        offset = 0
        while True:
            page_params = dict(params)
            page_params["limit"] = str(page_size)
            page_params["offset"] = str(offset)
            page = self.select(table, page_params)
            rows.extend(page)
            if len(page) < page_size:
                return rows
            offset += page_size

    def rpc(self, function_name: str, payload: dict[str, Any]) -> Any:
        request = urllib.request.Request(
            f"{self.rest_base}/rpc/{function_name}",
            method="POST",
            headers={
                **self._headers(),
                "Content-Type": "application/json",
            },
            data=json.dumps(payload).encode("utf-8"),
        )
        try:
            with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT, context=self.ssl_context) as response:
                raw = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Supabase RPC {function_name} failed: HTTP {exc.code}: {body}") from exc
        return json.loads(raw) if raw else None

    def ingredient_by_slug(self, slug: str) -> dict[str, Any] | None:
        rows = self.select(
            "ingredients",
            {
                "select": "id,slug,quality_status,parent_ingredient_id",
                "slug": f"eq.{slug}",
                "limit": "1",
            },
        )
        return rows[0] if rows else None

    def ingredient_by_id(self, ingredient_id: str) -> dict[str, Any] | None:
        rows = self.select(
            "ingredients",
            {
                "select": "id,slug,quality_status,parent_ingredient_id",
                "id": f"eq.{ingredient_id}",
                "limit": "1",
            },
        )
        return rows[0] if rows else None

    def latest_proposal(self, normalized_text: str) -> dict[str, Any] | None:
        rows = self.select(
            "catalog_agent_proposals",
            {
                "select": "id,normalized_text,proposal_type,status,target_slug,proposed_slug,risk_level,confidence_score,auto_apply_eligible",
                "normalized_text": f"eq.{normalized_text}",
                "order": "id.desc",
                "limit": "1",
            },
        )
        return rows[0] if rows else None

    def active_alias(self, normalized_text: str) -> dict[str, Any] | None:
        rows = self.select(
            "ingredient_aliases_v2",
            {
                "select": "id,ingredient_id,alias_text,normalized_alias_text,status,is_active,confidence_score",
                "normalized_alias_text": f"eq.{normalized_text}",
                "is_active": "is.true",
                "order": "id.desc",
                "limit": "1",
            },
        )
        return rows[0] if rows else None


def build_ssl_context() -> ssl.SSLContext:
    try:
        import certifi  # type: ignore

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def load_fixture(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload.get("cases"), list):
        raise ValueError("Fixture must contain a cases array.")
    return payload


def expected_values(expected: dict[str, Any], key: str) -> set[Any] | None:
    if f"{key}_any_of" in expected:
        values = expected[f"{key}_any_of"]
        if not isinstance(values, list):
            raise ValueError(f"{key}_any_of must be a list")
        return set(values)
    if key in expected:
        return {expected[key]}
    return None


def value_matches(actual: Any, expected: dict[str, Any], key: str) -> bool:
    values = expected_values(expected, key)
    return True if values is None else actual in values


def check_min_confidence(actual: Any, expected: dict[str, Any]) -> str | None:
    if "min_confidence" not in expected:
        return None
    try:
        confidence = float(actual)
    except (TypeError, ValueError):
        return f"missing confidence, expected >= {expected['min_confidence']}"
    if confidence < float(expected["min_confidence"]):
        return f"confidence {confidence:.2f} below {float(expected['min_confidence']):.2f}"
    return None


def evaluate_alias(client: SupabaseReadOnly, case: dict[str, Any], expected: dict[str, Any]) -> CheckResult:
    normalized_text = case["normalized_text"]
    alias = client.active_alias(normalized_text)
    if not alias:
        return fail(case, "active alias not found")
    target = client.ingredient_by_id(str(alias.get("ingredient_id", "")))
    target_slug = target.get("slug") if target else None
    checks = [
        ("target_slug", target_slug),
        ("status", alias.get("status")),
        ("is_active", alias.get("is_active")),
    ]
    for key, actual in checks:
        if not value_matches(actual, expected, key):
            return fail(case, f"{key}={actual!r} did not match expectation")
    confidence_error = check_min_confidence(alias.get("confidence_score"), expected)
    if confidence_error:
        return fail(case, confidence_error)
    return ok(case, f"alias {normalized_text} -> {target_slug}")


def evaluate_canonical(client: SupabaseReadOnly, case: dict[str, Any], expected: dict[str, Any]) -> CheckResult:
    slug = str(expected.get("slug") or case["normalized_text"]).strip()
    ingredient = client.ingredient_by_slug(slug)
    if not ingredient:
        return fail(case, f"canonical slug {slug!r} not found")
    if not value_matches(ingredient.get("quality_status"), expected, "status"):
        return fail(case, f"status={ingredient.get('quality_status')!r} did not match expectation")
    expected_parent_slug = expected.get("parent_slug")
    if expected_parent_slug:
        parent = client.ingredient_by_id(str(ingredient.get("parent_ingredient_id", "")))
        parent_slug = parent.get("slug") if parent else None
        if parent_slug != expected_parent_slug:
            return fail(case, f"parent_slug={parent_slug!r}, expected {expected_parent_slug!r}")
    return ok(case, f"canonical {slug} exists")


def evaluate_proposal(client: SupabaseReadOnly, case: dict[str, Any], expected: dict[str, Any]) -> CheckResult:
    proposal = client.latest_proposal(case["normalized_text"])
    if not proposal:
        return fail(case, "latest proposal not found")
    for key in ("proposal_type", "status", "target_slug", "proposed_slug", "risk_level"):
        if not value_matches(proposal.get(key), expected, key):
            return fail(case, f"{key}={proposal.get(key)!r} did not match expectation in proposal #{proposal.get('id')}")
    if "risk_any_of" in expected and proposal.get("risk_level") not in set(expected["risk_any_of"]):
        return fail(case, f"risk_level={proposal.get('risk_level')!r} did not match risk_any_of")
    if "max_risk" in expected:
        actual_rank = RISK_ORDER.get(str(proposal.get("risk_level")), 99)
        max_rank = RISK_ORDER.get(str(expected["max_risk"]), 99)
        if actual_rank > max_rank:
            return fail(case, f"risk_level={proposal.get('risk_level')!r} is above max_risk={expected['max_risk']!r}")
    confidence_error = check_min_confidence(proposal.get("confidence_score"), expected)
    if confidence_error:
        return fail(case, f"{confidence_error} in proposal #{proposal.get('id')}")
    return ok(case, f"proposal #{proposal.get('id')} {proposal.get('proposal_type')} status={proposal.get('status')}")


def ok(case: dict[str, Any], detail: str) -> CheckResult:
    return CheckResult(case["id"], case["normalized_text"], True, detail)


def fail(case: dict[str, Any], detail: str) -> CheckResult:
    return CheckResult(case["id"], case["normalized_text"], False, detail)


def evaluate_case(client: SupabaseReadOnly, case: dict[str, Any], profile: str) -> CheckResult | None:
    expected = case.get(profile)
    if not expected:
        return None
    kind = expected.get("kind")
    if kind == "alias":
        return evaluate_alias(client, case, expected)
    if kind == "canonical":
        return evaluate_canonical(client, case, expected)
    if kind == "proposal":
        return evaluate_proposal(client, case, expected)
    raise ValueError(f"Unsupported expected kind {kind!r} in case {case.get('id')}")


def schema_check(payload: dict[str, Any], profile: str) -> list[str]:
    errors: list[str] = []
    case_ids: set[str] = set()
    for index, case in enumerate(payload["cases"], start=1):
        case_id = case.get("id")
        if not case_id:
            errors.append(f"case {index}: missing id")
            continue
        if case_id in case_ids:
            errors.append(f"case {case_id}: duplicate id")
        case_ids.add(case_id)
        if not case.get("normalized_text"):
            errors.append(f"case {case_id}: missing normalized_text")
        expected = case.get(profile)
        if not expected:
            errors.append(f"case {case_id}: missing {profile} expectation")
            continue
        if expected.get("kind") not in {"alias", "canonical", "proposal"}:
            errors.append(f"case {case_id}: unsupported kind {expected.get('kind')!r}")
    return errors


def build_client() -> SupabaseReadOnly:
    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip() or os.environ.get("SUPABASE_ANON_KEY", "").strip()
    if not url or not key:
        raise RuntimeError(
            "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (preferred) or SUPABASE_ANON_KEY. "
            "The runner is read-only and does not call the LLM."
        )
    return SupabaseReadOnly(url, key)


def parse_args() -> argparse.Namespace:
    default_fixture = Path(__file__).with_name("golden_cases.json")
    parser = argparse.ArgumentParser(description="Run no-LLM Season catalog-agent golden checks.")
    parser.add_argument("--fixture", type=Path, default=default_fixture)
    parser.add_argument("--profile", default="current")
    parser.add_argument("--schema-only", action="store_true", help="Validate fixture shape without contacting Supabase.")
    parser.add_argument("--json", action="store_true", help="Print machine-readable JSON.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    payload = load_fixture(args.fixture)
    profiles = payload.get("profiles") or []
    if args.profile not in profiles:
        print(
            f"Unsupported profile {args.profile!r}. Available profiles: {', '.join(profiles)}",
            file=sys.stderr,
        )
        return 2
    schema_errors = schema_check(payload, args.profile)
    if schema_errors:
        print("\n".join(schema_errors), file=sys.stderr)
        return 2
    if args.schema_only:
        print(json.dumps({"ok": True, "profile": args.profile, "cases": len(payload["cases"])}, indent=2))
        return 0

    client = build_client()
    results = [
        result
        for case in payload["cases"]
        if (result := evaluate_case(client, case, args.profile)) is not None
    ]
    passed = sum(1 for result in results if result.ok)
    failed = len(results) - passed
    if args.json:
        print(json.dumps({
            "ok": failed == 0,
            "profile": args.profile,
            "passed": passed,
            "failed": failed,
            "results": [result.__dict__ for result in results],
        }, indent=2))
    else:
        print(f"Catalog agent golden cases [{args.profile}]: {passed}/{len(results)} passed")
        for result in results:
            marker = "PASS" if result.ok else "FAIL"
            print(f"{marker} {result.case_id} ({result.normalized_text}): {result.detail}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
