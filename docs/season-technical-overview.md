# Season - Documento Tecnico

Ultimo aggiornamento: 2026-05-09

## 1. Stack

- Piattaforma: iOS.
- UI: SwiftUI.
- Backend: Supabase.
- Auth: Supabase Auth, email/password e Apple Sign-In.
- Database remoto: Postgres via Supabase.
- Storage remoto: Supabase Storage per avatar.
- Persistenza locale: `UserDefaults`, `AppStorage`, cache in memoria e JSON bundle.
- Package principale: `supabase-swift`.
- Linguaggi backend edge: TypeScript/Deno per Supabase Edge Functions.

## 2. Entry point applicativo

File principali:

- `Season/SeasonApp.swift`: entry point SwiftUI, registra font e lancia audit debug sotto `#if DEBUG`.
- `Season/Views/AuthGateView.swift`: gate sessione auth, onboarding username e routing verso app autenticata.
- `Season/ContentView.swift`: tab shell principale, bottom bar custom, dispatcher outbox on launch/foreground.

Flow iniziale:

1. `SeasonApp` monta `AuthGateView`.
2. `AuthGateView` controlla sessione Supabase.
3. Se manca sessione, mostra login/signup.
4. Se manca username valido, mostra completion screen.
5. Se sessione e profilo sono validi, monta `ContentView`.
6. `ContentView` carica view model condivisi e processa outbox/follow sync.

## 3. Moduli UI principali

- `HomeView`: feed editoriale, hero ricetta, ranking, creator strip e sezioni stagionali.
- `SearchView`: ricerca ricette/ingredienti, filtri, sezioni discover e quick add; query state, debounce e rendering restano nella view, mentre ranking/filtering stanno in `SearchResultsService`.
- `InSeasonTodayView`: classifica ingredienti stagionali e insight mensili.
- `FridgeView`: lista frigo e ricette cucinabili dal frigo.
- `RecipeDetailView`: dettaglio ricetta, ingredienti, nutrizione, CTA, media, follow, save/crispy.
- `CreateRecipeView`: composer ricette, draft, smart import caption/URL, publish.
- `AccountView`: profilo, libreria, preferenze e auth tools. Le diagnostiche catalogo iOS sono disponibili solo in build Debug.
- `AuthorProfileView`: profilo creator/autore.
- `ShoppingListView`: lista della spesa.
- `ProduceDetailView` e `IngredientDetailView`: dettaglio prodotto/ingrediente.
- `CatalogCandidatesDebugView`: console legacy solo Debug; la governance catalogo operativa vive su `catalog.seasonapp.it`.

Componenti condivisi:

- `Season/Views/DesignSystem.swift`: colori/font/token UI.
- `Season/Views/UIComponents.swift`: card, top bar, badge, thumbnail, recipe card, componenti comuni.
- `Season/Views/HomeFeedAtoms.swift`: componenti feed Home.
- `Season/Components/RemoteImageView.swift`: rendering immagini remote.
- `Season/Components/AvatarView.swift`: avatar.

## 4. View model e servizi client

### View model

- `ProduceViewModel`: orchestratore principale per produce, ricette, ranking, stati ricette, search, nutrizione, catalog matching, publish e reconciliation-on-read.
- `FridgeViewModel`: stato frigo locale, add/remove, ingredienti custom/catalogo e write-through/outbox.
- `ShoppingListViewModel`: stato lista spesa, add/remove, ingredienti da ricetta, write-through/outbox.

### Servizi core

- `SupabaseService`: facade Supabase temporanea per auth, profili, ricette, stati, fridge, shopping, catalog RPC, edge function invoke e storage avatar. Il logging runtime passa da `SeasonLog`.
- `SmartImportRemoteDataSource`: datasource interno per la edge function `parse-recipe-caption`; `SupabaseService` resta facade retrocompatibile.
- `RecipeRepository`: layer di accesso remoto per ricette e user recipe states, con fallback per schema drift.
- `RecipeStore`: persistenza locale ricette create/draft e compatibility loader.
- `ProduceStore`: loader produce JSON.
- `BasicIngredientCatalog`: catalogo ingredienti base locale.
- `NutritionService`: calcolo score e riepiloghi nutrizionali.
- `SearchResultsService`: ranking/filtering search puro e testabile, separato dalla UI.
- `RecipeTranslationService`: traduzione runtime dove supportata.
- `SocialAuthService`: Apple/OAuth helper.
- `FollowStore` e `FollowSyncManager`: follow locale e sync delta.
- `OutboxStore`, `OutboxDispatcher`, `OutboxMutationEnqueuer`: coda mutazioni locali e replay remoto per fridge, shopping list e stati ricetta saved/crispy.
- `BackfillService`: convergenza frigo/shopping verso outbox.
- `CatalogAdminOpsService`: wrapper operativo per admin catalogo.
- `ReconciliationDiagnosticsService`: diagnostiche reconciliation.
- `SyncFeedbackCenter`: feedback UI per eventi sync.

## 5. Modello dati client

Modelli principali:

- `Recipe`: ricetta completa con creator, ingredienti, tempi, media, source, status, remix e metadata.
- `RecipeIngredient`: ingrediente ricetta con `ingredientID`, `produceID`, `basicIngredientID`, qualità, quantità, unità, raw line e mapping confidence.
- `ProduceItem`: prodotto stagionale locale con nutrizione e stagionalità.
- `BasicIngredient`: ingrediente base locale con categoria, flags dietetici e unit profile.
- `IngredientReference`: identita ingrediente cross-domain.
- `FridgeMatchedRecipe`: risultato matching ricetta-frigo.
- `ShoppingListEntry`: elemento lista spesa.
- `FridgeCatalogItem` e `FridgeCustomItem`: elementi frigo non legacy.
- `Creator`, `UserProfile`, `UserBadge`: creator/social profile.
- `FollowRelation`: stato follow con pending sync operation.
- `OutboxMutationRecord`: mutazione locale da sincronizzare.

## 6. Backend Supabase

### Tabelle/app domain principali

Le aree usate dall'app includono:

- `profiles`: profilo utente, username, avatar, lingua, social URL, admin flag.
- `linked_social_accounts`: account social collegati.
- `recipes`: ricette remote.
- `user_recipe_states`: saved/crispied/archived per utente.
- `shopping_list_items`: lista spesa remota.
- `fridge_items`: frigo remoto.
- `follows`: relazioni follow.
- `ingredients`: catalogo canonico.
- `ingredient_localizations`: nomi per lingua.
- `ingredient_aliases_v2`: alias approvati verso ingredienti canonici.
- `legacy_ingredient_mapping`: compatibilita verso vecchi ID produce/basic.
- Tabelle di audit/candidate/draft/reconciliation per pipeline catalogo.

### Edge Functions

- `parse-recipe-caption`: parsing caption social e ingredienti.
- `import-recipe-from-url`: import ricetta da URL.
- `catalog-enrichment-proposal`: proposta arricchimento ingrediente via LLM/policy.
- `run-catalog-enrichment-draft-batch`: batch draft arricchimento.
- `run-catalog-ingredient-creation-batch`: batch creazione ingredienti da draft validati.
- `run-catalog-automation-cycle`: ciclo autopilot completo.

### RPC e viste operative

Il backend espone RPC/vista per:

- candidate catalogo;
- coverage blockers;
- draft pronti/pending;
- auto-apply alias/localizzazioni sicure;
- reconciliation preview/apply;
- variant policy audit;
- guardrail Giallo Zafferano;
- readiness diagnostics;
- admin ops snapshot.

## 7. Source of truth dati

### Ricette

Direzione prodotto:

- Supabase è la source of truth per ricette pubblicate.
- In Release/TestFlight non devono essere caricati seed locali o TheMealDB.
- Le ricette locali restano per draft/user-created e UX immediata.

Stato tecnico:

- `RecipeStore.loadRecipes()` oggi restituisce ricette utente persistite localmente.
- I seed hardcoded storici sono disabilitati con `#if false`.
- `seed_recipes.json` e il loader legacy sono stati rimossi: i seed TheMealDB non sono più presenti nel repo app.
- `ProduceViewModel` carica ricette locali e poi effettua merge con remote via `RecipeRepository`.

### Catalogo ingredienti

Direzione prodotto:

- `ingredients` è il nodo canonico unico.
- `ingredient_localizations` contiene display name per lingua.
- `ingredient_aliases_v2` mappa testo libero a ingredienti canonici.
- `legacy_ingredient_mapping` e solo compatibilita.

Stato tecnico:

- Il client supporta `ingredient_id` sulle ricette.
- Il client mantiene compatibility con `produce_id` e `basic_ingredient_id`.
- Il catalogo locale produce/basic resta utile per fallback UI e dati statici, ma non deve definire la verità canonica futura.

### Frigo e shopping

Direzione prodotto:

- UX local-first.
- Sync remota best-effort con outbox.

Stato tecnico:

- Persistenza locale su `UserDefaults`.
- Ogni mutazione crea record outbox.
- Alcune mutazioni fanno anche write-through diretto.
- `OutboxDispatcher` processa pending mutation su launch/foreground e manualmente da diagnostiche.

## 8. Sync model

### Local-first

Usato per:

- frigo;
- shopping list;
- stati ricette saved/crispy;
- draft ricette;
- preferenze utente locali.

Vantaggi:

- UI immediata.
- Baseline offline.
- Meno blocchi su rete/auth.

Limiti:

- Possibile divergenza multi-device.
- Cloud-to-local hydration non completa per tutti i domini.
- Outbox su `UserDefaults` non e ideale a lungo termine.

### Write-through e outbox

Pattern:

1. Applica mutazione locale.
2. Salva record outbox.
3. Prova write-through remoto non bloccante.
4. Dispatcher riprova pending mutation.

Domini:

- `fridge_items`.
- `shopping_list_items`.
- backfill fridge/shopping.

### Follow sync

Pattern:

- Stato locale in `FollowStore`.
- Operazioni pending create/delete.
- `FollowSyncManager.syncToBackend()` invia solo delta.
- Unfollow usa tombstone locale finche la delete non e sincronizzata.

## 9. Ranking e personalizzazione

Il ranking combina segnali diversi:

- stagionalità ingrediente;
- nutrizione e preferenze utente;
- match frigo;
- qualita della ricetta: titolo, ingredienti, passaggi, media e metadati;
- convenienza: tempo totale e affidabilita del tempo;
- engagement calmierato: crispy score e view score pesati senza dominare il feed;
- freshness;
- creator/follow;
- disponibilità ingredienti;
- eligibility/presentability della ricetta.

La Home usa filtri rapidi con hard gate: `Pronte ora`, `15 min`, `Proteiche` e `Picco stagione` non ricadono piu sul feed generico quando hanno pochi risultati, cosi la promessa del filtro resta coerente. La diversity del feed evita ripetizioni ravvicinate di creator/source, hook editoriale e ingrediente dominante. Lo spotlight stagionale privilegia il punteggio stagionale corrente; la frequenza d'uso nelle ricette e solo un tie-break leggero, per evitare che ingredienti costanti tutto l'anno dominino sempre.

All'avvio, la Home non applica lo snapshot ranking finche il bootstrap iniziale delle ricette remote non e concluso. Durante questa finestra mostra uno skeleton redatto: evita che l'utente veda prima un feed locale/vuoto e poi un secondo feed diverso appena arriva Supabase. Il refresh manuale resta invece intenzionalmente dinamico e puo ruotare lo spotlight.

Classi/aree coinvolte:

- `ProduceViewModel`.
- `FeedPersonalizationService`.
- `NutritionService`.
- `FridgeMatchedRecipe`.

## 10. Smart import e reconciliation

Flusso tecnico:

1. L'utente incolla caption o URL.
2. Il client chiama edge function o parser locale.
3. Gli ingredienti vengono normalizzati.
4. Il client prova match su alias/localizzazioni/catalogo.
5. Se non trova match sicuro, mantiene ingrediente custom/unmapped.
6. Le osservazioni alimentano candidate/draft catalogo lato Supabase.
7. Autopilot/operatore crea alias, localizzazioni o nuovi ingredienti.
8. Reconciliation applica mapping sicuri alle ricette.

Obiettivo tecnico:

- ridurre `custom` nelle ricette;
- aumentare `ingredient_id`;
- mantenere policy conservativa sulle varianti;
- non usare LLM come fonte finale senza governance.

## 11. Autopilot catalogo

Componenti:

- Edge function `run-catalog-automation-cycle`.
- Batch enrichment draft.
- Batch ingredient creation.
- Candidate intake.
- Auto-apply alias/localizzazioni sicure.
- Reconciliation moderna.
- Audit e guardrail.

Policy chiave:

- Non collassare varianti culinarie significative.
- Non creare nodi per quantita o qualificatori superficiali.
- Usare alias quando cambia solo il testo.
- Creare ingrediente canonico quando cambia l'identita culinaria.
- Esempio: `patate` resta base; `patate dolci` resta variante separata.

## 12. Configurazione ambienti

Ambienti Supabase:

- Debug/dev: `gyuedxycbnqljryenapx.supabase.co`.
- Release/staging: `czdsnnsizyhldiurlmxd.supabase.co`.

Configurazione in Xcode:

- `INFOPLIST_KEY_SUPABASE_URL`.
- `INFOPLIST_KEY_SUPABASE_ANON_KEY`.
- `SUPABASE_URL` e `SUPABASE_ANON_KEY` in `Season-Info.plist` usano placeholder build setting.

Stato TestFlight:

- `CURRENT_PROJECT_VERSION = 9`.
- `MARKETING_VERSION = 1.0.1`.
- Release compila contro staging.
- TestFlight candidate `1.0.1 (7)` e stato caricato come bugfix, ma non deve essere considerato validato per Smart Import: le caption creator hanno mostrato regressioni su titolo e quantita. Prima di una nuova build serve il gate in `docs/smart-import-creator-validation-pack.md`.
- Hotfix branch `hotfix/smart-import-user-flow-build-8` contiene correzioni validate su simulator per parsing caption, quantita, titoli, mezze quantita naturali, q.b., `gocce di cioccolato` non mappato a `cola`, e verbi procedurali all'infinito.
- Candidate `1.0.1 (9)` e il prossimo build number da usare per TestFlight dopo merge del pacchetto Smart Import; i gate Smart Import devono restare verdi prima dell'upload firmato.
- Ultimo pass simulator Smart Import: 100 caption, 72 pass, 28 partial da gap catalogo/specificita, 0 fail, 0 title failure, 0 missing expected ingredients, 0 invented quantities. Vedi `docs/smart-import-creator-validation-pack.md`.
- Supabase staging preflight del 16 maggio 2026: `supabase db lint --linked` senza errori e `supabase db push --linked --dry-run` aggiornato dopo la migration `20260516105000_restore_profiles_authenticated_grants.sql`.
- Bundle Release esclude debug JSON e docs tecnici; le ricette arrivano da Supabase staging.

## 13. Build e verifica

Comandi utili:

```bash
xcodebuild -scheme Season -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme Season -configuration Release -sdk iphoneos build CODE_SIGNING_ALLOWED=NO
git diff --check
plutil -lint Season-Info.plist
```

Nota:

- `CODE_SIGNING_ALLOWED=NO` valida compilazione e bundle, non firma App Store/TestFlight.
- Per TestFlight serve Archive firmato da Xcode o pipeline export/upload configurata; non usare una build caricata come proxy di qualita finche non sono stati eseguiti i gate utente.
- Per modifiche Smart Import, non caricare TestFlight solo dopo build verde. Devono passare audit reale locale, audit server-fallback e verifica manuale UI sulle regression caption `REG-20260516-*`.
- Il parser locale deve restare utile anche quando il fallback remoto e limitato da quota o non disponibile.

## 14. Asset e design system

Asset principali:

- `Season/Assets.xcassets/DesignSystem`: colori app.
- `Season/Support/Fonts`: Inter, Newsreader, JetBrains Mono.
- `Season/Assets.xcassets/AppIcon.appiconset`: app icon.
- Asset ingredienti: imageset per produce/basic/catalog display.

Documentazione design:

- `docs/design/season-ui-refresh/`: prototipi, screenshot, componenti web e note refresh UI.
- `docs/design/stitch/`: riferimenti UI precedenti per schermate specifiche.

## 15. Logging e diagnostica

Logging:

- Il codice app non deve usare `print(...)` direttamente, salvo `Swift.print` dentro `SeasonLog`.
- `SeasonLog.debug(...)` e `SeasonLog.lifecycle(...)` non emettono log in Release e in Debug stampano solo se abilitati da flag.
- Log con user id, URL callback, path storage, payload RPC raw o identificativi ricetta devono restare disabilitati nelle build esterne.
- Trace ID e categorie errore restano utili in sviluppo, ma devono passare da logging centralizzato e redatto.

Diagnostiche app:

- Account diagnostics per fetch remoti.
- Outbox processing manuale.
- Backfill manuale.
- Reconciliation diagnostics.
- Catalog admin view solo in Debug. Per staging/prod usare la console web `catalog.seasonapp.it`.
- Home/Search performance logs sono dev-only (`SEASON_HOME_DEBUG`, `SEASON_SEARCH_DEBUG`) e passano sempre da `SeasonLog`.

## 16. Sicurezza

Stato:

- Supabase usa anon key nel client, come previsto.
- Service role non deve essere hardcoded nel client.
- Operazioni admin devono essere autorizzate lato backend, non solo nascoste in UI.
- RLS e policy rimangono boundary principale.
- Storage avatar usa upload da client, con URL salvato in `profiles.avatar_url`.

Documento correlato:

- `docs/security/supabase-security-findings-disposition.md`.

## 17. File e documenti correlati

Documenti architetturali:

- `README.md`.
- `ARCHITECTURE.md`.
- `CURRENT_STATUS.md`.
- `Season/Docs/DataArchitecture.md`.
- `docs/catalog-architecture.md`.
- `docs/smart-import-catalog-intelligence-pipeline.md`.
- `docs/catalog-system-review-and-consolidation-plan.md`.

Migrations Supabase:

- `supabase/migrations/`.

Edge Functions:

- `supabase/functions/`.

## 18. Debito tecnico e prossimi step

Debiti noti:

- `OutboxStore` su `UserDefaults` non e scalabile per coda lunga.
- Alcune aree hanno doppio write path: direct write-through + outbox.
- Cloud-to-local hydration non completa per frigo/shopping/stati ricetta.
- `RecipeRepository` mantiene fallback per schema drift.
- `RecipeIngredient` supporta ancora legacy `produce_id` e `basic_ingredient_id`.
- Media pipeline ricette remote non completa.
- Admin operations client-triggered richiedono disciplina operativa.
- Alcuni documenti storici possono risultare parzialmente superati.

Prossimi step raccomandati:

- Completare processing/review App Store Connect e assegnazione build ai gruppi tester.
- Monitorare staging con ricette Giallo Zafferano.
- Eseguire `supabase/devops/staging_testflight_preflight.sql` prima di ogni build candidata.
- Se l'autopilot deve girare anche su staging, usare solo gli script `staging_catalog_autopilot_v2_*` dedicati.
- Misurare ingredienti custom residui per ricetta.
- Continuare autopilot su coverage generale, non solo batch mirati.
- Migrare progressivamente ricette verso `ingredient_id` canonico.
- Consolidare sync cloud-to-local per frigo e shopping.
- Promuovere i documenti funzionale/tecnico come fonte onboarding aggiornata.
