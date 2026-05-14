# Smart Import real-caption E2E

Updated: 2026-05-14T08:26:37+00:00

This report uses real Instagram caption exports collected through Apify. Captions are not stored in full; only short excerpts and source URLs are kept for review.

## Summary

- Raw captions discovered: 2035
- Captions selected for bounded E2E: 7
- Edge responses OK: 7/7
- Publish-ready drafts: 7
- Needs more input: 0

## Findings

- High-signal creator captions are now reliably transformed into publishable drafts.
- The recurring residual quality gaps are non-blocking metadata: servings and timings.
- This E2E intentionally does not store full social captions in the repo.

## Results

### 1. Zuppa inglese

- Source: https://www.instagram.com/p/DR6sa03CLer/
- Caption excerpt: "👩‍🍳🧑‍🍳INGREDIENTI : 🍰PAN DI SPAGNA: •110g Uova (circa 2 medie) •30g Farina 00 •30g Fecola di patate •60g"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=8397
- Draft: ingredients=16 steps=18 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 2. Zeppole di San Giuseppe al forno

- Source: https://www.instagram.com/p/DHY2YjYMuzz/
- Caption excerpt: "Buon Festa del Papà a tutti i Papà del mondo ❤️ Zeppole di San Giuseppe al forno Ingredienti"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=5826
- Draft: ingredients=15 steps=14 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 3. Cream tart monoporzione per la Festa della Mamma

- Source: https://www.instagram.com/p/DYFg9t5sIYX/
- Caption excerpt: "🍰Per la Festa della Mamma ho scelto la semplicità . Frolla classica, crema pasticcera e amarene. Quei sapori"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=6662
- Draft: ingredients=17 steps=13 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Applied autofixes: none

### 4. brookies

- Source: https://www.instagram.com/p/DXhXmcoMeUP/
- Caption excerpt: "🍪Doveva essere un cookie. Poi è degenerata. E il problema è che funziona. Troppo. Crosticina fuori. Morbidissimo dentro."
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=7934
- Draft: ingredients=16 steps=10 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing
- Applied autofixes: none

### 5. LATTE FRITTO… versione tropicale

- Source: https://www.instagram.com/p/DXcWWSuCBQ0/
- Caption excerpt: "✨ LATTE FRITTO… versione tropicale 🥥🌴 Un grande classico della tradizione siciliana… ma con un twist inaspettato! Oggi"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=7657
- Draft: ingredients=9 steps=7 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none

### 6. Ricetta Pizza al Piatto

- Source: https://www.instagram.com/p/DGL8oB3u8uI/
- Caption excerpt: "Ora che ho perso la vista ci vedo di più. !! Se cuocete in casa o in forni"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4158
- Draft: ingredients=4 steps=12 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: timings_missing
- Applied autofixes: none

### 7. Sempre voglia di tiramisù?

- Source: https://www.instagram.com/p/DYC_mnjKWNu/
- Caption excerpt: "Sempre voglia di tiramisù? Ecco il secondo reel con un altra idea davvero A T O M I"
- Caption signal: complete_recipe score=28
- Result: ok=True usedLLM=True duration_ms=4200
- Draft: ingredients=15 steps=4 confidence=high
- Agent: quality=publishable next=publish
- Blocking issues: none
- Nice to fix: servings_missing, timings_missing
- Applied autofixes: none
