# Season - Documento Applicativo e Funzionale

Ultimo aggiornamento: 2026-05-09

## 1. Visione del prodotto

Season è una app iOS per decidere cosa cucinare partendo da tre segnali principali:

- cosa è di stagione adesso;
- cosa l'utente ha già in frigo;
- quali ricette sono disponibili nel catalogo remoto.

L'obiettivo prodotto è ridurre la distanza tra "ho ingredienti in casa" e "posso cucinare qualcosa di sensato ora", mantenendo un catalogo ingredienti coerente per stagionalità, filtri, valori nutrizionali, lista della spesa e raccomandazioni.

Il principio guida è che Supabase diventi la source of truth delle ricette e del catalogo ingredienti. L'app resta local-first per UX e offline baseline su alcune aree, ma il contenuto ricette/catalogo deve convergere verso dati governati lato backend.

## 2. Pubblico e casi d'uso

### Utente finale

- Scoprire ricette adatte alla stagione.
- Capire quali ingredienti sono al picco, in arrivo o in uscita.
- Salvare ricette interessanti.
- Segnare ricette come "crispy", cioe approvate/preferite.
- Aggiungere ingredienti al frigo.
- Vedere ricette fattibili con quello che ha in frigo.
- Aggiungere ingredienti mancanti alla lista della spesa.
- Creare o importare ricette proprie.
- Seguire creator e consultare profili/autori.

### Creator / utente avanzato

- Creare ricette manualmente.
- Importare ricette da caption social o URL.
- Pubblicare ricette con ingredienti, passaggi, media, fonte e attribuzione.
- Gestire bozze, archivio e ricette pubblicate.
- Collegare profili Instagram/TikTok.

### Admin / operatore catalogo

- Controllare ingredienti non riconciliati.
- Validare candidate/alias/draft di arricchimento.
- Eseguire operazioni catalogo e diagnostiche.
- Monitorare l'autopilot ingredienti e la copertura ricette.

## 3. Navigazione principale

La tab bar principale contiene:

- Home: feed editoriale e raccomandazioni.
- Scopri: ricerca ricette e ingredienti.
- Crea: compositore ricetta / smart import.
- Oggi: ingredienti di stagione.
- Io: account, libreria, preferenze, diagnostiche.

Il tab "Crea" apre un full screen composer, mentre le altre sezioni sono NavigationStack dedicate.

## 4. Home

La Home è il punto di ingresso editoriale dell'app.

Funzionalita principali:

- Hero "cook now" con ricetta consigliata.
- Feed misto di ricette, creator, ingredienti stagionali e suggerimenti.
- Strip creator freschi / rilevanti.
- Sezione ingredienti stagionali.
- Filtri rapidi sul feed.
- Ranking dinamico basato su stagionalità, trend, frigo, preferenze nutrizionali, interazioni e disponibilità.
- Accesso diretto al dettaglio ricetta.
- Azioni rapide per salvare o rendere crispy una ricetta.

La Home deve mostrare contenuti presentabili e non seed/locali indesiderati in Release. Per TestFlight la Release punta allo staging Supabase.

## 5. Scopri

La sezione Scopri è la ricerca principale.

Funzionalita principali:

- Ricerca per ricette.
- Ricerca per ingredienti.
- Filtri per tipologia di risultato.
- Sezioni senza query: peak season now, ricette dal frigo, trending now.
- Risultati ingredienti con quick add alla lista della spesa.
- Risultati ricetta con score/stagionalità e navigazione al dettaglio.
- Caching leggero dei risultati per evitare refresh inutili durante digitazione e cambio filtri.

## 6. Oggi / Stagionalita

La sezione Oggi spiega cosa conviene comprare o cucinare nel periodo corrente.

Funzionalita principali:

- Classifica ingredienti di stagione.
- Evidenza del migliore ingrediente del momento.
- Filtri per categoria.
- Indicatori di fase stagionale: perfetta ora, in arrivo, in uscita.
- Motivazioni e pairing suggeriti.
- Collegamento al dettaglio ingrediente/prodotto.
- Score costruito su stagionalità, nutrizione e rilevanza.

## 7. Frigo

La sezione Frigo e divisa in due modalita funzionali:

- Lista frigo: cosa ho in casa.
- Ricette dal frigo: cosa posso cucinare con quello che ho.

Funzionalita lista:

- Aggiunta di ingredienti stagionali/prodotti.
- Aggiunta di ingredienti base.
- Aggiunta di ingredienti catalogo unificato.
- Aggiunta di ingredienti custom quando non ancora riconosciuti.
- Rimozione ingredienti.
- Ricerca ingredienti da aggiungere.
- Ordinamento e filtri di visualizzazione.

Funzionalita ricette dal frigo:

- Match ricette rispetto agli ingredienti presenti.
- Separazione tra ricette molto fattibili e ricette con ingredienti mancanti.
- Conteggio ingredienti mancanti.
- Anteprima ingredienti mancanti.
- CTA per aggiungere i mancanti alla lista della spesa.
- Navigazione al dettaglio ricetta.

Questa sezione e fondamentale per il prodotto: non deve limitarsi a una sola ricetta suggerita in Home, ma deve dare accesso a un catalogo esplorabile di ricette fattibili.

## 8. Lista della spesa

La lista della spesa raccoglie ingredienti manuali o derivati da ricette.

Funzionalita principali:

- Aggiunta ingredienti da ricerca.
- Aggiunta ingredienti mancanti da una ricetta.
- Aggiunta massiva di ingredienti ricetta.
- Supporto a ingredienti catalogo, produce, basic e custom.
- Quantita e unita quando disponibili.
- Collegamento al recipe source quando l'ingrediente deriva da una ricetta.
- Rimozione ingredienti.
- Persistenza locale e write-through verso Supabase tramite outbox.

## 9. Dettaglio Ricetta

Il dettaglio ricetta è la schermata di conversione da interesse ad azione.

Funzionalita principali:

- Hero con immagine/media ricetta.
- Titolo, creator, fonte e metadati.
- Salvataggio ricetta.
- Toggle crispy.
- Follow creator.
- Servings scalabili.
- Ingredienti con quantita scalate.
- Stato ingredienti: in frigo, in lista spesa, mancanti.
- CTA intelligente: cucinare, aggiungere mancanti, andare ai passaggi.
- Lista passaggi.
- Valori nutrizionali stimati quando ricavabili dal catalogo.
- Tag dietetici confermati.
- Media e link fonte.
- Remix/derivazioni.
- Traduzione runtime dove supportata.

## 10. Crea / Smart Import

Il composer permette creazione manuale e import intelligente.

Funzionalita principali:

- Creazione bozza ricetta.
- Modifica titolo, ingredienti, passaggi, tempi, difficolta, porzioni, media e fonte.
- Upload/uso immagini locali per ricette create.
- Import da caption social.
- Import da URL tramite funzione Supabase.
- Parsing ingredienti da testo libero.
- Matching ingredienti verso catalogo.
- Evidenza qualità import e confidenza.
- Salvataggio bozza locale.
- Pubblicazione ricetta con insert remoto best-effort.

Il comportamento desiderato e che gli ingredienti importati arrivino gia riconciliati a un ingrediente catalogo. Se restano custom/unmapped, devono alimentare il ciclo di osservazione, arricchimento e governance catalogo.

## 11. Account e Profilo

La sezione Io gestisce identita, libreria e preferenze.

Funzionalita principali:

- Auth Supabase con email/password.
- Sign in con Apple.
- Gate username obbligatorio.
- Profilo con username, avatar e statistiche.
- Upload avatar su Supabase Storage.
- Collegamento profili Instagram/TikTok.
- Visualizzazione ricette salvate, crispy, bozze, archiviate e pubblicate.
- Gestione bozze.
- Archivio e cancellazione ricette locali.
- Preferenze lingua.
- Preferenze nutrizionali.
- Logout con reset dati sessione locali.

Funzionalita diagnostiche e operative:

- Test auth Supabase.
- Fetch profilo, stati ricette, shopping list e fridge remoti.
- Esecuzione outbox.
- Backfill.
- Reconciliation diagnostics.
- Catalog Admin non e una superficie consumer: in app resta solo in build Debug, mentre la governance operativa vive su `catalog.seasonapp.it`.

## 12. Creator e Social

Season supporta un modello social leggero.

Funzionalita principali:

- Profili creator.
- Avatar creator.
- Follow/unfollow.
- Conteggio follower stimato.
- Badge creator.
- Ricette per autore.
- Collegamento social esterni.
- Media esterni Instagram/TikTok associati a ricette.

La sync follow e delta-based: l'app conserva operazioni pending e le sincronizza col backend quando possibile.

## 13. Catalogo Ingredienti

Il catalogo ingredienti è il cuore del sistema.

Funzionalita prodotto abilitate dal catalogo:

- Stagionalita.
- Nutrizione.
- Matching frigo-ricetta.
- Filtri e ranking.
- Lista spesa coerente.
- Ingredienti mancanti.
- Import intelligente.
- Riconciliazione delle ricette.

Principio funzionale:

- Un ingrediente canonico rappresenta una identita culinaria.
- Le localizzazioni sono solo nomi nelle lingue.
- Gli alias collegano testo libero a ingredienti canonici.
- Le varianti si creano solo quando cambiano davvero identita culinaria.
- Qualificatori o quantita contaminate devono diventare alias/matching, non nuovi ingredienti.

Esempio: "patate a pasta gialla" puo rimanere "patate" se non serve identita distinta; "patate dolci" resta ingrediente separato perche cambia identita culinaria.

## 14. Autopilot Catalogo

L'autopilot serve a ridurre gli ingredienti custom nelle ricette.

Flusso atteso:

- Le ricette importate producono ingredienti normalizzati.
- Gli ingredienti non riconciliati diventano osservazioni/candidate.
- Il backend propone alias, localizzazioni o nuovi ingredienti.
- Le proposte passano da policy, audit e review.
- Le riconciliazioni sicure vengono applicate alle ricette.
- Il risultato finale è un numero sempre più basso di ingredienti custom nelle ricette pubblicate.

L'autopilot non deve ottimizzare solo un batch singolo, ma migliorare il sistema: catalogo, alias, policy e reconciliation devono diventare piu robusti nel tempo.

## 15. Localizzazione

Lingue supportate:

- Inglese.
- Italiano.

Le stringhe UI sono in `Localizable.strings`; gli ingredienti del catalogo usano localizzazioni separate lato dati.

## 16. Stato dati per TestFlight

Configurazione attuale desiderata:

- Dev Supabase: ambiente di sviluppo.
- Staging Supabase: ambiente TestFlight.
- Release iOS: punta allo staging.
- Ricette su staging: solo contenuto selezionato, in particolare Giallo Zafferano.
- TheMealDB e seed locali: non devono alimentare il catalogo ricette di staging/TestFlight.
- `seed_recipes.json` non e piu presente nel repo app; report debug e fixture locali non devono essere inclusi nel bundle Release.

## 17. Metriche e segnali prodotto

Segnali gia presenti o derivabili:

- Crispy count.
- View count.
- Saved recipes.
- Match stagionale.
- Match frigo.
- Ingredienti mancanti.
- Copertura ingredienti catalogo.
- Ricette riconciliate vs custom.
- Ricette per creator.
- Follow e follower count.

Metriche da tenere sotto controllo prima/dopo TestFlight:

- Percentuale ingredienti ricette con `ingredient_id` canonico.
- Numero ingredienti custom visibili all'utente.
- Numero ricette fattibili dal frigo.
- Success rate smart import.
- Errori auth/sync/outbox.
- Tempo percepito di caricamento Home/Search/Recipe detail.
- Log Release privi di dati sensibili e diagnostiche catalog/admin non raggiungibili dai tester esterni.

## 18. Funzionalita non completamente mature

Aree presenti ma da considerare ancora in consolidamento:

- Sync multi-device completa per frigo e shopping list.
- Cloud-to-local hydration completa per alcune aree local-first.
- Media pipeline completa per immagini ricetta remote.
- Eliminazione definitiva dei fallback legacy `produce_id` / `basic_ingredient_id`.
- Automazione catalogo completamente autonoma senza intervento operativo.
- Governance finale per tutte le varianti catalogo.

Queste non bloccano necessariamente TestFlight, ma sono da considerare nel piano successivo.
