#!/usr/bin/env python3
"""Probe Smart Import for exact caption quantity preservation and dedupe.

This is intentionally no-LLM: it sends Swift-like preparsed candidates, including
duplicate lower-quality candidates, and verifies the Edge Function keeps the
measured version.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any

from run_edge_contract import (
    DEFAULT_SUPABASE_URL,
    auth_token,
    delete_temp_user,
    post_json,
)


DEFAULT_CAPTION = (
    "Risotto ai funghi per 2: riso 180g, funghi 250g, "
    "brodo vegetale caldo, burro 20g, parmigiano 30g."
)


def candidate(
    raw_text: str,
    normalized_text: str,
    matched_id: str,
    quantity: float | None = None,
    unit: str | None = None,
) -> dict[str, Any]:
    return {
        "raw_text": raw_text,
        "normalized_text": normalized_text,
        "possible_quantity": quantity,
        "possible_unit": unit,
        "catalog_match": {
            "matchType": "exact",
            "matchedIngredientId": matched_id,
            "confidence": 0.96,
        },
    }


def request_payload(caption: str) -> dict[str, Any]:
    return {
        "caption": caption,
        "languageCode": "it",
        "ingredientCandidates": [
            candidate("riso", "riso", "basic:rice"),
            candidate("riso 180g", "riso", "basic:rice", 180, "g"),
            candidate("funghi 250g", "funghi", "produce:mushroom", 250, "g"),
            candidate("brodo vegetale caldo", "brodo vegetale", "basic:broth"),
            candidate("burro", "burro", "basic:butter"),
            candidate("burro 20g", "burro", "basic:butter", 20, "g"),
            candidate("parmigiano 30g", "parmigiano", "basic:parmesan", 30, "g"),
        ],
    }


def ingredient_key(item: dict[str, Any]) -> str:
    matched_id = str(item.get("matchedIngredientId") or "")
    if matched_id:
        return matched_id
    return str(item.get("name") or "").strip().lower()


def assert_probe(response: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    if response.get("ok") is not True:
        return [f"response ok=false: {response.get('error')}"]

    result = response.get("result")
    if not isinstance(result, dict):
        return ["missing result object"]

    ingredients = result.get("ingredients")
    if not isinstance(ingredients, list):
        return ["missing result.ingredients array"]

    by_key: dict[str, dict[str, Any]] = {}
    duplicate_keys: set[str] = set()
    for item in ingredients:
        if not isinstance(item, dict):
            continue
        key = ingredient_key(item)
        if key in by_key:
            duplicate_keys.add(key)
        by_key[key] = item

    if duplicate_keys:
        failures.append(f"duplicate ingredient keys: {sorted(duplicate_keys)}")

    expected = {
        "basic:rice": (180, "g"),
        "produce:mushroom": (250, "g"),
        "basic:butter": (20, "g"),
        "basic:parmesan": (30, "g"),
    }
    for key, (quantity, unit) in expected.items():
        item = by_key.get(key)
        if item is None:
            failures.append(f"missing ingredient {key}")
            continue
        if item.get("quantity") != quantity or item.get("unit") != unit:
            failures.append(
                f"{key} expected {quantity}{unit}, got {item.get('quantity')}{item.get('unit')}"
            )

    if response.get("meta", {}).get("usedServerLLM") is not False:
        failures.append("expected meta.usedServerLLM=false")

    return failures


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument("--anon-key", default=os.environ.get("SUPABASE_ANON_KEY", ""))
    parser.add_argument("--caption", default=DEFAULT_CAPTION)
    parser.add_argument("--use-temp-user", action="store_true")
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args(argv)

    if not args.anon_key:
        raise RuntimeError("SUPABASE_ANON_KEY is required.")

    cleanup_user: tuple[str, str] | None = None
    try:
        token, cleanup_user = auth_token(args.supabase_url, args.anon_key, args.use_temp_user)
        response = post_json(
            f"{args.supabase_url.rstrip('/')}/functions/v1/parse-recipe-caption",
            {
                "apikey": args.anon_key,
                "Authorization": f"Bearer {token}",
            },
            request_payload(args.caption),
        )
    finally:
        if cleanup_user is not None:
            user_id, service_role_key = cleanup_user
            try:
                delete_temp_user(args.supabase_url, service_role_key, user_id)
            except Exception as error:
                print(f"WARN failed to delete temporary user {user_id}: {error}", file=sys.stderr)

    failures = assert_probe(response)
    output = {
        "ok": not failures,
        "failures": failures,
        "usedServerLLM": response.get("meta", {}).get("usedServerLLM"),
        "ingredients": (response.get("result") or {}).get("ingredients") if response.get("ok") else [],
    }
    if args.json_output:
        print(json.dumps(output, indent=2, ensure_ascii=False))
    elif failures:
        for failure in failures:
            print(f"FAIL {failure}")
    else:
        print("PASS exact caption quantities preserved and duplicate candidates collapsed.")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
