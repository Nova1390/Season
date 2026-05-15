#!/usr/bin/env python3
"""Import reviewed external catalog evidence into Catalog Agent memory.

This importer is intentionally non-mutating for Season catalog truth. It only
upserts rows into `catalog_agent_external_evidence`; the Catalog Agent can then
read those rows as advisory grounding evidence before proposing governed work.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_SUPABASE_URL = "https://gyuedxycbnqljryenapx.supabase.co"
MAX_LIMIT = 500
ALLOWED_SOURCE_KEYS = {
    "usda_fdc",
    "wikidata",
    "foodon",
    "open_food_facts",
    "manual_open_source_review",
    "crea_alimenti_nutrizione",
    "ieo_bda",
    "masaf_pat",
    "regional_pat",
}
ALLOWED_EVIDENCE_TYPES = {
    "ingredient_identity",
    "variant_identity",
    "synonym_or_label",
    "taxonomy",
    "nutrition",
    "branded_product",
    "packaged_product",
    "not_catalog_identity",
    "ambiguous_identity",
}
ALLOWED_TRUST_LEVELS = {"low", "medium", "high"}
ALLOWED_STATUSES = {"needs_review", "accepted", "implemented", "rejected", "superseded"}
ITALIAN_SOURCE_KEYS = {
    "crea_alimenti_nutrizione",
    "ieo_bda",
    "masaf_pat",
    "regional_pat",
}


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


def parse_json_value(value: Any, fallback: Any) -> Any:
    if value is None:
        return fallback
    if isinstance(value, (dict, list)):
        return value
    text = str(value).strip()
    if not text:
        return fallback
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Invalid JSON field value: {text[:80]}") from exc


def parse_aliases(value: Any) -> list[str]:
    parsed = parse_json_value(value, [])
    if isinstance(parsed, str):
        parsed = [item.strip() for item in parsed.split("|") if item.strip()]
    if not isinstance(parsed, list):
        raise RuntimeError("aliases must be a JSON array or pipe-separated string")
    aliases: list[str] = []
    for item in parsed:
        text = str(item).strip()
        if text:
            aliases.append(text)
    return aliases


def normalize_row(raw: dict[str, Any], row_number: int) -> dict[str, Any]:
    row = {str(key).strip(): value for key, value in raw.items()}
    normalized_text = str(row.get("normalized_text") or row.get("term") or "").strip().lower()
    source_key = str(row.get("source_key") or "").strip().lower()
    source_license = str(row.get("source_license") or "").strip()
    evidence_type = str(row.get("evidence_type") or "").strip().lower()
    evidence_summary = str(row.get("evidence_summary") or "").strip()
    trust_level = str(row.get("trust_level") or "medium").strip().lower()
    status = str(row.get("status") or "needs_review").strip().lower()
    confidence_raw = str(row.get("confidence_score") or "").strip()
    confidence_score = float(confidence_raw) if confidence_raw else None

    if not normalized_text:
        raise RuntimeError(f"row {row_number}: normalized_text is required")
    if source_key not in ALLOWED_SOURCE_KEYS:
        raise RuntimeError(f"row {row_number}: unsupported source_key {source_key!r}")
    if not source_license:
        raise RuntimeError(f"row {row_number}: source_license is required")
    if evidence_type not in ALLOWED_EVIDENCE_TYPES:
        raise RuntimeError(f"row {row_number}: unsupported evidence_type {evidence_type!r}")
    if trust_level not in ALLOWED_TRUST_LEVELS:
        raise RuntimeError(f"row {row_number}: unsupported trust_level {trust_level!r}")
    if status not in ALLOWED_STATUSES:
        raise RuntimeError(f"row {row_number}: unsupported status {status!r}")
    if not evidence_summary:
        raise RuntimeError(f"row {row_number}: evidence_summary is required")
    if confidence_score is not None and not 0 <= confidence_score <= 1:
        raise RuntimeError(f"row {row_number}: confidence_score must be between 0 and 1")

    return {
        "normalized_text": normalized_text,
        "source_key": source_key,
        "source_license": source_license,
        "evidence_type": evidence_type,
        "evidence_summary": evidence_summary,
        "source_record_id": optional_text(row.get("source_record_id")),
        "source_url": optional_text(row.get("source_url")),
        "source_license_url": optional_text(row.get("source_license_url")),
        "trust_level": trust_level,
        "confidence_score": confidence_score,
        "language_code": optional_text(row.get("language_code")),
        "canonical_label": optional_text(row.get("canonical_label")),
        "aliases": parse_aliases(row.get("aliases")),
        "metadata": parse_json_value(row.get("metadata"), {}),
        "raw_payload": parse_json_value(row.get("raw_payload"), {}),
        "status": status,
    }


def optional_text(value: Any) -> str | None:
    text = str(value or "").strip()
    return text or None


def load_rows(path: Path) -> list[dict[str, Any]]:
    if path.suffix.lower() == ".json":
        payload = json.loads(path.read_text(encoding="utf-8"))
        rows = payload.get("evidence") if isinstance(payload, dict) else payload
        if not isinstance(rows, list):
            raise RuntimeError(f"{path} must contain a JSON array or an object with an evidence array")
        return [normalize_row(row, index + 1) for index, row in enumerate(rows) if isinstance(row, dict)]

    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return [normalize_row(row, index + 2) for index, row in enumerate(reader)]


def filter_rows(
    rows: list[dict[str, Any]],
    source_keys: set[str],
    statuses: set[str],
    only_italian_sources: bool,
    limit: int,
) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    for row in rows:
        if source_keys and row["source_key"] not in source_keys:
            continue
        if statuses and row["status"] not in statuses:
            continue
        if only_italian_sources and row["source_key"] not in ITALIAN_SOURCE_KEYS:
            continue
        selected.append(row)
        if len(selected) >= limit:
            break
    return selected


def rpc_payload(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "p_normalized_text": row["normalized_text"],
        "p_source_key": row["source_key"],
        "p_source_license": row["source_license"],
        "p_evidence_type": row["evidence_type"],
        "p_evidence_summary": row["evidence_summary"],
        "p_source_record_id": row["source_record_id"],
        "p_source_url": row["source_url"],
        "p_source_license_url": row["source_license_url"],
        "p_trust_level": row["trust_level"],
        "p_confidence_score": row["confidence_score"],
        "p_language_code": row["language_code"],
        "p_canonical_label": row["canonical_label"],
        "p_aliases": row["aliases"],
        "p_metadata": row["metadata"],
        "p_raw_payload": row["raw_payload"],
        "p_status": row["status"],
    }


def import_row(supabase_url: str, service_role_key: str, row: dict[str, Any]) -> dict[str, Any]:
    return post_json(
        f"{supabase_url.rstrip('/')}/rest/v1/rpc/upsert_catalog_agent_external_evidence",
        {
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
        },
        rpc_payload(row),
    )


def summary_for(rows: list[dict[str, Any]]) -> dict[str, Any]:
    by_source: dict[str, int] = {}
    by_type: dict[str, int] = {}
    by_status: dict[str, int] = {}
    for row in rows:
        by_source[row["source_key"]] = by_source.get(row["source_key"], 0) + 1
        by_type[row["evidence_type"]] = by_type.get(row["evidence_type"], 0) + 1
        by_status[row["status"]] = by_status.get(row["status"], 0) + 1
    return {
        "selected": len(rows),
        "by_source": by_source,
        "by_type": by_type,
        "by_status": by_status,
        "preview": [
            {
                "normalized_text": row["normalized_text"],
                "source_key": row["source_key"],
                "evidence_type": row["evidence_type"],
                "status": row["status"],
                "trust_level": row["trust_level"],
                "confidence_score": row["confidence_score"],
            }
            for row in rows[:20]
        ],
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Reviewed CSV or JSON evidence file.")
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument("--service-role-key", default=os.environ.get("SUPABASE_SERVICE_ROLE_KEY", ""))
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--source-key", action="append", default=[])
    parser.add_argument("--status", action="append", default=[])
    parser.add_argument("--only-italian-sources", action="store_true")
    parser.add_argument("--sleep-seconds", type=float, default=0.05)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args(argv)

    if args.limit < 1 or args.limit > MAX_LIMIT:
        raise RuntimeError(f"--limit must be between 1 and {MAX_LIMIT}.")

    source_keys = {source.strip().lower() for source in args.source_key if source.strip()}
    unsupported_sources = source_keys - ALLOWED_SOURCE_KEYS
    if unsupported_sources:
        raise RuntimeError(f"Unsupported --source-key values: {sorted(unsupported_sources)}")

    statuses = {status.strip().lower() for status in args.status if status.strip()}
    unsupported_statuses = statuses - ALLOWED_STATUSES
    if unsupported_statuses:
        raise RuntimeError(f"Unsupported --status values: {sorted(unsupported_statuses)}")

    rows = load_rows(args.input)
    selected = filter_rows(rows, source_keys, statuses, args.only_italian_sources, args.limit)

    if args.dry_run:
        output = {"ok": True, "mode": "dry_run", **summary_for(selected)}
        print(json.dumps(output, ensure_ascii=False, indent=2) if args.json_output else f"Dry run selected {len(selected)} external evidence rows.")
        return 0

    if not args.service_role_key:
        raise RuntimeError("SUPABASE_SERVICE_ROLE_KEY is required unless --dry-run is used.")

    imported: list[dict[str, Any]] = []
    failures: list[dict[str, Any]] = []
    for index, row in enumerate(selected):
        if index > 0:
            time.sleep(max(0, args.sleep_seconds))
        try:
            imported.append(import_row(args.supabase_url, args.service_role_key, row))
        except Exception as error:
            failures.append({"normalized_text": row["normalized_text"], "source_key": row["source_key"], "error": str(error)})

    output = {
        "ok": not failures,
        "mode": "import",
        **summary_for(selected),
        "imported": len(imported),
        "failed": len(failures),
        "failures": failures,
        "rows": imported,
    }
    print(json.dumps(output, ensure_ascii=False, indent=2) if args.json_output else f"Imported {len(imported)}/{len(selected)} external evidence rows; failed={len(failures)}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
