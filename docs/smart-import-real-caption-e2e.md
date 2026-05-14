# Smart Import real-caption E2E

Updated: 2026-05-14T08:46:07+00:00

This report uses real Instagram caption exports collected through Apify. Captions are not stored in full; only short excerpts and source URLs are kept for review.

## Summary

- Raw captions discovered: 2035
- Captions selected for bounded E2E: 20
- Selection strategy: stratified
- Edge responses OK: 20/20
- Publish-ready drafts: 15
- Needs more input: 5
- Caption categories: {"complete_recipe": 7, "ingredient_rich": 4, "messy_recipe_like": 4, "method_rich": 3, "weak_recipe_signal": 2}
- Draft qualities: {"needs_more_input": 5, "publishable": 15}
- Agent next actions: {"add_method_steps": 5, "publish": 15}

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
- Result: ok=True usedLLM=True duration_ms=6599
- Draft: ingredients=16 steps=18 confidence=medium
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 2. Zeppole di San Giuseppe al forno

- Source: https://www.instagram.com/p/DHY2YjYMuzz/
- Caption excerpt: "Buon Festa del Papà a tutti i Papà del mondo ❤️ Zeppole di San Giuseppe al forno Ingredienti"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=6429
- Draft: ingredients=15 steps=14 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 3. Per la Festa della Mamma ho scelto la semplicità

- Source: https://www.instagram.com/p/DYFg9t5sIYX/
- Caption excerpt: "🍰Per la Festa della Mamma ho scelto la semplicità . Frolla classica, crema pasticcera e amarene. Quei sapori"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=5091
- Draft: ingredients=17 steps=13 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Applied autofixes: none

### 4. Brookies

- Source: https://www.instagram.com/p/DXhXmcoMeUP/
- Caption excerpt: "🍪Doveva essere un cookie. Poi è degenerata. E il problema è che funziona. Troppo. Crosticina fuori. Morbidissimo dentro."
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=6103
- Draft: ingredients=16 steps=10 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 5. Pastiera Napoletana

- Source: https://www.instagram.com/p/DWEh3OOiP-t/
- Caption excerpt: "Pastiera Napoletana: il dolce della tradizione perfetto per Pasqua! 🥧🤤 Ingredienti: Per la pasta frolla: - 250 gr"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=5235
- Draft: ingredients=15 steps=6 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 6. Pomodori ripieni

- Source: https://www.instagram.com/p/DXuO75PjH0P/
- Caption excerpt: "⏱️10 minuti 🫕Zero fornelli 🍽️Cena pronta ➡️ Pomodori ripieni = il nuovo salvacena estivo ☀️ 👉 Salvate e"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=6485
- Draft: ingredients=13 steps=8 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: none
- Applied autofixes: none

### 7. Porridge d’avena al cacao

- Source: https://www.instagram.com/p/DXG8vdWAh6Z/
- Caption excerpt: "Porridge d’avena al cacao: la colazione più saziante di sempre! 😉 Quando so di non avere tempo per"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=3685
- Draft: ingredients=8 steps=5 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Applied autofixes: none

### 8. 6 idee al TIRAMISÙ che devi assolutamente provare

- Source: https://www.instagram.com/p/DX94QlaCuHZ/
- Caption excerpt: "6 idee al TIRAMISÙ che devi assolutamente provare 1.Weetabix tiramisù 📍ti servirà : •2 formelle di weetabix (in"
- Caption signal: ingredient_rich score=23
- Result: ok=True usedLLM=True duration_ms=5255
- Draft: ingredients=24 steps=8 confidence=medium
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 9. TORTINO BOUNTY

- Source: https://www.instagram.com/p/C0PRuklrkDw/
- Caption excerpt: "TORTINO BOUNTY by @martyfoodnfit Metti like o commenta se ti piace, mi supporteresti tanto e mi spinge a"
- Caption signal: ingredient_rich score=22
- Result: ok=True usedLLM=True duration_ms=3917
- Draft: ingredients=10 steps=1 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 10. dolce alle mele e cannella

- Source: https://www.instagram.com/p/DT7f-OqDHtM/
- Caption excerpt: "Hai comprato dei fogli di riso perché li utilizzavano tutti e ora sono lì in dispensa a guardarti"
- Caption signal: ingredient_rich score=21
- Result: ok=True usedLLM=True duration_ms=2774
- Draft: ingredients=8 steps=0 confidence=high
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: timings_missing
- Applied autofixes: none

### 11. Questa pasta con tonno, zucchine e olive taggiasche

- Source: https://www.instagram.com/p/DYMvtIHt5Pe/
- Caption excerpt: "Questa pasta con tonno, zucchine e olive taggiasche è una di quelle ricette veloci che dopo la prima"
- Caption signal: ingredient_rich score=20
- Result: ok=True usedLLM=True duration_ms=4804
- Draft: ingredients=8 steps=0 confidence=high
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 12. Pizzette di cavolfiore

- Source: https://www.instagram.com/p/DR4QhVrDYsN/
- Caption excerpt: "Non sapete come cucinare il cavolfiore? Allora provate le pizzette della nostra @valeairoldi, preparate con il microonde Samsung"
- Caption signal: method_rich score=23
- Result: ok=True usedLLM=True duration_ms=3347
- Draft: ingredients=10 steps=3 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 13. TORTA DI SUSHI

- Source: https://www.instagram.com/p/DVtCEszjNVy/
- Caption excerpt: "TORTA DI SUSHI🍣 zero sbatti😱 Hai voglia di Sushi ma non di preparlo, nè di spendere soldi per"
- Caption signal: method_rich score=23
- Result: ok=True usedLLM=True duration_ms=3245
- Draft: ingredients=9 steps=7 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 14. Pane all'avena, spezie & cottage cheese

- Source: https://www.instagram.com/p/DTs_ytejJEt/
- Caption excerpt: "𝗣𝗮𝗻𝗲 𝗮𝗹𝗹'𝗮𝘃𝗲𝗻𝗮, 𝘀𝗽𝗲𝘇𝗶𝗲 & 𝗰𝗼𝘁𝘁𝗮𝗴𝗲 𝗰𝗵𝗲𝗲𝘀𝗲 Un esperimento riuscito alla grande: morbido dentro, compatto fuori 🍞 𝗜𝗻𝗴𝗿𝗲𝗱𝗶𝗲𝗻𝘁𝗶: 120"
- Caption signal: method_rich score=23
- Result: ok=True usedLLM=True duration_ms=3068
- Draft: ingredients=8 steps=6 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 15. Alberi natalizi di pasta frolla

- Source: https://www.instagram.com/p/DSGInkHiDFt/
- Caption excerpt: "Alberi natalizi di pasta frolla🎄 👩‍🍳🧑‍🍳Ricetta tradizionale: • 330 gr di farina ’00 + un pò per la"
- Caption signal: messy_recipe_like score=18
- Result: ok=True usedLLM=True duration_ms=3324
- Draft: ingredients=15 steps=0 confidence=medium
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 16. Tortino all’acqua senza zucchero raffinato, uova burro e latticini!!

- Source: https://www.instagram.com/p/DXHts-riu4N/
- Caption excerpt: "Tortino all’acqua senza zucchero raffinato, uova burro e latticini!! ✨PROVALO SUBITO!! ✨ 📍ti servirà : -55 gr farina"
- Caption signal: messy_recipe_like score=17
- Result: ok=True usedLLM=True duration_ms=2849
- Draft: ingredients=7 steps=3 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 17. CORDON BLEU LIGHT

- Source: https://www.instagram.com/p/DU1TKh6DG5S/
- Caption excerpt: "CORDON BLEU LIGHT 🍗 ~~~~~~~~~~ Se non hai voglia di mangiare delle secche fette di petto di pollo,"
- Caption signal: messy_recipe_like score=17
- Result: ok=True usedLLM=True duration_ms=2572
- Draft: ingredients=10 steps=0 confidence=high
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: none
- Applied autofixes: none

### 18. SANGUCHITOS DE CARNE DESMECHADA

- Source: https://www.instagram.com/p/C3eHfK8JZBy/
- Caption excerpt: "SANGUCHITOS DE CARNE DESMECHADA🥩, en un pancito de papa que la rompe toda. 🎥 receta de @kulinaria.recetas ."
- Caption signal: messy_recipe_like score=16
- Result: ok=True usedLLM=True duration_ms=4961
- Draft: ingredients=22 steps=0 confidence=medium
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: timings_missing
- Applied autofixes: none

### 19. Sorprendila con la semplicità

- Source: https://www.instagram.com/p/DX_V5bgj6w0/
- Caption excerpt: "𝗦𝗼𝗿𝗽𝗿𝗲𝗻𝗱𝗶𝗹𝗮 𝗰𝗼𝗻 𝗹𝗮 𝘀𝗲𝗺𝗽𝗹𝗶𝗰𝗶𝘁𝗮̀. 🍣 Per la Festa della Mamma abbiamo pensato a un piatto che unisce la"
- Caption signal: weak_recipe_signal score=21
- Result: ok=True usedLLM=True duration_ms=3175
- Draft: ingredients=7 steps=6 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 20. Spiedini Salsiccia e Zucchine

- Source: https://www.instagram.com/p/DHmHq9xAa4X/
- Caption excerpt: "Spiedini Salsiccia e Zucchine – facili, sfiziosi e perfetti in friggitrice ad aria! Ingredienti: • 1 zucchina •"
- Caption signal: weak_recipe_signal score=21
- Result: ok=True usedLLM=True duration_ms=2606
- Draft: ingredients=4 steps=4 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none
