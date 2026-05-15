# Smart Import real-caption E2E

Updated: 2026-05-15T06:58:56+00:00

This report uses real Instagram caption exports collected through Apify. Captions are not stored in full; only short excerpts and source URLs are kept for review.

## Summary

- Raw captions discovered: 2035
- Captions selected for bounded E2E: 25
- Selection strategy: stratified
- Edge responses OK: 25/25
- Publish-ready drafts: 19
- Needs more input: 6
- Drafts with duplicate ingredient names: 0
- Ingredients with explicit quantities: 178/247
- Caption categories: {"complete_recipe": 9, "ingredient_rich": 5, "messy_recipe_like": 5, "method_rich": 3, "weak_recipe_signal": 3}
- Draft qualities: {"needs_more_input": 6, "publishable": 19}
- Agent next actions: {"add_method_steps": 6, "publish": 19}
- Error codes: {"none": 25}
- Operational signals: {"ingredients_only_caption": 6, "missing_servings_metadata": 17, "missing_timing_metadata": 17, "none": 2}

## Findings

- High-signal creator captions are reliably transformed into publishable drafts.
- Ingredient-rich captions without real method steps are correctly blocked with `steps_missing` instead of invented procedures.
- The recurring residual quality gaps are non-blocking metadata: servings and timings.
- This E2E intentionally does not store full social captions in the repo.

## Results

### 1. Zuppa inglese

- Source: https://www.instagram.com/p/DR6sa03CLer/
- Caption excerpt: "👩‍🍳🧑‍🍳INGREDIENTI : 🍰PAN DI SPAGNA: •110g Uova (circa 2 medie) •30g Farina 00 •30g Fecola di patate •60g"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=6490
- Draft: ingredients=14 steps=18 confidence=high
- Quantity coverage: measured=9 missing=5 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Operational signals: missing_servings_metadata
- Applied autofixes: none

### 2. Zeppole di San Giuseppe al forno

- Source: https://www.instagram.com/p/DHY2YjYMuzz/
- Caption excerpt: "Buon Festa del Papà a tutti i Papà del mondo ❤️ Zeppole di San Giuseppe al forno Ingredienti"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=5417
- Draft: ingredients=13 steps=17 confidence=high
- Quantity coverage: measured=11 missing=2 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 3. Per la Festa della Mamma ho scelto la semplicità

- Source: https://www.instagram.com/p/DYFg9t5sIYX/
- Caption excerpt: "🍰Per la Festa della Mamma ho scelto la semplicità . Frolla classica, crema pasticcera e amarene. Quei sapori"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=5106
- Draft: ingredients=17 steps=13 confidence=high
- Quantity coverage: measured=10 missing=7 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Operational signals: missing_timing_metadata
- Applied autofixes: none

### 4. Doveva essere un cookie. Poi è degenerata.

- Source: https://www.instagram.com/p/DXhXmcoMeUP/
- Caption excerpt: "🍪Doveva essere un cookie. Poi è degenerata. E il problema è che funziona. Troppo. Crosticina fuori. Morbidissimo dentro."
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4915
- Draft: ingredients=13 steps=10 confidence=high
- Quantity coverage: measured=12 missing=1 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Operational signals: missing_servings_metadata
- Applied autofixes: none

### 5. Pastiera Napoletana

- Source: https://www.instagram.com/p/DWEh3OOiP-t/
- Caption excerpt: "Pastiera Napoletana: il dolce della tradizione perfetto per Pasqua! 🥧🤤 Ingredienti: Per la pasta frolla: - 250 gr"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4238
- Draft: ingredients=14 steps=6 confidence=high
- Quantity coverage: measured=13 missing=1 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 6. Pomodori ripieni

- Source: https://www.instagram.com/p/DXuO75PjH0P/
- Caption excerpt: "⏱️10 minuti 🫕Zero fornelli 🍽️Cena pronta ➡️ Pomodori ripieni = il nuovo salvacena estivo ☀️ 👉 Salvate e"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4618
- Draft: ingredients=12 steps=8 confidence=high
- Quantity coverage: measured=10 missing=2 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: none
- Operational signals: none
- Applied autofixes: none

### 7. Porridge d’avena al cacao

- Source: https://www.instagram.com/p/DXG8vdWAh6Z/
- Caption excerpt: "Porridge d’avena al cacao: la colazione più saziante di sempre! 😉 Quando so di non avere tempo per"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=3666
- Draft: ingredients=8 steps=4 confidence=high
- Quantity coverage: measured=6 missing=2 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Operational signals: missing_timing_metadata
- Applied autofixes: none

### 8. LATTE FRITTO… versione tropicale

- Source: https://www.instagram.com/p/DXcWWSuCBQ0/
- Caption excerpt: "✨ LATTE FRITTO… versione tropicale 🥥🌴 Un grande classico della tradizione siciliana… ma con un twist inaspettato! Oggi"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=3017
- Draft: ingredients=9 steps=7 confidence=high
- Quantity coverage: measured=7 missing=2 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 9. 6 idee al TIRAMISÙ che devi assolutamente provare

- Source: https://www.instagram.com/p/DX94QlaCuHZ/
- Caption excerpt: "6 idee al TIRAMISÙ che devi assolutamente provare 1.Weetabix tiramisù 📍ti servirà : •2 formelle di weetabix (in"
- Caption signal: ingredient_rich score=23
- Result: ok=True usedLLM=True duration_ms=4537
- Draft: ingredients=15 steps=9 confidence=medium
- Quantity coverage: measured=11 missing=4 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 10. TORTINO BOUNTY

- Source: https://www.instagram.com/p/C0PRuklrkDw/
- Caption excerpt: "TORTINO BOUNTY by @martyfoodnfit Metti like o commenta se ti piace, mi supporteresti tanto e mi spinge a"
- Caption signal: ingredient_rich score=22
- Result: ok=True usedLLM=True duration_ms=2253
- Draft: ingredients=9 steps=1 confidence=high
- Quantity coverage: measured=8 missing=1 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 11. dolce alle mele e cannella

- Source: https://www.instagram.com/p/DT7f-OqDHtM/
- Caption excerpt: "Hai comprato dei fogli di riso perché li utilizzavano tutti e ora sono lì in dispensa a guardarti"
- Caption signal: ingredient_rich score=21
- Result: ok=True usedLLM=True duration_ms=2874
- Draft: ingredients=8 steps=0 confidence=high
- Quantity coverage: measured=8 missing=0 duplicate_names=none
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: timings_missing
- Operational signals: ingredients_only_caption, missing_timing_metadata
- Applied autofixes: none

### 12. Questa pasta con tonno, zucchine e olive taggiasche

- Source: https://www.instagram.com/p/DYMvtIHt5Pe/
- Caption excerpt: "Questa pasta con tonno, zucchine e olive taggiasche è una di quelle ricette veloci che dopo la prima"
- Caption signal: ingredient_rich score=20
- Result: ok=True usedLLM=True duration_ms=2103
- Draft: ingredients=8 steps=0 confidence=high
- Quantity coverage: measured=4 missing=4 duplicate_names=none
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Operational signals: ingredients_only_caption, missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 13. MELANZANE SALTATE CON CARNE

- Source: https://www.instagram.com/p/DQ48nC7jI_L/
- Caption excerpt: "MELANZANE SALTATE CON CARNE 🍆 ~~~~~~ Oggi avevo voglia di tornare in Cina, prendendo ispirazione da un piatto"
- Caption signal: ingredient_rich score=19
- Result: ok=True usedLLM=True duration_ms=4288
- Draft: ingredients=9 steps=0 confidence=high
- Quantity coverage: measured=4 missing=5 duplicate_names=none
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: timings_missing
- Operational signals: ingredients_only_caption, missing_timing_metadata
- Applied autofixes: none

### 14. Pizzette di cavolfiore

- Source: https://www.instagram.com/p/DR4QhVrDYsN/
- Caption excerpt: "Non sapete come cucinare il cavolfiore? Allora provate le pizzette della nostra @valeairoldi, preparate con il microonde Samsung"
- Caption signal: method_rich score=23
- Result: ok=True usedLLM=True duration_ms=2902
- Draft: ingredients=10 steps=3 confidence=high
- Quantity coverage: measured=6 missing=4 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Operational signals: missing_servings_metadata
- Applied autofixes: none

### 15. TORTA DI SUSHI

- Source: https://www.instagram.com/p/DVtCEszjNVy/
- Caption excerpt: "TORTA DI SUSHI🍣 zero sbatti😱 Hai voglia di Sushi ma non di preparlo, nè di spendere soldi per"
- Caption signal: method_rich score=23
- Result: ok=True usedLLM=True duration_ms=3457
- Draft: ingredients=9 steps=7 confidence=high
- Quantity coverage: measured=7 missing=2 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Operational signals: missing_servings_metadata
- Applied autofixes: none

### 16. Pane all'avena, spezie & cottage cheese

- Source: https://www.instagram.com/p/DTs_ytejJEt/
- Caption excerpt: "𝗣𝗮𝗻𝗲 𝗮𝗹𝗹'𝗮𝘃𝗲𝗻𝗮, 𝘀𝗽𝗲𝘇𝗶𝗲 & 𝗰𝗼𝘁𝘁𝗮𝗴𝗲 𝗰𝗵𝗲𝗲𝘀𝗲 Un esperimento riuscito alla grande: morbido dentro, compatto fuori 🍞 𝗜𝗻𝗴𝗿𝗲𝗱𝗶𝗲𝗻𝘁𝗶: 120"
- Caption signal: method_rich score=23
- Result: ok=True usedLLM=True duration_ms=2570
- Draft: ingredients=8 steps=6 confidence=high
- Quantity coverage: measured=6 missing=2 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 17. Alberi natalizi di pasta frolla

- Source: https://www.instagram.com/p/DSGInkHiDFt/
- Caption excerpt: "Alberi natalizi di pasta frolla🎄 👩‍🍳🧑‍🍳Ricetta tradizionale: • 330 gr di farina ’00 + un pò per la"
- Caption signal: messy_recipe_like score=18
- Result: ok=True usedLLM=True duration_ms=2745
- Draft: ingredients=16 steps=0 confidence=high
- Quantity coverage: measured=14 missing=2 duplicate_names=none
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Operational signals: ingredients_only_caption, missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 18. SANGUCHITOS DE CARNE DESMECHADA

- Source: https://www.instagram.com/p/C3eHfK8JZBy/
- Caption excerpt: "SANGUCHITOS DE CARNE DESMECHADA🥩, en un pancito de papa que la rompe toda. 🎥 receta de @kulinaria.recetas ."
- Caption signal: messy_recipe_like score=16
- Result: ok=True usedLLM=True duration_ms=6187
- Draft: ingredients=21 steps=0 confidence=medium
- Quantity coverage: measured=12 missing=9 duplicate_names=none
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: timings_missing
- Operational signals: ingredients_only_caption, missing_timing_metadata
- Applied autofixes: none

### 19. POSTRE SÚPER CHOCOLATOSO CON SOLO 4 INGREDIENTES

- Source: https://www.instagram.com/p/C3cyex_LBOx/
- Caption excerpt: "POSTRE SÚPER CHOCOLATOSO CON SOLO 4 INGREDIENTES 🍫✨ receta de @lasrecetasdesimon 🫶 • Ideal para el verano, sin"
- Caption signal: messy_recipe_like score=14
- Result: ok=True usedLLM=True duration_ms=1933
- Draft: ingredients=4 steps=1 confidence=high
- Quantity coverage: measured=4 missing=0 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 20. SNACK SANO 3 INGREDIENTI!

- Source: https://www.instagram.com/p/DVg8E4BgmEA/
- Caption excerpt: "SNACK SANO 3 INGREDIENTI! 🍫 Anche per chi segue un’alimentazione chetogenica o low carb! 🤎 salva il reel"
- Caption signal: messy_recipe_like score=14
- Result: ok=True usedLLM=True duration_ms=2066
- Draft: ingredients=3 steps=0 confidence=medium
- Quantity coverage: measured=1 missing=2 duplicate_names=none
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Operational signals: ingredients_only_caption, missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 21. TARTA DE QUESO “LA VIÑA”

- Source: https://www.instagram.com/p/C4J-SXsrnxU/
- Caption excerpt: "Por petición popular, comparto de nuevo la tarta de queso más famosa. GUÁRDATELA y así no se te"
- Caption signal: messy_recipe_like score=13
- Result: ok=True usedLLM=True duration_ms=3107
- Draft: ingredients=6 steps=5 confidence=high
- Quantity coverage: measured=6 missing=0 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: none
- Operational signals: none
- Applied autofixes: none

### 22. Sorprendila con la semplicità

- Source: https://www.instagram.com/p/DX_V5bgj6w0/
- Caption excerpt: "𝗦𝗼𝗿𝗽𝗿𝗲𝗻𝗱𝗶𝗹𝗮 𝗰𝗼𝗻 𝗹𝗮 𝘀𝗲𝗺𝗽𝗹𝗶𝗰𝗶𝘁𝗮̀. 🍣 Per la Festa della Mamma abbiamo pensato a un piatto che unisce la"
- Caption signal: weak_recipe_signal score=21
- Result: ok=True usedLLM=True duration_ms=2864
- Draft: ingredients=7 steps=6 confidence=high
- Quantity coverage: measured=2 missing=5 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Operational signals: missing_servings_metadata
- Applied autofixes: none

### 23. Spiedini Salsiccia e Zucchine

- Source: https://www.instagram.com/p/DHmHq9xAa4X/
- Caption excerpt: "Spiedini Salsiccia e Zucchine – facili, sfiziosi e perfetti in friggitrice ad aria! Ingredienti: • 1 zucchina •"
- Caption signal: weak_recipe_signal score=21
- Result: ok=True usedLLM=True duration_ms=2158
- Draft: ingredients=4 steps=4 confidence=high
- Quantity coverage: measured=2 missing=2 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Operational signals: missing_servings_metadata
- Applied autofixes: none

### 24. Cronometrata! Pronta in meno di 15 minuti

- Source: https://www.instagram.com/p/DXcLihiMmuc/
- Caption excerpt: "⏱️Cronometrata! Pronta in meno di 15 minuti 3 ingredienti e basta una padella. Zero sbatti, meno corrente… e"
- Caption signal: weak_recipe_signal score=21
- Result: ok=True usedLLM=True duration_ms=3221
- Draft: ingredients=6 steps=6 confidence=high
- Quantity coverage: measured=1 missing=5 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 25. Ricetta Pizza al Piatto

- Source: https://www.instagram.com/p/DGL8oB3u8uI/
- Caption excerpt: "Ora che ho perso la vista ci vedo di più. !! Se cuocete in casa o in forni"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=2737
- Draft: ingredients=4 steps=12 confidence=high
- Quantity coverage: measured=4 missing=0 duplicate_names=none
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Operational signals: missing_timing_metadata
- Applied autofixes: none
