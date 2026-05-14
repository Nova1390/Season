#!/usr/bin/env python3
"""Build a non-mutating Smart Import/Catalog training corpus from Apify captions.

This script does not call an LLM and does not write to Supabase. It profiles
real creator captions, extracts ingredient-like terms, and writes reviewable
training artifacts that can later feed Smart Import evals or Catalog Agent
learning after human/agent validation.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from run_real_caption_e2e import (
    DEFAULT_RAW_DIR,
    caption_score,
    load_posts,
    scored_posts,
    short_excerpt,
)


DEFAULT_REPORT = Path("docs/smart-import-caption-training-corpus.md")
DEFAULT_JSON = Path("docs/smart-import-caption-training-corpus.json")

SECTION_STOP_MARKERS = (
    "procedimento",
    "preparazione",
    "prepara",
    "preparate",
    "cottura",
    "forno",
    "salva",
    "seguimi",
    "commenta",
    "consigli",
)
INGREDIENT_SECTION_MARKERS = (
    "ingredienti",
    "dosi",
    "occorrente",
    "cosa serve",
)
NOISE_TERMS = {
    "ingredienti",
    "procedimento",
    "preparazione",
    "ricetta",
    "persone",
    "minuti",
    "circa",
    "q b",
    "qb",
    "quanto basta",
    "per persone",
    "proteine",
    "grassi",
    "carboidrati",
    "kcal",
    "calorie",
    "macro",
    "passo",
    "passaggi",
    "step",
    "procedi",
    "per",
    "una",
    "uno",
    "due",
    "tre",
}


def clean_line(value: str) -> str:
    value = value.replace("\u2060", " ")
    value = re.sub(r"[🍝🍅🥚🥛🧀🧈🍚🥄🧂🥩🥬🥔🥕🧅🧄🍋🍊🍎🍐🍓🍒🥥🌶️🌿✨❤️🔖👉👩‍🍳🧑‍🍳📝⸻]", " ", value)
    value = re.sub(r"^[\s\-•*·–—]+", "", value)
    value = re.sub(r"^\s*(?:\d+[.)]|[0-9]️⃣)\s*", "", value)
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def normalize_term(value: str) -> str:
    value = value.lower().replace("’", "'")
    value = re.sub(r"\([^)]*\)", " ", value)
    value = re.sub(r"\b\d+(?:[.,]\d+)?\s*(?:g|gr|kg|ml|l|lt|litri?|cucchiai?|cucchiaini?|pz|pezzi?|spicchi?|uova?|tuorli?)?\b", " ", value)
    value = re.sub(r"\bq\.?\s*b\.?\b", " ", value)
    value = re.sub(r"\b(?:pizzico|bustina|cucchiaio|cucchiaino|manciata|filo)\s+di\b", " ", value)
    value = re.sub(r"\b(?:a temperatura ambiente|fredd[ao] da frigo|cald[ao]|circa|facoltativ[ao])\b", " ", value)
    value = re.sub(r"[^a-zàèéìòùç'\s]+", " ", value)
    value = re.sub(r"\s+", " ", value).strip()
    if value.startswith("di "):
        value = value[3:]
    return value


def line_has_quantity(value: str) -> bool:
    return bool(re.search(r"\b\d+(?:[.,]\d+)?\s*(?:g|gr|kg|ml|l|lt|litri?|cucchiai?|cucchiaini?|pz|pezzi?|spicchi?|uova?|tuorli?)?\b|\bq\.?\s*b\.?\b|[½¼¾]", value, re.IGNORECASE))


def extract_ingredient_lines(caption: str) -> list[str]:
    lines = [clean_line(line) for line in caption.splitlines()]
    lines = [line for line in lines if line]
    extracted: list[str] = []
    in_ingredient_section = False

    for line in lines:
        normalized = line.lower()
        if any(marker in normalized for marker in INGREDIENT_SECTION_MARKERS):
            in_ingredient_section = True
            remainder = re.split(r"ingredienti|dosi|occorrente|cosa serve", line, flags=re.IGNORECASE)[-1].strip(" :.-")
            if remainder and line_has_quantity(remainder):
                extracted.append(remainder)
            continue
        if in_ingredient_section and any(marker in normalized for marker in SECTION_STOP_MARKERS):
            in_ingredient_section = False
            continue
        if in_ingredient_section:
            if line_has_quantity(line) or re.match(r"^(?:sale|pepe|olio|acqua)\b", normalized):
                extracted.append(line)
        elif line_has_quantity(line) and len(line.split()) <= 10:
            if any(marker in normalized for marker in SECTION_STOP_MARKERS):
                continue
            extracted.append(line)

    return extracted


def extract_terms(caption: str) -> list[str]:
    terms: list[str] = []
    for line in extract_ingredient_lines(caption):
        for chunk in re.split(r"\s+[+;,]\s+|\s{2,}", line):
            term = normalize_term(chunk)
            if len(term) < 3 or term in NOISE_TERMS:
                continue
            if len(term.split()) > 6:
                continue
            terms.append(term)
    return terms


def training_signal_for_term(term: str) -> str:
    if re.search(r"\b(rafferm[oi]|avanzat[oi]|surgelat[oi]|fresc[ao]|secc[ao]|tostat[oi]|grattugiat[ao])\b", term):
        return "condition_or_state_check"
    if re.search(r"\b(pomodorini|ciliegin[oi]|datterin[oi]|piccadilly)\b", term):
        return "meaningful_variant_candidate"
    if re.search(r"\b(fiocchi|farina|semola|amido|fecola)\b", term):
        return "product_form_candidate"
    if re.search(r"\b(uovo|uova|tuorli|albumi)\b", term):
        return "egg_family_candidate"
    if len(term.split()) >= 3:
        return "compound_identity_candidate"
    return "catalog_alias_candidate"


def build_corpus(posts: list[dict[str, Any]]) -> dict[str, Any]:
    scored = scored_posts(posts)
    category_counts = Counter(str(post.get("category") or "unknown") for post in scored)
    source_counts = Counter(str(post.get("source_file") or "unknown") for post in scored)

    term_counts: Counter[str] = Counter()
    term_examples: dict[str, list[dict[str, Any]]] = defaultdict(list)
    signal_counts: Counter[str] = Counter()

    for post in scored:
        caption = str(post.get("caption") or "")
        score, category = caption_score(caption)
        for term in extract_terms(caption):
            signal = training_signal_for_term(term)
            term_counts[term] += 1
            signal_counts[signal] += 1
            if len(term_examples[term]) < 3:
                term_examples[term].append({
                    "source_file": post.get("source_file"),
                    "url": post.get("url"),
                    "owner": post.get("ownerUsername"),
                    "caption_category": category,
                    "caption_score": score,
                    "excerpt": short_excerpt(caption),
                })

    top_terms = [
        {
            "term": term,
            "count": count,
            "training_signal": training_signal_for_term(term),
            "examples": term_examples[term],
        }
        for term, count in term_counts.most_common(80)
    ]

    return {
        "updated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "raw_captions_discovered": len(posts),
        "recipe_like_captions": len(scored),
        "category_counts": dict(category_counts),
        "top_source_files": dict(source_counts.most_common(20)),
        "training_signal_counts": dict(signal_counts),
        "top_terms": top_terms,
    }


def write_markdown(path: Path, corpus: dict[str, Any]) -> None:
    lines = [
        "# Smart Import caption training corpus",
        "",
        f"Updated: {corpus['updated_at']}",
        "",
        "This is a non-mutating corpus built from Apify Instagram caption exports. It is used to train Season operationally: regression cases, Smart Import prompt gaps, and Catalog Agent learning candidates.",
        "",
        "Full captions are not stored here. The report keeps compact term counts, short excerpts, and source URLs only.",
        "",
        "## Summary",
        "",
        f"- Raw captions discovered: {corpus['raw_captions_discovered']}",
        f"- Recipe-like captions: {corpus['recipe_like_captions']}",
        f"- Caption categories: `{json.dumps(corpus['category_counts'], sort_keys=True)}`",
        f"- Training signal counts: `{json.dumps(corpus['training_signal_counts'], sort_keys=True)}`",
        "",
        "## Top Ingredient-Like Terms",
        "",
        "| Term | Count | Signal | Example source |",
        "|---|---:|---|---|",
    ]

    for item in corpus["top_terms"][:40]:
        example = (item.get("examples") or [{}])[0]
        source = example.get("url") or example.get("source_file") or ""
        lines.append(f"| `{item['term']}` | {item['count']} | `{item['training_signal']}` | {source} |")

    lines.extend([
        "",
        "## How This Feeds Training",
        "",
        "- `catalog_alias_candidate`: frequent surface terms that may become aliases only after deterministic/catalog validation.",
        "- `meaningful_variant_candidate`: terms that may require child canonical ingredients or explicit no-collapse learning.",
        "- `condition_or_state_check`: terms where preparation/freshness may belong in recipe context instead of catalog identity.",
        "- `product_form_candidate`: terms where product form may be the correct canonical identity.",
        "- `compound_identity_candidate`: multi-word terms that need Catalog Agent semantic review before any apply.",
        "",
        "This report is intentionally advisory. It must not directly mutate `public.ingredients`, aliases, or learning memory without a governed review/apply step.",
    ])

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-dir", type=Path, default=DEFAULT_RAW_DIR)
    parser.add_argument("--extra-json", type=Path, action="append", default=[])
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--json-out", type=Path, default=DEFAULT_JSON)
    parser.add_argument("--json", action="store_true", dest="json_output")
    args = parser.parse_args(argv)

    posts = load_posts(args.raw_dir, args.extra_json)
    corpus = build_corpus(posts)

    args.report.parent.mkdir(parents=True, exist_ok=True)
    write_markdown(args.report, corpus)
    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps(corpus, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if args.json_output:
        print(json.dumps(corpus, ensure_ascii=False, indent=2))
    else:
        print(
            f"Built training corpus: raw={corpus['raw_captions_discovered']} "
            f"recipe_like={corpus['recipe_like_captions']} "
            f"terms={len(corpus['top_terms'])} report={args.report}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
