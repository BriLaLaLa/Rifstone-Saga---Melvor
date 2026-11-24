# 07. Task, M37: Casa d'Aste più bella e comoda (CORE + DATA + UI + QA)

Estensione di `07_TASKS.md`. Fonte: V47, `01_GDD_M37.md` (§45), `02_FORMULAS_M37.md` (F-209…F-213), `04_DATA_SCHEMA_M37.md` (§38), `05_INTERFACES_M37.md` (§5.49, §6i, §7.af), Q237-Q245. Il design non si
riscrive nei brief. `sonnet`; **save v12 → v13 (additivo)**; nessuna formula di prezzo cambia. Lezioni come `07_TASKS_M36.md`: `git checkout -B task/<ID> main`; mai `-gtest=`; test mirati con il filtro di
`CLAUDE.md`; screenshot 1280x720 e 1600x900 in cartelle separate guardati con Read; togliere i `*.uid` non tracciati prima del merge; nessun processo Godot in background; `run_checks.ps1` una sola volta
**dopo il merge di tutti**; file ≤ 400 righe (`auction_detail.gd` è a 271, `auction_page.gd` a 266, `bank_page.gd` a 388: M37-5 deve estrarre, non aggiungere); i test esistenti restano verdi: cambiano solo quelli dichiarati.

| ID | Titolo | Ruolo | Dim. | Dip. | File disgiunti da |
|---|---|---|---|---|---|
| M37-1 | CORE: storico, `price_gap`, `max_buyable`, riepilogo, save v13 | Core | M | design M37 | tutti |
| M37-2 | DATA: testo della Guida «Casa d'Aste» | Data | S | 1 (nomi dei concetti) | 3, 4, 5, 6 |
| M37-3 | UI: dettaglio a sezioni, azione fissa, Compra max, % sulla media | UI | M | 1 | 2, 4, 5, 6 |
| M37-4 | UI: lista, filtri, scelte ricordate, testata, «Le mie vendite» con Storico | UI | L | 1 | 2, 3, 5, 6 |
| M37-5 | UI: «Vendi alla Casa d'Aste» dal Deposito | UI | S | 4 (merge prima) | 2, 3, 6 |
| M37-6 | QA: equivalenza offline dello storico, migrazione, screenshot e controlli | QA | S | 1, 3, 4, 5 | 2 |
Ordine: **1** → **3 e 4 insieme** (contratto di §7.af) → **5** → 2 e 6. Massimo 2 agenti insieme. **Merge: 1, 3, 4, 5, 2, 6.** Task S consecutivi dello stesso ruolo allo stesso agente (2 con 6 no: ruoli diversi).

## M37-1: CORE
- **Leggere**: `01_GDD_M37.md` §45.3-§45.4; `02_FORMULAS_M37.md` F-209…F-213 (tutte); `04_DATA_SCHEMA_M37.md` §38; `05_INTERFACES_M37.md` §5.49, §6i; `systems/auction/auction_house.gd`, `auction_listings.gd`,
  `auction_view.gd`, `auction_pricing.gd` (`value_of`, `block`, `pending_ms`); `core/data/defs/auction_params.gd`, `core/data/data_validator_auction.gd`; `core/save/save_migrator.gd` e `migrations/migration_11_to_12.gd`;
  `tests/fixtures/data` (balance); `tests/systems/auction/`.
- **Ownership**: `systems/auction/auction_history.gd` (nuovo), `auction_house.gd`, `auction_view.gd`, `core/data/defs/auction_params.gd`, `core/data/data_validator_auction.gd`, `data/config/balance.json` (solo la chiave
  `auction.history_max`), `tests/fixtures/data/**` (stessa chiave), `core/save/save_migrator.gd` e `migrations/migration_12_to_13.gd` (nuovo), `tests/systems/auction/test_auction_history.gd`,
  `test_auction_view_m37.gd`, `tests/core/save/test_migration_12_to_13.gd`, i test di salvataggio che citano la versione 12 o i golden dei save. **Non toccare**: `ui/**`, `data/guide/**`, altri sistemi.
- **Accettazione**:
  1. Ogni esempio di F-209…F-213 è un test (fusione per id e riordino in cima, `closed` non scrive, cap `history_max`, unitario `floor(g/qty)`, `NO_GAP`, `max_buyable` con livello/scorta/oro/Deposito pieno, `age_ms`).
  2. `AuctionHouse` scrive lo storico **solo** in `_deliver`, `sell`, `cancel_listing`; `advance` offline di N blocchi produce le stesse voci del tick online (test di equivalenza con un seme fisso).
  3. Save v13: `to_save`/`from_save` (round-trip), caricamento tollerante (voce con `k` sconosciuto, oggetto inesistente, `qty` 0, float intero, lista più lunga di `history_max` → scartate/troncate con warn),
     chiave assente = vuoto, `new_game` svuota; `migration_12_to_13` aggiunge `auction.history = []` senza toccare altro e un v12 vero carica; `CURRENT_VERSION` 13.
  4. `validate_data` verde (dati veri e fixture): `history_max` obbligatorio 1..200, valore 50 in `balance.json`.
  5. Nessun prezzo, deposito, commissione o scorta cambia (i test esistenti di `systems/auction` e `sim_market` restano identici); nessun segnale nuovo.

## M37-2: DATA
- **Leggere**: `01_GDD_M37.md` §45.2 (punti 1-10); `data/guide/casa_aste.json` e il test che limita le parole delle pagine della Guida (sotto le 160 parole per pagina, come in M26).
- **Ownership**: `data/guide/casa_aste.json` (solo testo; stesso id di pagina), il test della Guida se serve un caso. **Non toccare**: codice, altri dati.
- **Accettazione**: la pagina «Casa d'Aste» parla di prezzo unitario e «% sulla media», Compra max, Le mie vendite (Attive/Storico, gli acquisti non si registrano), Vendi dal Deposito, Posta piena; italiano,
  ≤ 160 parole, nessun nome copiato da altri giochi; `validate_data` e i test della Guida verdi.

## M37-3: UI, dettaglio
- **Leggere**: `01_GDD_M37.md` §45.2 (punti 1, 2) e §45.3; `05_INTERFACES_M37.md` §7.af; `ui/pages/auction/auction_detail.gd`, `auction_list_form.gd`, `auction_offers_view.gd`, `auction_texts.gd` (solo lettura);
  `tests/ui/test_auction_page_smoke.gd`; `ui/theme` per i colori (`UiStyle.GOOD/BAD/GOLD`).
- **Ownership**: `ui/pages/auction/auction_detail.gd`, `auction_list_form.gd`, `auction_offers_view.gd`, `auction_detail_texts.gd` (nuovo), eventuali `auction_detail_*.gd` estratti, `tools/shot_m37_detail.gd` (+ `.tscn`),
  la parte «dettaglio» di `tests/ui/test_auction_page_smoke.gd` **solo se serve** (altrimenti un test nuovo `tests/ui/test_auction_detail_m37.gd`). **Non toccare**: `auction_page.gd/.tscn`, `auction_list.gd`,
  `auction_row.gd`, `auction_mine.gd`, `auction_category_tree.gd`, `auction_texts.gd`, `core/**`, `systems/**`, `data/**`.
- **Accettazione**:
  1. Il dettaglio ha parte alta fissa (icona, nome, categoria, prezzo unitario, `PriceGapLabel` con freccia e colore da `price_gap`, fascia) e `SectionBar` con **Subito / Inserzione / Mercato**; «Inserzione» solo in Vendi;
     ricorda la sezione scelta per scheda; il libro e i compratori/venditori stanno in «Mercato».
  2. **Pulsante di azione e messaggio di esito fissi in fondo**, fuori dallo scroll, sempre visibili; in Vendi «Vendi subito» in Subito e «Metti in vendita» in Inserzione con il proprio pulsante.
  3. `Shortcut_max` («Compra max») imposta la quantità a `max(max_buyable, 1)` (solo in Compra); `Shortcut_all` invariato; Vendi mostra anche il ricavo medio per pezzo `sell_quote(q) / q`.
  4. Nessun calcolo nella UI (scarto, massimo, ricavo medio, colori dai metodi di `AuctionHouse`); nessuna conferma d'acquisto; segnali `trade_requested`/`list_requested` invariati.
  5. Tutti i file ≤ 400 righe (estrarre `auction_detail_sections.gd` se serve); screenshot 1280x720 e 1600x900 (Compra, Vendi in ciascuna sezione, oggetto senza mercato, messaggio d'errore); smoke test.

## M37-4: UI, lista, filtri, «Le mie vendite»
- **Leggere**: `01_GDD_M37.md` §45.2 (punti 3-7, 9), §45.4; `02_FORMULAS_M37.md` F-210, F-212, F-213 (solo per i formati); `05_INTERFACES_M37.md` §5.49, §7.af; `ui/pages/auction/auction_page.gd`, `auction_list.gd`, `auction_row.gd`,
  `auction_mine.gd`, `auction_category_tree.gd`, `auction_page.tscn`, `auction_texts.gd`; `ui/screens/main/page_host.gd` (`route_of`, `argument_of`, `has_page`); `ui/pages/mail/` (pagina Posta, rotta).
- **Ownership**: `ui/pages/auction/auction_page.gd`, `auction_page.tscn`, `auction_list.gd`, `auction_row.gd`, `auction_mine.gd`, `auction_history_view.gd` (nuovo), `auction_category_tree.gd`, `auction_texts.gd`,
  `tests/ui/test_auction_page_smoke.gd` (parti non del dettaglio), `tests/ui/test_auction_history_view.gd` (nuovo), `ui/screens/main/page_host.gd` **solo** per far accettare `auction:<item>` in `has_page` se serve,
  `tools/shot_m37_page.gd` (+ `.tscn`). **Non toccare**: `auction_detail*.gd`, `auction_list_form.gd`, `auction_offers_view.gd` (M37-3), `ui/pages/bank/**` (M37-5), `core/**`, `systems/**`, `data/**`.
- **Accettazione**:
  1. Riga: colonne più larghe, importo compatto, colonna «% sulla media» con freccia e colore (anche «Stabile» leggibile), riga selezionata con riempimento + barra a sinistra da 3 px; ordinamento anche per `gap`
     e, in Vendi, per `total`; nessun calcolo nella UI.
  2. Filtri `FilterOwned` e `FilterBuyable` (Compra: ne ho / `can_buy(id,1)` riuscirebbe; Vendi: solo «Posseduti» non ha senso, la lista è già dei posseduti, quindi nascosto) sommati a categoria e ricerca;
     categorie in ordine d'uso (§45.2 punto 9); stato di vista (categoria, ordinamento, filtri, oggetto) **per scheda** e ricordato cambiando scheda, non salvato.
  3. Testata: `PostBadge` «Posta: N da ritirare» (clic → `page_requested(&"mail")`), `PostFullLabel` rosso con la Posta piena; scheda rinominata «Le mie vendite» con **Attive** (icona, riepilogo `MineSummary` da `listings_summary()`,
     `Cancel_<id>`, conferma `ConfirmCancel_<id>` solo se `sold > 0`) e **Storico** (`HistoryRows`: oggetto con icona, tipo colorato, quantità, unitario, netto, «quanto tempo fa» da `history_age_ms`; vuoto = testo).
  4. `AuctionPage.show_item(item_id, tab)` e rotta `auction:<item_id>` (`bind` legge `argument_of(page_id)`; oggetto non trattato → testo, nessuna eccezione).
  5. File ≤ 400 righe (estrarre `auction_filters.gd` o `auction_header.gd` se serve); smoke test (schede, filtri, storico vuoto e con 3 voci, `show_item`); screenshot 1280x720 e 1600x900 (Compra, Vendi, Le mie vendite
     Attive e Storico, Posta piena); i test esistenti della pagina restano verdi o cambiano solo per rinomina dichiarata.

## M37-5: UI, dal Deposito
- **Leggere**: `01_GDD_M37.md` §45.2 (punto 8); `05_INTERFACES_M37.md` §7.af (ultime righe); `ui/pages/bank/bank_item_panel.gd` (270), `bank_page.gd` (388!), `bank_texts.gd`, `ui/screens/main/page_host.gd`;
  come M36 ha cablato «Vai» (`ResourceTable.zone_requested`).
- **Ownership**: `ui/pages/bank/bank_item_panel.gd` e `.tscn`, `bank_page.gd` (estrarre ≥ 30 righe in un file nuovo `bank_page_links.gd` prima di aggiungere), `bank_texts.gd`, `tests/ui/test_bank_auction_link.gd` (nuovo).
  **Non toccare**: `ui/pages/auction/**`, `core/**`, `systems/**`, `data/**`.
- **Accettazione**:
  1. `SellAtAuctionButton` nel pannello dell'oggetto, visibile solo se `session.auction.listed_items()` contiene l'oggetto; disabilitato con tooltip se `session.auction.is_open()` è falso («Costruisci la Casa d'Aste») o l'oggetto è bloccato;
  2. il clic emette `auction_requested(item_id)`; `BankPage` lo inoltra come `page_requested(&"auction:<id>")`; test: pagina Deposito finta → segnale con l'id giusto; oggetto non trattato → pulsante assente;
  3. `bank_page.gd` ≤ 400 righe; screenshot 1280x720 (pulsante visibile e disabilitato).

## M37-6: QA
- **Leggere**: `02_FORMULAS_M37.md` F-209; `tests/systems/auction/` e `tools/sim_market.gd`; `tests/integration/` (equivalenza offline di M26/M27); `tools/run_checks.ps1`.
- **Ownership**: `tests/integration/test_m37_auction_history_offline.gd` (nuovo), `tests/core/save/test_save_v13_roundtrip.gd` se manca, `tools/sim_market.gd` (solo asserzione che lo storico ≤ `history_max` e non crea oro), report.
  **Non toccare** codice di produzione: i bug si segnalano.
- **Accettazione**: (1) una sessione con inserzioni attive simulata offline per N ore = stessa sessione online a tick: storico, Posta e oro identici; (2) slot v12 reale caricato e salvato come v13 senza altre differenze;
  (3) `sim_market` invariato nelle soglie (nessun guadagno comprando e rivendendo); (4) `run_checks.ps1` **una volta**, dopo il merge di 1, 3, 4, 5 e 2; riepilogo con il numero di test; screenshot di M37-3/4/5 guardati e difetti elencati.
