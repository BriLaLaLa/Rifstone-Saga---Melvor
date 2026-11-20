# 07. Task, M28: Abilità e tratti v2 (condizioni, 19 abilità, 31 tratti)

Estensione di `07_TASKS.md`. Fonte: V35-V36 e M28-01 (`DECISIONS_LOG.md`), `01_GDD_M28.md` §40, `02_FORMULAS_M28.md` F-185…F-194, `04_DATA_SCHEMA_M28.md` §33,
`05_INTERFACES_M28.md`, Q171-Q182. Il design **non** si riscrive nei brief: si citano ID e sezioni. Max **2** agenti insieme; `sonnet` per i ruoli implementativi.
**Prima di M28-03**: l'utente legge e corregge le tabelle §40.6-§40.7 (nomi, livelli, valori); le correzioni entrano nei documenti (Reviewer) e poi nei dati di M28-06.

**Ordine**: M28-02 → M28-03 (**da solo**: tocca motore, sessione del combattimento, save, segnali) → (**M28-04 ∥ M28-05**) → M28-06 → (**M28-07 ∥ M28-08**) → [M28-09 solo se F-194 fallisce] → **M28-10**.
Perché: 02 e 03 toccano `combat_fight.gd` (397 righe), `combat_state.gd`, `effect_set.gd`, `effect_context.gd`, `trait_effect.gd`, `ability_runner.gd`: in sequenza. 03 posa **tutti** i punti di
chiamata del motore con default neutri, così 04 (abilità: `ability_def.gd`, `ability_runner.gd`, `data_validator_abilities.gd`) e 05 (tratti: `effects/<tipo>.gd`, `create_typed`,
`data_validator_traits.gd`) hanno file disgiunti e **non toccano** `combat_fight.gd`. Unico file in comune: la fixture `tests/fixtures/data/classes/test_class.json` (04 solo `abilities`,
05 solo `traits`; il secondo che chiude fa rebase, `08_TEAM.md` §2). 07 (`ui/**`, `core/guide/loadout_describe*.gd`, Guida) e 08 (`tools/sim_*`, `tests/integration/`) sono disgiunti.

**Lezioni da applicare in ogni brief** (da M27): (a) ogni UI interattiva nuova ha un test con **clic vero** (`Viewport.push_input` con `InputEventMouseButton`), non solo `emit`/`select`;
(b) nel worktree, se parte da un commit vecchio: `git checkout -B task/<ID> main`; (c) mai `-gtest=` con GUT: `-gdir=... -gselect=<nome>`; (d) screenshot in cartelle separate per
risoluzione, guardati davvero (Read), poi il flusso provato con clic; (e) prima del merge si tolgono i `*.uid` non tracciati che lo bloccano; (f) pagine della Guida ≤ 160 parole
(`test_guide_texts`); (g) a fine task nessun processo Godot in background. In più per M28: (h) **non regressione**: con i contenuti di M27 i test esistenti del combattimento restano verdi
**senza cambiare i numeri attesi** (se un numero cambia è un difetto, non un test da riallineare); (i) nessun `roll_pct` nuovo: tirano solo i colpi (F-23, F-22).

| ID | Titolo | Ruolo | Dim. | Dip. | Accettazione |
|---|---|---|---|---|---|
| M28-01 | Design: GDD §40, F-185…F-194, schema §33, contratto, task, V35-V36, Q171-Q182 | REV | M | m27-done | **DONE** (questo commit) |
| M28-02 | Refactor senza cambi: `CombatCycle` estratto da `combat_fight.gd`; `DataValidatorAbilities` estratto da `DataValidatorTraits` | COMBAT | M | 01 | `combat_fight.gd` ≤ 300 righe; nessuna riga di logica cambiata (spostamenti e `extends`); `tests/systems/combat`, `tests/core/data`, `tests/integration` verdi **senza toccare i numeri**; `validate_data` verde su dati e fixture; `check_file_sizes` verde |
| M28-03 | Condizioni e cablaggio del motore: `EnemyConditions`, `PlayerWard`, `BleedClock`, `ConditionApply`, `ConditionParams`, `combat.conditions`, agganci e contesto (§5.10b-c), `roll_power_attack`, firma di `take_due`, `combat_condition_damage`, `get_state`, save additivo | COMBAT | L | 02 | esempi di F-185…F-190 e F-193 sono test (con effetti finti di prova nei test, non dati veri); **test di non regressione**: una sessione con i contenuti di M27 (3 assetti, `loadout=auto`, 2 h simulate, seme fisso) dà la stessa sequenza di `combat_hit`, uccisioni, PV e stato del generatore di `main` prima del task (registrata nel test); salva → carica → salva identico con condizioni, Riparo e orologio; save di M27 caricato identico; `combat_fight.gd` ≤ 380 righe; `tests/core/autoload/test_event_bus.gd` aggiornato per il segnale |
| M28-04 | Abilità: campi di `AbilityDef`, tipo `ward`, `hits`/`target`/`execute`/`apply`/`drain_pct`, `cut_cooldowns`, validatore §33.3 | COMBAT | M | 03 | esempi di F-191 sono test (`test_abilities_m28.gd`); casi rifiutati di §33.6 (parte abilità) sono test; `test_abilities.gd` esistente verde senza cambi; fixture con un'abilità per tipo e parametro nuovi; `validate_data` verde su fixture e dati |
| M28-05 | Tratti: 12 tipi di F-192 (un file e un test ciascuno), `create_typed`, tipi di F-120 ammessi nei tratti, "un effetto con stato per tratto", validatore §33.4 | COMBAT | L | 03 | ogni riga della tabella di F-192 è un test (`tests/systems/combat/effects/test_<tipo>.gd`); casi rifiutati di §33.6 (parte tratti e leggendari) sono test; i test dei tipi esistenti verdi senza cambi; fixture con un tratto per tipo nuovo; nessun effetto tocca motore o sessione (`grep`); `validate_data` verde |
| M28-06 | Contenuti: 19 tratti e 13 abilità in `rift_blade.json` (tabelle §40.6-§40.7 **dopo** le correzioni dell'utente), descrizioni senza cifre, nome di Q174, `NOMI.md`, test dei dati | DATA | M | 04, 05 | `validate_data` verde; esistenti primi e invariati (diff del file solo in coda, più l'eventuale `name` di Q174); `test_class_data.gd` e `test_crafting_data.gd` riallineati (conteggi 31/19, 5 abilità per Spadone/Spada e scudo/Due spade e 4 per Spada, ognuno con una al livello 1, tutti i tipi nuovi usati almeno una volta); nessuna cifra nelle `description` (test); nomi unici e nuovi in `NOMI.md` |
| M28-07 | UI: `LoadoutDescribe` (+ `LoadoutDescribeEffects`) per i tipi e i parametri nuovi; filtro "Solo assetto attuale" e ordine per livello; condizioni sui nemici, Riparo sul giocatore, numeri del Sanguinamento; icone; Guida "Condizioni" | UI | M | 06 | smoke test con **clic veri** (interruttore, carta) e un test di `LoadoutDescribe` per ogni tipo nuovo (testi non vuoti, nessun "Effetto speciale" per i dati veri); `player_column.gd` resta ≤ 400 righe (il Riparo in un componente nuovo); nessuno stato di gioco nella UI; Guida ≤ 160 parole; screenshot 1280×720 e 1600×900 (scheda con 20 tratti, combattimento con un nemico che sanguina, uno sbilanciato e il Riparo) guardati |
| M28-08 | QA: `sim_combat` con `setup=sword` e `traits=`/`abilities=` espliciti (helper `tools/sim_loadout.gd`: `sim_combat.gd` è a 400 righe), misure di F-194; `test_m28_offline_equivalence.gd`; `test_m28_conditions_flow.gd` (sessione vera) | QA | M | 06 | F-194 (1)-(4) con tabella nel report (K, D, F per gruppo, i tre equipaggiamenti completi per assetto e livello); (4) identico a `main` prima di M28; equivalenza: 12 h in un colpo = passi da 100 ms = blocchi da 60 s con salva e ricarica a metà, con un equipaggiamento che usa Sanguinamento, Sbilanciamento, Riparo, contrattacco e accumuli; flusso su sessione vera (sblocco al livello, scelta, uso, condizioni in `get_state`, save) |
| M28-09 | Ritocco dei soli contenuti nuovi se F-194 fallisce (massimo 2 giri, poi decide il Reviewer, Q178) | DATA | S | 08 | solo valori delle voci nuove; F-194 rimisurata verde; nessun valore esistente né chiave dell'economia toccati |
| M28-10 | Integrazione: merge, `run_checks.ps1` una volta, documenti principali (`01_GDD.md` §20, `03_ARCHITECTURE.md` cartella `conditions/` e save, `GUIDA.md`), Q171-Q182 riviste, build Windows (partita nuova, slot di M27 con combattimento in corso), tag `m28-done`; push **solo** dopo aver chiesto all'utente (Orchestratore) | REV | S | tutti | `run_checks.ps1` verde su main; nessun file oltre 400 righe; nessun riferimento vietato; build che parte in entrambi i casi |

## Rischi
- **Non regressione del combattimento** (alto): il motore cambia in molti punti (`_hurt_player`, `_apply_hits`, `_enemy_attack`, `_kill`, `_consume`, `_next_timer`). Mitigazione: default neutri
  ovunque, nessun tiro nuovo senza contenuti nuovi, test di sequenza registrata in M28-03, F-194 (4) in M28-08. Test sensibili: `test_combat_engine`, `test_abilities`, `effects/test_*`,
  `test_reference_encounter`, `test_offline_*`, `test_m26/m27_offline_equivalence`, `test_dungeon_*`, `test_metin_*`, `test_drop_balance`, `sim_*` usati nei test.
- **Limite di righe** (alto): `combat_fight.gd` 397, `player_column.gd` 400, `sim_combat.gd` 400, `loadout_describe.gd` 134 (+~25 tipi). Mitigazione: refactor in M28-02, file nuovi nominati nel
  contratto (`CombatCycle`, `LoadoutDescribeEffects`, `sim_loadout.gd`, componente del Riparo).
- **Test sui dati veri** (medio): `test_class_data.gd` (conteggi 12/6, "2 abilità per assetto", tipi usati), `test_crafting_data.gd` (12/6), `test_guide_tables` (righe delle tabelle), smoke del
  pannello (numero di carte). Si riallineano **solo** in M28-06/M28-07, con i numeri di §40.
- **`loadout=auto` e B1** (medio): `sim_combat`/`sim_progress` scelgono i primi sbloccati nel file: i contenuti nuovi vanno **in coda** (§33.5), così le ore al 99 (banda 250-380 h) non cambiano.
- **Save** (basso): tutto additivo in v11; un save di M27 carica identico; i contatori dei tratti restano con la chiave dell'id del tratto (un solo effetto con stato per tratto).
- **Offline** (medio): l'orologio del Sanguinamento aggiunge un evento al secondo solo mentre qualcuno sanguina; misurare in M28-08 il tempo di 12 h offline con un equipaggiamento a Sanguinamento
  (soglia: non oltre 1,5 × quello senza; altrimenti `tick_ms` più lungo, Q176).
- **Generatore** (medio): i colpi in più (abilità a più colpi, contrattacchi) consumano tiri: cambia la sequenza **solo** con i contenuti nuovi equipaggiati (atteso, documentato in §40.8).
- **Equilibrio** (medio, nessuna ritaratura): valori di partenza; se F-194 fallisce si toccano solo le voci nuove (M28-09).

## M28-02 — dettaglio
- **Leggere**: `05_INTERFACES_M28.md` §5.10b (refactor), §4e (validatori); `05_INTERFACES.md` §5.10.
- **Ownership**: `systems/combat/combat_fight.gd`, `systems/combat/combat_cycle.gd` (nuovo), `systems/combat/combat_engine.gd` (solo `extends`/riferimenti se servono),
  `core/data/data_validator_traits.gd`, `core/data/data_validator_abilities.gd` (nuovo), `core/data/data_validator.gd` (solo l'aggancio), `tests/core/data/test_data_validator_traits.gd`
  (solo spostamento dei casi delle abilità in `tests/core/data/test_data_validator_abilities.gd`, nuovo).

## M28-03 — dettaglio
- **Leggere**: `01_GDD_M28.md` §40.3, §40.8, §40.10; `02_FORMULAS_M28.md` F-185…F-190, F-193, §9f; `04_DATA_SCHEMA_M28.md` §33.1-§33.2; `05_INTERFACES_M28.md` §3f, §4e, §5.10b, §5.10c (parte M28-03), §6f.
- **Ownership**: `systems/combat/conditions/**` (nuova), `systems/combat/combat_state.gd`, `combat_fight.gd`, `combat_engine.gd`, `combat_save.gd`, `combat_view.gd`, `encounter.gd`,
  `ability_runner.gd` (solo firma, `Use`, `mult_of`, colpi su bersagli morti), `systems/combat/effects/effect_context.gd`, `trait_effect.gd`, `effect_set.gd` (composizioni, non `create_typed`),
  `core/data/defs/condition_apply.gd`, `condition_params.gd` (nuovi), `core/data/game_data.gd` (accessore), validatore di `balance.json` (solo `combat.conditions`), `data/config/balance.json`
  (solo `combat.conditions`), le fixture di `balance.json` se il validatore le richiede (idem), `core/autoload/event_bus.gd` (solo il segnale), `tests/systems/combat/**` (nuovi test e
  `conditions/`), `tests/core/autoload/test_event_bus.gd` (solo il segnale nuovo).

## M28-04 — dettaglio
- **Leggere**: `02_FORMULAS_M28.md` F-190, F-191; `04_DATA_SCHEMA_M28.md` §33.2-§33.3, §33.6; `05_INTERFACES_M28.md` §4e, §5.10c (AbilityRunner).
- **Ownership**: `core/data/defs/ability_def.gd`, `core/data/data_validator_abilities.gd`, `systems/combat/ability_runner.gd`, `tests/systems/combat/test_abilities_m28.gd` (nuovo),
  `tests/core/data/test_data_validator_abilities.gd`, `tests/fixtures/data/classes/test_class.json` (solo `abilities`).

## M28-05 — dettaglio
- **Leggere**: `02_FORMULAS_M28.md` F-190, F-192; `02_FORMULAS.md` F-81, F-120 (tabella); `04_DATA_SCHEMA_M28.md` §33.4, §33.6; `05_INTERFACES_M28.md` §5.10c.
- **Ownership**: `systems/combat/effects/<tipo>.gd` (12 nuovi), `systems/combat/effects/effect_set.gd` (solo `create_typed`), `core/data/data_validator_traits.gd`,
  `core/data/data_validator_legendary.gd` (solo il rifiuto dei tipi di F-192), `tests/systems/combat/effects/**`, `tests/core/data/test_data_validator_traits.gd`,
  `tests/fixtures/data/classes/test_class.json` (solo `traits`).

## M28-06 — dettaglio
- **Leggere**: `01_GDD_M28.md` §40.6-§40.7 (versione corretta dall'utente); `04_DATA_SCHEMA_M28.md` §33.3-§33.5; `NOMI.md` (regole dei nomi).
- **Ownership**: `data/classes/rift_blade.json`, `docs/NOMI.md` (sezione Tratti e abilità), `tests/data/test_class_data.gd`, `tests/data/test_crafting_data.gd` (solo i conteggi di classe).
- Nessuno script generatore: 32 voci scritte a mano dalle tabelle (non sono ripetitive come gradi o tabelle numeriche).

## M28-07 — dettaglio
- **Leggere**: `01_GDD_M28.md` §40.3, §40.9; `05_INTERFACES_M28.md` §5.10b (`get_state`), §5.10c (LoadoutDescribe), §7.aa; `docs/09_CONVENTIONS.md` (UI); `tools/shot_ui.gd`.
- **Ownership**: `core/guide/loadout_describe.gd`, `core/guide/loadout_describe_effects.gd` (nuovo), `ui/pages/character/**`, `ui/pages/combat/enemy_card.gd`, `hit_numbers.gd`,
  `player_column.gd` (solo l'aggancio del componente), un componente nuovo per il Riparo in `ui/pages/combat/`, `assets/icons/conditions/**`, `data/guide/condizioni.json`,
  `data/guide/combattimento.json` (solo il collegamento), `tests/ui/test_loadout_panel_smoke.gd`, `tests/ui/test_combat_conditions_smoke.gd` (nuovo), `tests/core/guide/test_loadout_describe*.gd`,
  `tests/core/guide/test_guide_tables.gd` (solo i conteggi).

## M28-08 — dettaglio
- **Leggere**: `02_FORMULAS_M28.md` F-194; `01_GDD_M28.md` §40.8; `02_FORMULAS.md` F-28 (banda B1); intestazione di `tools/sim_combat.gd`.
- **Ownership**: `tools/sim_combat.gd` (solo opzioni e aggancio), `tools/sim_loadout.gd` (nuovo), `tests/integration/test_m28_offline_equivalence.gd`, `tests/integration/test_m28_conditions_flow.gd`,
  test della sim se esistono (`tests/integration/test_*sim*` solo per le opzioni nuove).
- Report: tabelle di F-194 per assetto e livello, i tre equipaggiamenti completi, tempo reale di 12 h offline con e senza Sanguinamento.
