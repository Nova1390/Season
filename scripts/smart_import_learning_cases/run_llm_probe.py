#!/usr/bin/env python3
"""Budgeted live LLM probe for Smart Import creator captions.

This script intentionally calls `parse-recipe-caption` in dev. It should be run
sparingly and with a small `--limit` because it can spend provider tokens.
It uses caption fixtures and reports whether expected ingredient names appear
in the returned draft.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

from run_edge_contract import (
    DEFAULT_SUPABASE_URL,
    auth_token,
    delete_temp_user,
    post_json,
)


DEFAULT_CAPTIONS_CSV = Path(
    "/Users/roccodaffuso/Documents/Codex/2026-05-11/"
    "buonasera-ho-necessit-di-individuare-potenziali/"
    "apify-season-influencer-kit/data/smart_import_training_captions.csv"
)


def normalize_text(value: str) -> str:
    value = value.lower().replace("'", " ")
    value = re.sub(r"[^a-z0-9àèéìòùç\s]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def token_set(value: str) -> set[str]:
    return {token for token in normalize_text(value).split() if len(token) > 2}


def load_caption_cases(
    path: Path,
    limit: int,
    difficulties: set[str],
    case_ids: list[str],
) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))

    if case_ids:
        by_id = {row.get("id"): row for row in rows}
        missing_ids = [case_id for case_id in case_ids if case_id not in by_id]
        if missing_ids:
            raise RuntimeError(f"Unknown case ids: {', '.join(missing_ids)}")
        return [by_id[case_id] for case_id in case_ids]

    selected: list[dict[str, str]] = []
    for row in rows:
        difficulty = (row.get("difficulty") or "").strip().lower()
        if difficulties and difficulty not in difficulties:
            continue
        selected.append(row)
        if len(selected) >= limit:
            break
    return selected


def expected_ingredients(row: dict[str, str]) -> list[str]:
    return [
        item.strip()
        for item in (row.get("expected_ingredients") or "").split(";")
        if item.strip()
    ]


def expected_quantity_fragments(row: dict[str, str]) -> list[str]:
    return [
        item.strip()
        for item in (row.get("expected_quantities") or "").split(";")
        if item.strip()
    ]


def quantity_fragment_for(name: str, fragments: list[str]) -> str:
    name_tokens = token_set(name)
    if not name_tokens:
        return name

    best_fragment = ""
    best_overlap = 0
    for fragment in fragments:
        fragment_tokens = token_set(fragment)
        overlap = len(name_tokens & fragment_tokens)
        if overlap > best_overlap:
            best_fragment = fragment
            best_overlap = overlap

    return best_fragment if best_overlap > 0 else name


def parse_candidate_quantity(raw_text: str) -> tuple[float | None, str | None]:
    compact = raw_text.replace(",", ".")
    fraction_match = re.search(r"\b(\d+)\s*/\s*(\d+)\b", compact)
    if fraction_match:
        denominator = float(fraction_match.group(2))
        if denominator != 0:
            return float(fraction_match.group(1)) / denominator, "piece"
    if re.search(r"\bmezz[ao]\b", compact, flags=re.IGNORECASE):
        return 0.5, "piece"
    match = re.search(r"(\d+(?:\.\d+)?)\s*(g|ml)\b", compact, flags=re.IGNORECASE)
    if match:
        return float(match.group(1)), match.group(2).lower()
    if re.search(r"\bq\.?b\.?\b", compact, flags=re.IGNORECASE):
        return None, None
    piece_match = re.search(r"\b(\d+(?:\.\d+)?)\b", compact)
    if piece_match:
        return float(piece_match.group(1)), "piece"
    return None, None


def ingredient_rows(response: dict[str, Any]) -> list[dict[str, Any]]:
    result = response.get("result")
    if not isinstance(result, dict):
        return []
    ingredients = result.get("ingredients")
    if not isinstance(ingredients, list):
        return []
    return [ingredient for ingredient in ingredients if isinstance(ingredient, dict)]


def ingredient_names(response: dict[str, Any]) -> list[str]:
    names: list[str] = []
    for ingredient in ingredient_rows(response):
        if isinstance(ingredient.get("name"), str):
            names.append(ingredient["name"])
    return names


def ingredient_details(response: dict[str, Any]) -> list[dict[str, Any]]:
    details: list[dict[str, Any]] = []
    for ingredient in ingredient_rows(response):
        name = ingredient.get("name")
        if not isinstance(name, str):
            continue
        details.append({
            "name": name,
            "quantity": ingredient.get("quantity"),
            "unit": ingredient.get("unit"),
            "status": ingredient.get("status"),
            "confidence": ingredient.get("confidence"),
        })
    return details


def result_steps(result: dict[str, Any]) -> list[str]:
    steps = result.get("steps")
    if not isinstance(steps, list):
        return []
    return [
        step.strip()
        for step in steps
        if isinstance(step, str) and step.strip()
    ]


def quantity_expectations(row: dict[str, str]) -> list[dict[str, Any]]:
    expectations: list[dict[str, Any]] = []
    for fragment in expected_quantity_fragments(row):
        quantity, unit = parse_candidate_quantity(fragment)
        if quantity is None or unit is None:
            continue
        name = re.sub(r"\b\d+(?:[.,]\d+)?\s*(?:g|ml)?\b", "", fragment, flags=re.IGNORECASE)
        name = re.sub(r"\bq\.?b\.?\b", "", name, flags=re.IGNORECASE)
        name = normalize_text(name)
        if not name:
            continue
        expectations.append({
            "fragment": fragment,
            "name": name,
            "quantity": quantity,
            "unit": unit,
        })
    return expectations


def quantity_matches(row: dict[str, str], actual_details: list[dict[str, Any]]) -> tuple[list[str], list[str]]:
    matched: list[str] = []
    missing: list[str] = []

    for expectation in quantity_expectations(row):
        expectation_tokens = token_set(str(expectation["name"]))
        found = False
        for actual in actual_details:
            actual_tokens = token_set(str(actual.get("name") or ""))
            if expectation_tokens and expectation_tokens.isdisjoint(actual_tokens):
                continue
            try:
                actual_quantity = float(actual.get("quantity"))
            except (TypeError, ValueError):
                continue
            if actual.get("unit") == expectation["unit"] and abs(actual_quantity - float(expectation["quantity"])) < 0.0001:
                found = True
                break
        if found:
            matched.append(str(expectation["fragment"]))
        else:
            missing.append(str(expectation["fragment"]))

    return matched, missing


def matched_expectations(expected: list[str], actual: list[str]) -> tuple[list[str], list[str]]:
    actual_norm = [normalize_text(name) for name in actual]
    matched: list[str] = []
    missing: list[str] = []

    for expected_name in expected:
        expected_tokens = token_set(expected_name)
        expected_norm = normalize_text(expected_name)
        found = False
        for actual_name in actual_norm:
            if expected_norm and (expected_norm in actual_name or actual_name in expected_norm):
                found = True
                break
            actual_tokens = set(actual_name.split())
            if expected_tokens and expected_tokens.issubset(actual_tokens):
                found = True
                break
        if found:
            matched.append(expected_name)
        else:
            missing.append(expected_name)

    return matched, missing


def call_parse_recipe_caption(
    supabase_url: str,
    anon_key: str,
    token: str,
    caption: str,
    use_candidates: bool,
    row: dict[str, str],
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "caption": caption,
        "languageCode": "it",
    }
    if use_candidates:
        quantity_fragments = expected_quantity_fragments(row)
        payload["ingredientCandidates"] = [
            unresolved_candidate_payload(name, quantity_fragment_for(name, quantity_fragments))
            for name in expected_ingredients(row)
        ]

    return post_json(
        f"{supabase_url.rstrip('/')}/functions/v1/parse-recipe-caption",
        {
            "apikey": anon_key,
            "Authorization": f"Bearer {token}",
        },
        payload,
    )


def unresolved_candidate_payload(name: str, raw_text: str) -> dict[str, Any]:
    quantity, unit = parse_candidate_quantity(raw_text)
    return {
        "raw_text": raw_text,
        "normalized_text": name,
        "possible_quantity": quantity,
        "possible_unit": unit,
        "catalog_match": {
            "matchType": "none",
            "matchedIngredientId": None,
            "confidence": 0,
        },
    }


def response_summary(row: dict[str, str], response: dict[str, Any]) -> dict[str, Any]:
    expected = expected_ingredients(row)
    actual = ingredient_names(response)
    actual_details = ingredient_details(response)
    matched, missing = matched_expectations(expected, actual)
    matched_quantities, missing_quantities = quantity_matches(row, actual_details)
    result = response.get("result") if isinstance(response.get("result"), dict) else {}
    steps = result_steps(result)
    agent = result.get("smartImportAgent") if isinstance(result, dict) and isinstance(result.get("smartImportAgent"), dict) else {}
    scorecard = agent.get("scorecard") if isinstance(agent.get("scorecard"), dict) else {}
    auto_fix_plan = agent.get("autoFixPlan") if isinstance(agent.get("autoFixPlan"), dict) else {}
    meta = response.get("meta") if isinstance(response.get("meta"), dict) else {}
    return {
        "id": row.get("id"),
        "difficulty": row.get("difficulty"),
        "theme": row.get("theme"),
        "ok": response.get("ok") is True,
        "usedServerLLM": meta.get("usedServerLLM"),
        "draftQuality": agent.get("draftQuality"),
        "nextAction": agent.get("nextAction"),
        "actionReason": agent.get("actionReason"),
        "scorecard": {
            "blockingIssues": scorecard.get("blockingIssues") or [],
            "niceToFix": scorecard.get("niceToFix") or [],
            "autoFixable": scorecard.get("autoFixable") or [],
        },
        "autoFixPlan": {
            "safeFixes": auto_fix_plan.get("safeFixes") or [],
            "deferredFixes": auto_fix_plan.get("deferredFixes") or [],
        },
        "appliedAutoFixes": agent.get("appliedAutoFixes") or [],
        "title": result.get("title") if isinstance(result.get("title"), str) else None,
        "step_count": len(steps),
        "steps": steps,
        "confidence": result.get("confidence"),
        "servings": result.get("servings"),
        "prepTimeMinutes": result.get("prepTimeMinutes"),
        "cookTimeMinutes": result.get("cookTimeMinutes"),
        "expected_count": len(expected),
        "actual_count": len(actual),
        "matched_count": len(matched),
        "missing": missing,
        "expected_quantity_count": len(quantity_expectations(row)),
        "matched_quantity_count": len(matched_quantities),
        "missing_quantities": missing_quantities,
        "actual": actual,
        "actual_details": actual_details,
        "reviewHints": agent.get("reviewHints") or [],
        "passes": [
            item.get("name")
            for item in agent.get("passes", [])
            if isinstance(item, dict)
        ] if isinstance(agent, dict) else [],
    }


def error_summary(row: dict[str, str], error: Exception) -> dict[str, Any]:
    return {
        "id": row.get("id"),
        "difficulty": row.get("difficulty"),
        "theme": row.get("theme"),
        "ok": False,
        "usedServerLLM": None,
        "draftQuality": None,
        "nextAction": None,
        "actionReason": None,
        "scorecard": {
            "blockingIssues": [],
            "niceToFix": [],
            "autoFixable": [],
        },
        "autoFixPlan": {
            "safeFixes": [],
            "deferredFixes": [],
        },
        "appliedAutoFixes": [],
        "title": None,
        "step_count": 0,
        "steps": [],
        "confidence": None,
        "servings": None,
        "prepTimeMinutes": None,
        "cookTimeMinutes": None,
        "expected_count": len(expected_ingredients(row)),
        "actual_count": 0,
        "matched_count": 0,
        "missing": expected_ingredients(row),
        "expected_quantity_count": len(quantity_expectations(row)),
        "matched_quantity_count": 0,
        "missing_quantities": [expectation["fragment"] for expectation in quantity_expectations(row)],
        "actual": [],
        "actual_details": [],
        "reviewHints": [],
        "passes": [],
        "error": str(error),
    }


def assert_scorecard_expectations(
    summaries: list[dict[str, Any]],
    expected_blocking: set[str],
    expected_nice_to_fix: set[str],
    expected_auto_fixable: set[str],
) -> None:
    if not expected_blocking and not expected_nice_to_fix and not expected_auto_fixable:
        return

    failures: list[str] = []
    for summary in summaries:
        scorecard = summary.get("scorecard") if isinstance(summary.get("scorecard"), dict) else {}
        actual_blocking = set(scorecard.get("blockingIssues") or [])
        actual_nice_to_fix = set(scorecard.get("niceToFix") or [])
        actual_auto_fixable = set(scorecard.get("autoFixable") or [])

        missing_blocking = sorted(expected_blocking - actual_blocking)
        missing_nice_to_fix = sorted(expected_nice_to_fix - actual_nice_to_fix)
        missing_auto_fixable = sorted(expected_auto_fixable - actual_auto_fixable)

        if missing_blocking or missing_nice_to_fix or missing_auto_fixable:
            failures.append(
                f"{summary.get('id')}: "
                f"missing blocking={missing_blocking} "
                f"nice_to_fix={missing_nice_to_fix} "
                f"auto_fixable={missing_auto_fixable}"
            )

    if failures:
        raise RuntimeError("Scorecard expectations failed: " + "; ".join(failures))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captions-csv", type=Path, default=DEFAULT_CAPTIONS_CSV)
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument("--anon-key", default=os.environ.get("SUPABASE_ANON_KEY", ""))
    parser.add_argument("--limit", type=int, default=3)
    parser.add_argument("--case-id", action="append", default=[])
    parser.add_argument("--difficulty", action="append", default=[])
    parser.add_argument("--sleep-seconds", type=float, default=2.2)
    parser.add_argument("--use-temp-user", action="store_true")
    parser.add_argument("--with-candidates", action="store_true", help="Send expected ingredients as unresolved Swift-like candidates.")
    parser.add_argument("--expect-blocking", action="append", default=[], help="Assert every selected case includes this scorecard blocking issue.")
    parser.add_argument("--expect-nice-to-fix", action="append", default=[], help="Assert every selected case includes this scorecard nice-to-fix issue.")
    parser.add_argument("--expect-auto-fixable", action="append", default=[], help="Assert every selected case includes this scorecard auto-fixable issue.")
    parser.add_argument("--json", action="store_true", dest="json_output")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    if args.limit < 1 or args.limit > 10:
        raise RuntimeError("--limit must be between 1 and 10 to keep LLM spend bounded.")

    difficulties = {value.strip().lower() for value in args.difficulty if value.strip()}
    case_ids = [value.strip() for value in args.case_id if value.strip()]
    if case_ids and len(case_ids) > 10:
        raise RuntimeError("At most 10 explicit --case-id values are allowed.")

    cases = load_caption_cases(args.captions_csv, args.limit, difficulties, case_ids)
    if not cases:
        raise RuntimeError("No caption cases selected.")

    if args.dry_run:
        preview = [
            {
                "id": row.get("id"),
                "difficulty": row.get("difficulty"),
                "theme": row.get("theme"),
                "expected": expected_ingredients(row),
                "caption_preview": (row.get("caption") or "")[:180],
            }
            for row in cases
        ]
        print(json.dumps(preview, ensure_ascii=False, indent=2) if args.json_output else f"Dry run selected {len(preview)} caption cases.")
        return 0

    if not args.anon_key:
        raise RuntimeError("SUPABASE_ANON_KEY is required.")

    cleanup_user: tuple[str, str] | None = None
    summaries: list[dict[str, Any]] = []
    try:
        token, cleanup_user = auth_token(args.supabase_url, args.anon_key, args.use_temp_user)
        for index, row in enumerate(cases):
            if index > 0:
                time.sleep(max(0, args.sleep_seconds))
            try:
                response = call_parse_recipe_caption(
                    args.supabase_url,
                    args.anon_key,
                    token,
                    row.get("caption") or "",
                    args.with_candidates,
                    row,
                )
                summaries.append(response_summary(row, response))
            except Exception as error:
                summaries.append(error_summary(row, error))
    finally:
        if cleanup_user is not None:
            user_id, service_role_key = cleanup_user
            try:
                delete_temp_user(args.supabase_url, service_role_key, user_id)
            except Exception as error:
                print(f"WARN failed to delete temporary user {user_id}: {error}", file=sys.stderr)

    assert_scorecard_expectations(
        summaries,
        {value.strip() for value in args.expect_blocking if value.strip()},
        {value.strip() for value in args.expect_nice_to_fix if value.strip()},
        {value.strip() for value in args.expect_auto_fixable if value.strip()},
    )

    if args.json_output:
        print(json.dumps({"ok": all(summary.get("ok") for summary in summaries), "summaries": summaries}, ensure_ascii=False, indent=2))
    else:
        for summary in summaries:
            print(
                f"{summary['id']} {summary['difficulty']} {summary['theme']}: "
                f"matched {summary['matched_count']}/{summary['expected_count']} "
                f"quantities {summary['matched_quantity_count']}/{summary['expected_quantity_count']} "
                f"steps={summary['step_count']} title={bool(summary['title'])} "
                f"usedLLM={summary['usedServerLLM']} quality={summary['draftQuality']} "
                f"next={summary['nextAction']} "
                f"missing={summary['missing']} missing_quantities={summary['missing_quantities']}"
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
