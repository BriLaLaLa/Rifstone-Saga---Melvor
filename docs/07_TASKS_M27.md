# 07. Task, M27: Casa d'Aste v2 (inserzioni simulate, Posta, monete)

Estensione di `07_TASKS.md`. Fonte: V33-V34 e M27-01 (`DECISIONS_LOG.md`), `01_GDD_M27.md` §39, `02_FORMULAS_M27.md` F-177…F-184, `04_DATA_SCHEMA_M27.md` §32,
`05_INTERFACES_M27.md`, Q159-Q170. Il design **non** si riscrive nei brief: si citano ID e sezioni. Max **2** agenti insieme; `sonnet` per i ruoli implementativi.

**Filoni**: **A** = monete (02, 03, 04); **B** = libro e inserzioni (06, 08); **C** = Posta (05, 07); QA (09); integrazione (10).
**Ordine**: M27-02 → M27-03 (**da solo**, tocca tutto) → (**M27-04 ∥ M27-05**) → (**M27-06 ∥ M27-07**) → (**M27-08 ∥ M27-09**) → **M27-10**.
Perché: 02 e 03 cambiano l'unità del denaro in codice, dati, fixture e test (**03 parte dal branch `task/M27-02`**, non da main; il Reviewer li unisce uno dopo l'altro e lancia la
suite **una volta** dopo 03: fra i due il controllo dei dati veri è rosso per costruzione). 04 (`ui/**`, `core/guide/`) e 05 (`systems/mail/`, sessione, segnali, motivi, offline) sono
disgiunti; 06 (`systems/auction/`, dati della Casa d'Aste) e 07 (`ui/pages/mail/`, barra laterale, rotte) pure; 08 (`ui/pages/auction/`) e 09 (`tools/sim_market.gd`, test di integrazione)
pure. `balance.json`, `event_bus.gd`, `reasons.gd`, `game_session.gd` sono toccati da task mai paralleli fra loro (02/03, 05, 06).

**Lezioni da applicare in ogni brief** (prompt di M27): (a) ogni UI interattiva nuova ha un test con **clic vero** (`Viewport.push_input` con `InputEventMouseButton`), non solo
`emit`/`select`; (b) nel worktree, se parte da un commit vecchio: `git checkout -B task/<ID> main` (03: `task/M27-02`); (c) mai `-gtest=` con GUT: `-gdir=... -gselect=<nome>`;
(d) screenshot in cartelle separate per risoluzione, guardati davvero (Read), poi il flusso provato con clic; (e) prima del merge si tolgono i `*.uid` non tracciati che lo bloccano;
(f) pagine della Guida ≤ 160 parole (`test_guide_texts`); (g) a fine task nessun processo Godot in background.

| ID | Titolo | Ruolo | Dim. | Dip. | Accettazione |
|---|---|---|---|---|---|
| M27-01 | Design: GDD §39, F-177…F-184, schema §32, contratto, task, V33-V34, Q159-Q170 | REV | M | m26-done | **DONE** (questo commit) |
| M27-02 | **A** Monete, codice: `Money`, `CurrencyParams`, `GameData.currency()`, sezione `currency` di `balance.json` e validatore, passo di arrotondamento dei validatori di F-131/F-134, `Wallet` (`copper`), `migration_10_to_11.gd`, `CURRENT_VERSION` 11, slot v10 reale di prova | CORE | M | 01 | **DONE** (987e886). esempi di F-177 (scomposizione, testo, ricomposizione, migrazione) sono test; `tests/fixtures/saves/slot_v10.json` scritto con il codice di **main prima dei cambi** (sessione vera con Casa d'Aste, coda, Maestri, monete ≠ 0) e caricato: portafoglio ×100, il resto identico; catena v9 → v11; salva → carica → salva identico; test mirati di `tests/core` e `tests/systems/wallet` verdi (i test sui dati veri restano rossi fino a 03: atteso, scritto nel report) |
| M27-03 | **A** Conversione: `tools/convert_money_m27.gd` (una tantum, poi cancellato), dati e **tutte** le fixture ×100 (§32.2), generatori "in argento", testi "oro"→"monete", `NOMI.md`, pagina Guida "Monete", **riallineamento dei numeri di denaro nei test** | DATA | L | 02 | **DONE** (85c36c9). `validate_data` verde su dati veri e fixture; `--check` di **ogni** generatore esce 0; esempi sui dati veri di F-177 in `test_data_validity.gd`; invarianti di F-177 (scorte e fasce uguali); **suite completa verde sul branch** prima della consegna (unica eccezione alla regola dei test mirati: la lancia l'agente una volta, filtrata); nei test cambiano **solo** i numeri di denaro (×100, o ricalcolati per le formule ad "arrotondamento fine" di F-177, elenco nel report); nessuna logica di test cambiata; Guida ≤ 160 parole |
| M27-04 | **A** UI delle monete: `MoneyLabel`, icone e colori, ogni importo della UI e della Guida con `MoneyLabel`/`Money.text` (§7.o) | UI | M | 03 | **DONE** (f961faa, merge 656d163). `grep` senza importi formattati a mano (nessun "oro" accanto a un numero, nessun `/ 100` per il denaro nella UI); smoke test delle pagine toccate verdi; un test di `MoneyLabel` (parti e icone per 0, 7, 12.540, 1.000.005); screenshot 1280×720 e 1600×900 (barra in alto, Shop, Maestri, Villaggio, Casa d'Aste) guardati |
| M27-05 | **C** Posta, logica: `MailBox`, `MailTemplateDef`, `data/mail/templates.json` (un modello originale per tipo), `mail.capacity`, `DataValidatorMail`, `mail_changed`, `MAILBOX_FULL`, sessione, save additivo, riepilogo offline | CORE | M | 03 | **DONE** (552c7ac). esempi di F-183 sono test (fusione per inserzione e per oggetto, capienza, `bank_full` atomico, Ritira tutto, ordine); `post` sempre consegnato; nessun accredito senza `collect`; save → load → save identico; `from_save` tollerante (casi di §5.40); `MAX_SESSION_LINES` 246; casi rifiutati di §32.5 sono test |
| M27-06 | **B** Libro e inserzioni: `AuctionBook`, `AuctionListings`, aggiunte di `AuctionPricing` e `AuctionHouse` (§5.39), `auction.book`/`auction.listing`, `stack`, validatore, Vendi subito in Posta, save additivo | CORE | L | 05 | **DONE** (bf724ba, merge ae20b15; fix g/s/c 187180c). **vettori di hash** e tutti gli esempi di F-178…F-181 sono test (`test_auction_book.gd`, `test_auction_listings.gd`); scenari di F-180 (600 a 250, 300 a 270, 100 a 300, `riftite_plate`) blocco per blocco; vincolo di F-182 e casi rifiutati di §32.4; proprietà `advance(a); advance(b)` ≡ `advance(a+b)` **con inserzioni** su oggetti di tutte le fasce; nessun tiro dell'`RngService`; `test_auction_house.gd`, `test_auction_pricing.gd` e `tests/integration/test_auction_*` riallineati (Vendi subito → Posta); `auction_house.gd` ≤ 330 righe |
| M27-07 | **C** UI della Posta: pagina, voce con non letti nella barra laterale, Ritira/Ritira tutto, riga del riepilogo offline, pagina Guida "Posta" (§7.o) | UI | M | 04, 05 | **DONE** (9bd1677). smoke test `test_mail_page_smoke.gd` con **clic veri** (riga, Ritira, Ritira tutto; voce Posta della barra laterale); motivi dei pulsanti da `can_collect`; nessuno stato nella UI; Guida ≤ 160 parole; screenshot (casella con vendite e un reso, Deposito pieno) |
| M27-08 | **B** UI della Casa d'Aste v2: libro, popolazione e pezzi, Vendi subito/Metti in vendita, prezzo g/s/c col suggerito, durata, deposito, Le mie inserzioni con stato e Annulla; Guida "Casa d'Aste" aggiornata (§7.o) | UI | L | 04, 06, 07 | **DONE** (b4e552a). smoke test aggiornato con **clic veri** (categoria dell'albero, oggetto, Metti in vendita, Annulla); nessun calcolo nella UI (`grep`: niente `AuctionBook`/`AuctionMath`/`balance`); Guida ≤ 160 parole; screenshot 1280×720 e 1600×900 (libro con un'inserzione propria "superata", scheda Le mie inserzioni) e flusso provato col mouse |
| M27-09 | QA: `tools/sim_market.gd` con le soglie (6)-(9) di F-182; `tests/integration/test_m27_offline_equivalence.gd` (F-184); prova "slot v10 reale" in una sessione completa | QA | M | 06 | **DONE** (efd25a0, merge 3b7c78b). sim verde (500 strategie per oggetto se 2.000 non finiscono in tempo, scritto nel report); numeri nel report: rapporto (8) min-max, frazione venduta, tempi di vendita per fascia; se (8) salta nessun ritocco (Q164); equivalenza verde (12 h in un colpo = 100 ms = 60 s = 6 h + salva/carica + 6 h) |
| M27-10 | Integrazione: merge, `run_checks.ps1` una volta, documenti principali allineati (`01_GDD.md` §8/§34, `03_ARCHITECTURE.md` moduli e save v11, `GUIDA.md`), Q159-Q170 riviste, build Windows (partita nuova e slot v10 migrato), tag `m27-done`; push **solo** dopo aver chiesto all'utente (Orchestratore) | REV | S | tutti | **DONE** (commit `docs: M27 chiusura, STATUS e CLAUDE`, tag `m27-done`; run_checks 3776/3776; Q164 e Q165 risolte). `run_checks.ps1` verde su main; nessun riferimento vietato; nessun file oltre 400 righe; build che parte in entrambi i casi |

## Rischi
- **Test esistenti** (alto, filone A): ~100 file di test contengono importi; dopo 03 cambiano ×100 (fixture convertite) o, per le formule ad arrotondamento fine (F-31, F-110, F-139,
  F-142/F-143, F-148/F-175, F-151/F-176), vanno ricalcolati. Mitigazione: 03 lancia la suite completa sul suo branch e consegna verde; nei test cambia solo il numero.
- **Doppia conversione** (alto se succede): lo script si esegue una volta per radice e si cancella nello stesso commit; il save ha la chiave nuova `copper`, così un v10 non migrato
  carica 0 con un avviso invece di 1/100 in silenzio.
- **Generatori** (medio): ognuno deve restare idempotente dopo la conversione (`--check`); un generatore che legge un importo dei dati e non divide per `copper_per_silver` scriverebbe ×10.000.
- **Casa d'Aste** (medio): Vendi subito passa per la Posta → `test_auction_house`, `test_auction_real_session`, `test_auction_sim_smoke`, `test_m26_offline_equivalence`, `sim_market`
  (le strategie ritirano la posta subito); numeri di `test_auction_pricing` in rame. **Equivalenza** (basso): il ciclo a blocchi è additivo per costruzione; il rischio è un'inserzione
  elaborata con la saturazione **prima** del recupero o un ordine diverso dei messaggi: i test di F-180/F-184 lo coprono.
- **Versioni**: `CURRENT_VERSION` 10 → 11 nei test di migrazione; `test_reasons` +3; `MAX_SESSION_LINES` 243 → 246.
- **Bilanciamento** (medio, nessuna ritaratura): parametri del libro, commissione e deposito sono valori di partenza; le misure di M27-09 vanno al Reviewer (Q164, Q165). Q151 non si tocca.

## M27-02 — dettaglio
- **Leggere**: `02_FORMULAS_M27.md` F-177; `04_DATA_SCHEMA_M27.md` §32.1; `05_INTERFACES_M27.md` §4d, §5.38, §6e; `05_INTERFACES.md` §5.4; `05_INTERFACES_M26.md` §6d (procedura della migrazione).
- **Ownership**: `core/common/money.gd`, `core/data/defs/currency_params.gd`, `core/data/game_data.gd` (accessore), caricamento e validatore di `currency` in `core/data/`, `core/data/data_validator_village.gd`
  e `data_validator_quests.gd` (solo il passo di arrotondamento), `systems/wallet/wallet.gd`, `core/save/save_migrator.gd`, `core/save/migrations/migration_10_to_11.gd`, `data/config/balance.json`
  (solo la sezione `currency`), `tests/fixtures/saves/slot_v10.json`, `tests/core/common/test_money.gd`, `tests/core/save/**`, `tests/systems/wallet/**`, `tests/core/data/**` (casi di `currency`).
- **Fuori**: ogni altro file di `data/`, generatori, UI.

## M27-03 — dettaglio
- **Leggere**: `04_DATA_SCHEMA_M27.md` §32.2, §32.6; `02_FORMULAS_M27.md` F-177; `NOMI.md` (regole dei nomi).
- **Ownership**: `tools/convert_money_m27.gd` (creato, eseguito, cancellato), `data/**`, `tests/fixtures/data/**`, `tools/gen_*.gd` (solo lettura e scrittura degli importi), `tools/sim_*.gd` (solo unità),
  `data/guide/monete.json` e le parole "oro" delle altre pagine, `NOMI.md`, `tests/**` (**solo** numeri di denaro attesi e importi delle preparazioni).
- Il branch parte da `task/M27-02`. Nel report: elenco dei file di test toccati e delle formule ad arrotondamento fine ricalcolate.

## M27-04 — dettaglio
- **Leggere**: `05_INTERFACES_M27.md` §5.38, §7.o (M27-04); `01_GDD_M27.md` §39.1, §39.8; `docs/09_CONVENTIONS.md` (UI); `tools/shot_ui.gd`.
- **Ownership**: `ui/components/money/**` (nuovo), `ui/theme/` (solo i tre colori), `assets/icons/ui/coin_*.svg`, le pagine e i testi di `ui/**` che mostrano denaro (elenco con `grep` di
  `get_gold`, `gold`, "oro"), `core/guide/guide_tables.gd`, `guide_dungeon_tables.gd`, `map_effect_labels.gd` (solo formattazione), i loro smoke test.

## M27-05 — dettaglio
- **Leggere**: `02_FORMULAS_M27.md` F-183; `04_DATA_SCHEMA_M27.md` §32.5; `05_INTERFACES_M27.md` §1d, §3e, §4d, §5.40, §6e.
- **Ownership**: `systems/mail/**`, `core/data/defs/mail_template_def.gd`, caricamento e `core/data/data_validator_mail.gd` (+ aggancio in `data_validator.gd`), `data/mail/templates.json`,
  `data/config/balance.json` (solo `mail`), `tests/fixtures/data/mail/**`, `core/autoload/event_bus.gd` (solo `mail_changed`), `core/common/reasons.gd` (solo `MAILBOX_FULL`),
  `core/session/game_session.gd`, `core/offline/offline_summary.gd`, `core/session/session_snapshot.gd`, `tests/systems/mail/**`, `tests/core/session/test_game_session.gd` (solo il limite),
  `tests/core/common/test_reasons.gd`.

## M27-06 — dettaglio
- **Leggere**: `02_FORMULAS_M27.md` F-178…F-182, F-184, §9e; `02_FORMULAS_M26.md` F-172…F-176; `04_DATA_SCHEMA_M27.md` §32.3-§32.4; `05_INTERFACES_M27.md` §1d, §3e, §4d, §5.39, §6e;
  `05_INTERFACES.md` §5.30.
- **Ownership**: `systems/auction/**`, `core/data/defs/auction_params.gd`, `auction_population_band.gd`, `auction_duration.gd` (nuovo), `core/data/data_validator_auction.gd`, `core/data/auction_index.gd`,
  `data/auction/population.json`, `data/config/balance.json` (solo `auction`), `tests/fixtures/data/auction/**`, `core/autoload/event_bus.gd` (solo `auction_listings_changed`),
  `core/common/reasons.gd` (solo i due motivi), `tests/systems/auction/**`, `tests/core/data/test_data_validator_auction.gd`, `tests/integration/test_auction_*.gd`,
  `tests/integration/test_m26_offline_equivalence.gd` (solo la Vendi subito che ora passa dalla Posta), `tests/core/common/test_reasons.gd`.

## M27-07 e M27-08 — dettaglio (UI)
- **Leggere**: `01_GDD_M27.md` §39.3, §39.4, §39.8; `05_INTERFACES_M27.md` §5.39 (solo `AuctionHouse`), §5.40, §7.o; `docs/09_CONVENTIONS.md` (UI); `tools/shot_ui.gd`.
- **Ownership**: M27-07 `ui/pages/mail/**` (nuova), `ui/screens/main/sidebar.gd`, `page_host.gd`, la riga del riepilogo offline (`ui/feedback/` o dove sta oggi), `assets/icons/ui/mail.svg`,
  `data/guide/posta.json`, `core/guide/guide_index.gd` (`PAGE_MAIL`), `core/data/data_validator_guide.gd` (solo `ROUTES`), `tests/ui/test_mail_page_smoke.gd`;
  M27-08 `ui/pages/auction/**`, `data/guide/casa_aste.json`, `tests/ui/test_auction_page_smoke.gd` e il suo stub.

## M27-09 — dettaglio
- **Leggere**: `02_FORMULAS_M27.md` F-182, F-184; `02_FORMULAS.md` F-152 (simulazione di M23); `05_INTERFACES_M27.md` §5.39-§5.40.
- **Ownership**: `tools/sim_market.gd` (e un file d'aiuto `tools/sim_market_book.gd` se serve per il limite di righe), `tests/integration/test_m27_offline_equivalence.gd`, `tests/integration/test_auction_sim_smoke.gd`.
