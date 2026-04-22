# Smart Import Creator Validation Pack

Manual validation pack for caption-only Smart Import testing in `CreateRecipeView`.

Scope:
- Local Swift flow only: caption input -> parser -> fallback decision -> final draft ingredients.
- No backend, SQL, Edge Function, catalog write, translation, or LLM contract changes.
- Use this pack before further parser work to measure real-world creator behavior.

How to test:
1. Open Create Recipe.
2. Paste one caption into the Smart Import caption field. Leave URL empty unless a test explicitly adds one later.
3. Run Import Draft.
4. Compare final draft ingredients against expected ingredients and quantities.
5. Record: lost ingredients, custom ingredients, wrong quantity/unit, fallback notice/attempt, and obvious title/noise leakage.

Expected fallback:
- `skip`: local import should likely resolve all useful ingredient candidates and skip server fallback if refinement asks for one.
- `keep`: local import should likely keep local result without needing fallback.
- `maybe`: local import may reasonably attempt fallback because the ingredient structure is weak or noisy.

## Easy Structured Ingredient Captions

| ID | Difficulty | Caption | Expected core ingredients | Expected quantities | Expected fallback |
|---|---|---|---|---|---|
| SI-CVP-001 | easy | `Ingredienti: 200g spaghetti / passata di pomodoro 250g / olio evo q.b. / sale q.b.` | pasta, passata, olive oil, salt | pasta 200g; passata 250g; oil q.b.; salt q.b. | skip |
| SI-CVP-002 | easy | `Ingredienti: zucchine 2 / patate 3 / cipolle dorate 1 / olio evo q.b.` | zucchini, potato, onion, olive oil | zucchini 2 piece; potato 3 piece; onion 1 piece; oil q.b. | skip |
| SI-CVP-003 | easy | `Ingredienti: 4 uova / zucchine 2 / parmigiano 30g / sale q.b. / pepe q.b.` | eggs, zucchini, parmesan, salt, black pepper | eggs 4 piece; zucchini 2 piece; parmesan 30g; salt/pepper q.b. | skip |
| SI-CVP-004 | easy | `Ingredienti: farina 00 500g / acqua 350 ml / olio evo q.b. / sale q.b.` | flour, water, olive oil, salt | flour 500g; water 350ml; oil/salt q.b. | skip |
| SI-CVP-005 | easy | `Ingredienti: riso 180g / funghi 250g / brodo vegetale / burro / parmigiano reggiano 30g` | rice, mushrooms, broth, butter, parmesan | rice 180g; mushrooms 250g; parmesan 30g; broth/butter default | skip |
| SI-CVP-006 | easy | `Ingredienti: bucatini 180g / guanciale 90g / pecorino romano / pepe nero` | pasta, guanciale, pecorino, black pepper | pasta 180g; guanciale 90g; pecorino/pepper default or q.b. | skip |
| SI-CVP-007 | easy | `Ingredienti: tonno sott'olio 120g / capperi sotto sale / acciughe sott'olio 2 / pasta 200g` | tuna, capers, anchovies, pasta | tuna 120g; anchovies 2 piece; pasta 200g; capers default | skip |
| SI-CVP-008 | easy | `Ingredienti: patate 4 / funghi 200g / aglio 1 spicchio / rosmarino / sale q.b.` | potato, mushrooms, garlic, salt | potato 4 piece; mushrooms 200g; garlic 1 clove; salt q.b.; rosemary may be missed if not cataloged | maybe |

## Realistic Creator Captions With CTA, Noise, Emojis

| ID | Difficulty | Caption | Expected core ingredients | Expected quantities | Expected fallback |
|---|---|---|---|---|---|
| SI-CVP-009 | medium | `SALVA il video 🍝 In 5 min: zucchine 2, pasta 200g, olio evo q.b., pepe nero` | zucchini, pasta, olive oil, black pepper | zucchini 2 piece; pasta 200g; oil/pepper q.b. | skip |
| SI-CVP-010 | medium | `La carbonara cremosa che rifarai sempre 😍 ingredienti: spaghetti 200g / guanciale 80g / 2 uova / pecorino romano 40g / pepe nero q.b.` | pasta, guanciale, eggs, pecorino, black pepper | pasta 200g; guanciale 80g; eggs 2; pecorino 40g; pepper q.b. | skip |
| SI-CVP-011 | medium | `Pasta al volo: 200g pasta, 1 spicchio aglio, olio evo q.b., acciughe sott'olio 2, capperi sotto sale. Salvala!` | pasta, garlic, olive oil, anchovies, capers | pasta 200g; garlic 1 clove; anchovies 2 piece; oil q.b.; capers default | skip |
| SI-CVP-012 | medium | `Cena svuota frigo 🥔 patate 3 / cipolle dorate 1 / funghi 200g / olio evo q.b. / sale q.b.` | potato, onion, mushrooms, olive oil, salt | potato 3 piece; onion 1 piece; mushrooms 200g; oil/salt q.b. | skip |
| SI-CVP-013 | medium | `Non buttare le zucchine! Ingredienti: zucchine 2; uova 3; parmigiano reggiano 40g; pepe nero; basilico` | zucchini, eggs, parmesan, black pepper, basil | zucchini 2; eggs 3; parmesan 40g; pepper/basil default | skip |
| SI-CVP-014 | medium | `Risotto super cremoso ✨ riso 180g, funghi 250g, brodo vegetale, burro, parmigiano 30g. Segui per altre ricette.` | rice, mushrooms, broth, butter, parmesan | rice 180g; mushrooms 250g; parmesan 30g; broth/butter default | skip |
| SI-CVP-015 | medium | `La pasta tonno e capperi piu facile: pasta 200g; tonno sott'olio 120g; capperi sotto sale; acciughe sott'olio 2; prezzemolo` | pasta, tuna, capers, anchovies, parsley | pasta 200g; tuna 120g; anchovies 2; capers/parsley default | skip |
| SI-CVP-016 | medium | `Salva questa focaccia: farina 00 500g / acqua 350ml / lievito / olio evo q.b. / sale q.b.` | flour, water, olive oil, salt; yeast if cataloged | flour 500g; water 350ml; oil/salt q.b.; yeast may be custom/missed | maybe |

## Messy Mixed Captions: Ingredients + Procedure

| ID | Difficulty | Caption | Expected core ingredients | Expected quantities | Expected fallback |
|---|---|---|---|---|---|
| SI-CVP-017 | medium | `Spaghetti al pomodoro: 200g spaghetti / passata 250g / basilico / olio evo q.b. Poi cuoci la pasta e manteca tutto.` | pasta, passata, basil, olive oil | pasta 200g; passata 250g; basil/oil default or q.b. | skip |
| SI-CVP-018 | medium | `Carbonara: guanciale 100g, pasta 200g, 2 uova, pecorino 50g, pepe. Rosola il guanciale e spegni il fuoco.` | guanciale, pasta, eggs, pecorino, black pepper | guanciale 100g; pasta 200g; eggs 2; pecorino 50g | skip |
| SI-CVP-019 | medium | `Taglia zucchine 2 e patate 3, aggiungi cipolla dorata 1 e olio evo q.b., poi in forno fino a doratura.` | zucchini, potato, onion, olive oil | zucchini 2; potato 3; onion 1; oil q.b. | skip |
| SI-CVP-020 | medium | `Per il risotto: riso 180g, brodo vegetale caldo, funghi 250g. Tosta, sfuma e alla fine burro + parmigiano.` | rice, broth, mushrooms, butter, parmesan | rice 180g; mushrooms 250g; broth/butter/parmesan default | skip |
| SI-CVP-021 | medium | `In padella: aglio 1 spicchio, acciughe sott'olio 3, capperi sotto sale, tonno 120g, pasta 200g. Manteca con acqua di cottura.` | garlic, anchovies, capers, tuna, pasta | garlic 1 clove; anchovies 3; tuna 120g; pasta 200g; capers default | skip |
| SI-CVP-022 | medium | `Impasto veloce: farina 00 500g acqua 350 ml sale q.b. olio evo q.b. Mescola, riposa e cuoci.` | flour, water, salt, olive oil | flour 500g; water 350ml; salt/oil q.b. | skip |
| SI-CVP-023 | medium | `Frittata: uova 4, zucchine 2, cipolle dorate 1. Grattugia parmigiano 30g, sale e pepe, poi padella.` | eggs, zucchini, onion, parmesan, salt, black pepper | eggs 4; zucchini 2; onion 1; parmesan 30g; salt/pepper default | skip |
| SI-CVP-024 | medium | `Pasta fredda: pasta 200g, pomodori 3, tonno sott'olio 120g, capperi, basilico. Raffredda e condisci.` | pasta, tomato, tuna, capers, basil | pasta 200g; tomatoes 3; tuna 120g; capers/basil default | skip |

## Difficult Captions With Weak Ingredient Structure

| ID | Difficulty | Caption | Expected core ingredients | Expected quantities | Expected fallback |
|---|---|---|---|---|---|
| SI-CVP-025 | hard | `Questa pasta nasce con quello che avevo: spaghetti, pomodoro, olio buono, aglio e basilico. Fine.` | pasta, tomato/passata, olive oil, garlic, basil | mostly not recoverable | maybe |
| SI-CVP-026 | hard | `Frittata di recupero con uova, zucchine, cipolla e tanto parmigiano. Sale e pepe alla fine.` | eggs, zucchini, onion, parmesan, salt, black pepper | not recoverable | maybe |
| SI-CVP-027 | hard | `Risotto senza stress: riso, funghi, brodo caldo sempre vicino, una noce di burro e parmigiano.` | rice, mushrooms, broth, butter, parmesan | not recoverable | maybe |
| SI-CVP-028 | hard | `La puttanesca pigra: pasta, acciughe, capperi, pomodoro e olive. Tutto in padella mentre bolle l'acqua.` | pasta, anchovies, capers, tomato/passata, olives if cataloged | not recoverable | maybe |
| SI-CVP-029 | hard | `Patate e cipolle come le faceva nonna: patate, cipolle dorate, rosmarino, sale, pepe, olio. Niente bilancia.` | potato, onion, rosemary, salt, black pepper, olive oil | not recoverable | maybe |
| SI-CVP-030 | hard | `Cena in 10 minuti: apro il tonno, aggiungo capperi e acciughe, poi pasta e un giro d'olio.` | tuna, capers, anchovies, pasta, olive oil | not recoverable | maybe |

## Recommended First 10 In-App Tests

Run these first because they cover the highest-value creator cases and the most likely failure modes:

1. `SI-CVP-001` - inline `Ingredienti:` remainder with slash-separated measured ingredients.
2. `SI-CVP-002` - bare-count vegetables and adjective normalization.
3. `SI-CVP-004` - `farina 00`, reversed quantity, ml spacing.
4. `SI-CVP-010` - carbonara with CTA/emojis and mixed bare/measured counts.
5. `SI-CVP-011` - title contamination, garlic clove, anchovies, capers.
6. `SI-CVP-014` - risotto title/noise plus quantityless high-signal ingredients.
7. `SI-CVP-015` - tuna/capers/anchovies creator caption.
8. `SI-CVP-019` - procedure-first mixed sentence with bare counts.
9. `SI-CVP-024` - tomato/pomodori and mixed pantry/produce.
10. `SI-CVP-025` - weak ingredient structure where fallback may be appropriate.

Pass criteria for first 10:
- No high-value ingredient silently lost.
- No high-value ingredient degraded to custom when a local catalog match exists.
- Explicit quantities survive into the final draft.
- Non-countable q.b. ingredients avoid invalid `.piece` draft behavior.
- Weak captions may trigger fallback, but strong inline ingredient blocks should not.
