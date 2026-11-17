# 07. Task, M25: Alpha 1

Estensione di `07_TASKS.md`. Fonte: decisioni V25-V26 (`DECISIONS_LOG.md`), `01_GDD_M25.md` §36, `02_FORMULAS_M25.md` F-161…F-165, `04_DATA_SCHEMA_M25.md` §30,
`05_INTERFACES_M25.md`. Scadenza: alpha **giovedì 2026-11-19**. Il design **non** si riscrive nei brief: si citano ID e sezioni. Max 2 agenti insieme.
**Ordine**: M25-02 → (**M25-03 ∥ M25-04**) → (**M25-05 ∥ M25-06**, M25-05 solo quando l'utente fornisce la lista) → M25-07 (può partire in parallelo a M25-03 se i file non si toccano) → M25-08 → M25-09.
**Perché M25-02 per primo**: il validatore rifiuta chiavi e campi sconosciuti (schema e `balance.json` devono stare su `main` prima dei dati e della UI).

| ID | Titolo | Ruolo | Dip. | Accettazione |
|---|---|---|---|---|
| M25-01 | Design dei nodi con tentativi: GDD §36, F-161…F-165, schema §30, contratto, task, V25-V26, Q127-Q132 | REV | M24-09 | **DONE** (questo commit) |
| M25-02 | Logica: `EncounterCycle` (aggiunte), `NodeWork` a tentativi, motore, segnale `node_attempt_done`, `Reasons.TOO_HARD`, definizioni dati, validatore, `balance.json` (§9c), fixture, save additivo | CORE | 01 | tutti gli esempi di F-161…F-164 sono test; `expected` (F-165); blocco unico = 100 ms = 60 s anche con nodi a 3 e 5 tentativi, nodo ricco e coda attiva (estende `test_m24_offline_equivalence.gd`); salva → carica → salva identico, nodo M24 senza i campi nuovi riparte da 0; `bank_full` a metà nodo chiude e tiene il già messo; la Bacheca conta lo stesso totale per nodo; suite dei test mirati verde |
| M25-03 | Contenuti: fotogrammi animati e icona "ricco" per le 4 discipline (`assets/nodes/<skill>/`), `gen_nodes.gd` (facoltativo `difficulty`/`min_level`; di partenza nessuno), `sim_encounters.gd` con tentativi e ricchi | DATA | 02 | `validate_data` verde (dati veri e fixture); asset con nomi originali, `NOMI.md` aggiornato; la sim stampa unità/h per disciplina e le confronta con F-165 (±5%); soglie di F-156: se saltano come in Q122, **nessun ritocco**, numeri al Reviewer |
| M25-04 | UI: `NodeCard` (§7.p) al posto del riquadro del bersaglio, animazioni (sprite, particelle, tween), pips dei tentativi, lista del bottino, badge "Ricco", forma bloccata (`not_learned`, `too_hard`); Guida: testi dei tentativi | UI | 02 (03 per gli asset: fino ad allora segnaposto) | un solo smoke test della scheda (nodi di §7.p presenti, `refresh` con stato lavorato, ricco e saltato); `NodePanel` e i suoi test tolti; nessun numero di design e nessun calcolo nella UI (grep); screenshot con `tools/shot_ui.gd` (nodo normale, ricco, saltato) |
| M25-05 | Drop forniti dall'utente: tabelle di drop e oggetti dalla lista dell'utente | DATA | **lista dell'utente** | **IN ATTESA della lista**; accettazione definita alla consegna (validatore verde, Casa d'Aste e regole di non-arbitraggio rispettate) |
| M25-06 | UI: verifica del layout a 1280×720 e 1600×900 (Combattimento con scheda e mappa, Maestri, coda, Villaggio, Casa d'Aste), ritocchi dei screenshot M23 (`tools/ui_shots/m23_*.png`, Q125), pulsante "?" Guida nella pagina Maestri | UI | 04 | screenshot a entrambe le risoluzioni senza testi tagliati né sovrapposizioni (elenco dei difetti corretti nel report); "?" apre la pagina della Guida dei Maestri (rotta già esistente); smoke test invariati verdi |
| M25-07 | Strumento di debug del tempo offline: impostazione in `user://settings.cfg` (`[debug] offline_extra_minutes`, 0 = spento) e controllo nella pagina Impostazioni; applicato dal percorso di caricamento come tempo offline aggiuntivo (stesso `OfflineSimulator`, tetto 12 h invariato) | CORE/UI | 02 | **mai nello slot** (test: lo slot salvato è identico con e senza l'impostazione; nessuna chiave nel save); con valore 0 comportamento identico a oggi; con N minuti il riepilogo "Mentre eri via…" mostra il tempo simulato; `Settings` testata per salvataggio e lettura; nessun numero di design nel codice (il tetto è `offline.max_hours` esistente) |
| M25-08 | Export Windows: preset, eseguibile di prova, `docs/ALPHA1_README.md` (come installare, cosa provare, come segnalare problemi, limiti noti, uso dello strumento di debug) | REV/QA | 04, 06, 07 | l'eseguibile parte, apre un nuovo slot, combatte, entra in un nodo e mostra la scheda; README completo in italiano; checklist `RELEASE_CHECKLIST_MVP.md` aggiornata per l'alpha; `export/` resta fuori da git |
| M25-09 | Integrazione: merge, `run_checks.ps1` verde, `STATUS.md`, Q127-Q132 riviste, tag `m25-done` e `alpha-1` | REV | tutti | `run_checks.ps1` verde dopo il merge; nessun riferimento vietato; `01_GDD.md`, `03_ARCHITECTURE.md`, `GUIDA.md` allineati a §36; push solo a cura dell'Orchestratore |

## M25-02 — dettaglio
- **Leggere**: `02_FORMULAS_M25.md` (F-161…F-165, §9c); `05_INTERFACES_M25.md` §3c, §5.33b, §6b; `04_DATA_SCHEMA_M25.md` §30.1-30.2; `05_INTERFACES_M24.md` §5.33.
- **Ownership**: `systems/encounters/**`, `systems/combat/` (solo il motore del ciclo), `systems/actions/gathering_resolver.gd` (se serve), `core/common/reasons.gd`,
  `core/event_bus.gd`, `core/data/**` (definizioni e validatore dei nodi, `balance`), `core/save/` (solo la lettura tollerante del nodo), `data/config/balance.json`
  (solo le chiavi di §9c), `tests/fixtures/data/**`, `tests/systems/encounters/**`, `tests/data/**`, `tests/integration/test_m24_offline_equivalence.gd`.
- **Fuori ownership**: `ui/**`, `data/encounters/nodes.json`, `assets/**`, `tools/**` (salvo il minimo per compilare).

## M25-04 — dettaglio
- **Leggere**: `01_GDD_M25.md` §36.5; `05_INTERFACES_M25.md` §3c, §7.p; `docs/09_CONVENTIONS.md` (UI); `tools/shot_ui.gd`.
- **Ownership**: `ui/pages/combat/node_card*.gd|tscn`, `node_art.gd`, `node_panel.*` (da togliere), `ui/pages/combat/combat_page.gd` (solo il cambio riquadro), `tests/ui/**` della scheda, testi della Guida.

## Ritocchi dopo Alpha 1: M25-10…M25-14 (V27-V29)
Fonte: V27-V29 e M25-10 in `DECISIONS_LOG.md`; `01_GDD_M25.md` §37; `04_DATA_SCHEMA_M25.md` §30.4; `05_INTERFACES_M25.md` §5.31b, §6c, §7.p1, §7.p2; Q136-Q144.
**Ordine**: M25-10 → (**M25-11 ∥ M25-13**, file disgiunti) → **M25-12** (dopo M25-11: legge `is_extra`, `is_active` e l'Incisore appreso) → M25-14. Max 2 agenti insieme.

| ID | Titolo | Ruolo | Dip. | Accettazione |
|---|---|---|---|---|
| M25-10 | Design di V27-V29: GDD §37, schema §30.4, contratto §5.31b/§6c/§7.p1/§7.p2, task, Q136-Q144 | REV | alpha-1 | **DONE** (questo commit) |
| M25-11 | Incisore come 4ª disciplina di produzione: dati (`discipline: true`, Maestro), validatore "2 su 4", `Disciplines` (`extra`, `free_slots`, `is_extra`), `RiftAltar` (incavo bloccato = runa spenta, `is_active`), migrazione **v8 → v9** e congelamento di `migration_7_to_8.gd`, Guida e `NOMI.md` | CORE/DATA | 10 | `validate_data` verde (dati veri e fixture); casi rifiutati nuovi di §30.4 sono test; `test_data_validity` conta 4 + 4; **migrazione** (`tests/core/save/test_migration_8_to_9.gd`): Incisore con XP e 1 produzione → appreso al grado che copre il livello, `extra` vuoto; con XP e 2 produzioni → appreso con `extra` = `["riftbinding"]`, `free_slots(artisan)` 0, `can_learn` di un'altra produzione `discipline_slots_full`, dopo `unlearn` di una produzione `extra` vuoto e posti 0; XP 0 con un lavoro dell'Incisore in coda → grado 1; XP 0 e nessun lavoro → non appreso; livello 99 → grado 5; nessun oro tolto; XP, maestria, rune e lavori identici prima e dopo; catena **v7 → v9** con XP dell'Incisore conservata; salva → carica → salva identico; `test_migration_7_to_8` verde con i dati nuovi; **Altare**: dopo `unlearn(riftbinding)` le rune degli incavi oltre il livello restano (`get_socket`) ma `is_active` è false e la sorgente `rift_socket:<i>` non c'è, tornano attive risalendo di livello; senza Incisore `enqueue` di un'azione dell'Incisore → `not_learned`; smantellamento senza Incisore: prodotti sì, XP 0; offline equivalente (test esistenti verdi); i test che usano l'Incisore lo imparano nella preparazione (`TestFactory`), senza cambiare ciò che verificano |
| M25-12 | UI: menu laterale a gruppi con icone distinte (§37.3), pagina dei Maestri con 4 produzioni, posto in più e "drop dei mostri", testo dell'Altare senza Incisore e runa spenta | UI | 11 | smoke test `test_sidebar_groups.gd` (§7.p1); `test_sidebar_dungeon_lock.gd` e `test_trainers_page_smoke.gd` verdi; nessuna rotta cambiata (`page_requested` con gli stessi id); nessuna icona ripetuta tra le voci fisse; icone nuove Tabler con licenza; screenshot con `tools/shot_ui.tscn` a 1280×720 e 1600×900 (menu con 0 e con 4 discipline, pagina dei Maestri con il posto in più, Altare senza Incisore); nessuno stato di gioco nella UI |
| M25-13 | UI: area del bersaglio con `EnemyZone` / `NodeCard` / `TravelMiniMap` (§37.4), via `TravelMap` e la scheda in basso | UI | 10 | `test_travel_minimap_smoke.gd` e `test_combat_page_smoke.gd` aggiornato (§7.p2); `travel_map.gd` e il suo test tolti, nessun riferimento rimasto (grep `TravelMap`); `combat_page.gd` < 400 righe; nessun calcolo di gioco nella UI (solo `progress` di presentazione); nessun nodo né nemico sulla mappetta; screenshot a 1280×720 e 1600×900: viaggio, nodo lavorato, nodo saltato, scontro, senza salti di layout; "Effetti visivi ridotti" ferma il dondolio |
| M25-14 | Integrazione: merge, `run_checks.ps1` verde, `docs/ALPHA1_README.md` (punto 4 di "Come si gioca": Incisore tra le produzioni, 2 su 4; menu e mappetta), `01_GDD.md`/`GUIDA.md` allineati a §37, Q136-Q144 riviste; `STATUS.md` a cura dell'Orchestratore | REV | 11, 12, 13 | `run_checks.ps1` verde su main dopo i merge; nessun riferimento vietato; README e Guida coerenti con §37; un save v8 reale (alpha-1) caricato senza perdite (prova a mano o test con un file di esempio) |

## M25-11 — dettaglio
- **Leggere**: `01_GDD_M25.md` §37.1-§37.2; `04_DATA_SCHEMA_M25.md` §30.4; `05_INTERFACES_M25.md` §5.31b, §6c; `05_INTERFACES_M24.md` §5.31, §6b; `02_FORMULAS_M24.md`
  F-158…F-160; `01_GDD.md` §11 (Altare).
- **Ownership**: `data/skills/skills.json` (solo `riftbinding.discipline`), `data/disciplines/trainers.json` (solo il Maestro dell'Incisore), `data/guide/*.json`
  (solo i testi sull'Incisore e su "2 su 3"), `docs/NOMI.md` (Maestro dell'Incisore), `core/data/data_validator_disciplines.gd`, `systems/disciplines/**`,
  `systems/rift/rift_altar.gd`, `core/save/save_migrator.gd` (solo la versione), `core/save/migrations/migration_7_to_8.gd` (solo la costante storica),
  `core/save/migrations/migration_8_to_9.gd` (nuovo), `tests/core/save/**`, `tests/core/data/test_data_validator_disciplines.gd`, `tests/data/**`,
  `tests/systems/disciplines/**`, `tests/systems/rift/**`, `tests/helpers/test_factory.gd` (se serve un helper), e la **sola preparazione** dei test che usano
  l'Incisore con i dati veri (oggi: `tests/integration/test_m12_engraver_flow.gd`, `test_riftbinding_flow.gd`, `test_sockets_currency_flow.gd`, `test_m12_mastery_flow.gd`,
  `tests/systems/actions/test_engraver_resolver.gd`, `tests/systems/armory/test_salvage.gd`, `tests/systems/mastery/test_mastery_system.gd`,
  `tests/systems/skills/test_skills_*.gd`, `tests/data/test_rune_farming_hours.gd`, e i test UI `test_engraver_sections.gd`, `test_m8_05_rift_sockets.gd`,
  `test_mastery_panel_smoke.gd`, `test_m12_feedback_layout.gd`, `components/test_sub_tab_bar.gd` se falliscono).
- **Fuori ownership**: `ui/**` (salvo la preparazione dei test), `data/actions/**`, `balance.json` (nessuna chiave nuova), la Casa d'Aste.
- **Rischi**: (1) l'ordine della catena: se `migration_7_to_8.gd` non è congelata, un save v7 perde l'XP dell'Incisore prima di v9; (2) `Disciplines.from_save`
  azzera una disciplina non appresa con XP > 0: senza la migrazione un save v8 perderebbe l'Incisore; (3) `TestFactory` impara le prime 2 produzioni per `order`
  (l'Incisore è ultimo): i test che lo usano devono impararlo esplicitamente.

## M25-12 — dettaglio
- **Leggere**: `01_GDD_M25.md` §37.3 e §37.1 (testi di Maestri e Altare); `05_INTERFACES_M25.md` §7.p1; `05_INTERFACES.md` §7 (Sidebar); `09_CONVENTIONS.md` (UI).
- **Ownership**: `ui/screens/main/sidebar.gd`/`.tscn`, un eventuale `sidebar_texts.gd`, `assets/icons/ui/` (solo icone nuove), `ui/pages/trainers/**`, `ui/pages/rift/**`
  (testo e stato "spenta"), `tests/ui/test_sidebar_*.gd`, `tests/ui/test_trainers_page_smoke.gd`.

## M25-13 — dettaglio
- **Leggere**: `01_GDD_M25.md` §37.4 e §36.5; `05_INTERFACES_M25.md` §7.p, §7.p2; `05_INTERFACES_M24.md` §5.33 (`get_state`), §7.o; `tools/shot_ui.tscn`.
- **Ownership**: `ui/pages/combat/combat_page.gd`/`.tscn`, `travel_map.gd` (da togliere), `travel_minimap.gd`, `target_view.gd` (nuovi), `combat_texts.gd`
  (testo "In viaggio…"), `node_card.gd` (solo dimensioni), eventuale helper interno della pagina, `tests/ui/test_travel_*`, `tests/ui/test_combat_page_smoke.gd`,
  `tools/shot_ui.gd` (solo nuovi scenari).
- **Fuori ownership**: `systems/**`, `core/**` (nessun cambio di stato o segnali).

## Task di Alpha 1 fuori dai nodi
M25-05 attende la lista dell'utente (Q131). M25-07: Q130. Nessuna dipendenza di M25-05..07 dal design dei tentativi, salvo la UI di M25-06 (layout con la scheda).
