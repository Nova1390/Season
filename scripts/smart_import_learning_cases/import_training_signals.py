#!/usr/bin/env python3
"""Import reviewed Smart Import corpus signals into Catalog Agent training memory.

This is non-mutating with respect to catalog identity: it only upserts rows in
`catalog_agent_training_signals`. The Catalog Agent can read those rows as
advisory evidence; validators and governed apply paths remain mandatory.
"""

from __future__ import annotations

import argparse
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_CORPUS = Path("docs/smart-import-caption-training-corpus.json")
DEFAULT_SUPABASE_URL = "https://gyuedxycbnqljryenapx.supabase.co"
DEFAULT_SOURCE = "smart_import_real_caption_training"
MAX_LIMIT = 200


def post_json(url: str, headers: dict[str, str], payload: dict[str, Any]) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        method="POST",
        headers={**headers, "Content-Type": "application/json", "Accept": "application/json"},
        data=json.dumps(payload).encode("utf-8"),
    )
    try:
        with urllib.request.urlopen(request, timeout=30, context=build_ssl_context()) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"POST {url} failed: HTTP {exc.code}: {body}") from exc
    return json.loads(raw) if raw else {}


def build_ssl_context() -> ssl.SSLContext:
    try:
        import certifi  # type: ignore

        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def load_terms(path: Path) -> list[dict[str, Any]]:
    corpus = json.loads(path.read_text(encoding="utf-8"))
    terms = corpus.get("top_terms")
    if not isinstance(terms, list):
        raise RuntimeError(f"Missing top_terms array in {path}")
    return [term for term in terms if isinstance(term, dict)]


def selected_terms(
    terms: list[dict[str, Any]],
    limit: int,
    min_count: int,
    signals: set[str],
) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    for term in terms:
        count = int(term.get("count") or 0)
        signal = str(term.get("training_signal") or "")
        text = str(term.get("term") or "").strip()
        if not text or count < min_count:
            continue
        if signals and signal not in signals:
            continue
        selected.append(term)
        if len(selected) >= limit:
            break
    return selected


def compact_examples(term: dict[str, Any], max_examples: int) -> list[dict[str, Any]]:
    examples = term.get("examples")
    if not isinstance(examples, list):
        return []

    compact: list[dict[str, Any]] = []
    for example in examples[:max_examples]:
        if not isinstance(example, dict):
            continue
        compact.append({
            "source_file": example.get("source_file"),
            "url": example.get("url"),
            "owner": example.get("owner"),
            "caption_category": example.get("caption_category"),
            "caption_score": example.get("caption_score"),
            "excerpt": example.get("excerpt"),
        })
    return compact


def import_term(
    supabase_url: str,
    service_role_key: str,
    term: dict[str, Any],
    source: str,
    max_examples: int,
) -> dict[str, Any]:
    payload = {
        "p_normalized_text": term["term"],
        "p_training_signal": term["training_signal"],
        "p_occurrence_count": term["count"],
        "p_example_sources": compact_examples(term, max_examples),
        "p_source": source,
        "p_metadata": {
            "origin": "smart_import_caption_training_corpus",
            "importer": "scripts/smart_import_learning_cases/import_training_signals.py",
        },
    }
    return post_json(
        f"{supabase_url.rstrip('/')}/rest/v1/rpc/upsert_catalog_agent_training_signal",
        {
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
        },
        payload,
    )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", type=Path, default=DEFAULT_CORPUS)
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument("--service-role-key", default=os.environ.get("SUPABASE_SERVICE_ROLE_KEY", ""))
    parser.add_argument("--source", default=DEFAULT_SOURCE)
    parser.add_argument("--limit", type=int, default=40)
    parser.add_argument("--min-count", type=int, default=8)
    parser.add_argument("--signal", action="append", default=[])
    parser.add_argument("--max-examples", type=int, default=2)
    parser.add_argument("--sleep-seconds", type=float, default=0.05)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args(argv)

    if args.limit < 1 or args.limit > MAX_LIMIT:
        raise RuntimeError(f"--limit must be between 1 and {MAX_LIMIT}.")
    if args.min_count < 1:
        raise RuntimeError("--min-count must be >= 1.")

    terms = load_terms(args.corpus)
    signals = {signal.strip() for signal in args.signal if signal.strip()}
    selected = selected_terms(terms, args.limit, args.min_count, signals)

    if args.dry_run:
        preview = [
            {
                "term": term.get("term"),
                "count": term.get("count"),
                "training_signal": term.get("training_signal"),
                "examples": compact_examples(term, args.max_examples),
            }
            for term in selected
        ]
        print(json.dumps({"selected": preview}, ensure_ascii=False, indent=2) if args.json_output else f"Dry run selected {len(selected)} training signals.")
        return 0

    if not args.service_role_key:
        raise RuntimeError("SUPABASE_SERVICE_ROLE_KEY is required unless --dry-run is used.")

    imported: list[dict[str, Any]] = []
    failures: list[dict[str, Any]] = []
    for index, term in enumerate(selected):
        if index > 0:
            time.sleep(max(0, args.sleep_seconds))
        try:
            imported.append(import_term(args.supabase_url, args.service_role_key, term, args.source, args.max_examples))
        except Exception as error:
            failures.append({"term": term.get("term"), "error": str(error)})

    result = {
        "ok": not failures,
        "selected": len(selected),
        "imported": len(imported),
        "failed": len(failures),
        "failures": failures,
        "rows": imported,
    }
    if args.json_output:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"Imported {len(imported)}/{len(selected)} training signals; failed={len(failures)}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
