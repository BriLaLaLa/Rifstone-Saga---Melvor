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

## Task di Alpha 1 fuori dai nodi
M25-05 attende la lista dell'utente (Q131). M25-07: Q130. Nessuna dipendenza di M25-05..07 dal design dei tentativi, salvo la UI di M25-06 (layout con la scheda).
