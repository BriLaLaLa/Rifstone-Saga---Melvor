# 07. Task, M38: Casa d'Aste, libro unico (CORE + DATA + UI + QA)

Estensione di `07_TASKS.md`. Fonte: V48, `01_GDD_M38.md` (§46), `02_FORMULAS_M38.md` (F-214…F-218, F-210/F-211 modificate), `04_DATA_SCHEMA_M38.md` (§39), `05_INTERFACES_M38.md` (§5.50, §6j, §7.ag), Q246-Q253.
Il design non si riscrive nei brief. `sonnet`; **save v13 → v14 (additivo)**; il lato vendita (F-148, F-175, F-178…F-181, F-209, F-212, F-213) **non cambia**: i test esistenti restano verdi, cambiano solo quelli dichiarati
(scorta, acquisto, `price_gap`, `max_buyable`). Lezioni come `07_TASKS_M37.md`: `git checkout -B task/<ID> main`; mai `-gtest=`; test mirati con il filtro di `CLAUDE.md`; screenshot 1280x720 e 1600x900 in cartelle separate guardati con Read;
togliere i `*.uid` non tracciati prima del merge; nessun processo Godot in background; `run_checks.ps1` una sola volta **dopo il merge di tutti**; file ≤ 400 righe (`auction_detail.gd` è a 347: M38-3 deve estrarre, non aggiungere;
`auction_pricing.gd` è a 298 e `auction_house.gd` a 377: M38-1 estrae `auction_buy.gd` e `auction_reference.gd`).

| ID | Titolo | Ruolo | Dim. | Dip. | File disgiunti da |
|---|---|---|---|---|---|
| M38-1 | CORE: acquisto sul libro, `taken`, riferimento, vincoli, save v14 | Core | L | design M38 | tutti |
| M38-2 | DATA: progetti ricontrollati e testo della Guida | Data | S | 1 (validatore dei progetti) | 3, 4, 5 |
| M38-3 | UI: dettaglio (Disponibili, Esaurito, riferimento, conferma d'acquisto) | UI | M | 1 | 2, 4, 5 |
| M38-4 | UI: lista e riga (Disponibili, «% sulla media», ordinamenti), testi | UI | M | 1 | 2, 3, 5 |
| M38-5 | QA: `sim_market`, equivalenza offline, migrazione, screenshot, controlli | QA | M | 1, 2, 3, 4 | 2 |
Ordine: **1** → **3 e 4 insieme** (contratto di §7.ag) e **2** (dopo 1) → **5**. Massimo 2 agenti insieme. **Merge: 1, 3, 4, 2, 5.**

## M38-1: CORE
- **Leggere**: `01_GDD_M38.md` §46.2-§46.4; `02_FORMULAS_M38.md` (tutta); `04_DATA_SCHEMA_M38.md` §39; `05_INTERFACES_M38.md` §5.50, §6j; `02_FORMULAS_M26.md` F-172…F-175 e `02_FORMULAS_M27.md` F-178, F-179 (invariate: si riusano);
  `systems/auction/auction_pricing.gd`, `auction_math.gd`, `auction_book.gd`, `auction_house.gd`, `auction_view.gd`; `core/data/defs/auction_params.gd`, `core/data/data_validator_auction.gd`; `core/save/save_migrator.gd` e `migrations/migration_12_to_13.gd`;
  `tests/fixtures/data` (balance); `tests/systems/auction/`.
- **Ownership**: `systems/auction/auction_pricing.gd`, `auction_math.gd`, `auction_house.gd`, `auction_view.gd`, `auction_buy.gd` (nuovo: libro d'acquisto, costo, `taken`), `auction_reference.gd` (nuovo: F-214, con cache per epoca),
  `core/data/defs/auction_params.gd`, `core/data/data_validator_auction.gd` (e il validatore dei progetti dove vive F-151 `blueprint_margin`), `data/config/balance.json` (solo le chiavi `auction.buy`, `auction.supply`, `auction.reference`, via `auction.stock`),
  `tests/fixtures/data/**` (stesse chiavi), `core/save/save_migrator.gd` e `migrations/migration_13_to_14.gd` (nuovo), `tests/systems/auction/test_auction_buy.gd`, `test_auction_reference.gd`, `test_auction_view_m38.gd`,
  `tests/core/save/test_migration_13_to_14.gd`, i test esistenti di scorta/acquisto/`price_gap`/`max_buyable` e dei golden dei save che citano la versione 13. **Non toccare**: `ui/**`, `data/guide/**`, `data/items`/`data/actions` (M38-2), `tools/sim_market.gd` (M38-5).
- **Accettazione**:
  1. Ogni esempio di F-214…F-218 e di F-210/F-211 modificate è un test (mediana con `n` pari e dispari, epoche negative saltate, prezzi per inserzione e costo per `taken` 0/400/1.000 di `redbirch_grip` e `riftite_plate`, pavimento `EQMIN`,
     `avail`, `r_i` per fascia, recupero, esaurimento e `restock_blocks`, `taken` non tronca con `V` che scende, `max_buyable`, `buy_preview`/`large`).
  2. Vincoli del validatore con casi rifiutati: `markup_pct` 40 (F-217), finestra e rifornimento fuori range, `ceil_div(KMAX × stack, r_i)` oltre 144; chiavi tolte (`stock`, `spread_pct`) → errore; **progetti** con il nuovo `c(x)`.
  3. `taken` non cambia `ahead`, `D` né il libro di F-178/F-179 (test: inserzioni del giocatore identiche con `taken` 0 e 1.000). Le inserzioni del giocatore non entrano in `V` né si comprano.
  4. `advance(a); advance(b)` ≡ `advance(a + b)`; 12 h = passi da 100 ms = blocchi da 60 s con `taken` e con inserzioni attive (F-184 esteso, `tests/systems/auction/` e `tests/integration/test_m27_offline_equivalence.gd` aggiornato).
  5. Save v14: `to_save`/`from_save` round-trip; tollerante (oggetto inesistente o non acquistabile, valore negativo, float intero, oltre `KMAX × stack`); `stock` di un v13 ignorato; `migration_13_to_14` toglie `stock` e aggiunge `taken = {}`; un v13 vero carica;
     `CURRENT_VERSION` 14; `new_game` svuota `taken`.
  6. `can_buy`: `out_of_stock` se `qty > available`; `buy` paga la somma del libro (F-215) e aggiorna `taken`; segnali come oggi; `stock()`/`stock_max()` non esistono più (nessun riferimento residuo in `systems/`, `core/`, `tools/` esclusi i file di M38-5).
  7. `validate_data` verde su fixture; sui dati veri può restare rosso **solo** per i progetti di M38-2 (elencarli nel report).

## M38-2: DATA
- **Leggere**: `02_FORMULAS_M38.md` F-217 (§ «Progetti»); l'elenco dei progetti che il validatore di M38-1 rifiuta (`validate_data.gd` sui dati veri); `data/guide/casa_aste.json` e il test che limita le parole (sotto le 160 per pagina).
- **Ownership**: `data/guide/casa_aste.json` (solo testo; stesso id di pagina); i file dei progetti e degli oggetti acquistabili in `data/` **solo** per i progetti rifiutati, e `data/auction/auction_items.json` solo per togliere un componente
  dall'elenco acquistabile (`buy_level` 0), `tools/gen_*.gd` collegati se il file è generato (`--check` verde). **Non toccare**: codice, `balance.json`, altri dati.
- **Accettazione**: (1) ogni progetto rispetta `Σ qty × c(x) ≥ valore × 1,03` con il nuovo `c(x)`: si preferisce togliere da «acquistabili» il componente più pesante o aggiungere materiali rari **già esistenti** (nessun oggetto nuovo), si elenca cosa è cambiato
  e di quanto cambia il costo del progetto; (2) un oggetto acquistabile non è ingrediente di un'azione (regola invariata); (3) la pagina «Casa d'Aste» spiega: un solo libro, «Disponibili» = somma delle inserzioni, margine d'acquisto, «Esaurito» e rifornimento,
  media delle ultime 12 h, conferma per gli acquisti enormi; italiano, ≤ 160 parole, nessun nome copiato; (4) `validate_data` sui dati veri **verde**.

## M38-3: UI, dettaglio
- **Leggere**: `01_GDD_M38.md` §46.2-§46.3; `05_INTERFACES_M38.md` §7.ag; `ui/pages/auction/auction_detail.gd` (347 righe: estrarre prima), `auction_detail_sections.gd`, `auction_detail_texts.gd`, `auction_offers_view.gd`; `tests/ui/test_auction_page_smoke.gd`.
- **Ownership**: `ui/pages/auction/auction_detail.gd`, `auction_detail_sections.gd`, `auction_detail_texts.gd`, `auction_offers_view.gd`, `auction_buy_confirm.gd` (nuovo), `tests/ui/test_auction_detail_m38.gd` (nuovo), `tools/shot_m38_detail.gd` (+ `.tscn`).
  **Non toccare**: `auction_page.gd/.tscn`, `auction_list.gd`, `auction_row.gd`, `auction_mine.gd`, `auction_texts.gd` (M38-4), `core/**`, `systems/**`, `data/**`.
- **Accettazione**: (1) «Disponibili: N» (`AvailableLabel`, tooltip «somma delle inserzioni») al posto di «N / max»; con 0 `SoldOutLabel` «Esaurito, torna tra ~N min» e il pulsante Compra disabilitato con il motivo; (2) `RefLabel` «Media 12 h» e `PriceGapLabel` da `price_gap`;
  (3) il libro di Compra mostra `buy_price` e `left` (`BuyRow_<j>`, righe esaurite attenuate), le righe del giocatore non comprabili; (4) `BuyConfirm` solo se `buy_preview(...).large` (totale, prezzo medio, quota del libro; «Compra» emette `trade_requested`,
  «Annulla» no); mai per acquisti piccoli; vale anche per «Compra max»; (5) nessun calcolo nella UI; file ≤ 400 righe; smoke test (disponibili, esaurito, conferma sì/no); screenshot 1280x720 e 1600x900.

## M38-4: UI, lista e riga
- **Leggere**: `01_GDD_M38.md` §46.2; `05_INTERFACES_M38.md` §7.ag; `ui/pages/auction/auction_list.gd`, `auction_row.gd`, `auction_page.gd`, `auction_texts.gd`, `auction_mine.gd` (solo lettura); `tests/ui/test_auction_page_smoke.gd`.
- **Ownership**: `ui/pages/auction/auction_list.gd`, `auction_row.gd`, `auction_page.gd` e `.tscn` (solo se serve), `auction_texts.gd`, `tests/ui/test_auction_list_m38.gd` (nuovo), `tools/shot_m38_list.gd` (+ `.tscn`). **Non toccare**: `auction_detail*.gd`,
  `auction_offers_view.gd`, `auction_buy_confirm.gd` (M38-3), `core/**`, `systems/**`, `data/**`.
- **Accettazione**: (1) la colonna disponibili mostra `available` senza «/ max» (`AVAILABLE_TEXT` nuovo, `STOCK_TEXT` rimosso); in Compra l'ordinamento «Disponibili» usa `available`; (2) «% sulla media» da `price_gap` (nessun calcolo in UI), colori invariati; con `NO_GAP` il trattino;
  (3) il filtro «Comprabili ora» usa `can_buy(id, 1)` (esaurito → non comprabile); (4) il motivo `out_of_stock` letto dai testi: «Esaurito.»; (5) smoke test della lista; screenshot 1280x720 e 1600x900 (Compra con un oggetto esaurito e uno con +%).

## M38-5: QA
- **Leggere**: `02_FORMULAS_M38.md` F-217 (simulazione), F-216; `tools/sim_market.gd` e `tools/run_checks.ps1`; `tests/integration/test_m27_offline_equivalence.gd`; `tests/core/save/`.
- **Ownership**: `tools/sim_market.gd` (aggiornare (1), (2), (7); nuove (10), (11); le altre invariate), `tests/integration/test_m38_auction_offline.gd` (nuovo), `tests/core/save/test_save_v14_roundtrip.gd` se manca, report.
  **Non toccare** codice di produzione: i bug si segnalano.
- **Accettazione**: (1) `sim_market` esce con 0: (1) `unit` > ricavo massimo, (2) e (7) nessun guadagno, (10) «compra tutto e rivendi» ≤ 0,95 × costo in tutte le fasce, (4) equivalenza con `taken`; stampa (11) il ritmo `V + 144 × r_i` per oggetto contro M23 e il prezzo medio
  del «compra tutto» sul migliore; (2) una sessione con acquisti grandi e inserzioni attive simulata offline per 12 h = stessa sessione online a tick: `taken`, oro, Deposito, Posta e storico identici; (3) slot v13 reale caricato e salvato come v14 senza altre differenze;
  (4) `run_checks.ps1` **una volta**, dopo il merge di 1, 3, 4, 2: riepilogo con il numero di test; screenshot di M38-3/4 guardati e difetti elencati; se (1), (2), (7) o (10) saltano: nessun ritocco, numeri al Reviewer (Q250).
