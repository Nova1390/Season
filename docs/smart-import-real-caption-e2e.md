# Smart Import real-caption E2E

Updated: 2026-05-14T15:34:39+00:00

This report uses real Instagram caption exports collected through Apify. Captions are not stored in full; only short excerpts and source URLs are kept for review.

## Summary

- Raw captions discovered: 2035
- Captions selected for bounded E2E: 40
- Selection strategy: stratified
- Edge responses OK: 40/40
- Publish-ready drafts: 27
- Needs more input: 12
- Caption categories: {"complete_recipe": 19, "ingredient_rich": 3, "messy_recipe_like": 8, "method_rich": 6, "weak_recipe_signal": 4}
- Draft qualities: {"needs_creator_review": 1, "needs_more_input": 12, "publishable": 27}
- Agent next actions: {"add_ingredient_amounts": 1, "add_method_steps": 11, "add_more_recipe_detail": 1, "publish": 27}
- Error codes: {"none": 40}

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
- Result: ok=True usedLLM=True duration_ms=6607
- Draft: ingredients=16 steps=18 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 2. Zeppole di San Giuseppe al forno

- Source: https://www.instagram.com/p/DHY2YjYMuzz/
- Caption excerpt: "Buon Festa del Papà a tutti i Papà del mondo ❤️ Zeppole di San Giuseppe al forno Ingredienti"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=5575
- Draft: ingredients=15 steps=14 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 3. Per la Festa della Mamma ho scelto la semplicità

- Source: https://www.instagram.com/p/DYFg9t5sIYX/
- Caption excerpt: "🍰Per la Festa della Mamma ho scelto la semplicità . Frolla classica, crema pasticcera e amarene. Quei sapori"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4729
- Draft: ingredients=17 steps=13 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Applied autofixes: none

### 4. Doveva essere un cookie. Poi è degenerata.

- Source: https://www.instagram.com/p/DXhXmcoMeUP/
- Caption excerpt: "🍪Doveva essere un cookie. Poi è degenerata. E il problema è che funziona. Troppo. Crosticina fuori. Morbidissimo dentro."
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4892
- Draft: ingredients=16 steps=10 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 5. Pastiera Napoletana

- Source: https://www.instagram.com/p/DWEh3OOiP-t/
- Caption excerpt: "Pastiera Napoletana: il dolce della tradizione perfetto per Pasqua! 🥧🤤 Ingredienti: Per la pasta frolla: - 250 gr"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4756
- Draft: ingredients=15 steps=6 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 6. LATTE FRITTO… versione tropicale

- Source: https://www.instagram.com/p/DXcWWSuCBQ0/
- Caption excerpt: "✨ LATTE FRITTO… versione tropicale 🥥🌴 Un grande classico della tradizione siciliana… ma con un twist inaspettato! Oggi"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4145
- Draft: ingredients=9 steps=7 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 7. Ricetta Pizza al Piatto

- Source: https://www.instagram.com/p/DGL8oB3u8uI/
- Caption excerpt: "Ora che ho perso la vista ci vedo di più. !! Se cuocete in casa o in forni"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=3353
- Draft: ingredients=4 steps=12 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Applied autofixes: none

### 8. Sempre voglia di tiramisù?

- Source: https://www.instagram.com/p/DYC_mnjKWNu/
- Caption excerpt: "Sempre voglia di tiramisù? Ecco il secondo reel con un altra idea davvero A T O M I"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=3840
- Draft: ingredients=15 steps=4 confidence=medium
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 9. Panini per hamburger

- Source: https://www.instagram.com/p/DI7Hd4-MW0F/
- Caption excerpt: "Panini per hamburger avrebbe detto uno dei miei insegnanti. Questa è una variante di Giorilli appunto. Ho solo"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=2883
- Draft: ingredients=9 steps=9 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 10. La crostata che ha conquistato i miei bambini per merenda

- Source: https://www.instagram.com/p/DXwpm9lMsKq/
- Caption excerpt: "La crostata che ha conquistato i miei bambini per merenda. Base friabile, cuore cremoso e tanta frutta fresca…"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=3431
- Draft: ingredients=10 steps=7 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 11. ZARU SOBA: NOODLES FREDDI GIAPPONESI

- Source: https://www.instagram.com/p/DMgOy_8sW-V/
- Caption excerpt: "🍜 ZARU SOBA: NOODLES FREDDI GIAPPONESI 🇯🇵 Il piatto estivo più amato in Giappone: semplice, fresco e super"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4210
- Draft: ingredients=9 steps=6 confidence=medium
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Applied autofixes: none

### 12. Brownies proteici senza zuccheri aggiunti

- Source: https://www.instagram.com/p/DWtSbKTsrcZ/
- Caption excerpt: "𝗕𝗿𝗼𝘄𝗻𝗶𝗲𝘀 𝗽𝗿𝗼𝘁𝗲𝗶𝗰𝗶 𝘀𝗲𝗻𝘇𝗮 𝘇𝘂𝗰𝗰𝗵𝗲𝗿𝗶 𝗮𝗴𝗴𝗶𝘂𝗻𝘁𝗶 questi li rifaccio!! 😋 super semplici, pochi ingredienti e perfetti quando hai voglia"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=2744
- Draft: ingredients=10 steps=6 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 13. Brownie al cioccolato in padella (senza forno!)

- Source: https://www.instagram.com/p/DXoX_Fqo_G6/
- Caption excerpt: "⚠️ Attenzione: crea dipendenza. Brownie al cioccolato in padella (senza forno!) 😎 🍫 Super morbido e intenso, perfetto"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=2804
- Draft: ingredients=9 steps=5 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 14. crepes proteica

- Source: https://www.instagram.com/p/DVZC5vXDKcD/
- Caption excerpt: "190 CALORIE per una crepes proteica che puoi fare anche se NON sai cucinare. Zero voglia di cucinare?"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=2518
- Draft: ingredients=7 steps=3 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Applied autofixes: none

### 15. CIAMBELLONE CACHI E CASTAGNE

- Source: https://www.instagram.com/p/DQZz9hnCMU4/
- Caption excerpt: "CIAMBELLONE CACHI E CASTAGNE INGREDIENTI: • 200 gr. di farina normale o integrale • 4 cachi medi maturi"
- Caption signal: ingredient_rich score=18
- Result: ok=True usedLLM=True duration_ms=1888
- Draft: ingredients=6 steps=0 confidence=high
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 16. Gnocchetti di zucca

- Source: https://www.instagram.com/p/DRKvT4_jMjH/
- Caption excerpt: "Gnocchetti di zucca 🎃 Ingredienti per 2 persone * 250gr di polpa di zucca (cotta al forno con"
- Caption signal: ingredient_rich score=18
- Result: ok=True usedLLM=True duration_ms=2411
- Draft: ingredients=8 steps=0 confidence=high
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: timings_missing
- Applied autofixes: none

### 17. Cheesecake a colazione

- Source: https://www.instagram.com/p/DXbdtd3DMZk/
- Caption excerpt: "Cheesecake a colazione? Perché no! E sì, si può anche a “dieta”! 🙃 Che dici, ti ispira? ✨seguimi"
- Caption signal: ingredient_rich score=13
- Result: ok=True usedLLM=True duration_ms=2829
- Draft: ingredients=8 steps=0 confidence=high
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 18. Hummus di avocado e ceci

- Source: https://www.instagram.com/p/DVGVWlYjU00/
- Caption excerpt: "🥑 HUMMUS DI AVOCADO E CECI Una crema pronta in 5 minuti che ti salva aperitivi, pranzi veloci"
- Caption signal: method_rich score=22
- Result: ok=True usedLLM=True duration_ms=2782
- Draft: ingredients=6 steps=0 confidence=high
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing
- Applied autofixes: none

### 19. TORTA DI MELE

- Source: https://www.instagram.com/p/DQdySXYiOUA/
- Caption excerpt: "TORTA DI MELE🍂 Ingredienti: • 2 uova • 150 zucchero • 60 burro sciolto a bagno maria •"
- Caption signal: method_rich score=22
- Result: ok=True usedLLM=True duration_ms=2914
- Draft: ingredients=8 steps=0 confidence=medium
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 20. UN SUPERFOOD DA COLTIVARE IN CASA?!?

- Source: https://www.instagram.com/p/DXJjgtBiONJ/
- Caption excerpt: "UN SUPERFOOD DA COLTIVARE IN CASA?!? 🌱 Niente strane polveri o ingredieti assurdi: parlo dei GERMOGLI DI LENTICCHIE!"
- Caption signal: method_rich score=21
- Result: ok=True usedLLM=True duration_ms=3406
- Draft: ingredients=7 steps=7 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 21. Pollo Huli Huli

- Source: https://www.instagram.com/p/DWZP4pGClLj/
- Caption excerpt: "🔥Pollo Huli Huli🔥 . . 🧑‍🍳Pollo marinato a lungo, cotto fino alla giusta caramellizzazione e glassato più volte"
- Caption signal: method_rich score=21
- Result: ok=True usedLLM=True duration_ms=2934
- Draft: ingredients=12 steps=4 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 22. Torta soffice allo yogurt

- Source: https://www.instagram.com/p/DXXRl-FDu-a/
- Caption excerpt: "Torta soffice allo yogurt Perfetta per una merenda semplice o una colazione fatta in casa 🥰 👉🏻 Da"
- Caption signal: method_rich score=21
- Result: ok=True usedLLM=True duration_ms=3018
- Draft: ingredients=8 steps=5 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 23. Biscotto morbido al cioccolato

- Source: https://www.instagram.com/p/DPZX42IkbCa/
- Caption excerpt: "Biscotto morbido al cioccolato🍫 • 1 uovo • 1 avocado • 100 g di zucchero di canna •"
- Caption signal: method_rich score=21
- Result: ok=True usedLLM=True duration_ms=3728
- Draft: ingredients=8 steps=4 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 24. SANGUCHITOS DE CARNE DESMECHADA

- Source: https://www.instagram.com/p/C3eHfK8JZBy/
- Caption excerpt: "SANGUCHITOS DE CARNE DESMECHADA🥩, en un pancito de papa que la rompe toda. 🎥 receta de @kulinaria.recetas ."
- Caption signal: messy_recipe_like score=16
- Result: ok=True usedLLM=True duration_ms=10303
- Draft: ingredients=22 steps=0 confidence=medium
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: timings_missing
- Applied autofixes: none

### 25. POSTRE SÚPER CHOCOLATOSO CON SOLO 4 INGREDIENTES

- Source: https://www.instagram.com/p/C3cyex_LBOx/
- Caption excerpt: "POSTRE SÚPER CHOCOLATOSO CON SOLO 4 INGREDIENTES 🍫✨ receta de @lasrecetasdesimon 🫶 • Ideal para el verano, sin"
- Caption signal: messy_recipe_like score=14
- Result: ok=True usedLLM=True duration_ms=2296
- Draft: ingredients=4 steps=1 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 26. Ofyr Turkish Adana Kebab

- Source: https://www.instagram.com/p/DWrSq6UM7C8/
- Caption excerpt: "𝙊𝙛𝙮𝙧 𝙏𝙪𝙧𝙠𝙞𝙨𝙝 𝘼𝘿𝘼𝙉𝘼 𝙆𝙀𝘽𝘼𝘽🔥🔥 Pollo o il classico agnello?🐔🐑 Direttamente dalla Turchia. Costruito sulle spade. Come vuole la"
- Caption signal: messy_recipe_like score=12
- Result: ok=True usedLLM=True duration_ms=6599
- Draft: ingredients=30 steps=0 confidence=medium
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 27. TEAM BOBBY

- Source: https://www.instagram.com/p/DW1rvZgjJhV/
- Caption excerpt: "-𝙏𝙀𝘼𝙈 𝘽𝙊𝘽𝘽𝙔- Being chosen by @bobbyflay was a true honor for me. Our team had a strong connection"
- Caption signal: messy_recipe_like score=12
- Result: ok=True usedLLM=True duration_ms=1704
- Draft: ingredients=0 steps=0 confidence=low
- Agent: quality=needs_more_input next=add_more_recipe_detail
- Blocking issues: ingredients_missing, steps_missing, low_confidence_parse
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 28. pancake di mele

- Source: https://www.instagram.com/p/DC8ujztIJM6/
- Caption excerpt: "👉🏻seguimi @martinalasaluteincucina avere ogni giorno consigli e ricette. 👉🏻trovi le mie guide nutrizionali con i miei menu settimanali"
- Caption signal: messy_recipe_like score=10
- Result: ok=True usedLLM=True duration_ms=3225
- Draft: ingredients=7 steps=0 confidence=high
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: timings_missing
- Applied autofixes: none

### 29. ISSO AQUI É PERIGOSO

- Source: https://www.instagram.com/p/DTi_2Gnktl8/
- Caption excerpt: "🚨 ISSO AQUI É PERIGOSO 🚨 Não era pra ser só um docinho… Virou uma travessa inteira 🍫🤯"
- Caption signal: messy_recipe_like score=10
- Result: ok=True usedLLM=True duration_ms=2669
- Draft: ingredients=6 steps=0 confidence=high
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 30. PANE SENZA FARINA

- Source: https://www.instagram.com/p/DYCysq-NkIc/
- Caption excerpt: "PANE SENZA FARINA 😱 senza glutine ✨ Soffice, proteico e con solo 2 ingredienti: 👉 300g di albumi"
- Caption signal: messy_recipe_like score=10
- Result: ok=True usedLLM=True duration_ms=2441
- Draft: ingredients=3 steps=0 confidence=high
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 31. Cantucci

- Source: https://www.instagram.com/p/CHyDCYwjeKs/
- Caption excerpt: "Cantucci 🤩❤️ 3 uova 200 g zucchero 500 g farina 100 g di burro ammorbidito 200 g di"
- Caption signal: messy_recipe_like score=10
- Result: ok=True usedLLM=True duration_ms=2714
- Draft: ingredients=7 steps=0 confidence=high
- Agent: quality=needs_more_input next=add_method_steps
- Blocking issues: steps_missing
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 32. Burger di zucchine

- Source: https://www.instagram.com/p/DXmbIrPihkf/
- Caption excerpt: "Burger di zucchine 🥒✨ Se pensi che le verdure siano noiose… questa ricetta ti farà cambiare idea. Salvala"
- Caption signal: weak_recipe_signal score=20
- Result: ok=True usedLLM=True duration_ms=2176
- Draft: ingredients=4 steps=3 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 33. STRAWBERRY CHIA SEED BOWL

- Source: https://www.instagram.com/p/DYAZr6RoOt_/
- Caption excerpt: "STRAWBERRY CHIA SEED BOWL 🍓 📍 se ami le fragole e se alla ricerca di una ricetta sana"
- Caption signal: weak_recipe_signal score=20
- Result: ok=True usedLLM=True duration_ms=1814
- Draft: ingredients=5 steps=1 confidence=medium
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 34. Panino gourmet con salsiccia di Bra e Toma

- Source: https://www.instagram.com/p/DTkiDCaiImH/
- Caption excerpt: "Panino gourmet con salsiccia di Bra e Toma 🔥 Questo panino è possibile solo in Piemonte. Perché solo"
- Caption signal: weak_recipe_signal score=19
- Result: ok=True usedLLM=True duration_ms=2412
- Draft: ingredients=5 steps=6 confidence=high
- Agent: quality=needs_creator_review next=add_ingredient_amounts
- Blocking issues: none
- Nice to fix: quantities_missing, servings_missing, timings_missing
- Applied autofixes: none

### 35. Riso in teglia al forno

- Source: https://www.instagram.com/p/DYCuMWPxa2b/
- Caption excerpt: "EP. 3 ✨ Riso in teglia al forno: una ricetta veloce, pratica e con pochi ingredienti 💛 ⚠️"
- Caption signal: weak_recipe_signal score=19
- Result: ok=True usedLLM=True duration_ms=3191
- Draft: ingredients=12 steps=5 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 36. FONDUTA VALDOSTANA (quella vera)

- Source: https://www.instagram.com/p/DUi8LmgDQpG/
- Caption excerpt: "FONDUTA VALDOSTANA (quella vera) La fonduta valdostana non è una crema al formaggio qualsiasi. È una preparazione lenta,"
- Caption signal: complete_recipe score=26
- Result: ok=True usedLLM=True duration_ms=4145
- Draft: ingredients=5 steps=8 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Applied autofixes: none

### 37. Overnight lamponi e cioccolato

- Source: https://www.instagram.com/p/DX4eLT5KWgM/
- Caption excerpt: "Overnight lamponi e cioccolato 🍫💗 Una colazione golosa, fresca e pronta al risveglio. Perfetta quando vuoi qualcosa di"
- Caption signal: complete_recipe score=26
- Result: ok=True usedLLM=True duration_ms=2215
- Draft: ingredients=7 steps=4 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Applied autofixes: none

### 38. SALSA FIT AVOCADO & UOVA

- Source: https://www.instagram.com/p/DYEtMvvsZiE/
- Caption excerpt: "🥑 SALSA FIT AVOCADO & UOVA (cremosa, veloce, proteica!) Vuoi qualcosa di buono da spalmare sul pane ma"
- Caption signal: complete_recipe score=26
- Result: ok=True usedLLM=True duration_ms=5312
- Draft: ingredients=5 steps=5 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Applied autofixes: none

### 39. Una “focaccia” furba, pronta in pochi minuti!

- Source: https://www.instagram.com/p/DYEtLRZio0d/
- Caption excerpt: "Una “focaccia” furba, pronta in pochi minuti! Croccante fuori, morbida dentro… ma molto più leggera e bilanciata. Ingredienti"
- Caption signal: complete_recipe score=26
- Result: ok=True usedLLM=True duration_ms=2088
- Draft: ingredients=7 steps=2 confidence=medium
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: none
- Applied autofixes: none

### 40. Colazione sana, proteica e che sa di tiramisù

- Source: https://www.instagram.com/p/DXt11zSjHVa/
- Caption excerpt: "Colazione sana, proteica e che sa di tiramisù 🤤✨ La fai la sera prima e al mattino hai"
- Caption signal: complete_recipe score=26
- Result: ok=True usedLLM=True duration_ms=2555
- Draft: ingredients=7 steps=3 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none
