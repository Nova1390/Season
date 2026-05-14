# Smart Import caption training corpus

Updated: 2026-05-14T15:12:34+00:00

This is a non-mutating corpus built from Apify Instagram caption exports. It is used to train Season operationally: regression cases, Smart Import prompt gaps, and Catalog Agent learning candidates.

Full captions are not stored here. The report keeps compact term counts, short excerpts, and source URLs only.

## Summary

- Raw captions discovered: 2035
- Recipe-like captions: 734
- Caption categories: `{"complete_recipe": 261, "ingredient_rich": 39, "messy_recipe_like": 40, "method_rich": 93, "weak_recipe_signal": 301}`
- Training signal counts: `{"catalog_alias_candidate": 1425, "compound_identity_candidate": 1043, "condition_or_state_check": 88, "egg_family_candidate": 71, "meaningful_variant_candidate": 14, "product_form_candidate": 285}`

## Top Ingredient-Like Terms

| Term | Count | Signal | Example source |
|---|---:|---|---|
| `farina` | 97 | `product_form_candidate` | https://www.instagram.com/p/DR6sa03CLer/ |
| `sale` | 88 | `catalog_alias_candidate` | https://www.instagram.com/p/DHY2YjYMuzz/ |
| `zucchero` | 86 | `catalog_alias_candidate` | https://www.instagram.com/p/DR6sa03CLer/ |
| `acqua` | 55 | `catalog_alias_candidate` | https://www.instagram.com/p/DHY2YjYMuzz/ |
| `uovo` | 44 | `egg_family_candidate` | https://www.instagram.com/p/DWEh3OOiP-t/ |
| `yogurt greco` | 40 | `catalog_alias_candidate` | https://www.instagram.com/p/DXpBpykiypq/ |
| `lievito per dolci` | 40 | `compound_identity_candidate` | https://www.instagram.com/p/DXoX_Fqo_G6/ |
| `olio evo` | 39 | `catalog_alias_candidate` | https://www.instagram.com/p/DXuO75PjH0P/ |
| `latte` | 36 | `catalog_alias_candidate` | https://www.instagram.com/p/DYFg9t5sIYX/ |
| `olio extravergine d'oliva` | 27 | `compound_identity_candidate` | https://www.instagram.com/p/DXpCte3DNkm/ |
| `cacao amaro` | 26 | `catalog_alias_candidate` | https://www.instagram.com/p/DWtSbKTsrcZ/ |
| `olio` | 26 | `catalog_alias_candidate` | https://www.instagram.com/p/DYJ3mDpO_Yb/ |
| `albume` | 23 | `catalog_alias_candidate` | https://www.instagram.com/p/DYC_mnjKWNu/ |
| `lievito` | 21 | `catalog_alias_candidate` | https://www.instagram.com/p/DSpUk0NgqeZ/ |
| `pepe` | 21 | `catalog_alias_candidate` | https://www.instagram.com/p/DYEtMvvsZiE/ |
| `burro` | 20 | `catalog_alias_candidate` | https://www.instagram.com/p/DHY2YjYMuzz/ |
| `cioccolato fondente` | 20 | `catalog_alias_candidate` | https://www.instagram.com/p/DXhXmcoMeUP/ |
| `ricotta` | 20 | `catalog_alias_candidate` | https://www.instagram.com/p/DYC_mnjKWNu/ |
| `miele` | 20 | `catalog_alias_candidate` | https://www.instagram.com/p/DXpBpykiypq/ |
| `fecola di patate` | 17 | `product_form_candidate` | https://www.instagram.com/p/DR6sa03CLer/ |
| `amido di mais` | 16 | `product_form_candidate` | https://www.instagram.com/p/DR6sa03CLer/ |
| `olio di semi` | 15 | `compound_identity_candidate` | https://www.instagram.com/p/DXbKHTJu9fH/ |
| `farina di mandorle` | 15 | `product_form_candidate` | https://www.instagram.com/p/DVyraR8M0l9/ |
| `farina d'avena` | 14 | `product_form_candidate` | https://www.instagram.com/p/DWtSbKTsrcZ/ |
| `succo di limone` | 14 | `compound_identity_candidate` | https://www.instagram.com/p/DYKezFyou3e/ |
| `fiocchi d'avena` | 14 | `product_form_candidate` | https://www.instagram.com/p/DUMHHxmDCvd/ |
| `zucchero a velo` | 13 | `compound_identity_candidate` | https://www.instagram.com/p/DYFg9t5sIYX/ |
| `cannella` | 13 | `catalog_alias_candidate` | https://www.instagram.com/p/DVyraR8M0l9/ |
| `sale e pepe` | 13 | `compound_identity_candidate` | https://www.instagram.com/p/DYJ3mDpO_Yb/ |
| `salsa di soia` | 12 | `compound_identity_candidate` | https://www.instagram.com/p/DMgOy_8sW-V/ |
| `latte vegetale` | 12 | `catalog_alias_candidate` | https://www.instagram.com/p/CzCB0iJrWqA/ |
| `mele` | 11 | `catalog_alias_candidate` | https://www.instagram.com/p/DXw1c4xIIk_/ |
| `carote` | 11 | `catalog_alias_candidate` | https://www.instagram.com/p/DYHhLuMIvhT/ |
| `cipolla` | 11 | `catalog_alias_candidate` | https://www.instagram.com/p/DYHhLuMIvhT/ |
| `zucchero di canna` | 10 | `compound_identity_candidate` | https://www.instagram.com/p/DXhXmcoMeUP/ |
| `sciroppo d'acero` | 10 | `catalog_alias_candidate` | https://www.instagram.com/p/DXzMLI6sw84/ |
| `pangrattato` | 9 | `catalog_alias_candidate` | https://www.instagram.com/p/DXcWWSuCBQ0/ |
| `tazzina di caffè` | 9 | `compound_identity_candidate` | https://www.instagram.com/p/DYC_mnjKWNu/ |
| `gocce di cioccolato` | 9 | `compound_identity_candidate` | https://www.instagram.com/p/DWtSbKTsrcZ/ |
| `olio di cocco` | 9 | `compound_identity_candidate` | https://www.instagram.com/p/DXoX_Fqo_G6/ |

## How This Feeds Training

- `catalog_alias_candidate`: frequent surface terms that may become aliases only after deterministic/catalog validation.
- `meaningful_variant_candidate`: terms that may require child canonical ingredients or explicit no-collapse learning.
- `condition_or_state_check`: terms where preparation/freshness may belong in recipe context instead of catalog identity.
- `product_form_candidate`: terms where product form may be the correct canonical identity.
- `compound_identity_candidate`: multi-word terms that need Catalog Agent semantic review before any apply.

This report is intentionally advisory. It must not directly mutate `public.ingredients`, aliases, or learning memory without a governed review/apply step.
