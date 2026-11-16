# 07. Task, M24: Incontri e Mestieri

Estensione di `07_TASKS.md` (che supera le 400 righe). Fonte: `M24_MESTIERI.md`, V16-V24 (`DECISIONS_LOG.md`), `01_GDD_M24.md` §35, `02_FORMULAS_M24.md`
F-153…F-160, `04_DATA_SCHEMA_M24.md` §29, `05_INTERFACES_M24.md`. Il design **non** si riscrive nei brief: si citano gli ID e le sezioni.
Max 2 agenti insieme. **Ordine**: M24-02 → (**M24-03 ∥ M24-05**) → (**M24-04 ∥ M24-06**; se M24-05 non è finito, M24-04 ∥ M24-05 e M24-06 dopo) → M24-07 → M24-08.
**Perché M24-02 viene prima** (come in M23): il validatore rifiuta chiavi e campi sconosciuti, quindi lo schema (definizioni, validatore, `balance.json`,
fixture) deve essere su `main` prima dei dati veri (M24-05) e della logica (M24-03); la rimozione degli aiutanti va nello stesso task perché tocca gli stessi file.
**CORE e DATA disgiunti**: M24-03 tocca `systems/`, `core/session|save|autoload|common`, poche righe di `ui/` e i test non di dati; M24-05 tocca `data/`
(salvo `config/balance.json` e i `grades` di `trainers.json`), `tools/gen_*`, `assets/`, `tests/data/`, la costante `STRICT_REAL_DATA` e `NOMI.md`.

| ID | Titolo | Ruolo | Dip. | Accettazione |
|---|---|---|---|---|
| M24-01 | Design: GDD §35, F-153…F-160, schema §29, contratto M24, task, V16-V24, Q105-Q121 | REV | M23-06 | **DONE**: verifica sul codice in §35.0; G=a, H=una, I=livello proprio; save v8 con migrazione; elenco delle eliminazioni in §35.12 |
| M24-02 | Fondamenta: rimozione di aiutanti e Contratti; schema dati di M24 (definizioni, indice, validatore, `GameData`, tabella `trainer_grades`), `balance.json`, `skills.json` (`discipline`), `trainers.json` (`grades`), fixture | CORE | 01 | criterio di §35.12 verificato con `grep` (codice, dati, UI, test, strumenti, asset); `validate_data` verde su fixture e dati veri (`STRICT_REAL_DATA = false`); errori di §29.9 coperti; test toccati verdi; ogni file ≤ 400 righe |
| M24-03 | Discipline e Maestri (`Disciplines`), limite di livello, reset, coda di produzione (`ActionRunner` riscritto), Villaggio e Bacheca, sessione, segnali, motivi, save v8 e migrazione 7 → 8 | CORE | 02 | F-157…F-160 = test alla lettera; ordine dei rifiuti e atomicità di §5.31-§5.32; migrazione di §6b su save v7 veri di prova (5 casi); `from_save` tollerante; round-trip; i test esistenti adattati verdi |
| M24-04 | Ciclo degli incontri: `EncounterCycle`, `NodeWork`, `GatheringResolver.resolve_units`, stati `travel`/`node` del motore, save del motore, segnali, riepilogo offline | COMBAT | 03 | F-153…F-156 = test alla lettera; `advance(1000)` = dieci `advance(100)` con viaggi e nodi; Fratture e Dungeon invariati; 12 h offline < 10 s; `between` di un'area si carica come `travel` |
| M24-05 | Contenuti: Erborista (azioni, erbe, sottoprodotti, maestria), Tonici e Ricette, Lastra runica, Maestri, `gen_nodes.gd` e `nodes.json`, Ricette nelle tabelle, incarichi, Casa d'Aste rigenerata, Guida, nomi | DATA | 02 | `STRICT_REAL_DATA = true` e `validate_data` verde; §8.10-§8.11 = test dei dati; 4 + 3 discipline; ogni area con i 4 nodi; nomi originali in `NOMI.md`; generatori rieseguiti byte per byte |
| M24-06 | UI: mappa di viaggio e pannello del nodo, pagina Maestri, coda di produzione, pagine delle discipline, barra laterale, Villaggio, Deposito, toast, riepilogo offline | UI | 03 (04 per il motore vero: si parte con lo stub) | §7.o; uno smoke test per pagina; layout a 1280×720; nessuno stato di gioco né formula nella UI |
| M24-07 | QA: `tools/sim_encounters.gd` (soglie di F-156) e integrazione su sessione vera | QA | 04, 05, 06 | la sim esce 0 o riporta i numeri senza ritoccare i dati; test d'integrazione del flusso di §35 verde |
| M24-08 | Integrazione: `run_checks`, screenshot, criterio di §35.12, documenti allineati, tag `m24-done` | REV | 07 | `run_checks.ps1` verde dopo il merge; nessun riferimento agli aiutanti (grep); `01_GDD.md`, `03_ARCHITECTURE.md`, `GUIDA.md` allineati; Q105-Q121 riviste |

## M24-02 — dettaglio
- **Leggere**: `01_GDD_M24.md` §35.0 e §35.12; `04_DATA_SCHEMA_M24.md` (tutto); `02_FORMULAS_M24.md` §9b e F-158 (solo i valori dei gradi);
  `05_INTERFACES_M24.md` §1b, §3b (righe tolte), §4b, §5.31 (solo `SkillsSystem.add_xp`, `MasterySystem.add_for_action`, `GuideTables`), §5.34;
  come modelli `core/data/data_validator_auction.gd` e `core/data/auction_index.gd`.
- **Ownership**: i file da **eliminare** di §35.12 (con `.uid`/`.import`); `res://core/data/` (`game_data.gd`, `data_validator.gd`, `data_validator_items.gd`,
  `data_validator_rules.gd`, `data_validator_loot_tables.gd`, `data_validator_dungeon.gd`, nuovi `data_validator_disciplines.gd`, `discipline_index.gd`,
  `defs/trainer_grade_def.gd`, `defs/trainer_def.gd`, `defs/area_nodes_def.gd`, `defs/node_entry_def.gd`; `defs/item_def.gd`, `defs/skill_def.gd`,
  `defs/action_def.gd`), `res://core/guide/guide_tables.gd`, `guide_ref.gd`, `guide_index.gd`, `res://core/session/game_session.gd` (solo gli aiutanti),
  `res://core/autoload/event_bus.gd` (3 segnali tolti), `res://core/common/reasons.gd` (3 motivi tolti), `res://core/modifiers/modifier_context.gd`,
  `modifier_service.gd` (commento), `res://systems/actions/gathering_resolver.gd` (tolto `helper_grade`), `res://systems/actions/action_runner.gd` (solo le
  chiamate alle firme cambiate), `res://systems/mastery/mastery_math.gd`, `mastery_system.gd` (`cycles`), `res://systems/skills/skills_system.gd` (tolto
  `share_pct`), `res://systems/quests/quests.gd` (tolto `helper_completed`), `res://systems/bank/bank.gd` (`SORT_CATEGORIES`), `res://ui/pages/skill/skill_page.gd`,
  `res://ui/pages/bank/bank_page.gd`, `bank_item_panel.gd`, `res://ui/components/toast/toast_manager.gd`, `res://ui/components/tooltip/item_tooltip_lines.gd`
  (solo le righe degli aiutanti e dei Contratti; nome della categoria `recipe` "Ricetta"), `res://data/config/balance.json` (via `helper`; sezioni di §29.6),
  `res://data/skills/skills.json` (solo `discipline`), `res://data/disciplines/trainers.json` (nuovo: `grades` di F-158, `trainers` vuoto),
  `res://data/combat/loot_tables.json` e `res://tools/gen_areas.gd` (solo via i Contratti; il resto byte per byte uguale), `res://data/guide/deposito.json`
  (via `guide_helpers`) ed eccezioni della Guida se servono, `res://tools/sim_combat.gd` (via l'opzione `helpers`), `res://tests/fixtures/data/**` (§29.9),
  i test che citano aiutanti o Contratti (`tests/data/test_balance_invariants.gd`, `test_config_files.gd`, `test_loot_tables_content.gd`, `test_m12_content.gd`,
  `test_names_m12.gd`, `test_dungeon_data.gd`; `tests/core/modifiers/test_excluded_sources.gd`, `tests/core/guide/test_guide_m12.gd`,
  `tests/core/autoload/test_event_bus.gd`, `tests/core/data/test_game_data.gd`, `tests/core/common/test_reasons.gd`, `tests/core/settings/test_game_settings.gd`;
  `tests/systems/bank/test_bank_bags.gd`, `tests/systems/quests/test_quests.gd`, `tests/systems/dungeon/test_dungeon_data.gd`, `test_dungeon_flow.gd`,
  `tests/systems/mastery/**`, `tests/systems/skills/**`; `tests/integration/test_m12_mastery_flow.gd`, `test_m12_offline_game.gd`;
  `tests/ui/test_m12_feedback_layout.gd`, `test_bag_slots_bar.gd`; `tests/helpers/m14_data.gd`), nuovi `tests/core/data/test_data_validator_disciplines.gd`,
  `tests/core/data/test_game_data_m24.gd`.
- **Test**: errori di §29.9; letture di `GameData` di §4b (anche `null` senza errore); tabella `trainer_grades`; `add_for_action(action, 3)` = 3 × F-10 e
  pool F-12 sul totale; `add_xp` senza `share_pct` invariata per il resto; nessun riferimento agli aiutanti (`tests/tools/test_checks.gd` o un test nuovo con
  la lista delle parole di §35.12, cartella `tests/helpers/` esclusa).
- **Fuori ownership**: `systems/disciplines/**`, il resto di `systems/actions/**`, `systems/combat/**`, `core/save/**`, `ui/**` oltre alle righe sopra,
  i contenuti nuovi di `data/` (M24-05).

## M24-03 — dettaglio
- **Leggere**: `01_GDD_M24.md` §35.3-§35.6, §35.8, §35.10; `02_FORMULAS_M24.md` F-157…F-160; `05_INTERFACES_M24.md` §1b, §3b, §5.31, §5.32, §5.34, §6b;
  `05_INTERFACES.md` §5.8b (progetti), §6 (formato v7); come modelli `core/save/migrations/migration_6_to_7.gd`, `systems/village/village.gd`.
- **Ownership**: `res://systems/disciplines/**` (nuovo), `res://systems/actions/action_runner.gd` (riscritto; nuovo `production_job.gd` se serve),
  `res://systems/skills/skills_system.gd`, `res://systems/mastery/mastery_system.gd`, `res://systems/village/village.gd`, `res://systems/quests/quests.gd`,
  `quest_picker.gd`, `res://systems/combat/combat_engine.gd` (solo `node_skill()` stub e le chiamate tolte ad `actions.stop`), `res://systems/fractures/**` e
  `res://systems/dungeon/**` (solo le chiamate tolte ad `actions.stop`), `res://core/session/game_session.gd`, `session_participants.gd`,
  `res://core/save/save_migrator.gd`, `res://core/save/migrations/migration_7_to_8.gd` (nuovo), `res://core/autoload/event_bus.gd`, `res://core/common/reasons.gd`,
  `res://core/offline/offline_simulator.gd` (solo se legge le corsie), `res://ui/pages/skill/*.gd` e `res://ui/screens/main/sidebar.gd` (**solo** le righe che
  chiamano l'API tolta, sostituite nel modo più semplice: Avvia → `enqueue(…, 1, true)`; la UI vera è di M24-06), i test: nuovi
  `tests/systems/disciplines/test_disciplines.gd`, `tests/systems/skills/test_skills_cap.gd`, `tests/systems/actions/test_production_queue.gd`,
  `tests/core/save/test_migration_7_to_8.gd`; adattati quelli che usano l'API tolta di `ActionRunner` (`tests/systems/actions/**`, `tests/integration/**`,
  `tests/core/offline/test_offline_simulator.gd`, `tests/core/autoload/test_game.gd`, `tests/core/session/test_game_session.gd`,
  `tests/systems/equipment/test_equipment_setups.gd`, `tests/systems/combat/test_combat_engine.gd` (solo le righe della corsia), `tests/systems/discovery/**`,
  `tests/systems/village/**`, `tests/systems/quests/**`, `tests/ui/test_skill_page_smoke.gd`, `test_m16_ui_smoke.gd`, `test_blueprint_section_smoke.gd`).
  `tests/integration/test_gathering_loop.gd` si **elimina** (la raccolta avviata non esiste più; il suo sostituto è il test dei nodi di M24-04).
- **Test**: F-157…F-160 alla lettera; rifiuti nell'ordine di §5.31-§5.32 e nessun cambiamento su rifiuto; segnali e loro ordine; `unlearn` azzera XP,
  maestria, pool, nodi e i lavori (progetto avviato restituito); invariante "XP > 0 ⇒ appresa" al caricamento; coda: fine per `job_done`, `missing_inputs`,
  attesa per Deposito pieno, progetto che consuma in testa, `cancel`/`move`; il combattimento non ferma la coda e viceversa; Villaggio sul livello del personaggio;
  Bacheca senza incarichi di discipline non apprese; migrazione: 5 save v7 di prova (raccolta in corso, ricetta in corso, progetto in corso, 7 skill con XP,
  Contratti nel Deposito e nel Bottino) → v8 attesi.
- **Fuori ownership**: `systems/encounters/**`, il resto di `systems/combat/**` (M24-04), `data/**`, `core/data/**` (M24-02), `ui/**` oltre alle righe sopra.

## M24-04 — dettaglio
- **Leggere**: `01_GDD_M24.md` §35.1, §35.2, §35.9; `02_FORMULAS_M24.md` F-153…F-156; `05_INTERFACES_M24.md` §3b, §5.33, §6b (parte del motore);
  `05_INTERFACES.md` §5.10 (motore) e §5.29 (Dungeon, per non toccarlo); `systems/combat/combat_fight.gd` (`_cleared`, `_begin_encounter`).
- **Ownership**: `res://systems/encounters/**` (nuovi `encounter_cycle.gd`, `node_work.gd`), `res://systems/combat/combat_engine.gd`, `combat_fight.gd`,
  `combat_state.gd`, `combat_save.gd`, `combat_view.gd`, `res://systems/actions/gathering_resolver.gd`, `action_outcome.gd`, `res://core/offline/**`,
  `res://core/session/session_snapshot.gd`, `res://core/autoload/event_bus.gd` (3 segnali), `res://core/common/reasons.gd` (`NODE_DONE`), test nuovi
  `tests/systems/encounters/test_encounter_cycle.gd`, `test_node_work.gd`, `tests/systems/combat/test_combat_cycle.gd`, `tests/integration/test_node_loop.gd`;
  adattati `tests/systems/actions/test_gathering_resolver.gd`, `test_gathering_milestones.gd`, `test_gather_effects.gd`, `tests/systems/combat/**`,
  `tests/integration/test_offline_flow.gd`, `test_combat_flow.gd` e i test di prestazione dell'offline.
- **Test**: esempi di F-153…F-156 alla lettera; equivalenza dei passi con viaggi e nodi; un nodo saltato non tira nulla; Monolito o miniboss in attesa →
  scontro senza tiro; nodo chiuso da Deposito pieno; Fratture e Dungeon senza viaggio né nodi; ritorno all'area dopo Frattura e Dungeon con un viaggio;
  `stop` e morte durante viaggio e nodo; save → load → save identico in `idle`, `travel`, `node`; `between` di un'area caricato come `travel`.
- **Fuori ownership**: `systems/disciplines/**`, `systems/actions/action_runner.gd`, `data/**`, `ui/**`.

## M24-05 — dettaglio
- **Leggere**: `01_GDD_M24.md` §35.2, §35.3 (nomi), §35.5, §35.6, §35.8; `02_FORMULAS_M24.md` §8.10, §8.11, F-154 (gradini); `04_DATA_SCHEMA_M24.md` (tutto);
  `02_FORMULAS.md` §8.1, §8.3, §8.8b; `tools/gen_areas.gd`, `tools/gen_quests.gd`, `tools/gen_auction.gd` (sola esecuzione), `docs/NOMI.md`.
- **Ownership**: `res://data/skills/skills.json` (Erborista, nome di `hearthcraft`), `res://data/actions/herbalism.json` (nuovo), `hearthcraft.json` (Tonici),
  `riftbinding.json` (solo la Lastra), `res://data/mastery/herbalism.json` (nuovo), `res://data/items/materials.json` (erbe, sottoprodotti), `food.json`
  (Tonici), `recipes.json` (nuovo), `res://data/disciplines/trainers.json` (solo `trainers`), `res://tools/gen_nodes.gd` (nuovo) e
  `res://data/encounters/nodes.json` (generato), `res://tools/gen_areas.gd` e `res://data/combat/loot_tables.json` (Ricette), `res://tools/gen_quests.gd` e
  `res://data/quests/quests.json`, `res://data/auction/auction_items.json` (rigenerato con `gen_auction.gd` **invariato**), `res://data/guide/**`,
  `res://assets/icons/skills/herbalism.svg` e le icone nuove in `res://assets/icons/items/` (con uno script se sono molte), `res://core/data/data_validator_disciplines.gd`
  (solo `STRICT_REAL_DATA = true`), `res://tests/data/**` (nuovo `test_m24_content.gd`; `test_data_validity.gd`), `docs/NOMI.md`.
- **Accettazione**: come la tabella; nessun nome da altri giochi (nomi dei Maestri, delle erbe, dei Tonici originali); pesi dei nodi a tema e regola di §29.3;
  Ricette: circa una ogni 2 ore nell'area del gradino (stima nel report, la misura la fa M24-07). Se il validatore della Casa d'Aste rifiuta i nuovi oggetti:
  stop e richiesta al Reviewer (nessun cambio a `gen_auction.gd`).
- **Fuori ownership**: `core/**` salvo la costante, `systems/**`, `ui/**`, `data/config/**`, i `grades` di `trainers.json`.

## M24-06 — dettaglio
- **Leggere**: `01_GDD_M24.md` §35.11, §35.7; `05_INTERFACES_M24.md` §7.o e le API di §5.31-§5.33 (solo firme); `05_INTERFACES.md` §7 (pagine esistenti),
  `docs/UI_GDR.md`; come modelli `ui/pages/village/`, `ui/pages/auction/`.
- **Ownership**: `res://ui/pages/combat/travel_map.gd`, `node_panel.gd` (nuovi), `combat_page.gd`, `player_column.gd` (solo l'aggancio), `combat_texts.gd`;
  `res://ui/pages/trainers/**` (nuova); `res://ui/pages/skill/**` (inclusa la nuova `production_queue_panel.gd`); `res://ui/screens/main/sidebar.gd`,
  `page_host.gd`; `res://ui/pages/village/village_page.gd`, `village_texts.gd`; `res://ui/pages/bank/bank_item_panel.gd`; `res://ui/components/toast/toast_manager.gd`;
  `res://ui/screens/offline/offline_summary_view.gd`, `offline_texts.gd`; `res://tests/ui/**` (nuovi `test_trainers_page_smoke.gd`, `test_travel_map_smoke.gd`),
  `res://tests/helpers/combat_cycle_stub.gd` (nuovo).
- **Accettazione**: §7.o; ogni numero dal modello (stime, costi, colori); nessun file oltre 400 righe (`skill_page.gd` è a 396: spostare le parti in viste).
- **Fuori ownership**: `core/**`, `systems/**`, `data/**`, `tools/**`.

## M24-07 — dettaglio
- **Leggere**: `02_FORMULAS_M24.md` F-156 (soglie); `05_INTERFACES_M24.md` §8b; `tools/sim_combat.gd`, `tools/sim_market.gd` (modelli), `tools/shot_ui.gd`.
- **Ownership**: `res://tools/sim_encounters.gd` (nuovo), `res://tests/integration/test_m24_real_session.gd` (impara 2 + 2, combatte con nodi lavorati e saltati,
  coda in parallelo, grado successivo, disimpara, salva e ricarica, offline 1 h), `res://tests/integration/test_sim_encounters_smoke.gd`, `res://tools/shot_ui.gd`
  (Maestri, mappa di viaggio, nodo, coda).
- **Accettazione**: la sim stampa le misure di F-156 e le soglie; se una salta, **nessun ritocco** dei dati: numeri al Reviewer. Misura anche le Ricette/ora.
- **Fuori ownership**: codice di `core/`, `systems/`, `ui/`; `data/**`.

## M24-08 — dettaglio
- **Ownership** (REV): merge; `docs/01_GDD.md`, `02_FORMULAS.md`, `03_ARCHITECTURE.md`, `04_DATA_SCHEMA.md`, `05_INTERFACES.md`, `GUIDA.md` (allineamento al
  codice), `docs/RELEASE_CHECKLIST_MVP.md`; `docs/STATUS.md` lo aggiorna l'Orchestratore.
- **Accettazione**: come la tabella; il REV controlla anche che la UI non legga `balance.json` né calcoli F-153…F-160, che `Disciplines` non abbia sorgenti di
  modificatori, che la coda non fermi il combattimento, e che Q105-Q121 siano ancora giuste.
