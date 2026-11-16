# 05. Interfacce, M24: Incontri e Mestieri (§1b, §3b, §4b, §5.31-§5.34, §6b, §7.o, §8b)

Estensione di `05_INTERFACES.md` (che supera le 400 righe): **è contratto** con le stesse regole (la modifica solo il Reviewer; un task che ha bisogno di
una firma nuova si ferma e la chiede). Dove questo file contraddice `05_INTERFACES.md` vale questo file; le sezioni sostituite là sono segnate
"**SOSTITUITA in M24**". Design: `01_GDD_M24.md` (§35), formule `02_FORMULAS_M24.md` (F-153…F-160), dati `04_DATA_SCHEMA_M24.md` (§29). Accanto a ogni firma
il task che la scrive.

## 1b. Motivi (`core/common/reasons.gd`)
**Nuovi** (M24-03 salvo dove indicato): `NOT_LEARNED` (`&"not_learned"`), `ALREADY_LEARNED`, `DISCIPLINE_SLOTS_FULL` (`&"discipline_slots_full"`),
`NOT_A_DISCIPLINE`, `MAX_GRADE`, `DISCIPLINE_BUSY`, `RECIPE_UNKNOWN`, `RECIPE_KNOWN`, `NOT_A_RECIPE`, `QUEUE_FULL`, `JOB_DONE`; `NODE_DONE` (M24-04).
**Tolti** (M24-02): `NOT_A_CONTRACT`, `NO_HELPER`, `HELPER_NOT_BETTER`; `LANE_UNAVAILABLE` (M24-03, con le corsie). Restano `bank_full`, `missing_inputs`,
`level_too_low`, `requirement_not_met`, `not_enough_gold`, `not_enough_items`, `invalid_amount`, `unknown_id`, `blueprint_done`, `stopped_by_user`, `replaced`.
**Come implementato (M24-08)**: la lista chiusa di `Reasons` conta **77** costanti (`tests/core/common/test_reasons.gd`). `SKILL_IN_OTHER_LANE`
(`&"skill_in_other_lane"`, M12) **resta** come costante senza uso reale (nessun codice la restituisce; toglierla cambia il conteggio del test: task di pulizia).

## 3b. Segnali dell'EventBus
| Segnale | Parametri | Emesso da | Quando |
|---|---|---|---|
| ~~`helper_changed`, `helper_completed`, `helper_blocked`~~ | — | — | **tolti in M24-02** |
| `discipline_changed` (M24-03) | `skill_id: StringName, grade: int` | Disciplines | `learn` (1), `train` (nuovo grado), `unlearn` (0); dopo `gold_changed` e, per `unlearn`, dopo `skill_reset` |
| `recipe_learned` (M24-03) | `action_id: StringName` | Disciplines | una Ricetta usata (dopo `bank_changed`) |
| `skill_reset` (M24-03) | `skill_id: StringName` | SkillsSystem | `reset_skill`: XP a 0 (nessun `level_up`) |
| `xp_capped` (M24-03) | `skill_id: StringName, lost: int` | SkillsSystem | XP persa al limite del grado (F-160), dopo `xp_gained`/`level_up` |
| `production_queue_changed` (M24-03) | — | ActionRunner | cambia la coda: `enqueue*`, `cancel`, `move`, fine di un lavoro, `drop_jobs_of` |
| `travel_started` (M24-04) | `next_kind: StringName, skill_id: StringName, duration_ms: int` | CombatEngine | inizia un viaggio (`next_kind` `&"fight"`/`&"node"`, `skill_id` vuoto per `fight`) |
| `node_started` (M24-04) | `skill_id: StringName, action_id: StringName, skipped: bool, duration_ms: int` | CombatEngine | arrivo a un nodo |
| `node_finished` (M24-04) | `skill_id: StringName, action_id: StringName, units: int, reason: StringName` | CombatEngine | fine del nodo: `node_done`, `bank_full` (chiuso prima), `not_learned` (saltato) |
`action_started`/`action_completed`/`action_stopped` restano con le firme di §3; il parametro `lane` vale **`&"queue"`** (`ActionRunner.QUEUE`, la coda) o
**`&"node"`** (`ActionRunner.NODE`, solo `action_completed` di un nodo lavorato con almeno un'unità, emesso dal motore prima di `node_finished`). La corsia
`&"main"` non esiste più. Ordine alla fine di un nodo lavorato: `bank_changed` … → `xp_gained`/`level_up`/`xp_capped` → segnali della maestria →
`action_completed(node, …)` → `node_finished` → `travel_started`.

## 4b. Dati (`core/data/`, M24-02)
```gdscript
# SkillDef: var discipline: bool                     # 29.1
# ActionDef: var discover: bool                      # 29.5
# ItemDef: var recipe_action: StringName; func is_recipe() -> bool      # 29.4 (tolti contract_skill, contract_grade, is_contract)
class_name TrainerGradeDef extends RefCounted        # core/data/defs/trainer_grade_def.gd
var id: StringName; var name: String; var cap: int; var character_level: int
class_name TrainerDef extends RefCounted             # core/data/defs/trainer_def.gd
var skill: StringName; var name: String; var title: String; var description: String; var fed_by: Array[StringName]
class_name AreaNodesDef extends RefCounted           # core/data/defs/area_nodes_def.gd
var area: StringName; var max_level: int; var entries: Array[NodeEntryDef]
class_name NodeEntryDef extends RefCounted           # stesso file o file proprio
var skill: StringName; var weight: int
# GameData (aggiunte; tolte helper_grades, helper_grade, contract_for)
func disciplines(category: StringName = &"") -> Array[StringName]   # skill con discipline true, ordine `order`; &"" = tutte
func trainer_grades() -> Array[TrainerGradeDef]                    # ordine dei gradi (1…n)
func trainer_grade(grade: int) -> TrainerGradeDef                   # 1-based; null fuori intervallo (nessun errore)
func trainer(skill_id: StringName) -> TrainerDef                     # null se assente (nessun errore)
func area_nodes(area_id: StringName) -> AreaNodesDef                 # null se l'area non ha nodi (nessun errore)
func recipe_item_for(action_id: StringName) -> ItemDef               # null se nessuna Ricetta
```
Helper interno di `core/data/` (non API): `DisciplineIndex` (`discipline_index.gd`: carica `disciplines/trainers.json` e `encounters/nodes.json`).
Validatore: `DataValidatorDisciplines` (`data_validator_disciplines.gd`, regole di §29, `STRICT_REAL_DATA`), agganciato a `DataValidator`; `is_known_key`
riconosce `encounters`, `disciplines`, `trainer`, `production` e non più `helper`.

## 5.31 Disciplines (`systems/disciplines/disciplines.gd`, M24-03) — dipendenze: data, events, wallet, bank, skills, character, mastery, actions (solo `drop_jobs_of`), combat (solo `node_skill`)
```gdscript
class_name Disciplines extends RefCounted
const SAVE_KEY := &"disciplines"
func is_discipline(skill_id: StringName) -> bool
func category_of(skill_id: StringName) -> StringName      # &"gathering" | &"artisan" per una disciplina, &"" altrimenti
func is_learned(skill_id: StringName) -> bool             # disciplina appresa, oppure skill nota che non è una disciplina (Incisore); false se sconosciuta
func learned(category: StringName) -> Array[StringName]   # apprese della categoria, ordine `order`
func free_slots(category: StringName) -> int              # disciplines.max_per_category − apprese
func grade(skill_id: StringName) -> int                   # 1…n; 0 se non appresa o non disciplina
func level_cap(skill_id: StringName) -> int               # cap del grado; xp_curve.max_level per le non discipline; 0 se non appresa
func xp_max(skill_id: StringName) -> int                  # F-160
func next_grade_cost(skill_id: StringName) -> int         # F-158 oro del grado successivo (grado 0 → gold(1)); -1 al massimo o se non disciplina
func unlearn_cost(skill_id: StringName) -> int            # F-159; 0 se non appresa
func can_learn(skill_id: StringName) -> CommandResult     # unknown_id, not_a_discipline, already_learned, discipline_slots_full, requirement_not_met, not_enough_gold
func learn(skill_id: StringName) -> CommandResult
func can_train(skill_id: StringName) -> CommandResult     # unknown_id, not_a_discipline, not_learned, max_grade, level_too_low, requirement_not_met, not_enough_gold
func train(skill_id: StringName) -> CommandResult
func can_unlearn(skill_id: StringName) -> CommandResult   # unknown_id, not_a_discipline, not_learned, discipline_busy (combat.node_skill() = skill), not_enough_gold
func unlearn(skill_id: StringName) -> CommandResult
func knows_recipe(action_id: StringName) -> bool          # true per le azioni senza `discover`
func known_recipes() -> Array[StringName]                 # ordine di scoperta
func learn_recipe(item_id: StringName) -> CommandResult   # unknown_id, not_a_recipe, recipe_known, not_enough_items
func new_game() -> void; func to_save() -> Dictionary; func from_save(d: Dictionary) -> void
```
- Comandi atomici (nessun cambio se un controllo fallisce). `learn`: oro `gold(1)` → grado 1 → `discipline_changed(s, 1)`. `train`: oro → grado + 1 →
  `discipline_changed`. `unlearn`: oro F-159 → `actions.drop_jobs_of(s)` → `skills.reset_skill(s)` → `mastery.reset_skill(s)` → grado 0 →
  `discipline_changed(s, 0)`. `learn_recipe`: 1 Ricetta tolta → ricetta nota → `recipe_learned(action)`. Nessuna sorgente di modificatori.
- `new_game`: nessuna appresa, nessuna ricetta. `from_save` tollerante: skill sconosciute o non discipline, grado fuori 1…n → `Log.warn` e scartate; più di
  `max_per_category` in una categoria → restano le prime per `order` (`Log.warn`); ricette sconosciute o senza `discover` → scartate. Dopo il caricamento,
  una disciplina non appresa con XP > 0 viene azzerata (`skills.reset_skill`, `mastery.reset_skill`, `Log.warn`): l'invariante è "XP > 0 ⇒ appresa".
  Nessun segnale in `new_game`/`from_save`.
- **SkillsSystem** (aggiunte): `add_xp(skill_id, base_amount, ctx = null) -> int` (M24-02: tolto `share_pct`; M24-03: limite F-160 con
  `session.disciplines.xp_max`, `xp_capped`; senza `disciplines` nessun limite in più); `func reset_skill(skill_id: StringName) -> void` (M24-03: XP 0,
  sorgente `skill_level:<id>` ricostruita, `skill_reset`). Dipendenza nuova: disciplines (solo `xp_max`).
- **MasterySystem** (aggiunte): `add_for_action(action: ActionDef, cycles: int = 1) -> int` (M24-02, sostituisce `share_pct`: F-10 × `cycles`, F-12 sul
  totale; `cycles ≤ 0` → `Log.error` e 0); `func reset_skill(skill_id: StringName) -> void` (M24-03: xp delle azioni, pool e nodi a 0; sorgenti ricostruite
  in un batch; `mastery_pool_changed(s, 0)`). `MasteryMath.helper_share` tolta.
- **Village** (M24-03): il requisito del livello `n` confronta `village.woodwright_levels[n−1]` con `character.get_level()` (motivo invariato
  `level_too_low`); dipendenza `character` al posto di `skills`.
- **Quests** (M24-03): candidati con il livello 0 per le discipline non apprese (F-135 + §35.8); niente più `helper_completed`; contano `action_completed` di
  ogni `lane` (`node` per la raccolta, `queue` per la produzione).
- **GuideTables** (M24-02): sorgente `trainer_grades` (righe: nome del grado, livello massimo, livello del personaggio, oro di F-158). Tolta `helper_grades`.

## 5.32 Coda di produzione (`systems/actions/action_runner.gd`, M24-03) — dipendenze: data, events, modifiers, bank, armory, skills, mastery, rng, disciplines
**SOSTITUISCE** `05_INTERFACES.md` §5.8 (corsie) e le aggiunte di §5.8b su `ActionRunner`; `ActionMath`, `ActionOutcome`, `ArtisanResolver`,
`EngraverResolver`, `BlueprintCraft` restano (helper puri). Il file può dividersi (`production_job.gd`, interno) per restare sotto le 400 righe. **Come implementato**: interni `production_job.gd` (un lavoro) e
`production_queue_loader.gd` (lettura tollerante della coda), non API.
```gdscript
class_name ActionRunner extends RefCounted
const SAVE_KEY := &"actions"
const QUEUE := &"queue"; const NODE := &"node"            # valori di `lane` nei segnali (§3b)
func enqueue(skill_id: StringName, action_id: StringName, count: int, repeat: bool = false) -> CommandResult
    # in ordine: unknown_id (skill o azione sconosciuta, di un'altra skill, di raccolta o `single`), not_learned, recipe_unknown, level_too_low,
    # invalid_amount (count fuori 1..production.max_job_count; non controllato con repeat), queue_full
func enqueue_blueprint(blueprint_id: StringName, chosen_affix: StringName = &"") -> CommandResult
    # in ordine: not_learned (forging), queue_full, poi BlueprintCraft.can_start senza armory_full (unknown_id, level_too_low, invalid_choice, missing_inputs); nulla si consuma qui
func cancel(index: int) -> CommandResult                  # invalid_amount; testa con progetto già avviato → materiali restituiti (regola di §5.8b)
func move(index: int, new_index: int) -> CommandResult    # invalid_amount; la testa (0) non si sposta e nessun lavoro va in 0
func jobs() -> Array[Dictionary]                          # copie in ordine: {"skill","action","remaining","repeat"} | {"skill","action":"blueprint_craft","blueprint","chosen_affix","duration_ms","consumed"}
func is_running() -> bool                                 # coda non vuota
func current() -> Dictionary                              # {} | jobs()[0] + {"elapsed_ms","interval_ms","waiting": bool}
func get_progress() -> float                              # F-04 della testa
func estimate_ms(index: int = -1) -> int                  # F-157; -1 = tutta la coda
func capacity() -> int                                    # production.queue_slots
func current_interval_ms(action_id: StringName) -> int    # F-03 adesso; 0 con Log.error se sconosciuta
func blueprint_state() -> Dictionary                      # invariata (§5.8b), riferita alla testa
func drop_jobs_of(skill_id: StringName) -> void           # toglie i lavori della skill (testa avviata: restituzione), action_stopped(queue, s, not_learned)
func stop_reasons_log() -> Array[StringName]
func advance(delta_ms: int) -> void
```
- **Tolti**: `start`, `start_blueprint`, `stop`, `is_running(lane)`, `get_lane`, `lanes_available`, `MAIN`. Il combattimento, le Fratture e il Dungeon **non**
  fermano più la coda e la coda non ferma il combattimento (dipendenza `actions (solo stop)` tolta da §5.10, §5.23, §5.29).
- `advance`: la testa esegue cicli (F-157) finché il tempo basta; a fine lavoro `action_stopped(queue, s, motivo)`, `production_queue_changed`, e il successivo
  parte nello stesso passo (`action_started`). Ingredienti mancanti all'inizio di un ciclo → fine del lavoro (`missing_inputs`). Deposito o Armeria pieni →
  `waiting = true`, nessun progresso perso, una `notification_requested` (warning), riprova a ogni `advance`. Un progetto consuma i materiali quando
  diventa testa (`consumed = true`); mancano → esce con `missing_inputs`.
- Save (§6b). `from_save` tollerante: lavoro sconosciuto, di una disciplina non appresa, ricetta non scoperta, `remaining` non valido → `Log.warn` e scartato;
  oltre `queue_slots` → troncata; `elapsed_ms` non valido → 0. Nessun segnale.

## 5.33 Ciclo degli incontri (`systems/encounters/` e `CombatEngine`, M24-04) — dipendenze nuove del motore: skills, mastery, disciplines (solo `is_learned`)
```gdscript
class_name EncounterCycle extends RefCounted              # systems/encounters/encounter_cycle.gd — logica pura
static func next_kind(session: GameSession, area_id: StringName, forced_fight: bool) -> Dictionary   # F-153: {"kind": &"fight"|&"node", "skill": StringName}
static func worked_action(data: GameData, skill_id: StringName, skill_level: int, max_level: int) -> ActionDef   # F-154
static func color(data: GameData, skill_level: int, action_level: int) -> Dictionary                # F-154: {"id": StringName, "xp_pct": float}
static func node_duration_ms(session: GameSession, skill_id: StringName, action: ActionDef) -> int  # F-155
static func expected(p: Dictionary) -> Dictionary
    # F-156: p = {travel_ms, node_chance_pct, fight_ms, skip_ms, node_units, weights: {skill: int}, learned: [skill], node_ms: {skill: int}}
    #        → {"cycle_ms": float, "per_hour": float, "fights_per_hour": float, "nodes_per_hour": {skill: float}, "units_per_hour": {skill: float}}
class_name NodeWork extends RefCounted                   # systems/encounters/node_work.gd — il nodo in corso, tenuto dal motore
var skill_id: StringName; var action_id: StringName; var duration_ms: int; var elapsed_ms: int; var skipped: bool
static func begin(session: GameSession, area_id: StringName, skill_id: StringName) -> NodeWork      # risorsa F-154, durata F-155 o skip_ms
func finish(session: GameSession) -> ActionOutcome      # GatheringResolver.resolve_units con il colore di adesso; ok=false e vuoto se skipped
func to_save() -> Dictionary; static func from_save(raw: Dictionary, data: GameData) -> NodeWork    # null se malformato, azione sconosciuta o di un'altra skill
func color(session: GameSession) -> Dictionary          # (M24-04) colore F-154 se il nodo finisse adesso: {"id", "xp_pct"}; {&"", 0} se skipped (usato da finish e dalla vista)
# GatheringResolver (cambiata): static func resolve_units(session: GameSession, action: ActionDef, units: int, xp_pct: float) -> ActionOutcome   # F-155
#   tolta `resolve` (M24-02 le toglie `helper_grade`, M24-04 la sostituisce); ActionOutcome: var units: int (unità messe)
# CombatEngine (aggiunte)
const STATE_TRAVEL := &"travel"; const STATE_NODE := &"node"
func node_counts() -> Dictionary          # {"worked": int, "skipped": int}, contatori dello slot
func node_skill() -> StringName           # disciplina del nodo in corso (lavorato), &"" altrimenti (M24-03 la scrive come stub che restituisce &"", M24-04 la completa)
# get_state() aggiunge: "travel_ms", "travel_total_ms", "next": {} | {"kind","skill"}, "node": {} | {"skill","action","duration_ms","elapsed_ms","skipped","color","units"}
```
- `is_active()` vale anche in `travel` e `node`; `in_encounter()` invariato. `start(area)`: primo incontro subito (nessun viaggio). In `_cleared()` di un'area
  (non Frattura, non Dungeon): tiro del miniboss come oggi, poi `EncounterCycle.next_kind(forced_fight = Monolito o miniboss in attesa)` → `travel`
  (`travel_started`). A fine viaggio: `fight` → `_begin_encounter()`; `node` → `NodeWork.begin` → `node` (`node_started`). A fine nodo: `finish` → segnali di
  §3b → `travel`. `stop`, morte, apertura di Frattura o Dungeon durante `travel`/`node`: il nodo è perso senza prodotti. Equivalenza obbligatoria
  `advance(1000)` = dieci `advance(100)` anche con viaggi e nodi (il nodo si risolve all'istante della sua fine).
- **Come implementato (M24-04…M24-08)**: lo stato del ciclo sta in `CycleState` (`systems/encounters/cycle_state.gd`, helper interno del motore, non API:
  `begin_travel`, `clear`, `reset`, `worked_skill`, `to_save`, `apply`, `parse` tollerante, `view`); `get_state()` aggiunge esattamente `travel_ms`, `travel_total_ms`
  (0 fuori da `travel`), `next` (`{}` o `{"kind","skill"}`) e `node` (`{}` o `{"skill","action","duration_ms","elapsed_ms","skipped","color","units"}`, `color` = id del
  colore di adesso, `units` = `encounters.node_units` o 0 se saltato). Un nodo che non trova risorsa (`NodeWork.begin` null: disciplina senza azioni) diventa uno
  scontro con `Log.warn`; da M24-08 il validatore lo rifiuta nei dati (`04_DATA_SCHEMA_M24.md` §29.3).
- **Equivalenza con la coda (limite noto, M24-08, Q124)**: l'identità `advance(n)` = passi più piccoli vale per il motore da solo (con viaggi e nodi) e per la
  coda da sola; con **coda e combattimento insieme** no, perché tirano sullo stesso `session.rng` e in ogni `advance` la coda risolve tutti i suoi cicli prima
  del combattimento: l'ordine dei tiri dipende dalla dimensione del blocco (`tests/integration/test_m24_offline_equivalence.gd` controlla solo le grandezze
  dettate dal tempo). È in contrasto con F-41 e `01_GDD.md` §10.10: difetto aperto, non corretto in M24.
- **OfflineSummary** e **SessionSnapshot** (M24-04): campi `nodes_worked: int`, `nodes_skipped: int` (differenza di `node_counts`). La vista del riepilogo li
  mostra (M24-06).

## 5.34 Sessione (M24-02/03)
- `GameSession`: tolti `helpers` e `_PHASE_HELPERS` (M24-02); nuovo `var disciplines: Disciplines` (M24-03), registrato dopo `mastery` e prima di `actions`
  (`from_save`: skills → mastery → disciplines → actions → … → combat). Fasi di `advance`: fratture → azioni (coda) → combattimento → Casa d'Aste.

## 6b. Formato del salvataggio v8 (M24-03; motore M24-04)
`SaveMigrator.CURRENT_VERSION` = **8**; v5, v6, v7 si migrano in catena; v1-v4 restano `version_unsupported`. Moduli cambiati:
```json
"disciplines": {"learned": {"forestry": 2, "quarrying": 1, "forging": 3, "woodwright": 1}, "recipes": ["brew_tonic_1"]},
"actions": {"jobs": [{"skill": "forging", "action": "smelt_emberbronze", "remaining": 30, "repeat": false},
                     {"skill": "forging", "action": "blueprint_craft", "blueprint": "blueprint_sword_2", "chosen_affix": "", "duration_ms": 600000, "consumed": false}],
            "elapsed_ms": 1200},
"combat": {"state": "travel", "travel_ms": 1800, "next": {"kind": "node", "skill": "quarrying"}, "node": {}, "nodes": {"worked": 12, "skipped": 9}, "...": "come v7"},
"combat (nel nodo)": {"state": "node", "travel_ms": 0, "next": {}, "node": {"skill": "quarrying", "action": "mine_ironvein", "elapsed_ms": 4000, "duration_ms": 10800, "skipped": false}}
```
- `repeat: true` ⇒ `remaining` ignorato (scritto 0). `elapsed_ms` è della testa. `helpers` non esiste più.
- **Motore** (`CombatSave`, M24-04), tollerante: `between` in un'area (non Frattura, non Dungeon) → `travel` con `travel_ms` pieno e `next = fight`
  (nessun tiro); `next`/`node` malformati o con id sconosciuti → `travel` pieno verso `fight`; `nodes` assente → 0. Un motore `idle` scrive `travel_ms` 0,
  `next` `{}`, `node` `{}` (save → load → save identico).
- **Migrazione v7 → v8** (`core/save/migrations/migration_7_to_8.gd`, M24-03; legge `res://data/skills/skills.json`, `res://data/config/balance.json`,
  `res://data/disciplines/trainers.json` come `migration_6_to_7.gd`), tutto in `modules`:
  1. `helpers` tolto.
  2. Pile dei 12 Contratti (id storici `contract_{forestry,quarrying,angling}_{apprentice,journeyman,expert,master}`, costante nella migrazione) tolte da
     `bank.stacks`, `combat.loot.stacks`, dalle `stacks` delle borse di `fractures` e `dungeon` (corsa e attesa) e da `discoveries.items`.
  3. `disciplines.learned`: per `gathering` e `artisan` al più 2 skill con `discipline: true` e XP > 0: prima quella della ricetta o del progetto in corso
     (`actions.lanes.main`, solo `artisan`), poi per XP decrescente, a parità per `order`; grado = il più piccolo con `cap ≥` livello (F-158).
     `recipes` = `[]`.
  4. Discipline non apprese: voce di `skills` tolta (XP 0) e voce di `mastery` tolta. `riftbinding` invariato.
  5. `actions`: da `{"lanes": {"main": …}}` a `{"jobs", "elapsed_ms"}`: raccolta → nessun lavoro; ricetta di una disciplina appresa → `{skill, action,
     remaining: 0, repeat: true}` con il suo `elapsed_ms`; progetto → lavoro progetto con `consumed: true`, `duration_ms` ed `elapsed_ms` salvati.
  6. `combat` invariato (ci pensa la regola tollerante sopra).

## 7.o UI di M24 (nessuno stato di gioco nella UI, solo letture e comandi; `01_GDD_M24.md` §35.11; M24-06)
```gdscript
# ui/pages/combat/travel_map.gd — class_name TravelMap extends Control
func refresh(state: Dictionary, data: GameData, disciplines: Object) -> void   # state = combat.get_state(); posizione dell'icona = 1 − travel_ms / travel_total_ms
# nodi per i test: TravelPath, TravelIcon, TravelTarget (icona: spade per fight, icona della skill per node; grigia con lucchetto se !disciplines.is_learned)
# ui/pages/combat/node_panel.gd — class_name NodePanel extends PanelContainer: refresh(state, data); risorsa, colore (testo + colore UiStyle), barra elapsed/duration, unità; skipped → motivo
# ui/pages/trainers/trainers_page.gd (rotta &"trainers", `trainer_row.gd`, `trainers_texts.gd`)
# due riquadri GatheringBox/ArtisanBox con "n/2 posti"; una TrainerRow per disciplina (data.disciplines(categoria)): Maestro (data.trainer), grado e limite, livello,
# costo e requisiti (next_grade_cost, can_learn/can_train), fed_by; pulsanti LearnButton, TrainButton, UnlearnButton (ConfirmDialog con unlearn_cost e l'elenco della perdita);
# rifiuti in MessageLabel. Ridisegno su discipline_changed, gold_changed, level_up, character_level_up, skill_reset.
# ui/pages/skill/production_queue_panel.gd — class_name ProductionQueuePanel: righe di actions.jobs() (QueueRow_<i>), barra della testa (get_progress), stima (estimate_ms),
# CancelButton, UpButton, DownButton; "In attesa: Deposito pieno" se current().waiting. Ridisegno su production_queue_changed, action_completed, bank_changed.
```
- **SkillPage**: raccolta in sola lettura (risorse, livello, colore previsto al livello attuale con `EncounterCycle.color`, maestria e traguardi, aree con nodi
  da `data.area_nodes`), pannello dell'attrezzo; produzione e Incisore: `RecipeCard` con "Metti in coda" (SpinBox, scorciatoie 1/10/100, Ripeti →
  `actions.enqueue`), lucchetto "Da scoprire" se `!disciplines.knows_recipe`; `BlueprintSection` usa `enqueue_blueprint`; `ProductionQueuePanel` in alto.
  Tolte la riga Aiutante e i pulsanti Avvia/Ferma della raccolta.
- **Sidebar**: voci delle sole discipline apprese (`disciplines.is_learned`), "Maestri" (rotta `trainers`) e "Incisore" nel gruppo del Villaggio; pallino
  attivo su Combattimento con `combat.is_active()` e sulla disciplina della testa della coda. **VillagePage**: pulsante "Maestri di mestiere" →
  `page_requested(&"trainers")`; testo del requisito "Richiede livello n". **BankItemPanel**: "Impara" per le Ricette (`disciplines.learn_recipe`); niente "Assumi".
- **Toast**: `discipline_changed`, `recipe_learned`, `xp_capped` (al più uno per disciplina ogni `UiStyle` intervallo, solo presentazione), avviso di
  `node_finished(bank_full)`. **OfflineSummaryView**: nodi lavorati e saltati.
- **File interni di M24-06** (non API, solo presentazione): `ui/pages/skill/enqueue_controls.gd` (quantità e "Metti in coda"), `gathering_info.gd` (pagina di
  raccolta in sola lettura), `node_color_preview.gd` (colore previsto con `EncounterCycle.color`), `queue_texts.gd`; la rotta `trainers` ha la sua pagina della Guida
  `guide_disciplines` (`help_for: ["trainers"]`, rotta aggiunta a `DataValidatorGuide.ROUTES` da M24-08: lo chiede `test_guide_real_data.gd`); il pulsante "?"
  nella pagina dei Maestri non è ancora agganciato (`HelpButton.attach`, ritocco UI futuro).
- Smoke test (uno per pagina): `tests/ui/test_trainers_page_smoke.gd`, `tests/ui/test_travel_map_smoke.gd` (stato finto), `tests/ui/test_skill_page_smoke.gd`
  aggiornato. Testi in `*_texts.gd`.

## 8b. Strumento `tools/sim_encounters.gd` (M24-07, non è un'API di gioco)
`-s tools/sim_encounters.gd -- hours=12 area=<id> level=<n> learned=<skill,skill,…> seed=1234 nodes=1|0`: sessione vera con `TestFactory`, personaggio al
livello con il set del grado (come `sim_combat.gd`), discipline apprese al livello della risorsa dell'area. Stampa scontri/h, uccisioni/h, nodi lavorati e
saltati per disciplina, unità/h, XP/h per disciplina, `E_F` misurato, valori di F-156 e scarto; confronta con le soglie di F-156; `nodes=0` imposta
`node_chance_pct` 0 e `travel_ms` = `combat.respawn_ms` (riferimento "prima di M24"). Esce 0 se tutte le soglie passano, 1 altrimenti. Non scrive file.
