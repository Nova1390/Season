#!/usr/bin/env python3
"""Run bounded parallel Catalog Agent dry-run eval batches on dev.

The goal is to train/evaluate the agent, not to mutate catalog data. This
script invokes `run-catalog-agent-triage` with `dry_run=true`, aggregates run
summaries, and writes a compact report that can feed future prompt, validator,
or learning-memory changes.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import run_edge_contract as edge_contract
from run_edge_contract import DEFAULT_SUPABASE_URL


DEFAULT_SOURCES = [
    "smart_import_training_captions",
    "import",
    "import_recovery",
]
DEFAULT_REPORT = Path("docs/catalog-agent-parallel-eval-latest.json")
MAX_SOURCES = 8
MAX_LIMIT = 10
MAX_CONCURRENCY = 4


def invoke_agent(
    supabase_url: str,
    anon_key: str,
    operator_token: str,
    source_domain: str,
    limit: int,
    include_non_new: bool,
) -> dict[str, Any]:
    started_at = time.monotonic()
    payload = {
        "limit": limit,
        "dry_run": True,
        "source_domain": source_domain,
        "include_non_new": include_non_new,
    }
    try:
        response = edge_contract.post_json(
            f"{supabase_url.rstrip('/')}/functions/v1/run-catalog-agent-triage",
            {
                "apikey": anon_key,
                "Authorization": f"Bearer {anon_key}",
                "x-season-catalog-agent-token": operator_token,
            },
            payload,
        )
        ok = bool(response.get("ok"))
        error = response.get("error") if isinstance(response.get("error"), dict) else None
    except Exception as exc:
        response = {}
        ok = False
        error = {"code": "REQUEST_FAILED", "message": str(exc)}

    return {
        "source_domain": source_domain,
        "ok": ok,
        "error": error,
        "duration_ms": int((time.monotonic() - started_at) * 1000),
        "run_id": response.get("run_id"),
        "summary": compact_summary(response.get("summary")),
        "proposals": compact_proposals(response.get("proposals")),
    }


def compact_summary(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        return {}

    quality_gate = value.get("proposal_quality_gate")
    if not isinstance(quality_gate, dict):
        quality_gate = {}

    return {
        "items_in_snapshot": value.get("items_in_snapshot"),
        "items_sent_to_llm": value.get("items_sent_to_llm"),
        "proposals_returned": value.get("proposals_returned"),
        "proposals_persistable": value.get("proposals_persistable"),
        "proposals_blocked_by_quality_gate": value.get("proposals_blocked_by_quality_gate"),
        "proposals_created": value.get("proposals_created"),
        "skipped_recent_proposal": value.get("skipped_recent_proposal"),
        "dry_run": value.get("dry_run"),
        "usage": value.get("usage"),
        "training_signals": value.get("training_signals"),
        "learning_memory": value.get("learning_memory"),
        "reasoning_mode": value.get("reasoning_mode"),
        "quality_gate_issues": quality_gate.get("issues") or [],
        "quality_gate_error_count": quality_gate.get("error_count"),
        "quality_gate_warning_count": quality_gate.get("warning_count"),
    }


def compact_proposals(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    compact: list[dict[str, Any]] = []
    for proposal in value:
        if not isinstance(proposal, dict):
            continue
        compact.append({
            "proposal_type": proposal.get("proposal_type"),
            "normalized_text": proposal.get("normalized_text"),
            "risk_level": proposal.get("risk_level"),
            "status": proposal.get("status"),
            "quality_gate_status": proposal.get("quality_gate_status"),
        })
    return compact


def aggregate(results: list[dict[str, Any]]) -> dict[str, Any]:
    summaries = [result.get("summary") for result in results if isinstance(result.get("summary"), dict)]
    proposals = [
        proposal
        for result in results
        for proposal in result.get("proposals", [])
        if isinstance(proposal, dict)
    ]
    usage_rows = [
        summary.get("usage")
        for summary in summaries
        if isinstance(summary.get("usage"), dict)
    ]
    issues = [
        issue
        for summary in summaries
        for issue in (summary.get("quality_gate_issues") or [])
        if isinstance(issue, dict)
    ]

    return {
        "sources": len(results),
        "sources_ok": sum(1 for result in results if result.get("ok") is True),
        "sources_failed": sum(1 for result in results if result.get("ok") is not True),
        "runs": [result.get("run_id") for result in results if result.get("run_id") is not None],
        "items_sent_to_llm": sum_int(summary.get("items_sent_to_llm") for summary in summaries),
        "proposals_returned": sum_int(summary.get("proposals_returned") for summary in summaries),
        "proposals_persistable": sum_int(summary.get("proposals_persistable") for summary in summaries),
        "proposals_blocked_by_quality_gate": sum_int(summary.get("proposals_blocked_by_quality_gate") for summary in summaries),
        "proposals_created": sum_int(summary.get("proposals_created") for summary in summaries),
        "total_tokens": sum_int(usage.get("totalTokens") for usage in usage_rows),
        "input_tokens": sum_int(usage.get("inputTokens") for usage in usage_rows),
        "output_tokens": sum_int(usage.get("outputTokens") for usage in usage_rows),
        "proposal_type_counts": count_by_key(proposals, "proposal_type"),
        "quality_gate_issue_counts": count_by_key(issues, "code"),
    }


def sum_int(values: Any) -> int:
    total = 0
    for value in values:
        if isinstance(value, int):
            total += value
        elif isinstance(value, float):
            total += int(value)
    return total


def count_by_key(rows: list[dict[str, Any]], key: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for row in rows:
        value = row.get(key)
        label = str(value) if value is not None else "none"
        counts[label] = counts.get(label, 0) + 1
    return dict(sorted(counts.items(), key=lambda item: (-item[1], item[0])))


def parse_sources(raw_sources: list[str]) -> list[str]:
    sources: list[str] = []
    for raw in raw_sources:
        for item in raw.split(","):
            source = item.strip()
            if source and source not in sources:
                sources.append(source)
    return sources


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument("--anon-key", default=os.environ.get("SUPABASE_ANON_KEY", ""))
    parser.add_argument("--operator-token", default=os.environ.get("CATALOG_AGENT_OPERATOR_TOKEN", ""))
    parser.add_argument("--source", action="append", default=[], help="Source domain. Can be repeated or comma-separated.")
    parser.add_argument("--limit", type=int, default=2)
    parser.add_argument("--concurrency", type=int, default=3)
    parser.add_argument("--include-non-new", action="store_true", default=True)
    parser.add_argument("--new-only", action="store_true", help="Only include new observations.")
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=int(os.environ.get("CATALOG_AGENT_EVAL_TIMEOUT_SECONDS", "75")),
        help="HTTP read timeout for each Edge Function call.",
    )
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args(argv)

    sources = parse_sources(args.source) if args.source else DEFAULT_SOURCES
    if not sources or len(sources) > MAX_SOURCES:
        raise RuntimeError(f"Provide between 1 and {MAX_SOURCES} sources.")
    if args.limit < 1 or args.limit > MAX_LIMIT:
        raise RuntimeError(f"--limit must be between 1 and {MAX_LIMIT}.")
    if args.concurrency < 1 or args.concurrency > MAX_CONCURRENCY:
        raise RuntimeError(f"--concurrency must be between 1 and {MAX_CONCURRENCY}.")
    if not args.anon_key:
        raise RuntimeError("SUPABASE_ANON_KEY or --anon-key is required.")
    if not args.operator_token:
        raise RuntimeError("CATALOG_AGENT_OPERATOR_TOKEN or --operator-token is required.")
    if args.timeout_seconds < 5 or args.timeout_seconds > 180:
        raise RuntimeError("--timeout-seconds must be between 5 and 180.")

    edge_contract.REQUEST_TIMEOUT_SECONDS = args.timeout_seconds

    include_non_new = not args.new_only
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(args.concurrency, len(sources))) as executor:
        futures = [
            executor.submit(
                invoke_agent,
                args.supabase_url,
                args.anon_key,
                args.operator_token,
                source,
                args.limit,
                include_non_new,
            )
            for source in sources
        ]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]

    results.sort(key=lambda row: str(row.get("source_domain") or ""))
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mode": "dry_run_parallel_eval",
        "mutation_policy": "non_mutating",
        "input": {
            "sources": sources,
            "limit": args.limit,
            "concurrency": args.concurrency,
            "include_non_new": include_non_new,
        },
        "aggregate": aggregate(results),
        "results": results,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if args.json_output:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        agg = report["aggregate"]
        print(
            "Catalog Agent parallel eval: "
            f"sources={agg['sources_ok']}/{agg['sources']} ok, "
            f"runs={agg['runs']}, "
            f"items_sent_to_llm={agg['items_sent_to_llm']}, "
            f"blocked={agg['proposals_blocked_by_quality_gate']}, "
            f"tokens={agg['total_tokens']}, "
            f"report={args.report}"
        )
    return 0 if all(result.get("ok") for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
