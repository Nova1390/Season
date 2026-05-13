#!/usr/bin/env python3
"""Smoke-test the parse-recipe-caption Smart Import learning contract.

This runner calls the Edge Function with exact local-catalog candidates, so it
does not require an LLM call. It verifies that the response exposes
`smartImportAgent.passes[].name == "learning_memory_context"` when the imported
terms have Catalog Agent learning memory.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from run_learning_context import DEFAULT_FIXTURE, load_fixture, schema_check


DEFAULT_SUPABASE_URL = "https://gyuedxycbnqljryenapx.supabase.co"
REQUEST_TIMEOUT_SECONDS = 30


def build_ssl_context() -> ssl.SSLContext:
    try:
        import certifi  # type: ignore

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def post_json(url: str, headers: dict[str, str], payload: dict[str, Any]) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        method="POST",
        headers={
            **headers,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        data=json.dumps(payload).encode("utf-8"),
    )
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS, context=build_ssl_context()) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"POST {url} failed: HTTP {exc.code}: {body}") from exc
    return json.loads(raw) if raw else {}


def sign_in_with_password(supabase_url: str, anon_key: str, email: str, password: str) -> str:
    response = post_json(
        f"{supabase_url.rstrip('/')}/auth/v1/token?grant_type=password",
        {"apikey": anon_key},
        {"email": email, "password": password},
    )
    access_token = response.get("access_token")
    if not isinstance(access_token, str) or not access_token:
        raise RuntimeError("Password sign-in did not return an access_token.")
    return access_token


def create_temp_user(supabase_url: str, service_role_key: str) -> tuple[str, str, str]:
    email = f"smart-import-smoke-{secrets.token_hex(8)}@season.local"
    password = f"Season-smoke-{secrets.token_urlsafe(18)}"
    response = post_json(
        f"{supabase_url.rstrip('/')}/auth/v1/admin/users",
        {
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
        },
        {
            "email": email,
            "password": password,
            "email_confirm": True,
            "user_metadata": {
                "source": "smart_import_learning_edge_contract",
            },
        },
    )
    user_id = response.get("id")
    if not isinstance(user_id, str) or not user_id:
        raise RuntimeError("Temporary user creation did not return a user id.")
    return user_id, email, password


def delete_temp_user(supabase_url: str, service_role_key: str, user_id: str) -> None:
    request = urllib.request.Request(
        f"{supabase_url.rstrip('/')}/auth/v1/admin/users/{user_id}",
        method="DELETE",
        headers={
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS, context=build_ssl_context()):
        return


def auth_token(supabase_url: str, anon_key: str, use_temp_user: bool) -> tuple[str, tuple[str, str] | None]:
    direct_token = os.environ.get("USER_JWT", "").strip()
    if direct_token:
        return direct_token, None

    email = os.environ.get("SUPABASE_TEST_EMAIL", "").strip()
    password = os.environ.get("SUPABASE_TEST_PASSWORD", "").strip()
    if email and password:
        return sign_in_with_password(supabase_url, anon_key, email, password), None

    service_role_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if use_temp_user and service_role_key:
        user_id, temp_email, temp_password = create_temp_user(supabase_url, service_role_key)
        return sign_in_with_password(supabase_url, anon_key, temp_email, temp_password), (user_id, service_role_key)

    raise RuntimeError(
        "Set USER_JWT, or set SUPABASE_TEST_EMAIL and SUPABASE_TEST_PASSWORD. "
        "Alternatively pass --use-temp-user with SUPABASE_SERVICE_ROLE_KEY in dev. "
        "The smoke test needs a real authenticated user token because "
        "parse-recipe-caption calls auth.getUser(jwt)."
    )


def candidate_payload(case: dict[str, Any]) -> dict[str, Any]:
    term = str(case["term"])
    return {
        "raw_text": term,
        "normalized_text": term,
        "possible_quantity": None,
        "possible_unit": None,
        "catalog_match": {
            "matchType": "exact",
            "matchedIngredientId": f"smoke:{case['id']}",
            "confidence": 1,
        },
    }


def request_payload(cases: list[dict[str, Any]], max_cases: int) -> dict[str, Any]:
    selected = cases[:max_cases]
    captions = [str(case.get("caption") or case["term"]) for case in selected]
    return {
        "caption": "\n".join(captions + ["Procedimento: mescola tutto e completa la ricetta."]),
        "languageCode": "it",
        "ingredientCandidates": [candidate_payload(case) for case in selected],
    }


def assert_edge_contract(response: dict[str, Any], expected_cases: int) -> list[str]:
    failures: list[str] = []
    if response.get("ok") is not True:
        failures.append(f"response ok=false: {response.get('error')}")
        return failures

    result = response.get("result")
    if not isinstance(result, dict):
        return ["missing result object"]

    ingredients = result.get("ingredients")
    if not isinstance(ingredients, list) or len(ingredients) != expected_cases:
        failures.append(f"expected {expected_cases} ingredients, got {len(ingredients) if isinstance(ingredients, list) else 'none'}")

    agent = result.get("smartImportAgent")
    if not isinstance(agent, dict):
        return failures + ["missing smartImportAgent object"]

    passes = agent.get("passes")
    if not isinstance(passes, list):
        return failures + ["missing smartImportAgent.passes array"]

    pass_names = {item.get("name") for item in passes if isinstance(item, dict)}
    for required in ("swift_preparse_catalog_memory", "learning_memory_context", "draft_quality_gate"):
        if required not in pass_names:
            failures.append(f"missing pass {required!r}; found {sorted(str(name) for name in pass_names)}")

    if response.get("meta", {}).get("usedServerLLM") is not False:
        failures.append("expected meta.usedServerLLM=false for exact-candidate smoke")

    return failures


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, default=DEFAULT_FIXTURE)
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument("--anon-key", default=os.environ.get("SUPABASE_ANON_KEY", ""))
    parser.add_argument("--max-cases", type=int, default=2)
    parser.add_argument("--json", action="store_true", dest="json_output")
    parser.add_argument("--schema-only", action="store_true")
    parser.add_argument("--use-temp-user", action="store_true")
    args = parser.parse_args(argv)

    fixture = load_fixture(args.fixture)
    errors = schema_check(fixture)
    if errors:
        for error in errors:
            print(f"SCHEMA FAIL {error}", file=sys.stderr)
        return 2

    if args.schema_only:
        print(json.dumps({"ok": True, "mode": "schema_only", "cases": len(fixture["cases"])}, indent=2) if args.json_output else f"Schema OK: {len(fixture['cases'])} edge contract cases.")
        return 0

    if not args.anon_key:
        raise RuntimeError("SUPABASE_ANON_KEY is required.")

    cleanup_user: tuple[str, str] | None = None
    try:
        token, cleanup_user = auth_token(args.supabase_url, args.anon_key, args.use_temp_user)
        selected_cases = fixture["cases"][:max(1, args.max_cases)]
        payload = request_payload(selected_cases, max_cases=len(selected_cases))
        function_url = f"{args.supabase_url.rstrip('/')}/functions/v1/parse-recipe-caption"
        response = post_json(
            function_url,
            {
                "apikey": args.anon_key,
                "Authorization": f"Bearer {token}",
            },
            payload,
        )
    finally:
        if cleanup_user is not None:
            user_id, service_role_key = cleanup_user
            try:
                delete_temp_user(args.supabase_url, service_role_key, user_id)
            except Exception as error:
                print(f"WARN failed to delete temporary user {user_id}: {error}", file=sys.stderr)

    failures = assert_edge_contract(response, len(selected_cases))

    if args.json_output:
        print(json.dumps(
            {
                "ok": not failures,
                "failures": failures,
                "pass_names": [
                    item.get("name")
                    for item in (((response.get("result") or {}).get("smartImportAgent") or {}).get("passes") or [])
                    if isinstance(item, dict)
                ],
                "usedServerLLM": (response.get("meta") or {}).get("usedServerLLM"),
            },
            indent=2,
        ))
    elif failures:
        for failure in failures:
            print(f"FAIL {failure}")
    else:
        print("PASS parse-recipe-caption exposes learning_memory_context without using LLM.")

    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
