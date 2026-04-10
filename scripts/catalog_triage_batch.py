#!/usr/bin/env python3
"""
Minimal backoffice triage automation for unresolved catalog candidates.

What it does:
1) Seeds safe alias approvals.
2) Seeds create_new_ingredient decisions + enrichment drafts.
3) Seeds ignore decisions for noisy candidates.
4) Enriches new-ingredient drafts with USDA FoodData Central nutrition (when confident).

Safety principles:
- No automatic ingredient creation from drafts.
- No automatic draft "ready" transitions.
- needs_manual_review stays true.
- USDA nutrition is only attached when match confidence is high enough.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
USDA_API_KEY = os.environ.get("USDA_API_KEY", "DEMO_KEY")

REQUEST_TIMEOUT = 20


@dataclass(frozen=True)
class AliasSeed:
    source_text: str
    target_slug: str
    alias_text: str | None = None


@dataclass(frozen=True)
class NewIngredientSeed:
    source_text: str
    ingredient_type: str
    canonical_name_it: str
    canonical_name_en: str
    suggested_slug: str
    default_unit: str
    supported_units: list[str]
    is_seasonal: bool | None
    season_months: list[int]


@dataclass(frozen=True)
class IgnoreSeed:
    source_text: str


ALIAS_SEEDS: list[AliasSeed] = [
    AliasSeed("Latte intero", "milk"),
    AliasSeed("Sale fino", "salt"),
    AliasSeed("Sale grosso per le vongole", "salt"),
    AliasSeed("Noce moscata da grattugiare", "nutmeg"),
    AliasSeed("Pepe nero in grani", "black_pepper"),
    AliasSeed("Burro a temperatura ambiente", "butter"),
    AliasSeed("Burro freddo di frigo", "butter"),
    AliasSeed("Capperi sotto sale", "capers"),
    AliasSeed("Patate (a pasta gialla)", "potato", alias_text="Patate"),
    AliasSeed("Porri 1", "leek", alias_text="Porri"),
    AliasSeed("Prezzemolo 1 mazzetto", "parsley", alias_text="Prezzemolo"),
    AliasSeed("Alloro 1 foglia", "bay_leaf", alias_text="Alloro"),
    AliasSeed("Carote 1", "carrot", alias_text="Carote"),
    AliasSeed("Cipolle dorate 1", "onion", alias_text="Cipolle dorate"),
    AliasSeed("Spaghetti grossi", "spaghetti"),
]

NEW_INGREDIENT_SEEDS: list[NewIngredientSeed] = [
    NewIngredientSeed("Farina 00", "basic", "Farina 00", "Type 00 flour", "farina_00", "g", ["g", "piece"], False, []),
    NewIngredientSeed("Pecorino Romano DOP", "basic", "Pecorino Romano DOP", "Pecorino Romano", "pecorino_romano_dop", "g", ["g", "piece"], False, []),
    NewIngredientSeed("Vino bianco", "basic", "Vino bianco", "White wine", "vino_bianco", "ml", ["ml", "g", "tbsp"], False, []),
    NewIngredientSeed("Zucchero a velo", "basic", "Zucchero a velo", "Powdered sugar", "zucchero_a_velo", "g", ["g", "tbsp", "piece"], False, []),
    NewIngredientSeed("Amido di riso", "basic", "Amido di riso", "Rice starch", "amido_di_riso", "g", ["g", "tbsp", "piece"], False, []),
    NewIngredientSeed("Brodo di carne", "basic", "Brodo di carne", "Beef broth", "brodo_di_carne", "ml", ["ml", "g", "cup"], False, []),
    NewIngredientSeed("Brodo vegetale", "basic", "Brodo vegetale", "Vegetable broth", "brodo_vegetale", "ml", ["ml", "g", "cup"], False, []),
    NewIngredientSeed("Cacao amaro in polvere", "basic", "Cacao amaro in polvere", "Unsweetened cocoa powder", "cacao_amaro_in_polvere", "g", ["g", "tbsp", "tsp"], False, []),
    NewIngredientSeed("Cioccolato fondente al 70%", "basic", "Cioccolato fondente al 70%", "70% dark chocolate", "cioccolato_fondente_70", "g", ["g", "piece"], False, []),
    NewIngredientSeed("Capesante", "basic", "Capesante", "Scallops", "capesante", "g", ["g", "piece"], False, []),
    NewIngredientSeed("Panna fresca liquida", "basic", "Panna fresca liquida", "Fresh cream", "panna_fresca_liquida", "ml", ["ml", "g", "tbsp"], False, []),
    NewIngredientSeed("Riso Carnaroli", "basic", "Riso Carnaroli", "Carnaroli rice", "riso_carnaroli", "g", ["g", "cup"], False, []),
    NewIngredientSeed("Semolino", "basic", "Semolino", "Semolina", "semolino", "g", ["g", "cup"], False, []),
    NewIngredientSeed("Spaghetti", "basic", "Spaghetti", "Spaghetti", "spaghetti", "g", ["g", "piece"], False, []),
    NewIngredientSeed("Vongole", "basic", "Vongole", "Clams", "vongole", "g", ["g", "piece"], False, []),
    NewIngredientSeed("Zafferano in pistilli", "basic", "Zafferano in pistilli", "Saffron threads", "zafferano_in_pistilli", "g", ["g", "tsp", "piece"], False, []),
    NewIngredientSeed("Savoiardi", "basic", "Savoiardi", "Ladyfingers", "savoiardi", "g", ["g", "piece"], False, []),
    NewIngredientSeed("Nutella", "basic", "Nutella", "Nutella", "nutella", "g", ["g", "tbsp", "piece"], False, []),
    NewIngredientSeed("Sottilette", "basic", "Sottilette", "Processed cheese slices", "sottilette", "g", ["g", "piece"], False, []),
]

IGNORE_SEEDS: list[IgnoreSeed] = [
    IgnoreSeed("Uova medie 3"),
    IgnoreSeed("Uova 2"),
    IgnoreSeed("Uova 8"),
    IgnoreSeed("Uova (da almeno 70 g l'una) possibilmente biologiche 4"),
    IgnoreSeed("Tuorli (circa 7)"),
    IgnoreSeed("Tuorli (di uova medie) 6"),
    IgnoreSeed("Tuorli 2"),
    IgnoreSeed("Scorza di limone 1"),
    IgnoreSeed("Scorza di limone 1/2"),
    IgnoreSeed("Frutti di cappero per decorare"),
    IgnoreSeed("Formaggio da grattugiare"),
]


class SupabaseOps:
    def __init__(self, base_url: str, service_role_key: str) -> None:
        self.base_url = base_url
        self.service_role_key = service_role_key
        self.rpc_base = f"{self.base_url}/rest/v1/rpc"
        self.rest_base = f"{self.base_url}/rest/v1"

    def _headers(self) -> dict[str, str]:
        return {
            "apikey": self.service_role_key,
            "Authorization": f"Bearer {self.service_role_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Prefer": "return=representation",
        }

    def _request_json(self, url: str, payload: dict[str, Any] | None = None, method: str = "POST") -> Any:
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(url, data=body, method=method, headers=self._headers())
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else []

    def rpc(self, fn_name: str, payload: dict[str, Any]) -> Any:
        return self._request_json(f"{self.rpc_base}/{fn_name}", payload=payload, method="POST")

    def select_ingredient_id_by_slug(self, slug: str) -> str | None:
        query = urllib.parse.urlencode({
            "select": "id,slug",
            "slug": f"eq.{slug}",
            "limit": "1",
        })
        url = f"{self.rest_base}/ingredients?{query}"
        rows = self._request_json(url, payload=None, method="GET")
        if isinstance(rows, list) and rows:
            row = rows[0] or {}
            ingredient_id = (row.get("id") or "").strip()
            return ingredient_id or None
        return None

    def find_candidate_key(self, source_text: str) -> str | None:
        candidates = candidate_key_variants(source_text)
        for key in candidates:
            query = urllib.parse.urlencode({
                "select": "normalized_text",
                "normalized_text": f"eq.{key}",
                "limit": "1",
            })
            url = f"{self.rest_base}/custom_ingredient_observations?{query}"
            rows = self._request_json(url, payload=None, method="GET")
            if isinstance(rows, list) and rows:
                return key
        return None

    def get_observation(self, normalized_text: str) -> dict[str, Any] | None:
        query = urllib.parse.urlencode({
            "select": "normalized_text,status,occurrence_count,last_seen_at",
            "normalized_text": f"eq.{normalized_text}",
            "limit": "1",
        })
        url = f"{self.rest_base}/custom_ingredient_observations?{query}"
        rows = self._request_json(url, payload=None, method="GET")
        if isinstance(rows, list) and rows:
            return rows[0]
        return None

    def get_active_alias(self, normalized_text: str) -> dict[str, Any] | None:
        query = urllib.parse.urlencode({
            "select": "id,ingredient_id,status,is_active,alias_text",
            "normalized_alias_text": f"eq.{normalized_text}",
            "is_active": "is.true",
            "order": "id.desc",
            "limit": "1",
        })
        url = f"{self.rest_base}/ingredient_aliases_v2?{query}"
        rows = self._request_json(url, payload=None, method="GET")
        if isinstance(rows, list) and rows:
            return rows[0]
        return None

    def get_enrichment_draft(self, normalized_text: str) -> dict[str, Any] | None:
        query = urllib.parse.urlencode({
            "select": "normalized_text,status,ingredient_type,suggested_slug,validated_ready,updated_at",
            "normalized_text": f"eq.{normalized_text}",
            "limit": "1",
        })
        url = f"{self.rest_base}/catalog_ingredient_enrichment_drafts?{query}"
        rows = self._request_json(url, payload=None, method="GET")
        if isinstance(rows, list) and rows:
            return rows[0]
        return None


def candidate_key_variants(value: str) -> list[str]:
    raw = value.strip()
    variants: list[str] = []

    def add(v: str) -> None:
        cleaned = v.strip()
        if cleaned and cleaned not in variants:
            variants.append(cleaned)

    add(raw)
    lowered = raw.lower()
    add(lowered)
    add(normalize_text_conservative(raw, strip_parentheses=False))
    add(normalize_text_conservative(raw, strip_parentheses=True))
    add(re.sub(r"\s+", " ", re.sub(r"\([^)]*\)", " ", lowered)).strip())
    return variants


def normalize_text_conservative(value: str, strip_parentheses: bool) -> str:
    text = value.strip().lower()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    if strip_parentheses:
        text = re.sub(r"\([^)]*\)", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def normalize_alias_text(value: str) -> str:
    text = value.strip()
    text = re.sub(r"\([^)]*\)", " ", text)
    text = re.sub(r"\b\d+[\d\s/.,]*\b", " ", text)
    text = re.sub(
        r"\b(da|di|del|della|delle|degli|per|con|in|a|temperatura|ambiente|freddo|frigo|grani|foglia|mazzetto|grosso|grossi|fino)\b",
        " ",
        text,
        flags=re.IGNORECASE,
    )
    text = re.sub(r"\s+", " ", text).strip(" .,;:-")
    return text or value.strip()


def usda_search(query: str, page_size: int = 5) -> list[dict[str, Any]]:
    params = {
        "query": query,
        "pageSize": str(page_size),
        "api_key": USDA_API_KEY,
    }
    url = f"https://api.nal.usda.gov/fdc/v1/foods/search?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, method="GET")
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    return payload.get("foods") or []


def pick_usda_candidate(seed: NewIngredientSeed, foods: list[dict[str, Any]]) -> tuple[dict[str, Any] | None, float, str]:
    if not foods:
        return None, 0.0, "no_results"

    target = normalize_text_conservative(seed.canonical_name_en or seed.canonical_name_it, strip_parentheses=True)
    target_tokens = {t for t in re.split(r"\s+", target) if len(t) >= 3}
    preferred_types = {"Foundation", "SR Legacy"}

    best_food = None
    best_score = -1.0
    best_reason = "no_match"

    for food in foods:
        description = normalize_text_conservative(str(food.get("description") or ""), strip_parentheses=True)
        desc_tokens = {t for t in re.split(r"\s+", description) if len(t) >= 3}
        if not desc_tokens:
            continue
        overlap = len(target_tokens & desc_tokens)
        overlap_ratio = overlap / max(1, len(target_tokens))
        dtype = str(food.get("dataType") or "")
        type_bonus = 0.12 if dtype in preferred_types else 0.0
        score = overlap_ratio + type_bonus

        if description == target:
            score += 0.45

        if score > best_score:
            best_score = score
            best_food = food
            best_reason = f"overlap={overlap_ratio:.2f},dataType={dtype or 'unknown'}"

    if best_food is None:
        return None, 0.0, "no_token_overlap"

    return best_food, max(0.0, min(1.0, best_score)), best_reason


def extract_per_100g_nutrients(food: dict[str, Any]) -> dict[str, Any]:
    nutrients = food.get("foodNutrients") or []
    wanted = {
        "Energy": "calories_kcal",
        "Protein": "protein_g",
        "Carbohydrate, by difference": "carbs_g",
        "Total lipid (fat)": "fat_g",
        "Fiber, total dietary": "fiber_g",
        "Potassium, K": "potassium_mg",
        "Vitamin C, total ascorbic acid": "vitamin_c_mg",
    }
    output: dict[str, Any] = {}
    for nutrient in nutrients:
        name = str(nutrient.get("nutrientName") or "")
        key = wanted.get(name)
        if not key:
            continue
        value = nutrient.get("value")
        if value is None:
            continue
        try:
            output[key] = float(value)
        except (TypeError, ValueError):
            continue
    return output


def build_nutrition_fields(seed: NewIngredientSeed) -> tuple[dict[str, Any], bool, str]:
    try:
        foods = usda_search(seed.canonical_name_en)
    except urllib.error.HTTPError as exc:
        return {
            "source": "USDA FoodData Central",
            "lookup_status": "failed",
            "lookup_error": f"http_{exc.code}",
        }, False, f"search_http_{exc.code}"
    except Exception as exc:  # noqa: BLE001
        return {
            "source": "USDA FoodData Central",
            "lookup_status": "failed",
            "lookup_error": str(exc),
        }, False, "search_exception"

    food, score, reason = pick_usda_candidate(seed, foods)
    if not food:
        return {
            "source": "USDA FoodData Central",
            "lookup_status": "no_match",
            "search_query": seed.canonical_name_en,
            "match_confidence": "low",
            "match_score": score,
        }, False, reason

    fdc_id = food.get("fdcId")
    description = str(food.get("description") or "")
    per_100g = extract_per_100g_nutrients(food)
    confidence = "high" if score >= 0.72 and len(per_100g) >= 4 else "low"

    fields = {
        "source": "USDA FoodData Central",
        "search_query": seed.canonical_name_en,
        "lookup_status": "matched",
        "match_confidence": confidence,
        "match_score": round(score, 4),
        "match_reason": reason,
        "fdc_id": fdc_id,
        "fdc_description": description,
        "fdc_data_type": food.get("dataType"),
        "nutrition_basis": "per_100g",
        "reference": f"https://fdc.nal.usda.gov/fdc-app.html#/food-details/{fdc_id}/nutrients" if fdc_id else None,
        "per_100g": per_100g,
    }
    return fields, confidence == "high", reason


def init_report(dry_run: bool) -> dict[str, Any]:
    return {
        "timestamp": datetime.now(UTC).isoformat(),
        "dry_run": dry_run,
        "aliases_attempted": 0,
        "aliases_applied": 0,
        "ignores_attempted": 0,
        "ignores_applied": 0,
        "drafts_attempted": 0,
        "drafts_created": 0,
        "drafts_updated": 0,
        "skipped_items": 0,
        "failed_items": 0,
        "USDA_high_confidence": 0,
        "USDA_low_confidence": 0,
        "items": [],
    }


def add_report_item(report: dict[str, Any], item: dict[str, Any]) -> None:
    report["items"].append(item)
    status = (item.get("result_status") or "").lower()
    if status in {"failed", "error", "conflict"}:
        report["failed_items"] += 1
    if status in {
        "skipped",
        "already_done",
        "candidate_not_found",
        "ingredient_not_found",
        "would_apply",
        "would_create",
        "would_ignore",
    }:
        report["skipped_items"] += 1


def write_report(report: dict[str, Any], base_dir: Path) -> Path:
    report_dir = base_dir / "docs" / "reports"
    report_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    filename = f"catalog_triage_report_{stamp}.json"
    path = report_dir / filename
    path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    return path


def apply_alias_seeds(client: SupabaseOps, apply: bool, report: dict[str, Any]) -> None:
    for seed in ALIAS_SEEDS:
        report["aliases_attempted"] += 1
        item: dict[str, Any] = {
            "raw_term": seed.source_text,
            "intended_action": "add_alias",
            "target_canonical_slug": seed.target_slug,
            "result_status": "pending",
        }
        try:
            candidate_key = client.find_candidate_key(seed.source_text)
            if not candidate_key:
                item["result_status"] = "candidate_not_found"
                add_report_item(report, item)
                print(f"[TRIAGE_ALIAS] skip source='{seed.source_text}' reason=candidate_not_found")
                continue

            item["normalized_text"] = candidate_key
            ingredient_id = client.select_ingredient_id_by_slug(seed.target_slug)
            if not ingredient_id:
                item["result_status"] = "ingredient_not_found"
                add_report_item(report, item)
                print(f"[TRIAGE_ALIAS] skip normalized_text='{candidate_key}' reason=ingredient_not_found slug='{seed.target_slug}'")
                continue

            item["target_canonical_ingredient_id"] = ingredient_id
            alias_text = seed.alias_text or normalize_alias_text(seed.source_text)
            item["alias_text"] = alias_text

            existing_alias = client.get_active_alias(candidate_key)
            if existing_alias:
                existing_target = (existing_alias.get("ingredient_id") or "").strip().lower()
                if existing_target == ingredient_id.lower() and (existing_alias.get("status") or "") == "approved":
                    item["result_status"] = "already_done"
                    add_report_item(report, item)
                    print(f"[TRIAGE_ALIAS] skip normalized_text='{candidate_key}' reason=already_done")
                    continue
                item["result_status"] = "conflict"
                item["error_message"] = "active_alias_points_to_different_ingredient"
                add_report_item(report, item)
                print(f"[TRIAGE_ALIAS] fail normalized_text='{candidate_key}' reason=alias_conflict")
                continue

            if not apply:
                item["result_status"] = "would_apply"
                add_report_item(report, item)
                print(f"[TRIAGE_ALIAS] dry_run normalized_text='{candidate_key}' target_slug='{seed.target_slug}'")
                continue

            payload = {
                "p_normalized_text": candidate_key,
                "p_ingredient_id": ingredient_id,
                "p_alias_text": alias_text,
                "p_language_code": "it",
                "p_reviewer_note": "bulk triage seed alias",
                "p_confidence_score": 0.95,
            }
            client.rpc("approve_reconciliation_alias", payload)
            report["aliases_applied"] += 1
            item["result_status"] = "applied"
            add_report_item(report, item)
            print(f"[TRIAGE_ALIAS] ok normalized_text='{candidate_key}' target_slug='{seed.target_slug}'")
        except Exception as exc:  # noqa: BLE001
            item["result_status"] = "failed"
            item["error_message"] = str(exc)
            add_report_item(report, item)
            print(f"[TRIAGE_ALIAS] fail source='{seed.source_text}' error={exc}")
        time.sleep(0.06)


def apply_ignore_seeds(client: SupabaseOps, apply: bool, report: dict[str, Any]) -> None:
    for seed in IGNORE_SEEDS:
        report["ignores_attempted"] += 1
        item: dict[str, Any] = {
            "raw_term": seed.source_text,
            "intended_action": "ignore",
            "result_status": "pending",
        }
        try:
            candidate_key = client.find_candidate_key(seed.source_text)
            if not candidate_key:
                item["result_status"] = "candidate_not_found"
                add_report_item(report, item)
                print(f"[TRIAGE_IGNORE] skip source='{seed.source_text}' reason=candidate_not_found")
                continue

            item["normalized_text"] = candidate_key
            observation = client.get_observation(candidate_key)
            current_status = (observation or {}).get("status")
            item["observation_status_before"] = current_status
            if current_status == "ignored":
                item["result_status"] = "already_done"
                add_report_item(report, item)
                print(f"[TRIAGE_IGNORE] skip normalized_text='{candidate_key}' reason=already_ignored")
                continue

            if not apply:
                item["result_status"] = "would_ignore"
                add_report_item(report, item)
                print(f"[TRIAGE_IGNORE] dry_run normalized_text='{candidate_key}'")
                continue

            payload = {
                "p_normalized_text": candidate_key,
                "p_action": "ignore",
                "p_reviewer_note": "bulk triage seed ignore/noise",
                "p_confidence_score": 0.9,
            }
            client.rpc("apply_catalog_candidate_decision", payload)
            report["ignores_applied"] += 1
            item["result_status"] = "applied"
            add_report_item(report, item)
            print(f"[TRIAGE_IGNORE] ok normalized_text='{candidate_key}'")
        except Exception as exc:  # noqa: BLE001
            item["result_status"] = "failed"
            item["error_message"] = str(exc)
            add_report_item(report, item)
            print(f"[TRIAGE_IGNORE] fail source='{seed.source_text}' error={exc}")
        time.sleep(0.06)


def apply_new_ingredient_drafts(client: SupabaseOps, apply: bool, report: dict[str, Any]) -> None:
    for seed in NEW_INGREDIENT_SEEDS:
        report["drafts_attempted"] += 1
        item: dict[str, Any] = {
            "raw_term": seed.source_text,
            "intended_action": "create_new_ingredient_draft",
            "target_canonical_slug": seed.suggested_slug,
            "result_status": "pending",
        }
        try:
            candidate_key = client.find_candidate_key(seed.source_text)
            if not candidate_key:
                item["result_status"] = "candidate_not_found"
                add_report_item(report, item)
                print(f"[TRIAGE_NEW] skip source='{seed.source_text}' reason=candidate_not_found")
                continue

            item["normalized_text"] = candidate_key
            nutrition_fields, nutrition_confident, nutrition_reason = build_nutrition_fields(seed)
            report["USDA_high_confidence" if nutrition_confident else "USDA_low_confidence"] += 1
            item["usda_match"] = {
                "lookup_status": nutrition_fields.get("lookup_status"),
                "match_confidence": nutrition_fields.get("match_confidence", "low"),
                "match_score": nutrition_fields.get("match_score"),
                "fdc_id": nutrition_fields.get("fdc_id"),
                "reason": nutrition_reason,
            }

            existing_draft = client.get_enrichment_draft(candidate_key)
            if existing_draft:
                item["draft_status_before"] = existing_draft.get("status")
                item["validated_ready_before"] = existing_draft.get("validated_ready")
                item["result_status"] = "already_done"
                add_report_item(report, item)
                print(f"[TRIAGE_NEW] skip normalized_text='{candidate_key}' reason=draft_exists")
                continue

            if not apply:
                item["result_status"] = "would_create"
                add_report_item(report, item)
                print(f"[TRIAGE_NEW] dry_run normalized_text='{candidate_key}' slug='{seed.suggested_slug}'")
                continue

            observation = client.get_observation(candidate_key)
            if (observation or {}).get("status") != "create_new_ingredient":
                decision_payload = {
                    "p_normalized_text": candidate_key,
                    "p_action": "create_new_ingredient",
                    "p_reviewer_note": "bulk triage seed create_new_ingredient",
                    "p_confidence_score": 0.8,
                }
                client.rpc("apply_catalog_candidate_decision", decision_payload)

            draft_payload = {
                "p_normalized_text": candidate_key,
                "p_status": "pending",
                "p_ingredient_type": seed.ingredient_type,
                "p_canonical_name_it": seed.canonical_name_it,
                "p_canonical_name_en": seed.canonical_name_en,
                "p_suggested_slug": seed.suggested_slug,
                "p_suggested_aliases": [seed.source_text],
                "p_default_unit": seed.default_unit,
                "p_supported_units": seed.supported_units,
                "p_is_seasonal": seed.is_seasonal,
                "p_season_months": seed.season_months,
                "p_nutrition_fields": nutrition_fields,
                "p_confidence_score": 0.7 if nutrition_confident else 0.5,
                "p_needs_manual_review": True,
                "p_reasoning_summary": (
                    "Bulk triage draft seeded; "
                    f"USDA lookup={nutrition_fields.get('lookup_status')} ({nutrition_reason})."
                ),
                "p_reviewer_note": "seeded by catalog_triage_batch.py",
            }
            client.rpc("upsert_catalog_ingredient_enrichment_draft", draft_payload)
            report["drafts_created"] += 1
            item["result_status"] = "created"
            add_report_item(report, item)
            print(f"[TRIAGE_NEW] ok normalized_text='{candidate_key}' slug='{seed.suggested_slug}'")
        except Exception as exc:  # noqa: BLE001
            item["result_status"] = "failed"
            item["error_message"] = str(exc)
            add_report_item(report, item)
            print(f"[TRIAGE_NEW] fail source='{seed.source_text}' error={exc}")
        time.sleep(0.08)


def validate_env() -> None:
    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        raise SystemExit(
            "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. "
            "Run with service-role credentials in environment."
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed Catalog Intelligence triage buckets")
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument("--dry-run", action="store_true", help="Preview only (default)")
    mode_group.add_argument("--apply", action="store_true", help="Execute live mutations")
    args = parser.parse_args()

    apply = bool(args.apply)
    dry_run = not apply

    validate_env()
    client = SupabaseOps(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    report = init_report(dry_run=dry_run)

    apply_alias_seeds(client, apply=apply, report=report)
    apply_ignore_seeds(client, apply=apply, report=report)
    apply_new_ingredient_drafts(client, apply=apply, report=report)

    repo_root = Path(__file__).resolve().parent.parent
    report_path = write_report(report, repo_root)

    print("\n=== TRIAGE SUMMARY ===")
    print(f"mode={'apply' if apply else 'dry-run'}")
    print(f"aliases: attempted={report['aliases_attempted']} applied={report['aliases_applied']}")
    print(f"ignores: attempted={report['ignores_attempted']} applied={report['ignores_applied']}")
    print(
        "drafts: "
        f"attempted={report['drafts_attempted']} "
        f"created={report['drafts_created']} updated={report['drafts_updated']}"
    )
    print(
        "USDA: "
        f"high_confidence={report['USDA_high_confidence']} "
        f"low_confidence={report['USDA_low_confidence']}"
    )
    print(f"skipped_items={report['skipped_items']} failed_items={report['failed_items']}")
    print(f"report={report_path}")
    print("manual_review_required_for_new_drafts=true")

    return 0 if report["failed_items"] == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
