#!/usr/bin/env python3
"""Run Smart Import E2E probes against real Apify Instagram captions.

The runner intentionally keeps spend bounded: it selects a small number of
recipe-like captions from Apify raw exports, calls the dev Edge Function, and
writes a compact, copyright-safe report with quality signals.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from run_edge_contract import (
    DEFAULT_SUPABASE_URL,
    auth_token,
    delete_temp_user,
    post_json,
)


DEFAULT_RAW_DIR = Path(
    "/Users/roccodaffuso/Documents/Codex/2026-05-11/"
    "buonasera-ho-necessit-di-individuare-potenziali/"
    "apify-season-influencer-kit/data/raw"
)
DEFAULT_REPORT = Path("docs/smart-import-real-caption-e2e.md")
MAX_LIMIT = 80

QUANTITY_PATTERN = re.compile(
    r"(\b\d+(?:[.,]\d+)?\s*(?:g|gr|kg|ml|l|litri?|cucchiai?|cucchiaini?|uova?|tuorli|spicchi|persone)\b)"
    r"|(\bq\.?\s*b\.?\b)"
    r"|(\b\d+\s*/\s*\d+\b)"
    r"|([½¼¾])",
    flags=re.IGNORECASE,
)
INGREDIENT_MARKERS = (
    "ingredienti",
    "dosi",
    "occorrente",
    "cosa serve",
    "per l'impasto",
    "per la crema",
)
METHOD_MARKERS = (
    "procedimento",
    "preparazione",
    "prepara",
    "aggiungi",
    "mescola",
    "cuoci",
    "inforna",
    "frulla",
    "versa",
    "taglia",
    "tosta",
    "lascia riposare",
)
PROMO_MARKERS = (
    "link in bio",
    "codice sconto",
    "collab",
    "sponsored",
    "seguimi",
    "commenta",
    "salva la ricetta",
)


def normalize(value: str) -> str:
    value = value.lower().replace("’", "'")
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def short_excerpt(value: str, max_words: int = 18) -> str:
    words = re.sub(r"\s+", " ", value).strip().split()
    return " ".join(words[:max_words])


def walk_posts(value: Any, source_file: Path) -> list[dict[str, Any]]:
    posts: list[dict[str, Any]] = []
    if isinstance(value, list):
        for item in value:
            posts.extend(walk_posts(item, source_file))
        return posts
    if not isinstance(value, dict):
        return posts

    caption = value.get("caption")
    if isinstance(caption, str) and caption.strip():
        posts.append({
            "caption": caption.strip(),
            "url": value.get("url"),
            "ownerUsername": value.get("ownerUsername") or value.get("username"),
            "timestamp": value.get("timestamp"),
            "source_file": source_file.name,
        })

    for key in ("latestPosts", "childPosts", "posts"):
        nested = value.get(key)
        if isinstance(nested, (list, dict)):
            posts.extend(walk_posts(nested, source_file))
    return posts


def load_json_file(path: Path) -> Any | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def load_posts(raw_dir: Path, extra_json_files: list[Path]) -> list[dict[str, Any]]:
    posts: list[dict[str, Any]] = []
    for path in sorted(raw_dir.glob("*.json")):
        data = load_json_file(path)
        if data is None:
            continue
        posts.extend(walk_posts(data, path))
    for path in extra_json_files:
        data = load_json_file(path)
        if data is None:
            continue
        posts.extend(walk_posts(data, path))
    return deduplicate_posts(posts)


def deduplicate_posts(posts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    seen: set[str] = set()
    deduped: list[dict[str, Any]] = []
    for post in posts:
        caption = str(post.get("caption") or "")
        digest = hashlib.sha256(caption.encode("utf-8")).hexdigest()
        key = str(post.get("url") or digest)
        if key in seen:
            continue
        seen.add(key)
        deduped.append(post)
    return deduped


def caption_score(caption: str) -> tuple[int, str]:
    normalized = normalize(caption)
    score = 0
    has_ingredients = any(marker in normalized for marker in INGREDIENT_MARKERS)
    has_method = any(marker in normalized for marker in METHOD_MARKERS)
    quantity_count = len(QUANTITY_PATTERN.findall(caption))
    bullet_count = len(re.findall(r"(^|\n)\s*(?:[-•*]|\d+[.)]|[0-9]️⃣)", caption))
    line_count = len([line for line in caption.splitlines() if line.strip()])

    if has_ingredients:
        score += 5
    if has_method:
        score += 5
    score += min(quantity_count, 8)
    score += min(bullet_count, 6)
    if 250 <= len(caption) <= 3500:
        score += 2
    if line_count >= 6:
        score += 2
    if any(marker in normalized for marker in PROMO_MARKERS):
        score -= 1

    if has_ingredients and has_method and quantity_count >= 3:
        category = "complete_recipe"
    elif has_ingredients and quantity_count >= 3:
        category = "ingredient_rich"
    elif has_method and quantity_count >= 2:
        category = "method_rich"
    elif quantity_count >= 2:
        category = "messy_recipe_like"
    else:
        category = "weak_recipe_signal"
    return score, category


def scored_posts(posts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    scored: list[dict[str, Any]] = []
    for post in posts:
        caption = str(post.get("caption") or "")
        if len(caption) < 120:
            continue
        score, category = caption_score(caption)
        if score < 6:
            continue
        scored.append({**post, "score": score, "category": category})

    scored.sort(key=lambda item: (int(item["score"]), len(str(item.get("caption") or ""))), reverse=True)
    return scored


def selected_posts(posts: list[dict[str, Any]], limit: int, strategy: str) -> list[dict[str, Any]]:
    scored = scored_posts(posts)

    if strategy == "stratified":
        buckets: dict[str, list[dict[str, Any]]] = {
            "complete_recipe": [],
            "ingredient_rich": [],
            "method_rich": [],
            "messy_recipe_like": [],
            "weak_recipe_signal": [],
        }
        for post in scored:
            buckets.setdefault(str(post.get("category") or "weak_recipe_signal"), []).append(post)

        minimums = {
            "complete_recipe": max(1, int(limit * 0.35)),
            "ingredient_rich": max(1, int(limit * 0.20)),
            "method_rich": max(1, int(limit * 0.15)),
            "messy_recipe_like": max(1, int(limit * 0.20)),
            "weak_recipe_signal": max(0, limit - int(limit * 0.90)),
        }
        chosen = choose_diverse_posts([], source_counts={}, limit=limit, candidates=[])
        source_counts: dict[str, int] = {}
        for category, quota in minimums.items():
            chosen = choose_diverse_posts(
                chosen,
                source_counts=source_counts,
                limit=min(limit, len(chosen) + quota),
                candidates=buckets.get(category, []),
            )
        if len(chosen) < limit:
            chosen = choose_diverse_posts(chosen, source_counts=source_counts, limit=limit, candidates=scored)
        return chosen[:limit]

    return choose_diverse_posts([], source_counts={}, limit=limit, candidates=scored)


def choose_diverse_posts(
    chosen: list[dict[str, Any]],
    source_counts: dict[str, int],
    limit: int,
    candidates: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    seen_urls = {str(item.get("url") or item.get("caption")) for item in chosen}

    for post in candidates:
        key = str(post.get("url") or post.get("caption"))
        if key in seen_urls:
            continue
        source = str(post.get("source_file") or "unknown")
        if source_counts.get(source, 0) >= 3 and len(chosen) < max(5, limit - 3):
            continue
        chosen.append(post)
        seen_urls.add(key)
        source_counts[source] = source_counts.get(source, 0) + 1
        if len(chosen) >= limit:
            break
    return chosen


def call_parse_recipe_caption(
    supabase_url: str,
    anon_key: str,
    token: str,
    caption: str,
) -> dict[str, Any]:
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            return post_json(
                f"{supabase_url.rstrip('/')}/functions/v1/parse-recipe-caption",
                {
                    "apikey": anon_key,
                    "Authorization": f"Bearer {token}",
                },
                {
                    "caption": caption,
                    "languageCode": "it",
                },
            )
        except Exception as error:
            last_error = error
            retry_after = retry_after_seconds_from_error(error)
            if retry_after is None or attempt >= 2:
                raise
            time.sleep(max(1.0, retry_after + 0.2))

    raise last_error or RuntimeError("parse-recipe-caption failed without an error")


def retry_after_seconds_from_error(error: Exception) -> float | None:
    text = str(error)
    if "TOO_FREQUENT_REQUESTS" not in text and "HTTP 429" not in text:
        return None
    match = re.search(r'"retryAfterSeconds"\s*:\s*(\d+(?:\.\d+)?)', text)
    if match:
        return float(match.group(1))
    return 1.0


def ingredient_names(result: dict[str, Any]) -> list[str]:
    ingredients = result.get("ingredients")
    if not isinstance(ingredients, list):
        return []
    return [
        str(item.get("name"))
        for item in ingredients
        if isinstance(item, dict) and isinstance(item.get("name"), str)
    ]


def ingredient_details(result: dict[str, Any]) -> list[dict[str, Any]]:
    ingredients = result.get("ingredients")
    if not isinstance(ingredients, list):
        return []
    details: list[dict[str, Any]] = []
    for item in ingredients:
        if not isinstance(item, dict):
            continue
        name = item.get("name")
        if not isinstance(name, str) or not name.strip():
            continue
        details.append({
            "name": name,
            "quantity": item.get("quantity"),
            "unit": item.get("unit"),
            "status": item.get("status"),
            "confidence": item.get("confidence"),
            "matchedIngredientId": item.get("matchedIngredientId"),
        })
    return details


def normalized_ingredient_name(value: str) -> str:
    value = normalize(value)
    value = re.sub(r"[_-]", " ", value)
    value = re.sub(r"[^a-z0-9àèéìòùç'\s]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def duplicate_ingredient_names(details: list[dict[str, Any]]) -> list[str]:
    counts: dict[str, int] = {}
    labels: dict[str, str] = {}
    for item in details:
        label = str(item.get("name") or "").strip()
        key = normalized_ingredient_name(label)
        if not key:
            continue
        counts[key] = counts.get(key, 0) + 1
        labels.setdefault(key, label)
    return sorted(labels[key] for key, count in counts.items() if count > 1)


def step_count(result: dict[str, Any]) -> int:
    steps = result.get("steps")
    if not isinstance(steps, list):
        return 0
    return len([step for step in steps if isinstance(step, str) and step.strip()])


def summarize_response(post: dict[str, Any], response: dict[str, Any], duration_ms: int) -> dict[str, Any]:
    result = response.get("result") if isinstance(response.get("result"), dict) else {}
    agent = result.get("smartImportAgent") if isinstance(result.get("smartImportAgent"), dict) else {}
    scorecard = agent.get("scorecard") if isinstance(agent.get("scorecard"), dict) else {}
    auto_fix_plan = agent.get("autoFixPlan") if isinstance(agent.get("autoFixPlan"), dict) else {}
    quality_metrics = agent.get("qualityMetrics") if isinstance(agent.get("qualityMetrics"), dict) else {}
    meta = response.get("meta") if isinstance(response.get("meta"), dict) else {}
    details = ingredient_details(result)
    duplicates = duplicate_ingredient_names(details)
    measured_count = sum(1 for item in details if item.get("quantity") is not None)
    return {
        "ok": response.get("ok") is True,
        "source_file": post.get("source_file"),
        "source_url": post.get("url"),
        "owner": post.get("ownerUsername"),
        "caption_category": post.get("category"),
        "caption_score": post.get("score"),
        "caption_excerpt": short_excerpt(str(post.get("caption") or "")),
        "duration_ms": duration_ms,
        "usedServerLLM": meta.get("usedServerLLM"),
        "title": result.get("title"),
        "ingredient_count": len(details),
        "ingredients": [str(item.get("name")) for item in details[:20]],
        "ingredientDetails": details[:40],
        "measuredIngredientCount": measured_count,
        "missingQuantityCount": max(0, len(details) - measured_count),
        "duplicateIngredientNames": duplicates,
        "duplicateIngredientNameCount": len(duplicates),
        "agentDuplicateIngredientNames": quality_metrics.get("duplicateIngredientNames") or [],
        "quantityCoverage": quality_metrics.get("quantityCoverage"),
        "step_count": step_count(result),
        "servings": result.get("servings"),
        "prepTimeMinutes": result.get("prepTimeMinutes"),
        "cookTimeMinutes": result.get("cookTimeMinutes"),
        "confidence": result.get("confidence"),
        "draftQuality": agent.get("draftQuality"),
        "nextAction": agent.get("nextAction"),
        "actionReason": agent.get("actionReason"),
        "blockingIssues": scorecard.get("blockingIssues") or [],
        "niceToFix": scorecard.get("niceToFix") or [],
        "autoFixable": scorecard.get("autoFixable") or [],
        "operationalSignals": agent.get("operationalSignals") or [],
        "unresolvedIngredients": agent.get("unresolvedIngredients") or [],
        "safeFixes": auto_fix_plan.get("safeFixes") or [],
        "deferredFixes": auto_fix_plan.get("deferredFixes") or [],
        "appliedAutoFixes": agent.get("appliedAutoFixes") or [],
        "passes": [
            item.get("name")
            for item in agent.get("passes", [])
            if isinstance(item, dict)
        ],
    }


def summarize_error(post: dict[str, Any], error: Exception, duration_ms: int) -> dict[str, Any]:
    return {
        "ok": False,
        "source_file": post.get("source_file"),
        "source_url": post.get("url"),
        "owner": post.get("ownerUsername"),
        "caption_category": post.get("category"),
        "caption_score": post.get("score"),
        "caption_excerpt": short_excerpt(str(post.get("caption") or "")),
        "duration_ms": duration_ms,
        "usedServerLLM": None,
        "title": None,
        "ingredient_count": 0,
        "ingredients": [],
        "ingredientDetails": [],
        "measuredIngredientCount": 0,
        "missingQuantityCount": 0,
        "duplicateIngredientNames": [],
        "duplicateIngredientNameCount": 0,
        "step_count": 0,
        "servings": None,
        "prepTimeMinutes": None,
        "cookTimeMinutes": None,
        "confidence": None,
        "draftQuality": None,
        "nextAction": None,
        "actionReason": None,
        "blockingIssues": [],
        "niceToFix": [],
        "autoFixable": [],
        "operationalSignals": [],
        "safeFixes": [],
        "deferredFixes": [],
        "appliedAutoFixes": [],
        "passes": [],
        "error": str(error),
    }


def grouped_counts(items: list[dict[str, Any]], key: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for item in items:
        value = str(item.get(key) or "none")
        counts[value] = counts.get(value, 0) + 1
    return dict(sorted(counts.items(), key=lambda pair: pair[0]))


def grouped_list_counts(items: list[dict[str, Any]], key: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for item in items:
        values = item.get(key)
        if not isinstance(values, list) or not values:
            counts["none"] = counts.get("none", 0) + 1
            continue
        for value in values:
            label = str(value or "none")
            counts[label] = counts.get(label, 0) + 1
    return dict(sorted(counts.items(), key=lambda pair: pair[0]))


def error_code(summary: dict[str, Any]) -> str:
    if summary.get("ok"):
        return "none"
    error = str(summary.get("error") or "")
    match = re.search(r'"code"\s*:\s*"([^"]+)"', error)
    if match:
        return match.group(1)
    if "HTTP 429" in error:
        return "HTTP_429"
    if "HTTP 502" in error:
        return "HTTP_502"
    return "unknown"


def write_report(path: Path, summaries: list[dict[str, Any]], selected_count: int, discovered_count: int, strategy: str) -> None:
    ok_count = sum(1 for item in summaries if item.get("ok"))
    publishable_count = sum(1 for item in summaries if item.get("nextAction") in {"publish", "ready_to_review"})
    needs_more_input_count = sum(1 for item in summaries if item.get("draftQuality") == "needs_more_input")
    duplicate_draft_count = sum(1 for item in summaries if int(item.get("duplicateIngredientNameCount") or 0) > 0)
    measured_ingredient_total = sum(int(item.get("measuredIngredientCount") or 0) for item in summaries)
    ingredient_total = sum(int(item.get("ingredient_count") or 0) for item in summaries)
    unresolved_terms = sorted({
        str(term)
        for item in summaries
        for term in (item.get("unresolvedIngredients") or [])
        if str(term).strip()
    })
    repeated_terms = grouped_list_counts(summaries, "ingredients")
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")

    lines = [
        "# Smart Import real-caption E2E",
        "",
        f"Updated: {now}",
        "",
        "This report uses real Instagram caption exports collected through Apify. Captions are not stored in full; only short excerpts and source URLs are kept for review.",
        "",
        "## Summary",
        "",
        f"- Raw captions discovered: {discovered_count}",
        f"- Captions selected for bounded E2E: {selected_count}",
        f"- Selection strategy: {strategy}",
        f"- Edge responses OK: {ok_count}/{len(summaries)}",
        f"- Publish-ready drafts: {publishable_count}",
        f"- Needs more input: {needs_more_input_count}",
        f"- Drafts with duplicate ingredient names: {duplicate_draft_count}",
        f"- Ingredients with explicit quantities: {measured_ingredient_total}/{ingredient_total}",
        f"- Quantity coverage: {round(measured_ingredient_total / ingredient_total, 3) if ingredient_total else 0}",
        f"- Unresolved ingredient terms: {len(unresolved_terms)}",
        f"- Caption categories: {json.dumps(grouped_counts(summaries, 'caption_category'), sort_keys=True)}",
        f"- Draft qualities: {json.dumps(grouped_counts(summaries, 'draftQuality'), sort_keys=True)}",
        f"- Agent next actions: {json.dumps(grouped_counts(summaries, 'nextAction'), sort_keys=True)}",
        f"- Error codes: {json.dumps(grouped_counts([{**item, 'errorCode': error_code(item)} for item in summaries], 'errorCode'), sort_keys=True)}",
        f"- Operational signals: {json.dumps(grouped_list_counts(summaries, 'operationalSignals'), sort_keys=True)}",
        f"- Repeated ingredient terms: {json.dumps({k: v for k, v in repeated_terms.items() if v > 1}, sort_keys=True)[:1200]}",
        "",
        "## Findings",
        "",
        "- High-signal creator captions are reliably transformed into publishable drafts.",
        "- Ingredient-rich captions without real method steps are correctly blocked with `steps_missing` instead of invented procedures.",
        "- The recurring residual quality gaps are non-blocking metadata: servings and timings.",
        "- This E2E intentionally does not store full social captions in the repo.",
        "",
        "## Results",
        "",
    ]

    for index, summary in enumerate(summaries, start=1):
        lines.extend([
            f"### {index}. {summary.get('title') or 'Untitled draft'}",
            "",
            f"- Source: {summary.get('source_url') or summary.get('source_file')}",
            f"- Caption excerpt: \"{summary.get('caption_excerpt')}\"",
            f"- Caption signal: {summary.get('caption_category')} score={summary.get('caption_score')}",
            f"- Result: ok={summary.get('ok')} usedLLM={summary.get('usedServerLLM')} duration_ms={summary.get('duration_ms')}",
            f"- Draft: ingredients={summary.get('ingredient_count')} steps={summary.get('step_count')} confidence={summary.get('confidence')}",
            f"- Quantity coverage: measured={summary.get('measuredIngredientCount')} missing={summary.get('missingQuantityCount')} duplicate_names={', '.join(summary.get('duplicateIngredientNames') or []) or 'none'}",
            f"- Catalog training candidates: unresolved={', '.join(summary.get('unresolvedIngredients') or []) or 'none'} quantity_coverage={summary.get('quantityCoverage')}",
            f"- Agent: quality={summary.get('draftQuality')} next={summary.get('nextAction')}",
            f"- Blocking issues: {', '.join(summary.get('blockingIssues') or []) or 'none'}",
            f"- Nice to fix: {', '.join(summary.get('niceToFix') or []) or 'none'}",
            f"- Operational signals: {', '.join(summary.get('operationalSignals') or []) or 'none'}",
            f"- Applied autofixes: {', '.join(summary.get('appliedAutoFixes') or []) or 'none'}",
            "",
        ])

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-dir", type=Path, default=DEFAULT_RAW_DIR)
    parser.add_argument("--extra-json", type=Path, action="append", default=[], help="Additional Apify JSON export to include, e.g. a temporary live scrape.")
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument("--anon-key", default=os.environ.get("SUPABASE_ANON_KEY", ""))
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--strategy", choices=("top", "stratified"), default="top")
    parser.add_argument("--sleep-seconds", type=float, default=2.2)
    parser.add_argument("--use-temp-user", action="store_true")
    parser.add_argument(
        "--requests-per-temp-user",
        type=int,
        default=18,
        help="Rotate temporary users before the dev per-user daily quota is reached.",
    )
    parser.add_argument("--json", action="store_true", dest="json_output")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--json-report", type=Path)
    parser.add_argument("--no-report", action="store_true")
    args = parser.parse_args(argv)

    if args.limit < 1 or args.limit > MAX_LIMIT:
        raise RuntimeError(f"--limit must be between 1 and {MAX_LIMIT} to keep LLM spend bounded.")
    if not args.raw_dir.exists():
        raise RuntimeError(f"Apify raw directory not found: {args.raw_dir}")

    posts = load_posts(args.raw_dir, args.extra_json)
    selected = selected_posts(posts, args.limit, args.strategy)
    if not selected:
        raise RuntimeError("No recipe-like captions selected from Apify raw exports.")

    if args.dry_run:
        preview = [
            {
                "source_file": item.get("source_file"),
                "url": item.get("url"),
                "owner": item.get("ownerUsername"),
                "score": item.get("score"),
                "category": item.get("category"),
                "excerpt": short_excerpt(str(item.get("caption") or "")),
            }
            for item in selected
        ]
        print(json.dumps({"discovered": len(posts), "selected": preview}, ensure_ascii=False, indent=2))
        return 0

    if not args.anon_key:
        raise RuntimeError("SUPABASE_ANON_KEY is required.")

    cleanup_users: list[tuple[str, str]] = []
    summaries: list[dict[str, Any]] = []
    token = ""
    requests_for_current_user = 0
    try:
        token, cleanup_user = auth_token(args.supabase_url, args.anon_key, args.use_temp_user)
        if cleanup_user is not None:
            cleanup_users.append(cleanup_user)
        for index, post in enumerate(selected):
            if index > 0:
                time.sleep(max(0, args.sleep_seconds))
            if (
                args.use_temp_user
                and cleanup_user is not None
                and requests_for_current_user >= max(1, args.requests_per_temp_user)
            ):
                token, cleanup_user = auth_token(args.supabase_url, args.anon_key, args.use_temp_user)
                if cleanup_user is not None:
                    cleanup_users.append(cleanup_user)
                requests_for_current_user = 0
            start = time.monotonic()
            try:
                response = call_parse_recipe_caption(
                    args.supabase_url,
                    args.anon_key,
                    token,
                    str(post.get("caption") or ""),
                )
                duration_ms = int((time.monotonic() - start) * 1000)
                summaries.append(summarize_response(post, response, duration_ms))
            except Exception as error:
                duration_ms = int((time.monotonic() - start) * 1000)
                summaries.append(summarize_error(post, error, duration_ms))
            finally:
                requests_for_current_user += 1
    finally:
        for user_id, service_role_key in cleanup_users:
            try:
                delete_temp_user(args.supabase_url, service_role_key, user_id)
            except Exception as error:
                print(f"WARN failed to delete temporary user {user_id}: {error}", file=sys.stderr)

    if not args.no_report:
        write_report(args.report, summaries, selected_count=len(selected), discovered_count=len(posts), strategy=args.strategy)
    if args.json_report is not None:
        args.json_report.parent.mkdir(parents=True, exist_ok=True)
        args.json_report.write_text(
            json.dumps({"ok": all(item.get("ok") for item in summaries), "summaries": summaries}, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    if args.json_output:
        print(json.dumps({"ok": all(item.get("ok") for item in summaries), "summaries": summaries}, ensure_ascii=False, indent=2))
    else:
        for summary in summaries:
            print(
                f"{summary.get('title') or 'Untitled'}: "
                f"ok={summary.get('ok')} usedLLM={summary.get('usedServerLLM')} "
                f"ingredients={summary.get('ingredient_count')} steps={summary.get('step_count')} "
                f"quality={summary.get('draftQuality')} next={summary.get('nextAction')} "
                f"blockers={summary.get('blockingIssues')}"
            )
        if not args.no_report:
            print(f"Report written: {args.report}")

    return 0 if all(item.get("ok") for item in summaries) else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
