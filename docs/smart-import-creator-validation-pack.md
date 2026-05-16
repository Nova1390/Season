# Smart Import Creator Validation Pack

Manual validation pack for caption-only Smart Import testing in `CreateRecipeView`.

Scope:
- Local Swift flow only: caption input -> parser -> fallback decision -> final draft ingredients.
- No backend, SQL, Edge Function, catalog write, translation, or LLM contract changes.
- Use this pack before further parser work to measure real-world creator behavior.

Release gate:
- Do not upload a new TestFlight build after Smart Import parser changes until the real-flow audit, server-fallback audit, and at least the regression cases below have been verified.
- A single successful caption is not enough. The risotto caption is a useful smoke test, but it must not be treated as proof that titles and quantities work for other creator captions.
- Server/LLM output is allowed to improve a draft, but it must not overwrite a better local title, remove explicit quantities, introduce duplicate ingredients, or downgrade catalog matches.
- If TestFlight already contains a build with a failed Smart Import regression, mark it as not suitable for wider distribution and ship a new build only after this gate passes.

How to test:
1. Open Create Recipe.
2. Paste one caption into the Smart Import caption field. Leave URL empty unless a test explicitly adds one later.
3. Run Import Draft.
4. Compare final draft ingredients against expected ingredients and quantities.
5. Record: lost ingredients, custom ingredients, duplicated ingredients, wrong quantity/unit, fallback notice/attempt, and obvious title/noise leakage.

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
| SI-CVP-026 | easy | `Pasta tonno e capperi Ingredienti: pasta 200g; tonno sott'olio 120g; capperi sotto sale; acciughe sott'olio 2; prezzemolo` | pasta, tuna, capers, anchovies, parsley | pasta 200g; tuna 120g; anchovies 2 piece; no extra olive oil from sott'olio | skip |
| SI-CVP-027 | easy | `Risotto ai funghi per 2: riso 180g, funghi 250g, brodo vegetale caldo 700ml, burro 20g, parmigiano 30g. Tosta il riso, aggiungi i funghi, cuoci con il brodo poco alla volta e manteca con burro e parmigiano` | rice, mushrooms, broth, butter, parmesan | rice 180g; mushrooms 250g; broth 700ml; butter 20g; parmesan 30g | skip |
| SI-CVP-031 | easy | `Insalata di pollo per 2: pollo grigliato 250g, lattuga 120g, pomodorini 150g, mais 80g, olive 40g, olio 1 cucchiaio, limone mezzo. Taglia tutto, unisci in ciotola e condisci.` | chicken, lettuce, cherry tomato, corn, olives, olive oil, lemon | chicken 250g; lettuce 120g; cherry tomatoes 150g; corn 80g; olives 40g; oil 1 tbsp; lemon default | skip |
| SI-CVP-032 | easy | `Pancake banana e avena x2: banana 1, uova 2, fiocchi d'avena 80g, latte 100ml, lievito 1 cucchiaino. Frulla tutto, cuoci in padella antiaderente 2 minuti per lato.` | banana, eggs, oat flakes, milk, yeast/leavening | banana 1 piece; eggs 2 piece; oats 80g; milk 100ml; yeast 1 tsp | maybe |

## May 16 Smart Import Regression Cases

These cases reproduce the user-facing failures found on TestFlight build `1.0.1 (7)`: title staying `Untitled recipe`, explicit quantities disappearing after server fallback, and ingredient lists degrading after a seemingly successful "Alta qualità" import.

| ID | Caption | Must pass |
|---|---|---|
| REG-20260516-001 | `Risotto ai funghi per 2: riso 180g, funghi 250g, brodo vegetale caldo 700ml, burro 20g, parmigiano 30g. Tosta il riso, aggiungi i funghi, cuoci con il brodo poco alla volta e manteca con burro e parmigiano` | Title `Risotto ai funghi`; 5 unique ingredients; all explicit quantities preserved; at least 1 step. |
| REG-20260516-002 | `Insalata di pollo per 2: pollo grigliato 250g, lattuga 120g, pomodorini 150g, mais 80g, olive 40g, olio 1 cucchiaio, limone mezzo. Taglia tutto, unisci in ciotola e condisci.` | Title `Insalata di pollo`; 7 unique ingredients; no missing quantities for measured ingredients; `limone mezzo` preserved as 0.5 piece; at least 1 step. |
| REG-20260516-003 | `Pancake banana e avena x2: banana 1, uova 2, fiocchi d'avena 80g, latte 100ml, lievito 1 cucchiaino. Frulla tutto, cuoci in padella antiaderente 2 minuti per lato.` | Title `Pancake banana e avena`; banana 1, eggs 2, oats 80g, milk 100ml, leavening 1 tsp; at least 1 step. |
| REG-20260516-004 | `Muffin banana e cioccolato per 6: banana 2, farina 180g, uova 2, zucchero 80g, latte 80ml, lievito 1 bustina, gocce di cioccolato 70g. Mescola tutto, versa negli stampi e cuoci a 180 gradi per 20 minuti.` | Title `Muffin banana e cioccolato`; chocolate chips must remain `gocce di cioccolato`/custom if not cataloged and must never match `cola`; at least 1 step. |
| REG-20260516-005 | `Frittata spinaci e patate per 2: uova 4, spinaci 150g, patate 250g, parmigiano 30g, sale q.b., olio 1 cucchiaio. Lessare le patate, saltare gli spinaci, unire con le uova e cuocere in padella.` | Title `Frittata spinaci e patate`; 6 ingredients; infinitive procedure verbs must produce at least 1 step. |

Automated checks:

```bash
SEASON_RUN_SMART_IMPORT_REAL_FLOW_AUDIT=1 run the Debug app on simulator
SEASON_RUN_SMART_IMPORT_SERVER_FALLBACK_AUDIT=1 run the Debug app on simulator
```

The server-fallback audit has two parts:
- A deterministic degrading-server simulation that feeds `Untitled recipe` and quantityless ingredients into the Swift quality gate. This must preserve the local title, quantities, and unique ingredients.
- A live Edge Function attempt when the simulator has an authenticated Supabase session. If the simulator is unauthenticated, the live rows may show `serverError: unauthenticated`; that is not a pass for the live server, but the degrading simulation still validates the client-side safety gate.

Manual checks:
- Run at least `REG-20260516-001`, `REG-20260516-002`, and `REG-20260516-003` through the actual Create Recipe UI before TestFlight upload.
- Keep the keyboard open/closed states in mind: the bottom publish bar must not hide the ingredients being validated.
- Do not accept `Alta qualità` as a pass condition by itself; inspect title, portions, ingredients, quantities, duplicate rows, and steps.

May 16 simulator notes:
- The Smart Import disclosure now scrolls its action button into view when opened, so `Importa bozza` must remain tappable above the sticky `Salva bozza / Pubblica` bar.
- The title parser is tolerant of inline servings followed by ingredient lists even when the simulator keyboard injects a malformed separator, e.g. `x2ç` or `per 2ç`. This protects the same creator-caption shape as the real `:` input.
- Manual UI verification passed for `REG-20260516-002` and `REG-20260516-003` after the scroll/title robustness fix: clean title, correct servings, no duplicate ingredients, explicit quantities preserved, and at least one step.
- `lievito` in the pancake case may still require catalog confirmation until the catalog agent resolves the governed canonical mapping; this is not a Smart Import quantity/title regression.

May 16 intensive simulator pass:
- Branch under test: `hotfix/smart-import-user-flow-build-8`.
- Simulator: iPhone 17 Pro, Debug build, local Swift Smart Import flow.
- Automated stress file: `/private/tmp/season_smart_import_stress_100.json`.
- Result: 100 captions tested, 72 pass, 28 partial, 0 fail.
- Regression metrics: 0 title failures, 0 title suspects, 0 missing expected ingredients, 0 invented quantities, duplicate rate effectively 0 on the expected core ingredients.
- The 28 partial rows are catalog coverage/specificity gaps, not parser regressions: examples include `lievito`, `fragole`, `pinoli`, `carne macinata`, `panna fresca`.
- Remaining specificity warnings include parent matches such as `farina 00 -> flour` and `cipolla rossa -> onion`; the visible creator text is preserved, but catalog identity can be improved by Catalog Agent.
- Manual UI verification passed for `REG-20260516-002`, `REG-20260516-003`, and a keyboard-injection pasta case: `Pasta tonno e limone per 2ç pasta 180g, tonno sottàolio 120g...`.
- The keyboard-injection pasta case must produce title `Pasta tonno e limone`, 6 ingredients, preserved quantities for pasta and tuna, q.b. ingredients without fake numeric doses, and at least one step.
- Post-TestFlight device feedback added two regression guards: substring catalog matches must not map `gocce di cioccolato` to `cola`, and Italian infinitive procedure text such as `Lessare... saltare... unire...` must count as preparation steps.
- Follow-up simulator audit after those guards: 52 real-flow captions, 0 blocking samples, 0 title failures, 0 lost expected ingredients, 0 quantity/unit drifts, 0 duplicate final drafts, 0 forbidden matches, 0 step failures. The two new regressions passed as `muffin_chocolate_chips_not_cola` and `frittata_infinitive_steps`.
- Server-fallback degradation audit passed on the protected samples: simulated server output with `Untitled recipe` and degraded/no-quantity ingredients did not override the better local title, quantities, unique ingredient list, or steps. Live server rows were `unauthenticated` in the simulator session and must not be counted as live Edge Function proof.
- During the pass, the remote import quota returned `Limite giornaliero import raggiunto`; this must not block the local parser from producing a usable draft.

May 16 release-candidate `1.0.1 (9)` gate notes:
- Release/staging simulator login and session persistence passed after restoring authenticated `profiles` grants and app-side Supabase auth storage.
- Manual UI verification passed for risotto, insalata, pancake, and pasta captions on the Release simulator. `REG-20260516-002` specifically preserves `Limone` as `0.5 pezzo`.
- Supabase staging preflight passed: migration history is up to date and schema lint reports no errors.
- Release iPhoneOS build with `CODE_SIGNING_ALLOWED=NO` passed before upload/archive preparation.
- Build number was bumped from `1.0.1 (8)` to `1.0.1 (9)` for the next TestFlight candidate, because App Store Connect requires a new build number for every upload.

Hard release rule after this pass:
- Do not upload another TestFlight build for Smart Import unless the 100-caption stress harness, the real-flow audit, and at least the three manual UI regression cases above have been re-run on the exact candidate branch.
- Treat a green build as compile evidence only. Smart Import requires user-flow evidence before distribution.

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
- Inline recipe titles are clean: `Ingredienti:` must not remain attached to the title.
- Preparation-state phrases do not create false extra ingredients, e.g. `sott'olio` must not add standalone olive oil.
- Non-countable q.b. ingredients avoid invalid `.piece` draft behavior.
- Weak captions may trigger fallback, but strong inline ingredient blocks should not.
