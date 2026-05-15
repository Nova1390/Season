# Smart Import real-caption E2E

Updated: 2026-05-15T18:20:29+00:00

This report uses real Instagram caption exports collected through Apify. Captions are not stored in full; only short excerpts and source URLs are kept for review.

## Summary

- Raw captions discovered: 2035
- Captions selected for bounded E2E: 30
- Selection strategy: stratified
- Edge responses OK: 30/30
- Publish-ready drafts: 24
- Needs more input: 6
- Drafts with duplicate ingredient names: 0
- Ingredients with explicit quantities: 204/282
- Quantity coverage: 0.723
- Unresolved ingredient terms: 0
- Caption categories: {"complete_recipe": 11, "ingredient_rich": 6, "messy_recipe_like": 6, "method_rich": 4, "weak_recipe_signal": 3}
- Draft qualities: {"needs_more_input": 6, "publishable": 24}
- Agent next actions: {"add_method_steps": 6, "publish": 24}
- Error codes: {"none": 30}
- Operational signals: {"complete_recipe_caption": 8, "creator_caption": 3, "ingredients_only_caption": 6, "messy_recipe_like_caption": 13, "missing_servings_metadata": 17, "missing_timing_metadata": 18}
- Repeated ingredient terms: {"Farina": 2, "acqua": 3, "amido di mais": 3, "az\u00facar": 2, "burro": 6, "cacao": 2, "cacao amaro": 4, "cacao in polvere": 2, "caff\u00e8": 4, "cannella": 4, "farina": 2, "farina 00": 8, "gocce di cioccolato fondente": 2, "harina": 2, "latte": 5, "latte intero": 3, "lievito per dolci": 2, "limone": 4, "miele": 2, "olio di arachidi": 2, "olio evo": 3, "olio extravergine d\u2019oliva": 2, "pepe": 2, "sale": 9, "salsiccia": 2, "tuorli": 2, "uova": 8, "uovo": 3, "yogurt greco": 3, "zucchero": 7, "zucchero a velo": 4, "zucchero semolato": 3}

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
- Result: ok=True usedLLM=True duration_ms=5696
- Draft: ingredients=14 steps=18 confidence=high
- Quantity coverage: measured=9 missing=5 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.643
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Operational signals: missing_servings_metadata, complete_recipe_caption
- Applied autofixes: none

### 2. Zeppole di San Giuseppe al forno

- Source: https://www.instagram.com/p/DHY2YjYMuzz/
- Caption excerpt: "Buon Festa del Papà a tutti i Papà del mondo ❤️ Zeppole di San Giuseppe al forno Ingredienti"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=7296
- Draft: ingredients=13 steps=14 confidence=high
- Quantity coverage: measured=11 missing=2 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.846
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Operational signals: missing_timing_metadata, complete_recipe_caption
- Applied autofixes: The server recovered servings from explicit caption text such as per 2, x2, or 2 persone without guessing.

### 3. Per la Festa della Mamma ho scelto la semplicità

- Source: https://www.instagram.com/p/DYFg9t5sIYX/
- Caption excerpt: "🍰Per la Festa della Mamma ho scelto la semplicità . Frolla classica, crema pasticcera e amarene. Quei sapori"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=6269
- Draft: ingredients=17 steps=13 confidence=high
- Quantity coverage: measured=10 missing=7 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.588
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Operational signals: missing_timing_metadata, complete_recipe_caption
- Applied autofixes: none

### 4. brookies

- Source: https://www.instagram.com/p/DXhXmcoMeUP/
- Caption excerpt: "🍪Doveva essere un cookie. Poi è degenerata. E il problema è che funziona. Troppo. Crosticina fuori. Morbidissimo dentro."
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4227
- Draft: ingredients=13 steps=10 confidence=high
- Quantity coverage: measured=12 missing=1 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.923
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Operational signals: missing_servings_metadata, complete_recipe_caption
- Applied autofixes: none

### 5. Pastiera Napoletana

- Source: https://www.instagram.com/p/DWEh3OOiP-t/
- Caption excerpt: "Pastiera Napoletana: il dolce della tradizione perfetto per Pasqua! 🥧🤤 Ingredienti: Per la pasta frolla: - 250 gr"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4223
- Draft: ingredients=14 steps=6 confidence=high
- Quantity coverage: measured=13 missing=1 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.929
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata, complete_recipe_caption
- Applied autofixes: none

### 6. LATTE FRITTO… versione tropicale

- Source: https://www.instagram.com/p/DXcWWSuCBQ0/
- Caption excerpt: "✨ LATTE FRITTO… versione tropicale 🥥🌴 Un grande classico della tradizione siciliana… ma con un twist inaspettato! Oggi"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=3031
- Draft: ingredients=9 steps=7 confidence=high
- Quantity coverage: measured=7 missing=2 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.778
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata, complete_recipe_caption
- Applied autofixes: none

### 7. Ricetta Pizza al Piatto

- Source: https://www.instagram.com/p/DGL8oB3u8uI/
- Caption excerpt: "Ora che ho perso la vista ci vedo di più. !! Se cuocete in casa o in forni"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=3363
- Draft: ingredients=4 steps=12 confidence=high
- Quantity coverage: measured=4 missing=0 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=1
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Operational signals: missing_timing_metadata, messy_recipe_like_caption
- Applied autofixes: none

### 8. Sempre voglia di tiramisù? Ecco il secondo reel con un altra idea davvero A T O M I C A ma anche sana,leggera e saziante.

- Source: https://www.instagram.com/p/DYC_mnjKWNu/
- Caption excerpt: "Sempre voglia di tiramisù? Ecco il secondo reel con un altra idea davvero A T O M I"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=3425
- Draft: ingredients=14 steps=4 confidence=high
- Quantity coverage: measured=8 missing=6 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.571
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata, messy_recipe_like_caption
- Applied autofixes: none

### 9. Panini per hamburger

- Source: https://www.instagram.com/p/DI7Hd4-MW0F/
- Caption excerpt: "Panini per hamburger avrebbe detto uno dei miei insegnanti. Questa è una variante di Giorilli appunto. Ho solo"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=2563
- Draft: ingredients=9 steps=9 confidence=high
- Quantity coverage: measured=9 missing=0 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=1
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: none
- Operational signals: messy_recipe_like_caption
- Applied autofixes: The server recovered servings from explicit caption text such as per 2, x2, or 2 persone without guessing.

### 10. La crostata che ha conquistato i miei bambini per merenda

- Source: https://www.instagram.com/p/DXwpm9lMsKq/
- Caption excerpt: "La crostata che ha conquistato i miei bambini per merenda. Base friabile, cuore cremoso e tanta frutta fresca…"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=3197
- Draft: ingredients=10 steps=7 confidence=high
- Quantity coverage: measured=10 missing=0 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=1
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Operational signals: missing_servings_metadata, complete_recipe_caption
- Applied autofixes: none

### 11. 6 idee al TIRAMISÙ che devi assolutamente provare

- Source: https://www.instagram.com/p/DX94QlaCuHZ/
- Caption excerpt: "6 idee al TIRAMISÙ che devi assolutamente provare 1.Weetabix tiramisù 📍ti servirà : •2 formelle di weetabix (in"
- Caption signal: ingredient_rich score=23
- Result: ok=True usedLLM=True duration_ms=4942
- Draft: ingredients=15 steps=8 confidence=medium
- Quantity coverage: measured=11 missing=4 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.733
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Operational signals: missing_timing_metadata, messy_recipe_like_caption
- Applied autofixes: The server recovered servings from explicit caption text such as per 2, x2, or 2 persone without guessing.

### 12. TORTINO BOUNTY

- Source: https://www.instagram.com/p/C0PRuklrkDw/
- Caption excerpt: "TORTINO BOUNTY by @martyfoodnfit Metti like o commenta se ti piace, mi supporteresti tanto e mi spinge a"
- Caption signal: ingredient_rich score=22
- Result: ok=True usedLLM=True duration_ms=7204
- Draft: ingredients=9 steps=4 confidence=medium
- Quantity coverage: measured=8 missing=1 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.889
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata, messy_recipe_like_caption
- Applied autofixes: none

### 13. CIAMBELLONE CACHI E CASTAGNE

- Source: https://www.instagram.com/p/DQZz9hnCMU4/
- Caption excerpt: "CIAMBELLONE CACHI E CASTAGNE INGREDIENTI: • 200 gr. di farina normale o integrale • 4 cachi medi maturi"
- Caption signal: ingredient_rich score=18
- Result: ok=True usedLLM=True duration_ms=2118
- Draft: ingredients=6 steps=0 confidence=high
- Quantity coverage: measured=4 missing=2 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.667
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Operational signals: ingredients_only_caption, missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 14. Gnocchetti di zucca

- Source: https://www.instagram.com/p/DRKvT4_jMjH/
- Caption excerpt: "Gnocchetti di zucca 🎃 Ingredienti per 2 persone * 250gr di polpa di zucca (cotta al forno con"
- Caption signal: ingredient_rich score=18
- Result: ok=True usedLLM=True duration_ms=2076
- Draft: ingredients=8 steps=0 confidence=high
- Quantity coverage: measured=2 missing=6 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.25
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: timings_missing
- Operational signals: ingredients_only_caption, missing_timing_metadata
- Applied autofixes: none

### 15. Un modo bellino e “sistemato” per servire la pizza

- Source: https://www.instagram.com/p/DWgfEp0gtvf/
- Caption excerpt: "Un modo bellino e “sistemato” per servire la pizza 🍕🤭 🤤 salva il Reel e segui @alessia.casprini per"
- Caption signal: ingredient_rich score=17
- Result: ok=True usedLLM=True duration_ms=2729
- Draft: ingredients=5 steps=7 confidence=medium
- Quantity coverage: measured=5 missing=0 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=1
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata, messy_recipe_like_caption
- Applied autofixes: none

### 16. Pizzoccheri

- Source: https://www.instagram.com/p/DX_Qrf-jFBt/
- Caption excerpt: "Pizzoccheri siano! Cosi aiuto con le ricette anche i miei amici che soffrono di #celiachia, grazie ai prodotti"
- Caption signal: ingredient_rich score=17
- Result: ok=True usedLLM=True duration_ms=2593
- Draft: ingredients=8 steps=5 confidence=high
- Quantity coverage: measured=2 missing=6 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.25
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: none
- Operational signals: messy_recipe_like_caption
- Applied autofixes: none

### 17. HUMMUS DI AVOCADO E CECI

- Source: https://www.instagram.com/p/DVGVWlYjU00/
- Caption excerpt: "🥑 HUMMUS DI AVOCADO E CECI Una crema pronta in 5 minuti che ti salva aperitivi, pranzi veloci"
- Caption signal: method_rich score=22
- Result: ok=True usedLLM=True duration_ms=2397
- Draft: ingredients=6 steps=0 confidence=high
- Quantity coverage: measured=4 missing=2 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.667
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing
- Operational signals: ingredients_only_caption, missing_servings_metadata
- Applied autofixes: none

### 18. Crema pasticciera semplice-dose per 1 uovo

- Source: https://www.instagram.com/p/DXg7BlhqzlX/
- Caption excerpt: "Crema pasticciera semplice-dose per 1 uovo 🥚 Ingredienti 1 uovo intero�2 cucchiai di zucchero�1 cucchiaio raso di farina�190"
- Caption signal: method_rich score=22
- Result: ok=True usedLLM=True duration_ms=3073
- Draft: ingredients=6 steps=9 confidence=high
- Quantity coverage: measured=4 missing=2 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.667
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Operational signals: missing_timing_metadata, messy_recipe_like_caption
- Applied autofixes: none

### 19. Biscotti stile Snickers

- Source: https://www.instagram.com/p/DPDYTKJAkiN/
- Caption excerpt: "Biscotti stile Snickers 🍫🥜 • 110 g di fiocchi d'avena • 90 g di farina di farro •"
- Caption signal: method_rich score=22
- Result: ok=True usedLLM=True duration_ms=2863
- Draft: ingredients=10 steps=6 confidence=high
- Quantity coverage: measured=8 missing=2 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.8
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: none
- Operational signals: messy_recipe_like_caption
- Applied autofixes: The server recovered servings from explicit caption text such as per 2, x2, or 2 persone without guessing.

### 20. MUFFIN CACAO & BARBABIETOLA

- Source: https://www.instagram.com/p/DTyP0SmDN3z/
- Caption excerpt: "𝗠𝗨𝗙𝗙𝗜𝗡 𝗖𝗔𝗖𝗔𝗢 & 𝗕𝗔𝗥𝗕𝗔𝗕𝗜𝗘𝗧𝗢𝗟𝗔 🧁🍫 Non sarei io se non sperimentassi 😉 Ho visto una ricetta simile e"
- Caption signal: method_rich score=22
- Result: ok=True usedLLM=True duration_ms=2320
- Draft: ingredients=9 steps=4 confidence=high
- Quantity coverage: measured=7 missing=2 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.778
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: none
- Operational signals: messy_recipe_like_caption
- Applied autofixes: none

### 21. Alberi natalizi di pasta frolla

- Source: https://www.instagram.com/p/DSGInkHiDFt/
- Caption excerpt: "Alberi natalizi di pasta frolla🎄 👩‍🍳🧑‍🍳Ricetta tradizionale: • 330 gr di farina ’00 + un pò per la"
- Caption signal: messy_recipe_like score=18
- Result: ok=True usedLLM=True duration_ms=2952
- Draft: ingredients=15 steps=0 confidence=high
- Quantity coverage: measured=13 missing=2 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.867
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Operational signals: ingredients_only_caption, missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 22. SANGUCHITOS DE CARNE DESMECHADA

- Source: https://www.instagram.com/p/C3eHfK8JZBy/
- Caption excerpt: "SANGUCHITOS DE CARNE DESMECHADA🥩, en un pancito de papa que la rompe toda. 🎥 receta de @kulinaria.recetas ."
- Caption signal: messy_recipe_like score=16
- Result: ok=True usedLLM=True duration_ms=3447
- Draft: ingredients=21 steps=0 confidence=medium
- Quantity coverage: measured=12 missing=9 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.571
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: timings_missing
- Operational signals: ingredients_only_caption, missing_timing_metadata
- Applied autofixes: none

### 23. POSTRE SÚPER CHOCOLATOSO CON SOLO 4 INGREDIENTES

- Source: https://www.instagram.com/p/C3cyex_LBOx/
- Caption excerpt: "POSTRE SÚPER CHOCOLATOSO CON SOLO 4 INGREDIENTES 🍫✨ receta de @lasrecetasdesimon 🫶 • Ideal para el verano, sin"
- Caption signal: messy_recipe_like score=14
- Result: ok=True usedLLM=True duration_ms=2886
- Draft: ingredients=4 steps=1 confidence=high
- Quantity coverage: measured=4 missing=0 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=1
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata, messy_recipe_like_caption
- Applied autofixes: none

### 24. SNACK SANO 3 INGREDIENTI!

- Source: https://www.instagram.com/p/DVg8E4BgmEA/
- Caption excerpt: "SNACK SANO 3 INGREDIENTI! 🍫 Anche per chi segue un’alimentazione chetogenica o low carb! 🤎 salva il reel"
- Caption signal: messy_recipe_like score=14
- Result: ok=True usedLLM=True duration_ms=3899
- Draft: ingredients=3 steps=0 confidence=medium
- Quantity coverage: measured=1 missing=2 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.333
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Operational signals: ingredients_only_caption, missing_servings_metadata, missing_timing_metadata
- Applied autofixes: none

### 25. TARTA DE QUESO “LA VIÑA”

- Source: https://www.instagram.com/p/C4J-SXsrnxU/
- Caption excerpt: "Por petición popular, comparto de nuevo la tarta de queso más famosa. GUÁRDATELA y así no se te"
- Caption signal: messy_recipe_like score=13
- Result: ok=True usedLLM=True duration_ms=3108
- Draft: ingredients=6 steps=5 confidence=high
- Quantity coverage: measured=6 missing=0 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=1
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: none
- Operational signals: messy_recipe_like_caption
- Applied autofixes: none

### 26. GELADINHO GOURMET DE PRESTÍGIO

- Source: https://www.instagram.com/p/DTDkpSYEeHW/
- Caption excerpt: "🍫🥥 GELADINHO GOURMET DE PRESTÍGIO Cremoso por dentro, com aquela casquinha crocante de chocolate por fora 😍 Uma"
- Caption signal: messy_recipe_like score=13
- Result: ok=True usedLLM=True duration_ms=2322
- Draft: ingredients=5 steps=4 confidence=high
- Quantity coverage: measured=5 missing=0 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=1
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata, messy_recipe_like_caption
- Applied autofixes: none

### 27. Sorprendila con la semplicità

- Source: https://www.instagram.com/p/DX_V5bgj6w0/
- Caption excerpt: "𝗦𝗼𝗿𝗽𝗿𝗲𝗻𝗱𝗶𝗹𝗮 𝗰𝗼𝗻 𝗹𝗮 𝘀𝗲𝗺𝗽𝗹𝗶𝗰𝗶𝘁𝗮̀. 🍣 Per la Festa della Mamma abbiamo pensato a un piatto che unisce la"
- Caption signal: weak_recipe_signal score=21
- Result: ok=True usedLLM=True duration_ms=2754
- Draft: ingredients=7 steps=6 confidence=high
- Quantity coverage: measured=2 missing=5 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.286
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Operational signals: missing_servings_metadata, creator_caption
- Applied autofixes: none

### 28. Spiedini Salsiccia e Zucchine

- Source: https://www.instagram.com/p/DHmHq9xAa4X/
- Caption excerpt: "Spiedini Salsiccia e Zucchine – facili, sfiziosi e perfetti in friggitrice ad aria! Ingredienti: • 1 zucchina •"
- Caption signal: weak_recipe_signal score=21
- Result: ok=True usedLLM=True duration_ms=2218
- Draft: ingredients=4 steps=4 confidence=high
- Quantity coverage: measured=2 missing=2 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.5
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Operational signals: missing_servings_metadata, creator_caption
- Applied autofixes: none

### 29. Cronometrata! Pronta in meno di 15 minuti

- Source: https://www.instagram.com/p/DXcLihiMmuc/
- Caption excerpt: "⏱️Cronometrata! Pronta in meno di 15 minuti 3 ingredienti e basta una padella. Zero sbatti, meno corrente… e"
- Caption signal: weak_recipe_signal score=21
- Result: ok=True usedLLM=True duration_ms=2440
- Draft: ingredients=6 steps=6 confidence=high
- Quantity coverage: measured=1 missing=5 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.167
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Operational signals: missing_servings_metadata, missing_timing_metadata, creator_caption
- Applied autofixes: none

### 30. Pomodori ripieni

- Source: https://www.instagram.com/p/DXuO75PjH0P/
- Caption excerpt: "⏱️10 minuti 🫕Zero fornelli 🍽️Cena pronta ➡️ Pomodori ripieni = il nuovo salvacena estivo ☀️ 👉 Salvate e"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4016
- Draft: ingredients=12 steps=8 confidence=high
- Quantity coverage: measured=10 missing=2 duplicate_names=none
- Catalog training candidates: unresolved=none quantity_coverage=0.833
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: none
- Operational signals: complete_recipe_caption
- Applied autofixes: none
