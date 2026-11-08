# 05. Interfacce tra moduli

Questo è il **contratto**: firme pubbliche, segnali, formato del salvataggio. È definito prima dell'implementazione
perché i task possano procedere in parallelo. **Lo modifica solo il Reviewer/Integrator** (vedi `08_TEAM.md`); chi ha
bisogno di un cambio apre una richiesta nel report del task e si ferma.

Regole generali:
- Tutto tipizzato. `StringName` (`&"..."`) per gli id, `int` per ms, quantità, oro, XP.
- I metodi pubblici non iniziano con `_`. Quello che non è qui è privato e nessun altro modulo lo usa.
- I **comandi** restituiscono `CommandResult` e non cambiano nulla se falliscono. Le **letture** non cambiano mai lo stato.
- I segnali di gioco passano **solo** dall'`EventBus` (classe `GameEvents`); i sistemi emettono su `session.events`.
- Ogni sistema della sessione ha: `const SAVE_KEY: StringName`, `func new_game() -> void`,
  `func to_save() -> Dictionary`, `func from_save(d: Dictionary) -> void` (contratto "SaveParticipant").
  In `from_save` i numeri letti dal JSON arrivano come `float`: vanno convertiti con `int()`.
- Le "Dipendenze" di ogni sistema sono gli unici altri moduli che può usare.

## 1. Tipi comuni (`res://core/common/`)

```gdscript
class_name CommandResult extends RefCounted
var ok: bool
var reason: StringName            # &"" se ok
static func success() -> CommandResult
static func fail(reason: StringName) -> CommandResult
```

```gdscript
class_name Reasons extends RefCounted   # solo costanti; elenco chiuso
const NO_SESSION := &"no_session"
const SLOT_NOT_SELECTED := &"slot_not_selected"
const UNKNOWN_ID := &"unknown_id"
const INVALID_AMOUNT := &"invalid_amount"
const LEVEL_TOO_LOW := &"level_too_low"
const REQUIREMENT_NOT_MET := &"requirement_not_met"
const MISSING_INPUTS := &"missing_inputs"
const BANK_FULL := &"bank_full"
const NOT_ENOUGH_ITEMS := &"not_enough_items"
const NOT_ENOUGH_GOLD := &"not_enough_gold"
const MAX_PURCHASES := &"max_purchases"
const ITEM_LOCKED := &"item_locked"
const NOT_SELLABLE := &"not_sellable"
const NOT_EQUIPPABLE := &"not_equippable"
const NOT_FOOD := &"not_food"
const SLOT_EMPTY := &"slot_empty"
const COMBAT_ACTIVE := &"combat_active"
const LANE_UNAVAILABLE := &"lane_unavailable"
const SKILL_IN_OTHER_LANE := &"skill_in_other_lane"
const SOCKET_LOCKED := &"socket_locked"
const SOCKET_OCCUPIED := &"socket_occupied"
const POOL_INSUFFICIENT := &"pool_insufficient"
const NODE_PREREQ_MISSING := &"node_prereq_missing"
const NODE_OWNED := &"node_owned"
const MASTERY_MAX := &"mastery_max"
const NO_FOOD := &"no_food"
const PLAYER_DIED := &"player_died"
const STOPPED_BY_USER := &"stopped_by_user"
const REPLACED := &"replaced"               # fermata perché è partita un'altra attività
const IO_ERROR := &"io_error"
const CORRUPTED := &"corrupted"
const VERSION_UNSUPPORTED := &"version_unsupported"
const SLOT_ACTIVE := &"slot_active"
const INVALID_NAME := &"invalid_name"
const NOT_RUNNING := &"not_running"
const ARMORY_FULL := &"armory_full"         # M4: Armeria piena (01_GDD §21)
const NOT_STACKABLE := &"not_stackable"     # M4: equipment/tool rifiutati dalla bank
const ITEM_EQUIPPED := &"item_equipped"     # M4: pezzo indossato (non si vende né si smantella)
const SLOT_LOCKED := &"slot_locked"         # M6: slot di tratto/abilità non ancora aperto
const UPGRADE_MAX := &"upgrade_max"         # M7: raffinazione già a +9
const ITEM_UNIQUE := &"item_unique"         # M10: attrezzo unico (non si vende, non si smantella, non si toglie)
const NOT_A_TOOL := &"not_a_tool"           # M10: il pezzo non è un attrezzo unico (raffinazione F-94)
const INVALID_CHOICE := &"invalid_choice"   # M10: affisso scelto non ammesso o livello del Fabbro < blueprint.choose_affix_level (F-92)
const BLUEPRINT_DONE := &"blueprint_done"   # M10: motivo di stop di fine progetto (action_stopped)
```
Le costanti nuove le aggiunge il primo task che le usa (M4-01 per quelle di M4), con il test di `reasons.gd`.

## 2. Autoload

### `Log` (`core/autoload/log.gd`)
```gdscript
enum Level { DEBUG, INFO, WARN, ERROR }
var level: Level = Level.INFO
func debug(category: String, message: String) -> void
func info(category: String, message: String) -> void
func warn(category: String, message: String) -> void
func error(category: String, message: String) -> void   # anche push_error
```

### `EventBus` (`core/autoload/event_bus.gd`, `class_name GameEvents extends Node`) — vedi §3.

### `DataRegistry` (`core/autoload/data_registry.gd`)
```gdscript
var data: GameData                 # caricato in _ready() da res://data
func reload() -> bool              # true se valido
```

### `GameClock` (`core/autoload/game_clock.gd`)
```gdscript
signal ticked(delta_ms: int)       # delta_ms = tick_ms; più emissioni per frame se serve (max max_catchup_ms)
var time_source: Callable          # () -> int, ms Unix; default Time.get_unix_time_from_system() * 1000
func set_paused(paused: bool) -> void
func is_paused() -> bool
func now_unix_ms() -> int
func configure(tick_ms: int, max_catchup_ms: int) -> void   # chiamata da Game con i valori di balance.json
```

### `SaveService` (`core/autoload/save_service.gd`, `class_name SaveStore extends Node`)
```gdscript
var base_dir: String = "user://saves"     # i test lo cambiano in PreRun.save_dir() (§8)
var last_error: StringName
func configure(slot_count: int) -> void
func slot_path(slot: int) -> String       # base_dir + "/slot_%d.json"
func slot_exists(slot: int) -> bool
func read_slot(slot: int) -> Dictionary   # già migrato; {} se fallisce (last_error = corrupted | version_unsupported | io_error)
func write_slot(slot: int, payload: Dictionary) -> CommandResult   # atomica: .tmp, .bak, rename
func delete_slot(slot: int) -> CommandResult
func read_slot_info(slot: int) -> SlotInfo
func list_slots() -> Array[SlotInfo]      # slot da 1 a slot_count
```
`SaveStore` non conosce `GameSession`: legge e scrive dizionari.

Comportamenti di `SaveStore` (M1-06):
- `slot_count` arriva da `slots.count` di `balance.json`, passato da chi usa lo store con `configure()`; prima di
  `configure` non esistono slot validi (`list_slots()` è vuoto).
- Slot fuori da 1..`slot_count`: `write_slot`/`delete_slot` falliscono con `io_error`; `read_slot` restituisce `{}` con
  `last_error = io_error`; `slot_exists` è falso.
- Slot vuoto (né principale né `.bak`): `read_slot` → `{}` con `io_error`; `read_slot_info` → `state = empty`.
  Se esiste solo il `.bak`, `slot_exists` è vero e la lettura usa il `.bak`.
- File valido = JSON, radice dizionario, `format_version` numerico. Principale non valido o assente → `.bak`;
  entrambi non validi → `corrupted`.
- `format_version` maggiore di `CURRENT_VERSION` → `version_unsupported` (`state = unsupported`), **senza** ripiegare
  sul `.bak` (si perderebbe il progresso più nuovo). Versione minore senza catena di migrazioni completa →
  `version_unsupported`.
- `delete_slot` su uno slot vuoto riesce; cancella principale, `.bak` e `.tmp`.
- `write_slot` non valida il contenuto (`format_version` lo scrive `GameSession.to_save`). Solo `write_slot` e
  `delete_slot` toccano il disco.
- Errori di I/O con `Log.warn`; errori di programmazione con `assert`.

```gdscript
class_name SlotInfo extends RefCounted        # core/save/slot_info.gd
var slot: int
var state: StringName       # &"empty", &"ok", &"corrupted", &"unsupported"
var player_name: String
var saved_at_unix_ms: int
var play_time_ms: int
var total_level: int

class_name SaveMigrator extends RefCounted    # core/save/save_migrator.gd
const CURRENT_VERSION: int = 3                 # 3 da M10 (riforma del bottino); nessuna migrazione 1 → 2 né 2 → 3: un save v1 o v2 è version_unsupported (nessun giocatore reale ancora)
static func can_load(d: Dictionary) -> bool          # format_version <= CURRENT_VERSION
static func migrate(d: Dictionary) -> Dictionary     # applica migrations/migration_<a>_to_<b>.gd in catena
static func migrate_chain(d: Dictionary, target_version: int, step_for: Callable) -> Dictionary
    # usata da migrate() con CURRENT_VERSION e i file di migrations/, dai test con passi finti;
    # step_for(from_version) -> Callable da from_version a from_version + 1 (non valida se manca);
    # copia profonda con format_version = target_version, {} se un passo manca o fallisce o d è più nuovo

class_name SaveCodec extends RefCounted       # core/save/save_codec.gd
static func encode(d: Dictionary) -> String          # JSON con indentazione "\t", chiavi ordinate
static func decode(text: String) -> Dictionary       # {} se non valido o non dizionario
```

### `Game` (`core/autoload/game.gd`)
```gdscript
const NAME_MIN_LENGTH_KEY: String = "player_name.min_length"   # chiavi di balance.json del limite del nome,
const NAME_MAX_LENGTH_KEY: String = "player_name.max_length"   # lette anche da SlotTexts
var session: GameSession = null
var active_slot: int = -1
var state: StringName = &"menu"          # &"menu", &"loading", &"offline", &"playing"
var last_offline_summary: OfflineSummary = null
func list_slots() -> Array[SlotInfo]
func new_game(slot: int, player_name: String) -> CommandResult
    # nome dopo strip lungo player_name.min_length..max_length (invalid_name); crea sessione, new_game(), salva, avvia autosave, state playing
func continue_game(slot: int) -> CommandResult   # coroutine (M9-03): chiamare con `await`; ritorna dopo l offline
    # legge, from_save, rebuild_modifiers, poi offline (asincrono: state offline fino alla fine), poi salva e playing
func save_now() -> CommandResult          # slot_not_selected se session == null
func end_session(save: bool = true) -> void   # ferma autosave, salva se richiesto, session.free(), state menu
func delete_slot(slot: int) -> CommandResult  # slot_active se è lo slot della sessione
```
`Game` emette `session_started`/`session_ended` sull'`EventBus`, collega `GameClock.ticked` a `session.advance` in
`playing`, salva su `NOTIFICATION_WM_CLOSE_REQUEST`.

Comportamenti di `Game` (M1-11):
- `_ready`: mette in pausa `GameClock`; con dati validi chiama `GameClock.configure(tick_ms, max_catchup_ms)`,
  `SaveService.configure(slots.count)` e legge `autosave_interval_ms`, `player_name.min_length` e
  `player_name.max_length` (tutto da `balance.json`). Dati non validi →
  `Log.error` e nessuna configurazione: ogni slot è fuori intervallo (`io_error`). Non esiste un motivo `data_invalid`:
  la UI controlla `DataRegistry.data.is_valid()` prima di offrire Nuova partita/Continua.
- Clock in pausa in `menu`; si avvia all'ingresso in `playing` e torna in pausa in `end_session` (anche in `_exit_tree`).
- Errori di avvio, nell'ordine: `new_game` → `invalid_name` (lunghezza del nome dopo `strip_edges` fuori da
  `player_name.min_length`..`max_length`, oggi 1-24), poi entrambi →
  `slot_active` se una sessione è aperta (il chiamante chiude prima con `end_session`), `io_error` se lo slot è fuori da
  1..`slots.count`. `continue_game` → `SaveService.last_error` (`io_error` per slot vuoto, `corrupted`,
  `version_unsupported`) oppure l'errore di `from_save`. In ogni errore: nessuna sessione, `state = menu`, nulla scritto.
- `new_game`: sovrascrive lo slot senza chiedere (la conferma è della UI); `created_at_unix_ms = GameClock.now_unix_ms()`;
  salva subito. Se il primo salvataggio fallisce (`save_failed` già emesso) la sessione è scartata, `state = menu` e
  restituisce l'errore dello store.
- `continue_game`: lo slot è quello del nome del file (prevale su `slot` dell'intestazione); dopo il caricamento salva;
  se quel salvataggio fallisce → `Log.warn` + `save_failed`, la partita parte lo stesso e l'autosave ritenta.
- Seme nuovo: `(Time.get_ticks_usec() ^ (slot << 48)) & (2^53 - 1)`, intero non negativo esatto in JSON;
  `from_save` lo sostituisce con quello salvato.
- Autosave sul tempo di `GameClock` (non un `Timer`): ogni `ticked` in `playing` fa `session.advance(delta_ms)` e
  somma `delta_ms`; a `autosave_interval_ms` raggiunti → `save_now()`. Ogni `save_now` azzera il contatore. Nessuna
  connessione a `ticked` fuori da `playing`.
- `session_started(slot, is_new)` è l'ultimo passo dell'avvio: sessione pronta, già salvata, clock avviato,
  `state = playing`. `session_ended(slot)` dopo lo stop del clock e il salvataggio, prima di liberare la sessione.
- La sessione è figlia di `Game` nell'albero (`add_child`) e viene liberata con `free()` in `end_session`.
- `save_now` senza sessione → `slot_not_selected` senza segnali; `end_session` senza sessione non fa nulla.

### `Tooltips` (`ui/components/tooltip/tooltip_manager.gd`)
```gdscript
var data: GameData = null                 # null = DataRegistry.data; i test passano i dati delle fixture
func show_item(item: ItemDef, count: int, global_pos: Vector2) -> void   # item null: push_error e tooltip nascosto
func show_text(title: String, body: String, global_pos: Vector2) -> void
func hide_tooltip() -> void
```

## 3. Segnali dell'EventBus (`GameEvents`)

| Segnale | Parametri | Emesso da | Quando |
|---|---|---|---|
| `session_started` | `slot: int, is_new: bool` | Game | sessione pronta (dopo l'offline) |
| `session_ended` | `slot: int` | Game | prima di liberare la sessione |
| `action_started` | `lane: StringName, skill_id: StringName, action_id: StringName` | ActionRunner | avvio |
| `action_completed` | `lane: StringName, skill_id: StringName, action_id: StringName, outputs: Dictionary` | ActionRunner | fine di un ciclo riuscito (`outputs`: `{item_id: qty}`) |
| `action_stopped` | `lane: StringName, skill_id: StringName, reason: StringName` | ActionRunner | stop per qualunque motivo |
| `xp_gained` | `skill_id: StringName, amount: int` | SkillsSystem | ogni guadagno > 0 |
| `level_up` | `skill_id: StringName, new_level: int` | SkillsSystem | un evento per livello |
| `mastery_xp_gained` | `skill_id: StringName, action_id: StringName, amount: int` | MasterySystem | |
| `mastery_level_up` | `skill_id: StringName, action_id: StringName, new_level: int` | MasterySystem | |
| `mastery_pool_changed` | `skill_id: StringName, pool_xp: int` | MasterySystem | |
| `mastery_node_purchased` | `skill_id: StringName, node_id: StringName` | MasterySystem | |
| `bank_changed` | `item_id: StringName, new_count: int, delta: int` | Bank | ogni variazione; `delta` = variazione con segno di quella singola operazione (`new_count` dopo − prima). La Bank (M1-07) deve emetterlo così; la UI non ricava il delta da copie delle quantità |
| `bank_capacity_changed` | `used: int, capacity: int` | Bank | variano caselle usate o capienza |
| `bank_rejected` | `item_id: StringName, qty: int` | Bank | `add` fallita per bank piena |
| `gold_changed` | `new_amount: int, delta: int` | Wallet | |
| `equipment_changed` | `slot_id: StringName, uid: int` | Equipment | M4: `uid` 0 = slot vuoto (prima: `item_id`; il segnale non si usa più per cibo e stance) |
| `food_changed` | `item_id: StringName` | Equipment | M4: cibo scelto (`&""` = nessuno) |
| `character_xp_gained` | `amount: int` | CharacterSystem | M4: ogni guadagno > 0 |
| `character_level_up` | `new_level: int` | CharacterSystem | M4: un evento per livello |
| `traits_changed` | — | Loadout | M6: tratti o abilità equipaggiati cambiati |
| `armory_changed` | `uid: int, change: StringName` | Armory | M4: `change` = `&"added"`, `&"removed"`, `&"updated"` (blocco, raffinazione, indossato) |
| `armory_capacity_changed` | `used: int, capacity: int` | Armory | M4 |
| `armory_rejected` | `base_id: StringName, qty: int` | Armory | M4: istanze non create per Armeria piena |
| `item_upgraded` | `uid: int, success: bool, new_level: int` | Armory | M7: dopo `armory_changed(uid, updated)`; M10: anche per gli attrezzi (`success` sempre `true`) |
| `item_salvaged` | `uid: int, base_id: StringName, auto: bool` | Armory | M7: `auto` = smantellato dal filtro o dall'Armeria piena (`add_drop`); l'uid non è mai nell'Armeria |
| `blueprint_crafted` | `blueprint_id: StringName, uid: int` | ActionRunner | M10: fine di un progetto, dopo `armory_changed(uid, added)` e prima di `action_completed`/`action_stopped(blueprint_done)` |
| `modifiers_changed` | — | ModifierService | una volta per modifica o per batch |
| `combat_started` | `area_id: StringName` | CombatEngine | M5 (prima anche `monster_id`) |
| `combat_stopped` | `reason: StringName` | CombatEngine | |
| `encounter_started` | `monster_ids: Array[StringName]` | CombatEngine | M5: in ordine di posizione (sostituisce `monster_spawned`) |
| `encounter_cleared` | — | CombatEngine | M5: tutti i nemici morti, inizia `BETWEEN` |
| `combat_hit` | `attacker: int, target: int, hit: bool, damage: int, blocked: bool` | CombatEngine | M5: `-1` = giocatore, `0..n-1` = posizione del nemico |
| `player_hp_changed` | `hp: int, max_hp: int` | CombatEngine | |
| `monster_hp_changed` | `index: int, hp: int, max_hp: int` | CombatEngine | M5 |
| `monster_killed` | `index: int, monster_id: StringName` | CombatEngine | M5 |
| `ability_used` | `ability_id: StringName, targets: Array[int]` | CombatEngine | M6 |
| `trait_triggered` | `trait_id: StringName` | CombatEngine (via `EffectSet`) | M6: un effetto del tratto è scattato (feedback); emesso a fine aggancio |
| `rift_stone_appeared` | `stone_id: StringName` | CombatEngine | M7 |
| `player_died` | — | CombatEngine | |
| `food_eaten` | `item_id: StringName, healed: int` | AutoEat | |
| `loot_bag_changed` | `used: int, capacity: int` | LootBag | |
| `loot_lost` | `item_id: StringName, qty: int` | LootBag | borsa piena o morte |
| `shop_purchased` | `entry_id: StringName, count: int` | Shop | `count` = acquisti totali della voce |
| `item_sold` | `item_id: StringName, qty: int, gold: int` | Shop | |
| `infusion_socketed` | `socket_index: int, item_id: StringName` | RiftAltar | |
| `infusion_removed` | `socket_index: int, item_id: StringName` | RiftAltar | |
| `offline_started` | `elapsed_ms: int, capped: bool` | OfflineSimulator | |
| `offline_progress` | `done_ms: int, total_ms: int` | OfflineSimulator | dopo ogni blocco |
| `offline_completed` | `summary: OfflineSummary` | OfflineSimulator | |
| `save_completed` | `slot: int` | Game | |
| `save_failed` | `slot: int, reason: StringName` | Game | |
| `notification_requested` | `text: String, kind: StringName` | qualunque sistema | `kind` = `&"info"`, `&"success"`, `&"warning"` |
| `hint_triggered` (M9) | `hint_id: StringName` | HintsSystem | |
| `fracture_opened` (M12) | `fracture_id: StringName, duration_ms: int` | FractureSystem | |
| `fracture_closed` (M12) | `fracture_id: StringName` | FractureSystem | |

I segnali segnati M4…M7 li aggiunge (o cambia) in `core/autoload/event_bus.gd` e in `tests/core/autoload/test_event_bus.gd`
il task che li emette per primo (ownership estesa alle sole righe del segnale). Fino ad allora `event_bus.gd` ha le firme
precedenti: `monster_spawned` e le vecchie firme di `combat_started`, `combat_hit`, `monster_hp_changed`,
`monster_killed`, `equipment_changed` spariscono con M4-06 (equipaggiamento) e M5-03 (motore). Fatto: M5-03 ha tolto
`monster_spawned` (sostituito da `encounter_started`) e scritto le firme di M5 in `event_bus.gd`.

## 4. Dati (`res://core/data/`)

```gdscript
class_name GameData extends RefCounted
static func load_from_dirs(content_root: String = "res://data", config_root: String = "res://data/config") -> GameData
var errors: PackedStringArray
var stats: StatRegistry
func is_valid() -> bool
func balance_value(path: String) -> Variant          # es. "combat.respawn_ms"; chiave mancante → push_error, null
func xp_table() -> XpTable                            # da xp_curve
func mastery_table() -> XpTable                       # da mastery_curve
func item(id: StringName) -> ItemDef                  # null + push_error se manca
func has_item(id: StringName) -> bool
func items() -> Array[ItemDef]
func skill(id: StringName) -> SkillDef
func skills() -> Array[SkillDef]                      # ordinate per order
func skills_by_category(category: StringName) -> Array[SkillDef]
func action(id: StringName) -> ActionDef
func actions_for_skill(skill_id: StringName) -> Array[ActionDef]   # ordinate per level, poi id
func mastery_actions_for_skill(skill_id: StringName) -> Array[ActionDef]   # solo mastery == true
func mastery_node(id: StringName) -> MasteryNodeDef
func mastery_nodes(skill_id: StringName) -> Array[MasteryNodeDef]
func area(id: StringName) -> AreaDef
func areas() -> Array[AreaDef]                        # ordinate per order
func monster(id: StringName) -> MonsterDef
func has_area(id: StringName) -> bool                 # M6-01: senza push_error (save tolleranti)
func has_monster(id: StringName) -> bool              # M6-01: senza push_error
func shop_entry(id: StringName) -> ShopEntryDef
func shop_entries() -> Array[ShopEntryDef]
func character_xp_table() -> XpTable                  # M4-01: da character_curve (F-71)
func character_class(id: StringName) -> ClassDef      # M4-01; null + Log.error se manca
func classes() -> Array[ClassDef]                     # M4-01; ordinate per order
func affix(id: StringName) -> AffixDef                # M4-01
func affixes_for_slot(slot: StringName) -> Array[AffixDef]   # M4-01; ordine del file
func rift_stone_for_area(area_id: StringName) -> RiftStoneDef   # M7
func blueprints() -> Array[ItemDef]                   # M10: tutti i progetti, ordinati per grado e sort_order
func blueprint_for_base(base_id: StringName) -> ItemDef   # M10: il progetto della base (uno solo); null senza push_error se non c'è (anelli, amuleti, attrezzi)
func unique_tool(slot: StringName) -> ItemDef         # M10: l'attrezzo unico dello slot tool_*; null + Log.error se manca
func hints() -> Array[HintDef]                        # M9-04, nell ordine del file
func hint(id: StringName) -> HintDef                  # M9-04; null se sconosciuto
func fractures() -> Array[FractureDef]                # M12: lo aggiunge il task delle Fratture (non esiste in M1-04)
const LOG_CATEGORY: String = "data"
const BALANCE_FILE: String = "balance.json"           # in config_root
const STATS_FILE: String = "stats.json"               # in config_root
const CONTENT_FILES: Dictionary[String, String]       # sezione a file unico -> percorso relativo a content_root
const CONTENT_DIRS: Dictionary[String, String]        # sezione a cartella ("items", "actions", "mastery") -> cartella

class_name JsonLoader extends RefCounted
static func load_file(path: String, errors: PackedStringArray) -> Variant      # null se manca o non valido
static func load_dir(dir: String, errors: PackedStringArray) -> Array[Dictionary]   # tutti i .json, ordine alfabetico
static func list_json_files(dir: String, errors: PackedStringArray) -> PackedStringArray
    # percorsi dei .json direttamente in dir, ordine alfabetico (GameData ne ricava il nome del file); load_dir usa questa
    # nessun push_error: ogni problema (file o cartella mancante, JSON rotto, top level non oggetto) va in errors con il percorso

class_name DataValidator extends RefCounted
const REQUIRED_BALANCE_KEYS: PackedStringArray       # le chiavi di 02_FORMULAS.md §9 già in uso (non quelle segnate M6 e oltre)
static func validate(raw: Dictionary, errors: PackedStringArray) -> void
    # raw = {"balance", "stats", "skills", "items", "actions", "mastery", "areas", "monsters", "shop",
    #        "classes" (cartella, M4-01), "affixes" (file unico, M4-01)}
    # ogni sezione: {percorso del file: oggetto di testa del file} (sezioni a file unico: esattamente una voce, altrimenti
    # errore; cartelle: una voce per .json, anche zero). Il percorso compare nei messaggi e dà il nome del file con cui
    # lo schema confronta `skill` (azioni, maestria) e `category` (oggetti)
    # messaggi: "<percorso>: <tipo> '<id>': <messaggio>" (`<tipo> #<indice>` se la voce non ha un id usabile)
const SKILL_CATEGORIES: PackedStringArray            # usata anche da GameData.skills_by_category
static func lookup(d: Dictionary, path: String) -> Variant       # valore a un percorso puntato, null se manca un pezzo
# helper usati da DataValidatorRules/DataValidatorItems (non API per gli altri moduli):
static func entries(v: DataValidatorRules, content: Dictionary, list_key: String, extra: PackedStringArray = []) -> Array[Dictionary]
static func icon(v: DataValidatorRules, e: Dictionary, dir: String) -> void
static func file_skill(v: DataValidatorRules, content: Dictionary, path: String, categories: PackedStringArray) -> String
```
- `GameData.load_from_dirs`: con un errore qualsiasi (caricamento o validazione) nessuna Def viene costruita,
  `is_valid()` è falso e ogni lettura per id restituisce `null` + `Log.error`. `balance_value` restituisce i numeri come
  `float` (JSON) e copie di oggetti e array.
- `DataRegistry.reload()` sostituisce `data` anche se non valido (la UI mostra `data.errors`), logga ogni errore con
  `Log.warn` e una riga `Log.error`.
- `DataValidatorRules` (`data_validator_rules.gd`: strumenti per campi, tipi, intervalli, riferimenti, modificatori,
  mappe dei livelli con la chiave riservata `character`; regole di maestria), `DataValidatorItems`
  (`data_validator_items.gd`: regole di oggetti, azioni, shop) e `DataValidatorClasses` (`data_validator_classes.gd`,
  M4-01: regole di aree, gruppi, mostri, classi, assetti, affissi e delle chiavi di M4 di `balance.json`) sono classi
  **interne** di `DataValidator`, non API per gli altri moduli. I limiti di formato dello schema (regex degli id,
  `cost_pct` ≤ 50, `pos` 0..5, max 8 drop, `name` delle stat ≤ 40, `grade` 1..8, `min_ilvl` ≤ 99, numero di affissi
  per rarità ≤ 6, `combat.max_pack_size` ≤ 6) sono costanti di queste classi; i limiti che dipendono dal bilanciamento
  si leggono dai dati (`xp_curve.max_level`, `mastery_curve.max_level`, `character_curve.max_level`,
  `action.min_interval_ms`, `combat.min_attack_interval_ms`, `combat.max_pack_size`, `max` della stat
  `damage_reduction`).
- `tools/validate_data.gd [-- <content_root> [<config_root>]]`: stampa gli errori ed esce con 1 se non validi; carica
  `GameData` per percorso (in uno script `-s` l'autoload `Log` non è risolto in compilazione).

Def (`res://core/data/defs/`, tutte `RefCounted`, campi in sola lettura per convenzione, `static func from_dict(d) -> X`):

- `from_dict` converte solo i tipi (numeri in `int` dove il campo è `int`, id in `StringName`, `#rrggbb` in `Color`,
  `[a, b]` in `Vector2i` o in coppia min/max); nessuna validazione semantica (è di `DataValidator`). Campo mancante o di
  tipo sbagliato (anche un float con parte decimale in un campo `int`): `Log.error` (categoria `data`) e ritorno `null`,
  mai un default inventato. Si applicano solo i default dello schema.
- Eccezioni alla firma: `ActionDef.from_dict(d: Dictionary, file_skill_id: StringName = &"") -> ActionDef` e
  `MasteryNodeDef.from_dict(d: Dictionary, file_skill_id: StringName = &"") -> MasteryNodeDef`: lo `skill` sta a livello
  di file e lo passa `GameData`; vuoto → errore e `null`.
- Modificatori creati solo con `Modifier.from_dict`. Scope di default: `skill:<skill>` per i nodi della maestria, `global`
  per equip, infusioni ed effetti dello shop. In `MasteryBonusRule` lo `scope` dei dati è ignorato e i modificatori sono
  globali segnaposto: lo scope `action:<id>` (e il moltiplicatore di F-11) lo applica `MasterySystem`.
- `ActionDef.icon` resta `""` se manca: il default dello schema (icona del primo output) lo calcola `GameData`.
- `DefReader` (`def_reader.gd`) è un helper interno dei `from_dict` di `core/data/defs/`, non API per gli altri moduli.

```gdscript
class_name ItemQty    ; var item_id: StringName; var qty: int
class_name DropEntry  ; var item_id: StringName; var chance_pct: float; var qty_min: int; var qty_max: int
class_name ItemDef
  var id: StringName; var name: String; var description: String; var category: StringName
  var icon: String; var value: int; var sort_order: int
  var equip: EquipInfo            # null se non equipaggiabile
  var food_heal: int              # 0 se non cibo
  var infusion_modifiers: Array[Modifier]; var infusion_unique: bool
  var blueprint: BlueprintInfo    # M10: null se non progetto
  func is_equippable() -> bool; func is_food() -> bool; func is_infusion() -> bool
  func is_blueprint() -> bool; func is_component() -> bool   # M10: categoria blueprint / component
class_name EquipInfo  ; var slot: StringName; var requirements: Dictionary[StringName, int]   # chiave &"character" = personaggio
                        var modifiers: Array[Modifier]; var weapon: WeaponInfo   # null se non arma
                        var kind: StringName; var grade: int      # M4-01: &"" se lo slot non è weapon/offhand
                        var unique: bool; var upgrade_extras: Array[ToolExtra]   # M10: attrezzo unico (04 §5); extras vuoto se assente
class_name ToolExtra  ; var at: int; var modifiers: Array[Modifier]   # M10: bonus cumulativi dal passo `at` (F-94)
class_name BlueprintInfo ; var base_id: StringName; var grade: int; var inputs: Array[ItemQty]; var rare_component: ItemQty   # M10
class_name WeaponInfo ; var style: StringName; var attack_interval_ms: int; var two_handed: bool
class_name SkillDef
  var id: StringName; var name: String; var description: String; var category: StringName
  var order: int; var icon: String; var color: Color; var has_mastery: bool
  var mastery_bonuses: Array[MasteryBonusRule]
  var level_modifiers: Array[LevelModifier]   # M10: vuoto se assente
class_name LevelModifier ; var stat: StringName; var per_level: float   # M10, F-93
class_name MasteryBonusRule ; var every_levels: int; var at_level: int; var modifiers: Array[Modifier]
class_name ActionDef
  var id: StringName; var skill_id: StringName; var name: String; var level: int
  var interval_ms: int; var xp: int; var mastery: bool; var icon: String
  var inputs: Array[ItemQty]; var outputs: Array[ItemQty]
  var single: bool                # M10: azione a ciclo unico (04 §6); false se assente
  func is_artisan() -> bool       # inputs non vuoto; M10: true anche per single (artigianato del Fabbro)
class_name MasteryNodeDef
  var id: StringName; var skill_id: StringName; var name: String; var description: String
  var cost_pct: float; var requires: Array[StringName]; var pos: Vector2i; var modifiers: Array[Modifier]
class_name AreaDef    ; var id: StringName; var name: String; var description: String; var order: int
                        var requirements: Dictionary[StringName, int]; var packs: Array[PackDef]   # M4-01 (packs)
                        var monster_ids: Array[StringName]   # distinti, ricavati dai gruppi
class_name PackDef    ; var weight: int; var monster_ids: Array[StringName]   # M4-01 (ripetibili, ordine = posizioni)
class_name MonsterDef
  var id: StringName; var name: String; var description: String; var icon: String
  var hp: int; var xp: int; var style: StringName; var attack_interval_ms: int      # xp: M4-01
  var attack_level: int; var power_level: int; var defence_level: int
  var accuracy_bonus: int; var power_bonus: int; var evasion_bonus: int; var damage_reduction: float
  var gold_min: int; var gold_max: int; var rift_shard_chance: float; var drops: Array[DropEntry]
class_name ShopEntryDef
  var id: StringName; var name: String; var description: String; var category: StringName
  var cost_gold: int; var cost_formula: StringName      # &"" oppure &"bank_slot"
  var max_purchases: int                                # 0 = illimitato
  var req_entries: Array[StringName]; var req_skills: Dictionary[StringName, int]; var req_total_level: int
  var req_character: int                                # M4-01; 0 = nessun requisito
  var effect_modifiers: Array[Modifier]; var effect_item: ItemQty   # uno dei due
  # cost_formula: &"" oppure &"bank_slot" (F-17) oppure &"armory_slot" (F-82, M4-01)
class_name ClassDef (M4)   ; var id: StringName; var name: String; var description: String; var order: int
                             var weapon_kinds: Array[StringName]; var offhand_kinds: Array[StringName]
                             var setups: Array[SetupDef]; var traits: Array[TraitDef]; var abilities: Array[AbilityDef]
                             func setup_for(weapon_kind: StringName, offhand_kind: StringName) -> SetupDef   # null se nessuno (F-72)
class_name SetupDef (M4)   ; var id: StringName; var name: String; var weapon_kind: StringName; var offhand_kind: StringName
                             var alternate: bool; var modifiers: Array[Modifier]
class_name TraitDef (M6)   ; var id: StringName; var name: String; var description: String; var unlock_level: int
                             var setups: Array[StringName]; var effects: Array[TraitEffectDef]; var modifiers: Array[Modifier]
class_name TraitEffectDef (M6) ; var type: StringName; var params: Dictionary    # parametri già validati (F-81)
class_name AbilityDef (M6) ; var id: StringName; var name: String; var description: String; var unlock_level: int
                             var setups: Array[StringName]; var kind: StringName; var cooldown_ms: int
                             var power_mult: float; var targets: int; var heal_pct: float
                             var modifiers: Array[Modifier]; var duration_ms: int   # solo i campi del kind; gli altri 0/vuoti
class_name AffixDef (M4)   ; var id: StringName; var name: String; var stat: StringName; var slots: Array[StringName]
                             var weight: int; var tiers: Array[AffixTier]
class_name AffixTier (M4)  ; var min_ilvl: int; var min: float; var max: float; var step: float
class_name RiftStoneDef (M7); campi di 04_DATA_SCHEMA §16
class_name HintDef (M9)    ; var id: StringName; var title: String; var text: String; var trigger: StringName
class_name FractureDef (M12); var id: StringName; var name: String; var description: String; var weight: int
                             var modifiers: Array[Modifier]; var bonus_area_id: StringName; var bonus_monster_id: StringName
```
(`class_name X ; var ...` è notazione compatta: ogni classe è un file `snake_case` separato.)

## 5. Logica

### 5.1 Progressione e casualità
```gdscript
class_name XpTable extends RefCounted                  # core/progression/xp_table.gd
static func from_params(base: float, growth: float, linear: float, max_level: int) -> XpTable
var max_level: int
func xp_for_level(level: int) -> int                    # F-01; level 1 → 0
func xp_to_next(level: int) -> int                      # delta(level); 0 a max_level
func level_for_xp(xp: int) -> int
func progress(xp: int) -> float                         # 0..1 dentro il livello; 1.0 a max_level

class_name RngService extends RefCounted                # core/session/rng_service.gd
func _init(seed_value: int) -> void
func randf() -> float
func randi_range(from: int, to: int) -> int
func roll_pct(chance_pct: float) -> bool                # chance <= 0 → false senza consumare; >= 100 → true senza consumare
func pick_weighted(weights: Array[int]) -> int          # indice
func to_save() -> Dictionary                            # {"seed": int, "state": int} (state come stringa se > 2^53)
func from_save(d: Dictionary) -> void
```

### 5.2 Modificatori (`res://core/modifiers/`)
```gdscript
class_name Modifier extends RefCounted
var stat: StringName; var value: float
var scope_kind: StringName        # &"global", &"skill", &"action"
var scope_id: StringName
static func from_dict(d: Dictionary, default_scope: String = "global") -> Modifier   # null (+ errore) se stat/value/scope malformati; default_scope ha la sintassi di "scope" ("skill:forestry"), usato se manca
static func make(stat: StringName, value: float, scope_kind: StringName = &"global", scope_id: StringName = &"") -> Modifier
func applies_to(ctx: ModifierContext) -> bool
func scaled(factor: float) -> Modifier

class_name ModifierContext extends RefCounted
var skill_id: StringName; var action_id: StringName
static func global_ctx() -> ModifierContext
static func for_skill(skill_id: StringName) -> ModifierContext
static func for_action(skill_id: StringName, action_id: StringName) -> ModifierContext

class_name StatRegistry extends RefCounted
static func from_array(stats: Array, errors: PackedStringArray) -> StatRegistry
func has(stat: StringName) -> bool
func ids() -> Array[StringName]
func info(stat: StringName) -> Dictionary     # {name, format, min, max, description, formula, test}
func clamp_total(stat: StringName, value: float) -> float

class_name ModifierService extends RefCounted
func _init(stats: StatRegistry, events: GameEvents) -> void
func set_source(source_id: StringName, mods: Array[Modifier]) -> void    # sostituisce; stat sconosciute → push_error e ignorate
func clear_source(source_id: StringName) -> void
func clear_all() -> void
func has_source(source_id: StringName) -> bool
func total(stat: StringName, ctx: ModifierContext = null) -> float       # F-05; null = global
func total_without(stat: StringName, ctx: ModifierContext, excluded: Array[StringName]) -> float
    # M5-02: come total senza le sorgenti in excluded, poi limitato (F-74); ctx null = global
func breakdown(stat: StringName, ctx: ModifierContext = null) -> Array[Dictionary]   # [{source, value}] per i tooltip
func begin_batch() -> void           # sospende modifiers_changed
func end_batch() -> void             # emette una sola volta se qualcosa è cambiato
```
Id delle sorgenti: `equipment:<slot>` (modificatori dell'istanza: base × F-86 + affissi + castoni), `setup:<id>` (M4),
`trait:<id>` (M6), `ability:<id>` (M6, buff temporanei del combattimento), `mastery_item:<action_id>`,
`mastery_node:<node_id>`, `shop:<entry_id>`, `rift_socket:<index>` (M8), `skill_level:<skill_id>` (M10, F-93: modificatori
`level_modifiers` della skill, ricostruiti da `SkillsSystem` a ogni `level_up` e in `rebuild_modifiers`), `fracture:<id>` (M12).

### 5.3 Sessione (`res://core/session/game_session.gd`)
```gdscript
class_name GameSession extends Node
var data: GameData; var events: GameEvents; var rng: RngService; var modifiers: ModifierService
var wallet: Wallet; var bank: Bank; var skills: SkillsSystem; var mastery: MasterySystem
var character: CharacterSystem   # M4-03
var armory: Armory                # M4-05
var loadout: Loadout              # M6-03 (null prima)
var equipment: Equipment; var actions: ActionRunner; var combat: CombatEngine   # combat: M5-03
var shop: Shop; var rift: RiftAltar   # rift: M8
var hints: HintsSystem            # M9 (null prima)
var fractures: FractureSystem     # M12 (null prima)
var slot: int; var player_name: String; var created_at_unix_ms: int; var play_time_ms: int
func _init(game_data: GameData, game_events: GameEvents, rng_seed: int) -> void
func new_game() -> void                                  # stato iniziale 01_GDD §1.1 + rebuild_modifiers
func advance(delta_ms: int) -> void                      # ordine: fractures, actions, combat, play_time
func to_save(now_unix_ms: int) -> Dictionary             # file completo (§6)
func from_save(d: Dictionary) -> CommandResult           # poi rebuild_modifiers
func rebuild_modifiers() -> void                         # begin_batch, clear_all, rebuild di ogni sistema, end_batch
func total_level() -> int

class_name SessionSnapshot extends RefCounted            # core/session/session_snapshot.gd
var xp: Dictionary[StringName, int]; var levels: Dictionary[StringName, int]
var bank: Dictionary[StringName, int]; var gold: int
var kills: Dictionary[StringName, int]; var deaths: int; var food_eaten: int
var armory_count: int                                    # M9-01: pezzi nell'Armeria
static func take(session: GameSession) -> SessionSnapshot
# xp/levels: anche la chiave &"character" (XP e livello del personaggio, M4-03); è riservata, nessuna skill la usa
```
**Registrazione di un sistema** (M1-05). I campi tipizzati dei sistemi li dichiara il task che crea il sistema (prima
non esistono). In `_create_systems()`, in ordine di dipendenza: una riga di creazione (`wallet = Wallet.new(self)`) e una
`_join(Wallet.SAVE_KEY, wallet.new_game, wallet.to_save, wallet.from_save[, wallet.rebuild_modifiers])`; chi ha
`advance` aggiunge `_tick(_PHASE_ACTIONS, actions.advance)`. Punti di estensione **protetti** (usabili solo da
`GameSession` e dalle sue sottoclassi, comprese quelle dei test; eccezione dichiarata a `09_CONVENTIONS.md` §2):
```gdscript
func _create_systems() -> void
func _join(key: StringName, new_game_fn: Callable, to_save_fn: Callable, from_save_fn: Callable,
		rebuild_fn: Callable = Callable()) -> void            # SAVE_KEY duplicata → assert
func _tick(phase: int, advance_fn: Callable) -> void         # una fase = un solo sistema, altrimenti assert
const _PHASE_FRACTURES: int; const _PHASE_ACTIONS: int; const _PHASE_COMBAT: int
```
- `advance`: ordine fisso fratture → azioni → combattimento (solo le fasi registrate), poi `play_time_ms`; indipendente
  dall'ordine di `_join`. `new_game`, `to_save`, `from_save` e `rebuild_modifiers` seguono l'ordine di `_join`.
- `from_save`: `format_version` assente o intestazione malformata (`slot`, `created_at_unix_ms`, `play_time_ms` non interi,
  `player_name` non stringa, `rng`/`modules` non oggetti) → `corrupted` senza toccare nulla; `format_version` ≠
  `SaveMigrator.CURRENT_VERSION` → `version_unsupported` (il file va migrato prima). Modulo assente o non oggetto →
  `new_game()` di quel sistema; modulo sconosciuto → `Log.warn` e ignorato. Blocco `rng` con valori non interi →
  `Log.warn`, generatore invariato.
- `RngService.to_save`: `state` come stringa decimale se `|state| > 2^53`; `from_save` accetta int, float interi e stringhe.
- `total_level()` restituisce 0 finché non esiste `SkillsSystem` (M1-08); `SessionSnapshot.take` legge solo i sistemi
  presenti (xp/livelli M1-08, personaggio M4-03, bank/oro M1-07, kills/deaths/food_eaten M5-03).
- `game_session.gd` ≤ 200 righe (test). Da M1-07 i partecipanti al salvataggio stanno in
  `core/session/session_participants.gd` (`class_name SessionParticipants extends RefCounted`, con la classe interna
  `_Participant`): **helper interno** di `GameSession`, non un'API per gli altri moduli (nessuno lo usa o lo referenzia
  fuori da `game_session.gd`). `_join` delega a `SessionParticipants.join`; `new_game`, `to_save`, `from_save` (moduli
  assenti, non oggetti o sconosciuti come sopra) e `rebuild_modifiers` iterano tramite lui, nell'ordine di `_join`.
- Ordine attuale di `_create_systems()`: `wallet`, `bank`, `skills`, `mastery` (`rebuild_fn = mastery.rebuild_modifiers`),
  `actions` (senza `rebuild_fn`; `_tick(_PHASE_ACTIONS, actions.advance)`). I task successivi aggiungono in coda, in ordine
  di dipendenza. Con la riforma: `character` subito dopo `skills` (M4-03), `armory` prima di `equipment` (M4-05),
  `equipment` dopo `armory` e `character` (M4-06 sposta la riga se serve), `combat` dopo `equipment` (M5-03).
- Nei test, `ProbeSession` (`test_game_session.gd`) ridefinisce `_tick` registrando solo le fasi dei `FakeSystem`; le
  chiavi finte non devono coincidere con le `SAVE_KEY` dei sistemi veri (oggi `lanes`, `combat`, `fractures`): il task
  che registra un sistema con la stessa chiave rinomina quella finta.

### 5.4 Wallet (`systems/wallet/wallet.gd`) — dipendenze: events
```gdscript
const SAVE_KEY := &"wallet"
func get_gold() -> int
func add_gold(amount: int) -> void                 # amount > 0, altrimenti push_error e nulla
func spend(amount: int) -> CommandResult           # invalid_amount, not_enough_gold
```
- Ogni variazione emette `gold_changed(new_amount, delta)` dopo il cambio (`delta` = `+amount` / `-amount`).
- `new_game` (oro = `start.gold`) e `from_save` non emettono segnali: la UI legge lo stato dopo `session_started`.
- `from_save` tollerante: `gold` assente, non intero (i float interi del JSON sono accettati) o negativo → `Log.warn` e 0.

### 5.5 Bank (`systems/bank/bank.gd`) — dipendenze: data, events, modifiers
```gdscript
const SAVE_KEY := &"bank"
const PIECE_CATEGORIES: Array[StringName] = [&"equipment", &"tool"]   # M4-05: pezzi unici dell'Armeria, rifiutati dalla bank; li usano anche Armory e Shop
func get_count(item_id: StringName) -> int
func has(item_id: StringName, qty: int) -> bool
func can_add(item_id: StringName) -> bool          # già presente o casella libera; false per equipment/tool (M4-05)
func add(item_id: StringName, qty: int) -> CommandResult      # unknown_id, not_stackable (M4-05: equipment/tool), invalid_amount, bank_full
func remove(item_id: StringName, qty: int) -> CommandResult   # invalid_amount, not_enough_items
func capacity() -> int                             # F-16
func used() -> int
func stacks() -> Array[Dictionary]                 # copie: [{"item": StringName, "count": int, "locked": bool}] in ordine
func is_locked(item_id: StringName) -> bool
func set_locked(item_id: StringName, locked: bool) -> CommandResult   # unknown_id se non presente
func move_stack(item_id: StringName, new_index: int) -> CommandResult
func sort_stacks() -> void                         # per categoria (ordine: material, food, infusion, misc; M4-05), sort_order, id
```
- Capienza F-16 = `bank.base_slots + floori(total(bank_slots))`; su `modifiers_changed`, solo se la capienza cambia,
  `bank_capacity_changed(used, capacity)`. Lo emettono anche `add` di un oggetto nuovo e la casella liberata.
- `add`: id sconosciuto → `unknown_id` (prima del controllo della quantità); `qty ≤ 0` → `invalid_amount`; oggetto nuovo
  con bank piena → `bank_rejected(item_id, qty)` + `bank_full`, nessun `bank_changed`. Un oggetto già presente entra
  sempre. `remove`: `qty ≤ 0` → `invalid_amount`; quantità insufficiente o oggetto assente → `not_enough_items`;
  a 0 la casella si libera e il blocco si perde.
- `bank_changed(item_id, new_count, delta)`: `delta` = `+qty` / `-qty` per `add`/`remove`; **`delta` = 0** per i
  cambi che non toccano la quantità: `set_locked` (solo se il blocco cambia davvero), `move_stack` e `sort_stacks`
  (uno per ogni casella che cambia indice).
- `move_stack`: oggetto assente → `unknown_id`; `new_index` fuori da `0..used()-1` → `invalid_amount`; stesso indice →
  ok senza segnali. Le altre caselle scorrono.
- `can_add` di un id sconosciuto → false. `has(item_id, qty)` = `get_count(item_id) >= qty`.
- `new_game` (applica `start.items`) e `from_save` non emettono segnali (la UI legge dopo `session_started`); il
  `rebuild_modifiers` che li segue può emettere `bank_capacity_changed` se la capienza cambia.
- `from_save` tollerante, ordine conservato: voci con id sconosciuto, duplicate, `count` non intero o ≤ 0 (i float interi
  del JSON sono accettati) → `Log.warn` e scartate; `locked` non booleano → false; `stacks` non lista → bank vuota.
  Non controlla la capienza (le caselle comprate non si perdono, `01_GDD.md` §7).
- Da M4-05: `add` di un oggetto `equipment`/`tool` → `not_stackable` (dopo `unknown_id`, prima di `invalid_amount`),
  nessun segnale; `from_save` scarta queste voci con `Log.warn`. `sort_stacks` non ha più le categorie `equipment`/`tool`.

### 5.6 SkillsSystem (`systems/skills/skills_system.gd`) — dipendenze: data, events, modifiers
```gdscript
const SAVE_KEY := &"skills"
func get_xp(skill_id: StringName) -> int
func get_level(skill_id: StringName) -> int
func get_progress(skill_id: StringName) -> float
func add_xp(skill_id: StringName, base_amount: int, ctx: ModifierContext = null) -> int   # F-02; restituisce XP data
func meets_requirements(requirements: Dictionary) -> bool    # {skill_id: livello}
func total_level() -> int
```
- Stato: solo l'XP cumulativa per skill (tutte le skill dei dati, in ordine); livello e progresso derivano da `XpTable`
  (F-01); l'XP cresce oltre `max_level` fino a `xp_curve.xp_cap`. `add_xp` con `ctx = null` usa
  `ModifierContext.for_skill(skill_id)`; emette `xp_gained` (se > 0) e poi un `level_up` per livello, dopo il cambio.
- M10 (F-93): `rebuild_modifiers()` (nuovo, registrato con `_join`) imposta la sorgente `skill_level:<skill_id>` con i
  `level_modifiers` della skill (`per_level × livello`, scope globale) e si richiama a ogni `level_up` e dopo `from_save`; senza
  `level_modifiers` nessuna sorgente. Dipende da `modifiers` (già tra le dipendenze).
- Skill sconosciuta: `Log.error` e nessun cambio; `get_xp`/`get_level` → 0, `get_progress` → 0.0, `add_xp` → 0,
  `meets_requirements` → false (anche con un livello richiesto non numerico). XP base negativa: `Log.error`, `add_xp` → 0.
- `from_save` tollerante: skill mancanti a 0; voci di skill sconosciute o malformate (non `{"xp": intero}`; i float interi
  del JSON sono accettati) → `Log.warn` e ignorate; XP limitata a `0..xp_cap`.

### 5.7 Maestria (`systems/mastery/`) — dipendenze: data, events, modifiers
```gdscript
class_name MasteryMath extends RefCounted
static func mastery_xp(interval_ms: int, item_level: int, skill_ratio: float, mastery_xp_pct: float, data: GameData) -> int  # F-10
static func pool_gain(mastery_xp: int, share_pct: float) -> int     # F-12
static func pool_cap(action_count: int, per_item: int) -> int       # F-13
static func node_cost(pool_cap: int, cost_pct: float) -> int        # F-15
static func rule_multiplier(rule: MasteryBonusRule, level: int) -> int   # F-11: floor(L/k) o 0/1

class_name MasterySystem extends RefCounted
const SAVE_KEY := &"mastery"
func get_mastery_xp(action_id: StringName) -> int
func get_mastery_level(action_id: StringName) -> int
func get_skill_ratio(skill_id: StringName) -> float                # R di F-10
func get_pool(skill_id: StringName) -> int
func get_pool_cap(skill_id: StringName) -> int
func add_for_action(action: ActionDef) -> int                      # F-10 + F-12; restituisce mxp
func spend_pool_on_action(action_id: StringName, amount: int) -> CommandResult   # F-14; invalid_amount, pool_insufficient, mastery_max
func node_cost(node_id: StringName) -> int
func owns_node(node_id: StringName) -> bool
func can_buy_node(node_id: StringName) -> CommandResult            # unknown_id, node_owned, node_prereq_missing, pool_insufficient
func buy_node(node_id: StringName) -> CommandResult
func rebuild_modifiers() -> void                                   # sorgenti mastery_item:* e mastery_node:*
```
- Stato: la xp di maestria di ogni azione `mastery: true` delle skill `has_mastery` e il pool di ogni skill `has_mastery`;
  il livello deriva da F-09. La xp di maestria si ferma a `xp_for_level(max_level)` (nessun guadagno oltre il 99).
  `get_mastery_level` di un'azione senza maestria o sconosciuta → 0; `get_pool`/`get_pool_cap`/`get_skill_ratio` di una
  skill senza maestria → 0. R di F-10 = somma dei **livelli di maestria** delle azioni con maestria della skill /
  (`max_level` × loro numero), non il livello della skill.
- `add_for_action(action)`: è sicuro chiamarlo a ogni ciclo completato con qualunque `ActionDef` (azione senza maestria →
  0, nessun cambio, nessun segnale; `null` → `Log.error` e 0). L'mxp di F-10 usa l'intervallo **base** e
  `total(mastery_xp_pct, for_action(skill, action))`. Restituisce l'mxp di F-10 anche al 99 (la xp resta ferma) e il pool
  riceve comunque la quota F-12, fino al tetto F-13 (al tetto: nessun cambio, nessun `mastery_pool_changed`).
- `mastery_xp_gained(skill, action, amount)`: `amount` = xp effettivamente aggiunta (> 0; nessun segnale se 0); lo
  emettono sia il ciclo sia `spend_pool_on_action`. Ordine degli effetti: stato → sorgente `mastery_item:<action>`
  aggiornata (batch, un solo `modifiers_changed`, solo se un moltiplicatore di F-11 cambia) → `mastery_xp_gained` → un
  `mastery_level_up` per livello → `mastery_pool_changed` (solo se il pool cambia).
- `spend_pool_on_action`: errori nell'ordine `unknown_id` (azione senza maestria o sconosciuta) → `invalid_amount`
  (`amount ≤ 0`) → `mastery_max` (già al 99) → `pool_insufficient` (pool 0); in errore nessun cambio di stato né segnale.
- F-11: sorgente `mastery_item:<action_id>` con scope `action:<id>` solo se ha almeno un modificatore (altrimenti
  `clear_source`). `rebuild_modifiers` registra in **un solo batch** (un `modifiers_changed`) le sorgenti
  `mastery_item:*` e le `mastery_node:<node_id>` dei nodi posseduti.
- Nodi (M2-01, `01_GDD.md` §6.3): `node_cost(id)` = F-15 sul tetto del pool della skill del nodo (`get_pool_cap`);
  id sconosciuto → 0. `owns_node` di un id sconosciuto → false. `can_buy_node` controlla senza cambiare nulla, errori
  nell'ordine `unknown_id` (non è un nodo di una skill con maestria) → `node_owned` → `node_prereq_missing` (un nodo di
  `requires` non posseduto) → `pool_insufficient` (pool < `node_cost`; pool = costo basta). `buy_node`: stessi errori
  (in errore nessun cambio né segnale); ordine degli effetti: stato (nodo posseduto, pool − costo) → sorgente
  `mastery_node:<node_id>` con i modificatori del nodo e i loro scope dei dati (un `modifiers_changed`; nodo senza
  modificatori → nessuna sorgente) → `mastery_node_purchased(skill_id, node_id)` → `mastery_pool_changed` (solo se il
  pool cambia). I nodi sono permanenti: spendere il pool (F-14) non li toglie; `new_game` li azzera.
- Save (§6): `{skill_id: {"pool": int, "actions": {action_id: xp}, "nodes": [node_id, …]}}` per ogni skill con maestria;
  `nodes` = nodi posseduti della skill nell'ordine dei dati. `new_game` e `from_save` non emettono segnali. `from_save`
  tollerante: skill sconosciute o senza maestria, voci non oggetto, azioni sconosciute o di un'altra skill, valori non
  interi o negativi (i float interi del JSON sono accettati) → `Log.warn` e scartati (a 0); `actions` non oggetto →
  azioni a 0 (il pool resta); pool oltre il tetto e xp oltre il 99 → limitati (pool con `Log.warn`). `nodes` non lista →
  nessun nodo (`Log.warn`); voci non stringa, id sconosciuti o di un'altra skill → `Log.warn` e scartati; i
  prerequisiti **non** si ricontrollano al caricamento (un nodo salvato resta posseduto).

### 5.8 Azioni (`systems/actions/`) — dipendenze: data, events, modifiers, bank, skills, mastery, rng, combat (solo `stop`)
```gdscript
class_name ActionMath extends RefCounted
static func interval_ms(base_ms: int, interval_pct: float, min_ms: int) -> int          # F-03
static func secondary_interval_ms(interval_ms: int, penalty_pct: float) -> int          # F-51 (M13)

class_name ActionOutcome extends RefCounted
var ok: bool; var reason: StringName
var outputs: Dictionary[StringName, int]; var consumed: Dictionary[StringName, int]
var xp: int; var mastery_xp: int; var shard: bool

class_name GatheringResolver extends RefCounted
static func resolve(session: GameSession, action: ActionDef) -> ActionOutcome         # 01_GDD §4, F-06, F-07

class_name ArtisanResolver extends RefCounted
static func can_start(session: GameSession, action: ActionDef) -> CommandResult       # missing_inputs
static func resolve(session: GameSession, action: ActionDef) -> ActionOutcome         # 01_GDD §5, F-08

class_name ActionRunner extends RefCounted
const SAVE_KEY := &"actions"
const MAIN := &"main"
const SECONDARY := &"secondary"                    # M13
func start(skill_id: StringName, action_id: StringName, lane: StringName = MAIN) -> CommandResult
    # unknown_id, level_too_low, missing_inputs, lane_unavailable, skill_in_other_lane; nella corsia main ferma il combattimento (REPLACED)
func stop(lane: StringName = MAIN, reason: StringName = Reasons.STOPPED_BY_USER) -> void
func is_running(lane: StringName = MAIN) -> bool
func get_lane(lane: StringName = MAIN) -> Dictionary     # {} oppure {"skill", "action", "elapsed_ms", "interval_ms"}
func get_progress(lane: StringName = MAIN) -> float      # F-04
func current_interval_ms(action_id: StringName, lane: StringName = MAIN) -> int
func lanes_available() -> int                            # 1 nell'MVP; F-51 in M13
func stop_reasons_log() -> Array[StringName]              # motivi di stop dall'ultima lettura (per OfflineSummary), poi svuota
func advance(delta_ms: int) -> void
```
Comportamento (M1-10):
- `start`: ordine dei controlli `lane_unavailable` (ogni corsia diversa da `main` fino a M13) → `unknown_id` (skill o
  azione sconosciuta, azione di un'altra skill) → `level_too_low` → `missing_inputs` (azione con `inputs` senza tutti gli
  ingredienti nella bank, `ArtisanResolver.can_start`; stesso controllo in `from_save`); un errore non cambia nulla. Avviare l'azione già in corso nella corsia è un no-op `ok` (il ciclo continua, nessun segnale). Altrimenti
  l'azione in corso si ferma con `replaced`, poi `action_started`. Nella corsia main ferma anche il combattimento
  (`replaced`): la riga arriva con M5-03.
- `stop` di una corsia ferma: no-op, nessun segnale. Ogni stop emette `action_stopped` e accoda il motivo al log;
  `stop_reasons_log()` restituisce **tutti** i motivi dall'ultima lettura, in ordine (anche `stopped_by_user` e `replaced`),
  poi svuota; il log non è salvato e `new_game`/`from_save` lo svuotano.
- Intervallo F-03 fissato all'inizio di ogni ciclo (un cambio di modificatori vale dal ciclo successivo); `advance`
  completa tutti i cicli che entrano nel passo. Dopo `from_save` l'intervallo è "da fissare" e si calcola al primo
  `advance` (i modificatori si ricostruiscono dopo il caricamento); `get_lane`/`get_progress` intanto usano quello attuale.
- `get_lane` restituisce l'`interval_ms` del ciclo corrente; `current_interval_ms` quello che avrebbe un ciclo avviato ora
  (id sconosciuto → 0 con `Log.error` di `GameData.action`; la corsia non conta fino a M13).
- `GatheringResolver`: tiri sempre in quest'ordine su `session.rng`: doppio (F-06), poi frammento (F-07, quantità 1).
  Lo spazio nella bank si controlla **prima** di aggiungere (`can_add` e caselle libere per gli oggetti nuovi, frammento
  compreso): se non c'è, il ciclo non conta, nulla cambia e la corsia si ferma con `bank_full` (nessun `bank_rejected`:
  il feedback è `action_stopped(bank_full)`). Ciclo riuscito: `bank_changed` → `xp_gained`/`level_up` →
  segnali della maestria → `action_completed` (`outputs` comprende `rift_shard` se è uscito).
- `ArtisanResolver` (M3-01): gli ingredienti si controllano all'avvio di ogni ciclo e di nuovo alla fine; se mancano (es.
  venduti a metà ciclo) il ciclo fallisce con `missing_inputs`, nulla cambia, niente XP, e la corsia si ferma. Tiri sempre
  in quest'ordine su `session.rng`: conservazione (F-08), poi doppio (F-06). Nessun frammento. Lo spazio nella bank si
  controlla **prima** di ogni cambio, al netto degli ingredienti da consumare: le caselle liberate dagli ingredienti
  consumati del tutto contano per i prodotti nuovi (per questo non si usa `Bank.can_add`, che guarda le caselle prima del
  consumo); se non c'è posto il ciclo non conta, nulla è consumato e la corsia si ferma con `bank_full`. Ciclo conservato:
  `consumed` vuoto, prodotti e XP pieni. Ordine dei segnali come per `GatheringResolver`.
- ~~`ArtisanResolver` da M4-07 (SUPERATO da M10, vedi 5.8b: nessuna ricetta produce più equipaggiamento)~~: i prodotti `equipment`/`tool` (quantità dopo F-06) non vanno nella bank ma diventano
  istanze con `session.armory.create(base, ItemRoller.roll_rarity(craft_chances(M, item_rarity_pct)), action.level)`
  (F-83, F-85; `M` = livello di maestria dell'azione **prima** della maestria del ciclo). Lo spazio si controlla prima di
  ogni cambio con `armory.can_add(qty)`: se manca, ciclo non contato, nulla consumato, stop `armory_full`. Tiri su
  `session.rng`: conservazione, doppio, poi per ogni istanza rarità e affissi. `outputs` resta `{item_id: qty}`.
- Save (§6): `{"lanes": {lane: {"skill", "action", "elapsed_ms"}}}`, corsie ferme assenti. `from_save` tollerante: corsia
  sconosciuta, voce non oggetto, azione sconosciuta/di un'altra skill/non avviabile ora (livello, `inputs`) → `Log.warn`
  e corsia ferma; `elapsed_ms` non intero o negativo → `Log.warn` e ciclo da 0. Nessun segnale.

#### 5.8b Progetti (M10, `01_GDD.md` §5.1, F-90…F-92) — in `systems/actions/`
```gdscript
class_name BlueprintCraft extends RefCounted          # blueprint_craft.gd: logica pura, nessuno stato
static func required_level(blueprint: ItemDef, data: GameData) -> int            # livello del grado (02 §8.1)
static func duration_ms(blueprint: ItemDef, interval_pct: float, data: GameData) -> int   # F-90, F-03 inclusa
static func xp(blueprint: ItemDef, data: GameData) -> int                        # F-90, prima di F-02
static func inputs(blueprint: ItemDef) -> Array[ItemQty]                         # inputs del progetto + rare_component (il progetto stesso escluso)
static func can_start(session: GameSession, blueprint_id: StringName, chosen_affix: StringName = &"") -> CommandResult
    # in ordine: unknown_id (non è un progetto o non è in bank), level_too_low, invalid_choice, missing_inputs, armory_full
static func finish(session: GameSession, blueprint_id: StringName, chosen_affix: StringName) -> int   # crea il pezzo (ItemRoller.create_from_blueprint); uid, 0 se Armeria piena
# ActionRunner (aggiunte):
func start_blueprint(blueprint_id: StringName, chosen_affix: StringName = &"") -> CommandResult   # corsia MAIN; stessi rifiuti di can_start, più lane_unavailable
func blueprint_state() -> Dictionary    # {} oppure {"blueprint", "chosen_affix", "duration_ms", "elapsed_ms", "waiting": bool}
```
- `start_blueprint` consuma il progetto e gli `inputs` all'avvio (la bank li toglie in un'operazione sola; nessun cambio se un
  controllo fallisce), ferma l'azione o il combattimento in corso (`replaced`), emette `action_started(main, forging,
  blueprint_craft)`. `start(forging, blueprint_craft)` diretto è rifiutato (`unknown_id`): serve `start_blueprint`.
  Durata fissata all'avvio (F-90, `skill_interval_pct` di quel momento). Un'azione `single` con `mastery: false` non dà maestria.
- `stop` prima della fine restituisce progetto e materiali (stesse quantità, `bank_changed`; se la bank è piena per un oggetto
  il resto va perso con `bank_rejected`: caso estremo, ma documentato). Alla fine: tiri su `session.rng` (rarità, affissi, F-91/F-92),
  `armory.add` → `armory_changed(added)`, XP (F-90, poi F-02) → `xp_gained`/`level_up`, `blueprint_crafted`, `action_completed`
  (`outputs` = `{base_id: 1}`), poi stop con motivo `blueprint_done`. Armeria piena alla fine: `waiting = true`, nessun
  segnale di stop, riprova a ogni `advance`, una sola `notification_requested` (warning). I tiri di rarità e affissi si fanno solo quando il pezzo trova posto.
- Save (§6): la corsia `main` di un progetto è `{"skill": "forging", "action": "blueprint_craft", "elapsed_ms": n, "blueprint": id,
  "chosen_affix": id, "duration_ms": n}`. `from_save` tollerante: progetto sconosciuto o `duration_ms` non intero → `Log.warn` e
  corsia ferma (i materiali già consumati non tornano: nessun giocatore reale con quel caso). L'offline lo fa avanzare come ogni azione.
- `ArtisanResolver`: non crea più istanze (`equipment`/`tool` non sono più prodotti di ricette; il validatore lo vieta); il controllo
  `armory.can_add` e la rarità F-83 escono. `ItemRoller.craft_chances` esce dal contratto (5.18).

### 5.9 Equipment (`systems/equipment/equipment.gd`) — dipendenze: data, events, modifiers, bank, character, armory, combat (solo `in_encounter`)
> M10: `Equipment.new_game()` indossa il kit iniziale: per ogni voce di `start.armory` con `equip` non vuoto il pezzo con quel `uid` (le istanze
> create da `Armory.new_game()` hanno `uid` 1…n nell'ordine di `start.armory`, poi i tre attrezzi di `start.tools`), gli attrezzi nel proprio slot
> `tool_*`, il cibo `start.food`. `unequip` di uno slot `tool_*` → `item_unique`; `equip` di un altro pezzo in uno slot `tool_*` → `not_equippable`.
Firme da M4-06 (prima: `item_id` della bank negli slot e stance, M3-03).
```gdscript
const SAVE_KEY := &"equipment"
const SLOTS: Array[StringName] = [&"head", &"body", &"legs", &"feet", &"hands", &"neck", &"ring",
    &"weapon", &"offhand", &"tool_forestry", &"tool_quarrying", &"tool_angling"]
const UNARMED := &"unarmed"                              # assetto senza arma (F-72)
func get_uid(slot: StringName) -> int                    # 0 se vuoto
func get_item(slot: StringName) -> StringName            # base dell'istanza indossata; &"" se vuoto
func slot_of(uid: int) -> StringName                     # &"" se non indossato
func equip(uid: int, slot: StringName = &"") -> CommandResult
    # unknown_id, not_equippable, requirement_not_met (livello, kind non ammesso dalla classe, combinazione senza assetto),
    # combat_active (arma o offhand durante un incontro), armory_full; slot &"" = equip.slot della base
func unequip(slot: StringName) -> CommandResult          # slot_empty, armory_full, combat_active (arma/offhand)
func get_food() -> StringName
func set_food(item_id: StringName) -> CommandResult      # &"" toglie; not_food; l'oggetto deve essere nella bank
func setup() -> StringName                               # F-72: id dell'assetto o UNARMED
func setup_def() -> SetupDef                             # null con UNARMED
func weapon() -> ItemDef                                 # base dell'arma; null = mani nude
func offhand_weapon() -> ItemDef                         # base della spada nell'offhand; null se scudo o vuoto
func style() -> StringName                               # weapon.style o combat.unarmed.style
func base_attack_interval_ms() -> int                    # weapon, F-73 con assetto alternate, o combat.unarmed
func rebuild_modifiers() -> void                         # sorgenti equipment:<slot> (Armory.instance_modifiers) e setup:<id>
```
Comportamento:
- `equip` è atomico, controlli nell'ordine della firma; un errore non cambia nulla. `combat_active` vale per `weapon` e
  `offhand` mentre `session.combat.in_encounter()` (null-safe). Le regole delle due mani e "senza arma solo scudo
  nell'offhand" (`01_GDD.md` §9) spostano pezzi tra i non indossati: `armory_full` se non c'è posto per loro, al netto
  del pezzo che si indossa. Riuscito: `armory.set_worn` per ogni pezzo cambiato, una sola ricostruzione dei
  modificatori (batch), poi `equipment_changed(slot, uid)` per ogni slot svuotato e infine per lo slot occupato.
- Casi fissati in M4-06: `uid` già indossato (in qualsiasi slot) → `not_equippable`; `slot` diverso da `equip.slot`
  della base → `not_equippable`, tranne un'arma a una mano in `offhand` (un'arma a due mani in `offhand` →
  `not_equippable`); una spada nell'`offhand` senza arma → `requirement_not_met` (combinazione senza assetto). Ordine:
  `unknown_id`, `not_equippable`, `requirement_not_met` (livello, `kind`, assetto), `combat_active`, `armory_full`.
  `armory_full` in `equip`: i pezzi che tornano tra i non indossati meno quello che si indossa (che lascia un posto);
  in `unequip`: tutti i pezzi tolti. `unequip(&"weapon")` lascia lo scudo nell'offhand ma toglie anche la spada
  nell'offhand. Indossare un pezzo dell'offhand con un'arma a due mani rimette l'arma tra i non indossati.
- `armory_changed(uid, &"updated")` su un pezzo indossato **non** ricostruisce le sorgenti: oggi nessun comando cambia
  un pezzo indossato (la raffinazione arriva con M7-01, che deve gestirlo).
- Requisiti: `character.meets_requirements(equip.requirements)`; `kind` in `weapon_kinds`/`offhand_kinds` della classe;
  la coppia risultante (`weapon`, `offhand`) deve avere un assetto (`ClassDef.setup_for`) o essere senza arma con scudo.
- `set_food`: come M3-03; emette `food_changed`.
- Save (§6): `{"slots": {slot: uid}, "food": item_id | ""}`. `from_save` tollerante, con `Log.warn`: slot sconosciuto,
  `uid` assente dall'Armeria o già usato in un altro slot, base non equipaggiabile o di un altro slot, combinazione senza
  assetto → slot vuoto (il pezzo resta nell'Armeria, non indossato); arma a due mani con offhand → offhand vuoto (M3-11);
  cibo non valido → nessuno; una chiave `stance` (save v1) non arriva mai (v1 non si carica). Chiama
  `armory.set_worn(uid, true, true)` (`quiet`) per i pezzi indossati. Nessun segnale.

### 5.10 Combattimento (`systems/combat/`) — dipendenze: data, events, modifiers, rng, bank, wallet, character, equipment, armory, loadout (M6), actions (solo `stop`)
Firme da M5 (motore a eventi e gruppi, `01_GDD.md` §10); `CombatMath` da M5-01.
```gdscript
class_name CombatMath extends RefCounted
static func accuracy_rating(level: int, bonus: float, pct: float, data: GameData) -> int     # F-20
static func evasion_rating(level: int, bonus: float, pct: float, data: GameData) -> int      # F-21
static func max_hit(level: int, bonus: float, pct: float, data: GameData) -> int             # F-22
static func min_hit(max_hit: int, data: GameData) -> int                                     # F-22
static func hit_chance(accuracy: int, evasion: int, data: GameData) -> float                 # F-23
static func triangle(attacker_style: StringName, defender_style: StringName, data: GameData) -> StringName   # &"advantage"/&"neutral"/&"disadvantage"
static func triangle_damage(damage: int, relation: StringName, data: GameData) -> int        # F-24
static func effective_dr(defender_dr: float, relation: StringName, data: GameData) -> float  # F-25 (relation dell'attaccante)
static func damage_after_dr(damage: int, dr_eff: float) -> int                               # F-25
static func attack_interval_ms(base_ms: int, pct: float, data: GameData) -> int              # F-26
static func dual_wield_base_ms(weapon_ms: int, offhand_ms: int, data: GameData) -> int       # F-73
static func max_hp(character_level: int, flat: float, data: GameData) -> int                 # F-27
static func block_chance(total: float, data: GameData) -> float                             # F-75 (limite dalla stat)

class_name CombatantStats extends RefCounted
var style: StringName; var accuracy: int; var evasion: int; var max_hit: int; var min_hit: int
var attack_interval_ms: int; var damage_reduction: float; var max_hp: int; var block_chance: float
static func for_player(session: GameSession, hand: int = 0) -> CombatantStats   # F-70; hand 1 = offhand (F-74)
static func for_monster(monster: MonsterDef, data: GameData) -> CombatantStats
    # M5-02: sempre ricalcolati (niente nel save); block_chance 0 senza scudo nell'offhand; mostri senza modificatori,
    # intervallo con F-26 (pct 0, quindi minimo combat.min_attack_interval_ms)

class_name AutoEat extends RefCounted
static func eat_one(session: GameSession, hp: int, max_hp: int) -> int      # nuovo hp; -1 se nessun cibo (F-29)
    # M5-02: a PV pieni non mangia (nessun pezzo tolto, hp invariato); food_eaten(item, healed) con la cura reale
static func after_hit(session: GameSession, hp: int, max_hp: int) -> int   # F-30; nuovo hp
    # M5-02: soglia floor(max_hp × threshold/100), obiettivo ceil(max_hp × target/100); tier 0 o hp ≤ 0: nulla

class_name LootBag extends RefCounted
func _init(session: GameSession) -> void
func items() -> Array[Dictionary]          # [{"item": StringName, "qty": int}]
func used() -> int
func capacity() -> int                     # F-33
func add(item_id: StringName, qty: int) -> bool    # con auto_loot prova prima la bank; false = perso (loot_lost)
    # M5-02: qty ≤ 0 → true, nulla; auto_loot (T ≥ 1): bank se can_add e add riesce, altrimenti la borsa; tipo nuovo
    # a borsa piena → loot_lost(item, qty) e false; altrimenti somma e loot_bag_changed(used, capacity)
func collect_all() -> CommandResult        # bank_full se qualcosa resta
    # M5-02: sposta ogni tipo che entra; loot_bag_changed alla fine
func lose_all() -> void                    # morte
    # M5-02: un loot_lost per tipo, poi loot_bag_changed
func to_save() -> Array                    # [{"item": String, "qty": int}] in ordine di inserimento (§6)
    # from_save tollerante: voci malformate o oggetti sconosciuti saltati con Log.warn, duplicati sommati, nessun segnale
func from_save(a: Array) -> void

class_name CombatEngine extends RefCounted
const SAVE_KEY := &"combat"
const STATE_IDLE := &"idle"; const STATE_ENCOUNTER := &"encounter"; const STATE_BETWEEN := &"between"
const STATE_RIFTSTONE := &"riftstone"      # M7
var loot: LootBag
func start(area_id: StringName) -> CommandResult    # unknown_id, requirement_not_met (character); ferma la corsia main (REPLACED)
func stop(reason: StringName = Reasons.STOPPED_BY_USER) -> void
func is_active() -> bool                   # stato ≠ idle
func in_encounter() -> bool                # encounter o riftstone
func state() -> StringName
func area_id() -> StringName
func get_state() -> Dictionary
    # copia per la UI: {"state", "area", "player_hp", "player_max_hp", "player_timer_ms", "player_interval_ms",
    #  "hand", "between_ms", "enemies": [{"monster", "hp", "max_hp", "timer_ms", "interval_ms"}], "target": int,
    #  "abilities": [{"id", "timer_ms", "cooldown_ms", "enabled"}] (M6), "buffs": {id: ms} (M6)}
func rebuild_modifiers() -> void           # M6-03: rimette le sorgenti `ability:<id>` dei buff attivi dopo un load (la sessione le azzera prima)
func eat() -> CommandResult                 # no_food, not_running
func player_stats(hand: int = 0) -> CombatantStats
func enemy_stats(index: int) -> CombatantStats    # null se la posizione è vuota o morta
func kills(monster_id: StringName) -> int
func total_kills() -> Dictionary[StringName, int]
func deaths() -> int
func food_eaten() -> int
func stop_reasons_log() -> Array[StringName]
func advance(delta_ms: int) -> void        # motore a eventi (01_GDD §10.10): salta al prossimo timer
```
Comportamento (M5-03):
- `advance` ripete: `next` = minimo tra i timer attivi (attacco base, abilità (M6), nemici vivi, attesa `BETWEEN`,
  impulso della Pietra (M7)); se `next > resto` scala tutti i timer del resto e si ferma; altrimenti scala `next` e
  risolve tutti i timer a 0 nell'ordine F-76. Equivalenza obbligatoria: `advance(1000)` = dieci `advance(100)`.
- **Ordine dei tiri di un attacco** (contratto per il determinismo: stesso seme → stessa sequenza di `Rng`):
  1. colpo: `roll(hit_chance)` (F-23); mancato → fine (nessun altro tiro);
  2. parata, solo se il difensore è il giocatore con `block_chance > 0` (scudo): `roll_pct(block_chance)` (F-75);
     parato → danno 0, fine (nessun tiro del danno, nessun `after_hit`);
  3. danno: intero uniforme in `[min_hit, max_hit]` (F-22);
  4. senza tiri: `triangle` → `triangle_damage` (F-24) → `effective_dr` con la relazione dell'attaccante →
     `damage_after_dr` (F-25); poi i PV e, se il difensore è il giocatore vivo, `AutoEat.after_hit` (F-30).
  Uccisione, nell'ordine: oro (F-31), drop nell'ordine dei dati (F-32, un tiro di probabilità e poi uno di quantità per
  voce; per un pezzo (M7), dopo il tiro della quantità e per ciascuna istanza: un tiro di rarità (F-84), poi i tiri degli
  affissi (F-85)), frammento (F-07). Poi, per un mostro ordinario, F-87 (`since += 1`, il tiro `chance_pct` solo se
  `since` < `pity_kills`). Uccisione di una Pietra: XP, frammenti `randi_range(shards)`, drop con fonte `rift_stone`.
- Uccisione: XP al personaggio (F-28), oro (F-31), drop (F-32) e frammento (F-07) nella borsa, `monster_killed`;
  ultimo nemico → `encounter_cleared`, stato `between` per `combat.respawn_ms`, poi nuovo gruppo (F-77) e
  `encounter_started`. Morte: `lose_all`, PV al massimo, `player_died`, stop `player_died`.
- M6-03, classi di supporto (interne al modulo): `CombatView.build(engine, encounter, abilities, snapshot) -> Dictionary`
  (la copia di `get_state()`); `AbilityRunner` (`reset`, `tick(ms)`, `next_ms(hp, max_hp)`, `take_due(encounter, hp, stats, rule) -> Use`,
  `view()`, `buffs()`, `timers_save()`, `buffs_save()`, `from_save(timers, buffs)`, `rebuild_modifiers()`), tenuto dal motore.
  Segnale `ability_used(ability_id: StringName, targets: Array[int])`, emesso prima degli effetti dell'uso.
- Agganci dei tratti (M6, `01_GDD.md` §20.3): il motore chiama gli effetti di `systems/combat/effects/` (classe base
  `TraitEffect`, un file per tipo di F-81) nei punti `on_encounter_start`, `on_before_attack`, `on_hit`, `on_kill`,
  `on_damaged`, `on_low_hp`, `choose_target`, `modify_stats`; abilità in `systems/combat/ability_runner.gd` (F-79, F-80).
- Save (§6): stato, area, nemici, PV, timer, mano, attesa, contatori, borsa, stato degli effetti (`effects`: solo i
  contatori non vuoti per tratto, es. quello di `every_nth_attack_all`) e, da M6-03, di abilità e buff. `attack_count` non è
  una chiave del save. Da M7-04 `combat.stone = {since: int, pending: bool}` (additiva, salvata anche da `idle`,
  `format_version` invariata; tollerante: assente o malformata → 0 / false). Stato `riftstone`: i nemici stanno in
  `enemies` con `monster` = id della Pietra (`from_save` risolve anche `GameData.rift_stone`); `monster_killed(index,
  stone_id)`, la UI risolve nome e icona con `GameData.rift_stone`. Impulso: nessun tiro di colpo, la parata (F-75) è
  l'unico tiro.
  `from_save` tollerante: area o mostro sconosciuto → `idle` con `Log.warn` (borsa e contatori tenuti).
- Comportamenti fissati da M5-03 (contratto, coperti da `test_combat_engine.gd`):
  - `start` sulla stessa area già attiva: successo, nulla cambia; su un'altra area: `stop(replaced)` e nuovo avvio.
    Ogni avvio: PV al massimo, mano 0, `combat_started`, `player_hp_changed`, primo incontro.
  - A ogni nuovo incontro il timer dell'attacco base riparte dal proprio intervallo (come i nemici, F-77).
  - Con due spade (assetto `alternate` e spada nell'offhand) la mano cambia dopo **ogni** attacco base, riuscito o no;
    l'intervallo successivo è quello della nuova mano. In difesa valgono le stat della mano 0 (F-74: le stat non
    d'attacco sono i totali normali).
  - Un nemico morto nello stesso istante non attacca (01 §10.9, F-76); i morti restano nella lista con `hp` 0 (la
    posizione non cambia); `target` -1 se non c'è nessun vivo.
  - `combat.respawn_ms` 0: il nuovo incontro parte nello stesso istante.
  - `between`: `enemies` vuoto in `get_state` e nel save; `get_state` in `idle` ha `player_hp` = massimo.
  - In `idle` (dopo `stop`, morte, sostituzione o un load in `idle`) `area_id()`, `get_state()["area"]` e il campo `area`
    del save sono `""` (deciso in M5-07). Nel save di un motore in `idle` contano solo borsa e contatori: `player_hp`,
    `player_timer_ms`, `hand` e `between_ms` si scrivono `0` (normalizzazione da fare in M6-02, nota "da M5-07"), così
    save → load → save di un motore fermo è identico byte per byte.
  - Statistiche del giocatore in cache, scartate su `modifiers_changed`, `equipment_changed`, `character_level_up`;
    se il nuovo massimo è minore, i PV attuali scendono al massimo (01 §10.9).
  - `eat()` a PV pieni: `ok` senza consumare (come `AutoEat.eat_one`); il contatore `food_eaten` conta i pezzi tolti
    dalla bank (differenza della quantità del cibo scelto), sia per `eat` sia per `after_hit`.
  - `from_save`: stato diverso da `encounter`/`between` → `idle`; nemici malformati → `idle` con `Log.warn`; un
    `encounter` senza nemici vivi riprende come `between` con `combat.respawn_ms` pieno; `hp` dei nemici limitato a
    `[0, max]`, timer a `[0, intervallo]`; PV del giocatore ≥ 1 (il limite al massimo arriva con la ricostruzione dei
    modificatori); conteggi `kills` di mostri non presenti in nessun gruppo scartati con `Log.warn`.
- Helper interni (non contratto per gli altri moduli): `CombatEngine.PLAYER = -1` (convenzione di §3) e
  `SHARD_ITEM = &"rift_shard"` (id fisso, come `GatheringResolver.SHARD_ITEM` e la regola del validatore degli
  oggetti); `class_name Encounter` (`systems/combat/encounter.gd`): nemici di un incontro (`Enemy`: `def`, `stats`,
  `hp`, `timer_ms`), `spawn` (F-77), `target(rule)` (F-76, regole `first`/`lowest_hp`/`highest_hp`),
  `roll_attack` (ordine dei tiri sopra), `to_save`/`from_save`, `alive_indices()` (M6-02); `find_area`/`is_known_monster`
  sono rimossi (M6-02: `GameData.has_area`/`has_monster`, §4).
- File di M6-02 (interni al modulo): `CombatSave` (`combat_save.gd`: `write(snapshot)`/`read(d, data)` statici del formato
  di §6; un motore `idle` scrive `player_hp`, `player_timer_ms`, `hand`, `between_ms` a 0, `area` `""`, `enemies` `[]`,
  `effects` `{}`, così save -> load -> save è identico); `KillRewards` (`kill_rewards.gd`, `grant(session, loot, def)`:
  xp, oro, drop, frammento); `EffectSet` (`effects/effect_set.gd`: effetti dei tratti di `Loadout.active_traits()`,
  dispatch degli agganci, emette `trait_triggered`) e `TraitEffect` con un file per tipo di F-81. Per M6-03: i colpi
  delle abilità passano da `EffectSet.hit(ctx, damage)` (altrimenti `leech_pct` non cura).

### 5.11 Shop (`systems/shop/shop.gd`) — dipendenze: data, events, modifiers, bank, wallet, skills, character, armory
```gdscript
const SAVE_KEY := &"shop"
func purchase_count(entry_id: StringName) -> int
func price(entry_id: StringName) -> int               # F-17 / F-82 per formula, altrimenti cost_gold
func can_buy(entry_id: StringName) -> CommandResult   # unknown_id, max_purchases, requirement_not_met, not_enough_gold, bank_full, armory_full
func buy(entry_id: StringName) -> CommandResult
func sell_value(item_id: StringName, qty: int) -> int # F-18
func sell(item_id: StringName, qty: int) -> CommandResult   # invalid_amount, unknown_id, item_locked, not_sellable, not_enough_items
func sell_instance(uid: int) -> CommandResult         # M4-05: unknown_id, item_locked, item_equipped, not_sellable; F-18 con qty 1
func rebuild_modifiers() -> void                      # sorgenti shop:<id> (F-19)
```
M10: `Shop.new_game()` imposta gli acquisti di `start.purchases` (senza oro né segnali; i modificatori `shop:<id>` si ricostruiscono
con `rebuild_modifiers`); `sell_instance` di un attrezzo unico → `item_unique` (prima di `item_equipped`).
Da M4-05: requisiti con `req_character` (`character.meets_requirements`); effetto `item` di una base `equipment`/`tool`
→ `qty` istanze comuni con `armory.create(base, &"common", 1)`, controllo `armory_full` con `armory.can_add(qty)` al posto
di `bank_full`; `price` con `cost_formula = &"armory_slot"` → F-82. `sell_instance` toglie il pezzo dall'Armeria e
aggiunge l'oro, poi `item_sold(base_id, 1, gold)`.
Comportamento (M3-02):
- `can_buy`/`buy`: controlli nell'ordine della firma; `max_purchases` 0 = illimitato; `bank_full` solo per effetti
  `item` (`Bank.can_add`). Un errore non cambia nulla (oro non speso). Riuscito: oro speso, effetto applicato (oggetto
  nella bank, oppure sorgente `shop:<id>` con valori × acquisti, F-19), poi `shop_purchased`.
- `price` di una voce sconosciuta → 0. `sell_value` di un oggetto sconosciuto o con `qty <= 0` → 0.
- `sell`: controlli nell'ordine della firma; riuscito: oggetti tolti, oro aggiunto, poi `item_sold`.
- Save (§6): `{"purchases": {entry_id: n}}`, solo le voci comprate almeno una volta. `from_save` tollerante, con
  `Log.warn`: `purchases` non oggetto → nessun acquisto; voce sconosciuta o conteggio non intero o ≤ 0 → scartato;
  conteggio oltre `max_purchases` (se > 0) → limitato a `max_purchases`. Nessun segnale; i modificatori si ricostruiscono
  con `rebuild_modifiers`.

### 5.12 RiftAltar (`systems/rift/rift_altar.gd`, M8) — dipendenze: data, events, modifiers, bank, skills
```gdscript
const SAVE_KEY := &"rift"
const SKILL := &"riftbinding"
func socket_total() -> int                     # numero di voci in rift.sockets
func is_unlocked(index: int) -> bool
func get_socket(index: int) -> StringName      # &"" se vuota
func socket(index: int, item_id: StringName) -> CommandResult   # socket_locked, socket_occupied, not_equippable, not_enough_items, requirement_not_met (unique)
func clear_socket(index: int) -> CommandResult  # slot_empty; distrugge l'infusione
func rebuild_modifiers() -> void               # sorgenti rift_socket:<i>
```

### 5.13 Offline (`res://core/offline/`)
```gdscript
class_name OfflineSimulator extends RefCounted
static func compute_elapsed(saved_at_unix_ms: int, now_unix_ms: int, cap_ms: int) -> int    # F-40
static func is_capped(saved_at_unix_ms: int, now_unix_ms: int, cap_ms: int) -> bool      # F-40: tempo via > cap_ms
static func chunk_count(elapsed_ms: int, chunk_ms: int) -> int                           # F-41: ceil(elapsed / chunk_ms), 0 se <= 0
static func advance_silently(session: GameSession, elapsed_ms: int) -> void
    # sotto offline.min_ms: stessi blocchi senza segnali ne riepilogo; play_time_ms ripristinato
func run(session: GameSession, elapsed_ms: int, capped: bool, yield_frames: bool = true) -> OfflineSummary
    # coroutine (await): blocchi da offline.chunk_ms (F-41); emette offline_started/progress/completed su session.events;
    # con yield_frames = false (test) non aspetta frame

class_name OfflineSummary extends RefCounted
var elapsed_ms: int; var capped: bool
var xp: Dictionary[StringName, int]; var levels: Dictionary[StringName, Vector2i]   # x = da, y = a
var items: Dictionary[StringName, int]         # differenza (positiva = ottenuti, negativa = consumati)
var gold_delta: int; var kills: Dictionary[StringName, int]; var deaths: int; var food_eaten: int
var stop_reasons: Array[StringName]
var stop_times_ms: Array[int]                  # tempo offline di ogni stop (parallelo a stop_reasons); M10 (B3): ms dall'INIZIO dell'offline (blocchi già fatti + tempo nel blocco), mai relativi al blocco: una morte dopo 3 h 12 m dice 3 h 12 m
var pieces_stored: int; var pieces_dismantled: int; var pieces_rejected: int   # Armeria: conservati / smantellati dal filtro / persi per Armeria piena
var bank_rejected: Dictionary[StringName, int]  # rese che non entrano nella banca (anche rese di smantellamento automatico)
static func from_snapshots(before: SessionSnapshot, after: SessionSnapshot, elapsed_ms: int, capped: bool, stop_reasons: Array[StringName]) -> OfflineSummary
func is_empty() -> bool
```

### 5.14 Impostazioni (`core/settings/game_settings.gd`)
```gdscript
class_name GameSettings extends RefCounted     # statica; user://settings.cfg; unico file scritto fuori dagli slot
static func get_value(key: String) -> Variant
static func set_value(key: String, value: Variant) -> void
static func save() -> void
static func apply(window: Window) -> void
static var file_path: String                   # default "user://settings.cfg" (i test lo reindirizzano)
static func reset() -> void                    # valori predefiniti (non salva)
static func ui_scale(window: Window) -> float  # ui_scale = 0.0 -> automatica dalla dimensione della finestra
static func apply_volume() -> void             # bus Master
static func apply_log_level() -> void          # Log.level
static func apply_ui_scale(window: Window) -> void
# chiavi: window_mode, window_size, ui_scale, vsync, fps_limit, volume, log_level
```

### 5.15 Hint (M9) e Fratture (M12)
```gdscript
class_name HintsSystem extends RefCounted      # systems/hints/hints_system.gd (M9); dipendenze: data, events
const SAVE_KEY := &"hints"
func is_seen(hint_id: StringName) -> bool
func mark_seen(hint_id: StringName) -> void
func connect_triggers() -> void                # ascolta session.events; ogni trigger emette hint_triggered una sola volta per slot (se non visto)
func new_game() -> void                        # svuota visti e in attesa
func to_save() -> Dictionary                   # {"seen": [id, ...]} nell ordine del file hints.json
func from_save(d: Dictionary) -> void          # tollerante: lista errata = nessuno visto; id sconosciuti scartati con Log.warn
func pending() -> Array[StringName]            # attivati e non ancora chiusi; volatile, mai salvato

class_name FractureSystem extends RefCounted   # systems/fractures/fracture_system.gd (M12); dipendenze: data, events, modifiers, rng, combat
const SAVE_KEY := &"fractures"
func active_id() -> StringName
func time_left_ms() -> int
func next_in_ms() -> int
func bonus_monster_for_area(area_id: StringName) -> StringName
func advance(delta_ms: int) -> void            # F-50
func rebuild_modifiers() -> void               # sorgente fracture:<id>
```

### 5.15b UI di M9 (sola lettura/comandi; nessuno stato di gioco)
```gdscript
class_name OfflineOverlay extends Control      # ui/screens/offline/; static func attach(parent: Node, source: GameEvents = null) -> OfflineOverlay
    # ascolta offline_started/progress/completed; mostra la barra solo se elapsed_ms >= offline.min_ms; a fine run apre il riepilogo
class_name OfflineSummaryView extends Control  # signal closed; static func open(parent: Node, summary: OfflineSummary, data: GameData) -> OfflineSummaryView; func shown_lines() -> PackedStringArray
class_name OfflineTexts extends RefCounted     # testi italiani del riepilogo; static func duration(ms: int) -> String; static func reason_text(reason: StringName) -> String
class_name HintCard extends Control            # ui/feedback/; signal shown(hint_id), closed(hint_id); var is_blocked: Callable
func bind(session: GameSession) -> void; func unbind() -> void; func current_hint() -> StringName; func queued() -> Array[StringName]
func close_current() -> void                   # mark_seen sul modello + passa al successivo; refresh()
class_name SettingsPanel extends Control       # ui/settings/; signal closed; var in_game: bool; var game: GameScript; var scene_changer: Callable; var apply_window: Callable
    # legge/scrive solo GameSettings; in partita mostra "Salva ed esci" (end_session + scene_changer)
class_name ToastManager extends Control        # al massimo UiStyle.TOAST_MAX_VISIBLE visibili; oltre UiStyle.TOAST_PENDING_MAX in attesa scarta il piu vecchio
```
M13 non aggiunge classi: estende `ActionRunner` (corsia `SECONDARY`, `lanes_available()` con F-51). Le firme di M12
si rivedono a inizio M12 (Fratture come mappe, `01_GDD.md` §17).

### 5.16 CharacterSystem (`systems/character/character_system.gd`) — dipendenze: data, events, modifiers, skills
```gdscript
const SAVE_KEY := &"character"
const REQUIREMENT_KEY := &"character"          # chiave riservata dei requisiti
func class_id() -> StringName
func class_def() -> ClassDef
func get_xp() -> int
func get_level() -> int                        # F-71
func get_progress() -> float
func add_xp(base_amount: int) -> int           # F-71 (skill_xp_pct global); restituisce l'XP data
func meets_requirements(requirements: Dictionary) -> bool
    # chiave "character" → get_level(); le altre → skills.meets_requirements; valore non numerico → false
```
- `new_game`: classe `character.start_class`, XP 0. `add_xp` emette `character_xp_gained` e poi un `character_level_up`
  per livello, dopo il cambio. XP base negativa: `Log.error`, 0.
- Save (§6): `{"class": id, "xp": int}`. `from_save` tollerante, con `Log.warn`: classe sconosciuta → `start_class`;
  XP non intera o negativa → 0, oltre il tetto → tetto. Nessun segnale.
- `GameSession.total_level()` = `skills.total_level() + character.get_level()` (da M4-03).

### 5.16b Loadout (`systems/character/loadout.gd`, M6) — dipendenze: data, events, modifiers, character, equipment, combat (solo `in_encounter`)
```gdscript
const SAVE_KEY := &"loadout"
func trait_slots() -> int                      # F-78
func ability_slots() -> int                    # F-78
func get_trait(slot_index: int) -> StringName  # &"" se vuoto
func get_ability(slot_index: int) -> StringName
func set_trait(slot_index: int, trait_id: StringName) -> CommandResult
    # &"" toglie; slot_locked, unknown_id, level_too_low, requirement_not_met (già in un altro slot), combat_active
func set_ability(slot_index: int, ability_id: StringName) -> CommandResult   # stessi motivi
func active_traits() -> Array[TraitDef]        # in ordine di slot, ammessi dall'assetto attuale (equipment.setup())
func active_abilities() -> Array[AbilityDef]   # in ordine di slot, ammesse dall'assetto attuale
func rebuild_modifiers() -> void               # sorgenti trait:<id> dei tratti attivi
```
- `ClassDef` non ha helper per id: `Loadout` scorre `traits`/`abilities`. Esistono `TraitDef.allows_setup(setup_id)` e
  `AbilityDef.allows_setup(setup_id)` (`setups` vuoto = tutti gli assetti).
- Riuscito: `traits_changed`; su `equipment_changed` dell'arma/offhand ricostruisce i modificatori (l'assetto può
  cambiare). `combat_active` se `session.combat != null and session.combat.in_encounter()`.
- Save (§6): `{"traits": [id | ""], "abilities": [id | ""]}`. `from_save` tollerante: id sconosciuti, non della classe,
  non sbloccati, duplicati o in slot non aperti → vuoti, con `Log.warn`. Nessun segnale.

### 5.17 Armory (`systems/armory/armory.gd`) — dipendenze: data, events, modifiers, rng, bank, wallet, skills (per `level_too_low`)
> Nota (M10-03): `use_currency` su un attrezzo unico non è definito (risponde `item_equipped`).
```gdscript
class_name ItemInstance extends RefCounted     # systems/items/item_instance.gd
var uid: int; var base_id: StringName; var rarity: StringName; var ilvl: int
var affixes: Array[AffixRoll]; var upgrade: int; var sockets: Array[StringName]; var locked: bool
func duplicate_instance() -> ItemInstance
func to_dict() -> Dictionary; static func from_dict(d: Dictionary, data: GameData) -> ItemInstance   # null se non valida
class_name AffixRoll extends RefCounted        # systems/items/affix_roll.gd
var affix_id: StringName; var tier: int; var value: float   # tier da 1

class_name Armory extends RefCounted
const SAVE_KEY := &"armory"
func capacity() -> int                         # F-82
func used() -> int                             # pezzi non indossati
func can_add(count: int = 1) -> bool
func add(inst: ItemInstance) -> int            # assegna il uid e lo restituisce; 0 + armory_rejected se piena
func create(base_id: StringName, rarity: StringName, ilvl: int) -> int   # ItemRoller.create + add; 0 se piena o base non equipment/tool
func get_instance(uid: int) -> ItemInstance    # copia; null se assente
func instances() -> Array[ItemInstance]        # copie, ordine di inserimento
func has(uid: int) -> bool
func is_worn(uid: int) -> bool
func set_worn(uid: int, worn: bool, quiet: bool = false) -> void   # solo Equipment; quiet = nessun segnale (Equipment.from_save)
func set_locked(uid: int, locked: bool) -> CommandResult   # unknown_id
func remove(uid: int) -> CommandResult         # unknown_id, item_locked, item_equipped
func instance_modifiers(uid: int) -> Array[Modifier]       # ItemRoller.instance_modifiers
func upgrade(uid: int, use_seal: bool = false) -> CommandResult   # M7, F-86
    # rifiuti, in ordine: unknown_id, upgrade_max (Reasons.UPGRADE_MAX), not_enough_gold, not_enough_items
    # (lingotti, frammenti, Sigillo se use_seal e il passo può far scendere); atomico: rifiuto = nessun cambiamento
func salvage(uid: int) -> CommandResult        # M7, F-95 (M10; era F-88): unknown_id, item_unique, item_locked, item_equipped, bank_full (nulla cambia)
func add_drop(inst: ItemInstance) -> int       # M7: ingresso dei drop; uid se in Armeria, 0 se smantellato (filtro o piena)
func set_filter(slot: StringName, min_rarity: StringName, min_grade: int) -> CommandResult   # unknown_id, invalid_amount
func filter_rule(slot: StringName) -> Dictionary          # {"min_rarity", "min_grade"}; "common"/1 = tieni tutto
func filter_rules() -> Dictionary                         # slot -> regola, solo quelle diverse da "tieni tutto"
func is_filtered(inst: ItemInstance) -> bool              # il pezzo sarebbe smantellato dal filtro
func socket_count(uid: int) -> int                       # M8, F-89: castoni del pezzo (Sockets.count)
func socket_stone(uid: int, stone_id: StringName) -> CommandResult   # M8: unknown_id, not_equippable (non è una pietra), socket_locked (0 castoni), socket_occupied, not_enough_items
func clear_socket(uid: int, index: int) -> CommandResult  # M8: unknown_id, slot_empty; distrugge la pietra (Q8)
func upgrade_tool(uid: int) -> CommandResult  # M10, F-94: sempre riuscita; unknown_id, not_a_tool, upgrade_max, level_too_low (mestiere), not_enough_gold, not_enough_items; atomico
func tool_next_step(uid: int) -> Dictionary   # M10: {} se non è un attrezzo o è a +9; altrimenti {"target", "min_level", "grade", "plates": ItemQty, "handles": ItemQty, "gold", "interval_pct"} (sola lettura, per la UI)
func tool_uid(slot_id: StringName) -> int     # M10: uid dell'attrezzo unico dello slot tool_* (0 se assente)
func new_game() -> void                       # M10: crea il kit iniziale (start.armory, poi start.tools), comune, senza affissi; uid 1…n
func use_currency(uid: int, currency_id: StringName) -> CommandResult   # M8-09, GDD §26: effetti to_magic / to_rare / reroll; unknown_id, not_equippable (non è una valuta), item_locked, item_equipped, requirement_not_met (rarità non adatta), not_enough_items; atomico
```
- M10: `upgrade_tool` consuma `plates` e `handles` dalla bank e l'oro, incrementa `upgrade`, emette `armory_changed(uid, updated)` e
  `item_upgraded(uid, true, new_level)`; le sorgenti `equipment:tool_*` si ricostruiscono come per ogni pezzo indossato (`Equipment` ascolta
  `armory_changed`). `set_locked`/`remove`/`salvage` su un attrezzo unico → `item_unique`. `upgrade` (F-86) su un attrezzo unico → `not_equippable`
  (la raffinazione degli attrezzi ha solo `upgrade_tool`). `salvage` (F-95): componenti del progetto
  della base (`GameData.blueprint_for_base`) × `salvage.component_ratio`, più frammenti; le rese entrano nella bank (`bank_full` come prima).
- M7: il Sigillo (`upgrade.seal_item`) si consuma solo a fallimento con `use_seal` quando il passo parte da
  `N ≥ upgrade.downgrade_from`; altrimenti non serve e non si consuma. `upgrade` emette `armory_changed(uid, updated)` e
  `item_upgraded`; `salvage` emette `armory_changed(uid, removed)`, la capacità e `item_salvaged(auto=false)`.
- M8: `socket_stone` e `clear_socket` emettono `armory_changed(uid, updated)`; `ItemInstance.sockets` contiene solo le pietre presenti (nessuna voce vuota), le prime `Sockets.count` sono attive, le altre restano nel pezzo e tornano attive se i castoni risalgono (raffinazione).
- Il filtro non ha segnale: la UI (M7-06) rilegge `filter_rules()` a ogni apertura/aggiornamento della pagina.
- `add`/`create` emettono `armory_changed(uid, &"added")` e `armory_capacity_changed`; `remove`, `set_locked`,
  `set_worn` emettono `armory_changed` (`removed`/`updated`); `set_worn` cambia `used()`.
- `uid` crescenti da 1 (`next_uid` salvato), mai riusati.
- Save (§6): `{"next_uid": int, "items": [ItemInstance.to_dict()], "filter": {slot: {"min_rarity": str, "min_grade": int}}}`
  (`filter` additivo, `format_version` invariata; assente = tieni tutto; regole non valide → `Log.warn` e scartate) (`to_dict`: `uid`, `base`, `rarity`, `ilvl`,
  `affixes` `[{"affix", "tier", "value"}]`, `upgrade`, `sockets`, `locked`). `from_save` tollerante: voce non valida, base
  sconosciuta o non `equipment`/`tool`, `uid` duplicato → `Log.warn` e scartata; `next_uid` minore o uguale al massimo
  `uid` → massimo + 1. Non controlla la capienza. Il flag indossato non si salva (lo rimette
  `Equipment.from_save` con `set_worn(uid, true, true)`, senza segnali). `set_worn` non controlla la capienza.

### 5.18 ItemRoller (`systems/items/item_roller.gd`) — logica pura, nessuno stato
```gdscript
class_name ItemRoller extends RefCounted
static func drop_chances(source: StringName, rarity_pct: float, data: GameData) -> Vector2     # F-84 (M7): &"monster" / &"rift_stone"
static func roll_rarity(chances: Vector2, rng: RngService) -> StringName                     # F-84: &"common"/&"magic"/&"rare" (un randf)
static func blueprint_rare_chance(forging_level: int, rarity_pct: float, data: GameData) -> float   # M10, F-91: p_rare 0..100
static func create_from_blueprint(bp: ItemDef, forging_level: int, rarity_pct: float, chosen_affix: StringName, data: GameData, rng: RngService) -> ItemInstance   # M10, F-91/F-92: uid 0, mai common; ilvl = livello del grado; chosen_affix &"" = nessuna scelta
static func chosen_affix_candidates(base: ItemDef, ilvl: int, data: GameData) -> Array[AffixDef]   # M10, F-92: per la UI
static func roll_affixes(base: ItemDef, rarity: StringName, ilvl: int, data: GameData, rng: RngService) -> Array[AffixRoll]   # F-85
static func extend_affixes(base: ItemDef, rarity: StringName, ilvl: int, existing: Array[AffixRoll], data: GameData, rng: RngService) -> Array[AffixRoll]   # M8: aggiunge affissi F-85 fino al numero della rarita, senza duplicare quelli in existing
static func create(base: ItemDef, rarity: StringName, ilvl: int, data: GameData, rng: RngService) -> ItemInstance   # uid 0
static func instance_modifiers(inst: ItemInstance, data: GameData) -> Array[Modifier]
    # base × F-86 (upgrade) + un modificatore per affisso (scope di 04_DATA_SCHEMA §15) + castoni (M8)
```
- Ordine dei tiri su `rng`: rarità (un `randf`), numero di affissi, poi per ogni affisso scelta, grado, valore (F-85). Con un affisso scelto
  (F-92) il primo affisso non ha il tiro di scelta né di grado; per un attrezzo unico `instance_modifiers` non applica F-86 ma F-94
  (intervallo a N più gli `upgrade_extras` con `at ≤ N`).

### 5.19 Guida in gioco (M11; `01_GDD.md` §27, `04_DATA_SCHEMA.md` §19) — sola lettura dei dati, nessuno stato, nessun salvataggio
```gdscript
class_name GuidePageDef extends RefCounted     # core/data/defs/guide_page_def.gd
var id: StringName; var section: StringName; var title: String; var order: int
var blocks: Array[Dictionary]                  # come nel file (type, text, source, targets)
var help_for: PackedStringArray; var allow_digits: bool
# GameData (M11-02): carica data/guide/*.json e lo valida con gli altri dati
func guide_pages() -> Array[GuidePageDef]      # ordinate per sezione, order, id
func guide_page(id: StringName) -> GuidePageDef   # null + Log.error se manca
func guide_exceptions() -> Dictionary          # {"no_source": Array[StringName], "no_use": Array[StringName]}

class_name GuideIndex extends RefCounted       # core/guide/guide_index.gd (dipendenze: data); costruito da GameData, immutabile
func _init(data: GameData) -> void
static func entry(kind: StringName, id: StringName) -> StringName   # id canonico di una pagina generata: &"item:<id>", &"monster:<id>", &"area:<id>", &"skill:<id>", &"stat:<id>", &"trait:<id>", &"ability:<id>"
func sources_of(item_id: StringName) -> Array[GuideRef]    # "Si ottiene da": drop dei mostri (con area e %), ricette/progetti, shop, Pietre del Rift, smantellamento, kit iniziale
func uses_of(item_id: StringName) -> Array[GuideRef]       # "Serve a": ricette, progetti, raffinazione, castoni, Altare, cibo
func items_without_source() -> Array[StringName]           # per i test: esclude no_source delle eccezioni
func items_without_use() -> Array[StringName]              # per i test: esclude no_use delle eccezioni
func summary_line(refs: Array[GuideRef], max_entries: int = 3) -> String   # "a, b, c e altro" (tooltip)

class_name GuideRef extends RefCounted         # core/guide/guide_ref.gd
var kind: StringName                           # monster / recipe / blueprint / shop / rift_stone / salvage / starter_kit / refine / socket / altar / food
var target: StringName                         # pagina collegata (id canonico di entry())
var label: String                              # nome da mostrare (dai dati)
var detail: String                             # opzionale, es. area e percentuale (numeri dai dati, mai scritti a mano)

class_name GuideText extends RefCounted        # core/guide/guide_text.gd: risoluzione dei segnaposto (logica pura)
static func resolve(text: String, data: GameData) -> String                       # sostituisce {balance:…}, {stat:…}; {link:…} diventa il solo testo
static func parse_links(text: String) -> Array[Dictionary]                        # [{"kind","id","label","start","end"}] per la UI
static func validate(text: String, data: GameData, allow_digits: bool) -> PackedStringArray   # errori (vuoto = ok): segnaposto o link sconosciuti, cifre a mano

class_name GuideTables extends RefCounted      # core/guide/guide_tables.gd: tabelle generate dai dati per i blocchi `table`
static func ids() -> PackedStringArray         # sorgenti dichiarate (es. affix_tiers, refine_costs, traits, abilities, actions:<skill>)
static func build(source: String, data: GameData) -> Array[Array]                   # righe di testo, la prima è l'intestazione; sorgente sconosciuta: Log.error e []
static func page_ids(data: GameData) -> Array[StringName]                           # tutte le pagine: scritte a mano + generate (una per entità)
```
- `sources_of`/`uses_of` seguono l'ordine dei dati. Un `item_id` sconosciuto → `[]` con `Log.error`.
- La Guida non emette né ascolta segnali dell'`EventBus`, non entra in `GameSession` né nel salvataggio (si ricostruisce da `GameData`).

## 6. Formato del salvataggio (`user://saves/slot_<n>.json`)

Versione 3 da M10 (v2 da M4-03, D3). Un save v1 o v2 non si carica (`version_unsupported`, nessuna migrazione: nessun giocatore reale ancora).
```json
{
  "format_version": 3,
  "game_version": "0.2.0",
  "slot": 2,
  "player_name": "Davide",
  "created_at_unix_ms": 1793600000000,
  "saved_at_unix_ms": 1793603600000,
  "play_time_ms": 3600000,
  "total_level": 31,
  "rng": {"seed": 918273, "state": "1234567890123"},
  "modules": {
    "wallet": {"gold": 1250},
    "bank": {"stacks": [{"item": "redbirch_log", "count": 412, "locked": false},
                        {"item": "rift_shard", "count": 3, "locked": true}]},
    "skills": {"forestry": {"xp": 15320}, "forging": {"xp": 4100}},
    "mastery": {"forestry": {"pool": 2210, "actions": {"cut_redbirch": 9800}, "nodes": ["forestry_n1_quick_axe"]}},
    "character": {"class": "rift_blade", "xp": 4100},
    "loadout": {"traits": ["chain_cleave", ""], "abilities": ["whirl", ""]},
    "armory": {"next_uid": 4, "items": [
      {"uid": 1, "base": "emberbronze_sword", "rarity": "magic", "ilvl": 1,
       "affixes": [{"affix": "keen", "tier": 1, "value": 4}], "upgrade": 0, "sockets": [], "locked": false},
      {"uid": 3, "base": "hatchet", "rarity": "common", "ilvl": 1, "affixes": [], "upgrade": 3,
       "sockets": [], "locked": true}]},
    "equipment": {"slots": {"weapon": 1, "tool_forestry": 3}, "food": "seared_brookfin"},
    "actions": {"lanes": {"main": {"skill": "forestry", "action": "cut_redbirch", "elapsed_ms": 1200}}},
    "combat": {"state": "between", "area": "redrock_plains", "player_hp": 52, "player_timer_ms": 800, "hand": 0,
               "between_ms": 700, "enemies": [],
               "abilities": {"whirl": 3000}, "buffs": {}, "effects": {"chain_cleave": {"count": 2}},
               "loot": [{"item": "boar_tusk", "qty": 2}], "kills": {"plains_boar": 41}, "deaths": 1, "food_eaten": 12},
    "shop": {"purchases": {"bank_slot": 3, "auto_eat_1": 1}},
    "rift": {"sockets": ["inf_swift_hands", "", "", "", ""]},
    "hints": {"seen": ["first_action"]},
    "fractures": {"active": "", "time_left_ms": 0, "next_in_ms": 9000000}
  }
}
```
Regole: chiavi assenti in `modules` = stato di partita nuova per quel sistema (così aggiungere un sistema non richiede
migrazioni); id sconosciuti al caricamento vengono scartati con `Log.warn`; enum sempre come stringhe; `total_level`,
`player_name`, `saved_at_unix_ms`, `play_time_ms` in testa servono al menu senza caricare tutto. I modificatori e le
statistiche derivate non si salvano. Lo stato del giocatore non esiste fuori da questo file. In `combat.enemies` ogni
voce è `{"monster", "hp", "timer_ms"}` (posizione = indice); `loadout` e `abilities`/`effects`/`buffs` di `combat` esistono da M6.

## 7. Contratti della UI (`res://ui/`)

```gdscript
class_name Page extends Control                 # ui/pages/page.gd; base di tutte le pagine
var page_id: StringName
func bind(session: GameSession) -> void         # virtuale: collega EventBus, prima lettura dello stato
func unbind() -> void                           # virtuale: scollega tutto

class_name PageHost extends Control             # ui/screens/main/page_host.gd
signal page_changed(page_id: StringName)
const ROUTE_SEPARATOR: String = ":"
const ROUTE_SKILL := &"skill"
const ROUTES: Dictionary[StringName, String]    # rotta -> scena della pagina (estende Page); assente = "In arrivo"
                                                # oggi: skill -> skill_page.tscn, bank -> bank_page.tscn, shop -> shop_page.tscn (M3-06), equipment -> equipment_page.tscn (M3-07) (nessun segnaposto)
                                                # aggiunte: armory -> armory_page.tscn (M4-08), character -> character_page.tscn (M4-09), combat -> combat_page.tscn (M5-05), rift (M8)
func setup(session: GameSession) -> void        # null: unbind e liberazione della pagina corrente
func show_page(page_id: StringName) -> void     # &"skill:<id>", &"character", &"combat", &"armory", &"equipment", &"bank", &"shop", &"rift", &"settings"
func has_page(page_id: StringName) -> bool      # rotta in ROUTES; per skill:<id> skill di raccolta/artigianato con azioni
func current_page_id() -> StringName            # &"" se nessuna pagina
static func route_of(page_id: StringName) -> StringName      # &"skill:forestry" -> &"skill"
static func argument_of(page_id: StringName) -> StringName   # &"skill:forestry" -> &"forestry"; &"" se assente

class_name MainScreen extends Control           # ui/screens/main/main_screen.gd (+ .tscn): TopBar, Sidebar, PageHost, toast
var session: GameSession = null                 # iniettabile prima di _ready; null = Game.session
var menu_action: Callable = Callable()          # () -> void; non valido = Game.end_session(true) e poi main_scene

class_name Sidebar extends PanelContainer       # ui/screens/main/sidebar.gd (+ .tscn)
signal page_requested(page_id: StringName)
func bind(session: GameSession, is_available: Callable) -> void   # is_available: (page_id: StringName) -> bool
func unbind() -> void
func set_current(page_id: StringName) -> void
# Da M4-09: voci fisse Personaggio, Combattimento, Armeria, Equipaggiamento, Bank, Shop (Altare da M8), poi le skill di
# raccolta e artigianato dai dati (le 5 skill di combattimento non esistono più; niente voci "In arrivo" per loro).

class_name TopBar extends PanelContainer        # ui/screens/main/top_bar.gd (+ .tscn): oro, caselle, nome · slot, Menu
signal menu_requested
func bind(session: GameSession) -> void
func unbind() -> void

class_name SkillPage extends Page                # ui/pages/skill/skill_page.gd (+ .tscn), rotta skill:<id>
const REFUSED_TEXTS: Dictionary[StringName, String]   # motivo di actions.start -> testo; altri: REFUSED_TEXT_DEFAULT

class_name ActionCard extends PanelContainer      # ui/pages/skill/action_card.gd (+ .tscn), interna a SkillPage
signal toggle_requested(action_id: StringName)    # la pagina manda start o stop
func setup(action: ActionDef, data: GameData) -> void   # una volta, dopo l'ingresso nell'albero: parti dai dati
func redraw(session: GameSession) -> void         # livello, intervallo (current_interval_ms), maestria, azione in corso
func set_progress(progress: float) -> void        # 0..1 letto da actions.get_progress
func action_id() -> StringName                    # &"" prima di setup
static func seconds_text(ms: int) -> String       # = NumberFormat.format_seconds(ms): 3000 -> "3,0 s", 2700 -> "2,7 s"

class_name RecipeCard extends ActionCard         # ui/pages/skill/recipe_card.gd (+ .tscn ereditata da action_card.tscn), M3-05
# nessun segnale nuovo (usa toggle_requested); stesse setup/redraw. SkillPage la crea per le azioni con inputs.
# redraw aggiunge: una riga per ingrediente distinto con "posseduti / richiesti" (bank.get_count; UiStyle.BAD se mancano),
# preservation_chance e double_item_chance da modifiers.total con ModifierContext.for_action, Avvia disabilitato se
# ArtisanResolver.can_start fallisce (tranne la ricetta in corso, che si può sempre fermare).
# SkillPage la ridisegna anche su bank_changed (collegato solo se la pagina ha ricette).

### 7.x UI della riforma del bottino (M10; nessuno stato di gioco nella UI, solo letture e comandi)
```gdscript
class_name BlueprintSection extends VBoxContainer     # ui/pages/skill/blueprint_section.gd (+ .tscn), interna a SkillPage; solo per la skill forging
func setup(data: GameData) -> void                    # una volta: elenco dei progetti dai dati (GameData.blueprints())
func redraw(session: GameSession) -> void             # progetti posseduti (bank), requisiti con "posseduti / richiesti", durata (BlueprintCraft.duration_ms), XP, probabilità di raro (ItemRoller.blueprint_rare_chance), lavoro in corso (actions.blueprint_state)
signal start_requested(blueprint_id: StringName, chosen_affix: StringName)   # la pagina chiama actions.start_blueprint; il rifiuto va in MessageLabel
signal stop_requested                                 # la pagina chiama actions.stop
# Scelta dell'affisso: lista di ItemRoller.chosen_affix_candidates, visibile e abilitata solo se il livello del Fabbro >= balance blueprint.choose_affix_level;
# la scelta corrente è stato di presentazione ammesso (nessuna copia di dati). Nodi per i test: Blueprint_<id>, AffixChoice, StartButton, StopButton, ProgressBar.
class_name ToolUpgradePanel extends PanelContainer    # ui/pages/skill/tool_upgrade_panel.gd (+ .tscn), interno a SkillPage delle 3 skill di raccolta
func redraw(session: GameSession) -> void             # attrezzo (armory.tool_uid + get_instance, "Accetta +N"), tool_next_step (costo con "posseduti / richiesti", livello minimo del mestiere), effetti attuali (modifiers.breakdown con ModifierContext.for_skill)
signal upgrade_requested(uid: int)                    # la pagina chiama armory.upgrade_tool; rifiuto in MessageLabel
```
- `SkillPage` mostra `BlueprintSection` per `forging` e `ToolUpgradePanel` per `forestry`, `quarrying`, `angling`; ridisegno su `bank_changed`,
  `armory_changed`, `level_up`, `action_started/stopped`, `blueprint_crafted`.
- `ArmoryPage`/`ArmoryItemPanel`: nessun pulsante Vendi/Smantella/Blocca per un attrezzo unico (non compare nell'elenco dell'Armeria: sta nello slot);
  l'anteprima dello smantellamento mostra le rese di F-95. La riga dell'attrezzo in `EquipmentPage` mostra "Accetta +N" senza "Rimuovi".
- `ToastManager`/UI dei livelli (B5): i `level_up` e i `character_level_up` ravvicinati (stesso passo del frame) della stessa skill si fondono in un solo
  toast "Boscaiolo: livello 2 → 5" (`NumberFormat`-style, testo in `UiStyle`/`LevelToastTexts` definito una volta); il banner del livello mostra l'ultimo.
- `CombatPage` (B2): all'avvio (`combat_started`) se `equipment.get_food()` è vuoto o a quantità 0, `MessageLabel` mostra `CombatTexts.NO_FOOD_WARNING`
  (non impedisce l'avvio, nessun nuovo motivo di rifiuto); tolto al primo cibo scelto o a `combat_stopped`.
- Testi (B4/Q52): "Deposito" al posto di "Bank" in sidebar, pagina, shop e tooltip (`UiStyle`/testi centralizzati, nessuna stringa "Bank" visibile);
  il primo suggerimento (`first_action`) punta al combattimento; i nomi di skill, oggetti, aree e mostri vengono dai dati (`NOMI.md` in M10-05).

class_name BankPage extends Page                 # ui/pages/bank/bank_page.gd (+ .tscn), rotta bank
const REFUSED_TEXTS: Dictionary[StringName, String]   # motivo di un comando della bank -> testo; altri: REFUSED_TEXT_DEFAULT
const REFUSED_TEXT_DEFAULT: String
const NO_MATCH_TEXT: String                      # griglia vuota per la ricerca (con la bank non vuota)

class_name BankItemPanel extends PanelContainer  # ui/pages/bank/bank_item_panel.gd (+ .tscn), interno a BankPage
signal lock_requested(item_id: StringName, locked: bool)   # la pagina manda bank.set_locked; locked letto da bank.is_locked
signal sell_requested(item_id: StringName, qty: int)       # M3-06: la pagina manda shop.sell e mostra il motivo (REFUSED_TEXTS)
                                                           # equip_requested (M3-07) tolto in M4-08: equipment/tool non sono nella bank, si equipaggia dall'ArmoryPage
signal food_requested(item_id: StringName)                 # M3-07: la pagina manda equipment.set_food; "Usa come cibo" solo se is_food, disabilitato ("Cibo scelto") se è già il cibo
signal close_requested
func show_item(session: GameSession, item_id: StringName) -> bool   # rilegge tutto; false (e clear) se assente o sconosciuto
func clear() -> void                             # nasconde e dimentica l'oggetto
func item_id() -> StringName                     # &"" se chiuso
# Tiene l'id mostrato e il riferimento alla sessione dell'ultimo show_item (solo per leggere: is_locked, get_count,
# shop.sell_value a ogni uso; nessuna copia dello stato). Sezione vendita: cursore 1..quantità, anteprima
# shop.sell_value, "Vendi" / "Tutti tranne 1" / "Tutti" (quantità lette dalla bank alla pressione); disabilitata con
# una nota se l'oggetto è bloccato o ha valore 0.

class_name ShopPage extends Page                 # ui/pages/shop/shop_page.gd (+ .tscn), rotta shop (M3-06)
const REFUSED_TEXTS: Dictionary[StringName, String]   # motivo di can_buy/buy -> testo; altri: REFUSED_TEXT_DEFAULT
const REFUSED_TEXT_DEFAULT: String
# Righe di data.shop_entries() per categoria, costruite in bind. Prezzo da shop.price, "Acquisti x / max" solo se
# max_purchases > 0, requisiti mancanti (req_entries, req_character, req_skills, req_total_level confrontati con shop,
# character e skills; req_character da M4-09).
# Compra abilitato solo se shop.can_buy riesce, altrimenti motivo accanto al pulsante e nel tooltip; errore di buy in
# %MessageLabel. Ridisegno su shop_purchased, item_sold, gold_changed, bank_changed, level_up (scollegati in unbind).

class_name EquipmentPage extends Page            # ui/pages/equipment/equipment_page.gd (+ .tscn), rotta equipment (M3-07)
const REFUSED_TEXTS: Dictionary[StringName, String]   # motivo di unequip/set_food -> testo; altri: REFUSED_TEXT_DEFAULT
const REFUSED_TEXT_DEFAULT: String
# Righe di Equipment.SLOTS (pezzo da equipment.get_uid + armory.get_instance: nome della base nel colore
# UiStyle.rarity_color, "+N" (ArmoryTexts.piece_name); "Rimuovi" = unequip), assetto (equipment.setup_def(): SetupDef.name
# o "Mani nude"), cibo (food_heal dai dati, quantità
# dalla bank o "Esaurito", "Togli" = set_food(&"")). La stance non c'è più (M4-08). Riepilogo: solo stat del registro
# (data.stats) con almeno una sorgente, totale da modifiers.total, sorgenti da modifiers.breakdown; per gli attrezzi
# anche le sorgenti con ambito della skill (ModifierContext.for_skill). Si equipaggia dall'ArmoryPage. Ridisegno su
# equipment_changed, food_changed, modifiers_changed, bank_changed, armory_changed (scollegati in unbind).

class_name ArmoryPage extends Page               # ui/pages/armory/armory_page.gd (+ .tscn), rotta armory (M4-08)
const REFUSED_TEXTS: Dictionary[StringName, String]   # motivo di equip/set_locked/sell_instance -> testo
const REFUSED_TEXT_DEFAULT: String
# Griglia di armory.instances() con filtro per slot e rarità (colori UiStyle.RARITY_*), capienza used/capacity.
# Pannello del pezzo (ArmoryItemPanel, interno): nome della base, rarità, ilvl, affissi (AffixDef.name e valore),
# modificatori (Armory.instance_modifiers), requisiti, confronto con il pezzo indossato nello stesso slot,
# "Equipaggia" (per una spada: "In mano" / "Seconda mano"), "Blocca", "Vendi" (shop.sell_instance); da M7 raffina e
# smantella. Nessuna copia dello stato: il pannello tiene solo l'uid. Ridisegno su armory_changed,
# armory_capacity_changed, equipment_changed, character_level_up (scollegati in unbind).
# Il confronto con il pezzo indossato elenca le differenze (candidato meno indossato) senza colori buono/cattivo.
# Stato di presentazione ammesso: i due filtri e l'uid selezionato. Costanti di presentazione: UiStyle.ARMORY_*.

class_name ArmoryItemPanel extends PanelContainer   # ui/pages/armory/armory_item_panel.gd (+ .tscn), interno ad ArmoryPage (M4-08)
signal equip_requested(uid: int, slot: StringName)  # la pagina manda equipment.equip(uid, slot); slot &"" = slot della base, &"offhand" = "Seconda mano"
signal unequip_requested(slot: StringName)          # la pagina manda equipment.unequip (slot letto da equipment.slot_of)
signal lock_requested(uid: int, locked: bool)       # la pagina manda armory.set_locked
signal sell_requested(uid: int)                     # la pagina manda shop.sell_instance
signal close_requested
func show_piece(session: GameSession, uid: int) -> bool   # rilegge armory, equipment, character, shop; false (e clear) se il pezzo non c'è più
func clear() -> void                                # nasconde e dimentica il pezzo
func uid() -> int                                   # 0 se chiuso
# Tiene l'uid e il riferimento alla sessione dell'ultimo show_piece (solo per leggere, come BankItemPanel). Requisiti
# in UiStyle.BAD se character.meets_requirements fallisce. "In mano"/"Seconda mano" solo per un'arma a una mano dello
# slot weapon; "Vendi" disabilitato con una nota se il pezzo è indossato, bloccato o ha valore 0.

class_name ArmoryCell extends PanelContainer        # ui/pages/armory/armory_cell.gd (+ .tscn), interna ad ArmoryPage (M4-08)
signal pressed(uid: int)                            # clic sinistro
signal hover_started(uid: int)                      # la pagina mostra il tooltip del pezzo (Tooltips.show_text con titolo vuoto: il nome nel colore della rarità è la prima riga del corpo, ItemTooltipLines.colored_title, M5-00)
signal hover_ended
func set_piece(inst: ItemInstance, base: ItemDef, worn: bool, selected: bool) -> void   # icona, bordo di rarità, "+N", segni bloccato/indossato
func uid() -> int                                   # 0 prima del primo set_piece; non legge la sessione

class_name ArmoryTexts extends RefCounted           # ui/pages/armory/armory_texts.gd, solo statiche, senza stato (M4-08)
const RARITY_NAMES: Dictionary[StringName, String]  # common/magic/rare -> Comune/Magico/Raro (testi di presentazione, come Q42)
const CAPACITY_TEXT: String                         # "Pezzi: %s / %s" (M5-00)
const CAPACITY_WORN_TEXT: String                    # "Pezzi: %s / %s (+%s indossati)" (M5-00)
static func capacity_text(used: int, capacity: int, worn: int) -> String   # contatore dell'Armeria; "(+N indossati)" solo se worn > 0 (i pezzi indossati non occupano capienza)
static func rarity_name(rarity: StringName) -> String               # sconosciuta: Log.warn e l'id
static func piece_name(inst: ItemInstance, base: ItemDef) -> String # "Nome +N" se upgrade > 0, altrimenti il nome della base
static func affix_lines(inst: ItemInstance, data: GameData) -> PackedStringArray   # "<AffixDef.name> <valore> (grado N)"; affisso assente: Log.warn, nessuna riga
static func comparison_lines(candidate: Array[Modifier], worn: Array[Modifier], data: GameData) -> PackedStringArray   # differenze per (stat, scope), formato di modifier_lines

class_name CharacterPage extends Page            # ui/pages/character/character_page.gd (+ .tscn), rotta character (M4-09)
# Classe (ClassDef.name/description), livello e XpBar del personaggio (character.get_level/get_progress), sezione Assetto
# (titolo ItemTooltipLines.SETUP_LABEL) con gli assetti della classe in lista e quello in uso evidenziato (M5-00: niente
# riga "In uso", niente CurrentSetupLabel), valori base F-70 (M5-05: sezione StatsTitle/StatsList,
# CombatantStats.for_player in sola lettura, nomi delle stat da stats.json con CombatTexts.stat_line). Da M6 gli slot
# di tratti e abilità (loadout). Ridisegno su character_xp_gained, character_level_up, equipment_changed e (M5-05)
# modifiers_changed (scollegati in unbind).

class_name CombatPage extends Page               # ui/pages/combat/combat_page.gd (+ .tscn), rotta combat (M5-05)
# 01_GDD §10.11: scelta dell'area (requisiti con character.meets_requirements), carta del giocatore e una carta per
# nemico da combat.get_state(), numeri del danno su combat_hit, borsa con "Raccogli tutto", Mangia; nessuno stato
# dell'incontro nella UI.
# M5-05: lettura di combat.get_state() sui segnali di combattimento (combat_started/stopped, encounter_*, *_hp_changed,
# monster_killed, food_*, bank_changed, loot_bag_changed, equipment_changed, combat_hit, player_died, character_level_up)
# e in _process (solo le barre di PV e timer, sola lettura); comandi combat.start/stop/eat e combat.loot.collect_all,
# motivo del rifiuto in MessageLabel; messaggio di sconfitta su player_died, tolto al successivo combat_started.
# Nodi per i test: Area_<id>, Enemy_<i>, PlayerCard, StopButton, EatButton, CollectButton, LootList, MessageLabel.
# Costanti di presentazione: UiStyle.COMBAT_* (margini, larghezza della lista delle aree, carta, bordo del bersaglio,
# barre, numero del colpo e dissolvenza, altezza del bottino, colore del timer).
func bind(session: GameSession) -> void
func unbind() -> void                            # anche in _exit_tree

class_name CombatantCard extends PanelContainer  # ui/pages/combat/combatant_card.gd (+ .tscn), carta di un combattente, senza stato
func setup(title: String, subtitle: String) -> void
func redraw(hp: int, max_hp: int, timer_ms: int, interval_ms: int, is_target: bool) -> void
func show_hit(hit: bool, damage: int, blocked: bool, color: Color) -> void   # danno, CombatTexts.MISS_TEXT o BLOCKED_TEXT, dissolvenza sul posto
func hit_text() -> String; func shown_hp() -> int; func is_highlighted() -> bool; func shown_timer() -> float   # per i test

class_name CombatTexts extends RefCounted        # ui/pages/combat/combat_texts.gd, testi fissi della pagina (come ArmoryTexts/MasteryTexts)
# Titoli, stati (STATE_TEXTS per stato del motore), pulsanti, cibo, borsa, PV, intervallo, Mancato/Parato, REASON_TEXTS,
# DEFEAT_TEXT; nomi di aree, mostri, cibo e bottino dai dati; requisito con ItemTooltipLines.CHARACTER_REQUIREMENT_TEXT.
const STAT_NAME_SOURCES: Dictionary[StringName, StringName]   # accuracy/evasion/max_hp -> stat di stats.json da cui si legge il nome
static func stat_line(data: GameData, key: StringName, value: int) -> String   # "<nome della stat>: <valore>" (CharacterPage, F-70)
static func seconds_text(ms: int) -> String     # "2,0"

class_name EquipmentStatsText extends RefCounted # ui/pages/equipment/equipment_stats_text.gd, testi di EquipmentPage (M3-07), senza stato
static func slot_text(slot: StringName, data: GameData) -> String     # etichetta; tool_<id> -> "Attrezzo: <nome skill dai dati>" o "Attrezzo"
static func summary(session: GameSession) -> String                  # BBCode: blocco globale + un blocco per skill (for_skill meno le sorgenti globali)
static func source_name(source_id: StringName, session: GameSession) -> String   # nome leggibile di una sorgente (05 §5.2); setup:<id> -> "Assetto: <SetupDef.name>" (M5-00)
const SOURCE_SETUP_PREFIX: String                # "setup:" (M5-00)

class_name MasteryPanel extends GameWindow       # ui/pages/mastery/mastery_panel.gd (+ .tscn), figlia di SkillPage
const POOL_WARNING_KEY: String = "mastery.pool_warning_pct"   # soglia dell'avviso letta da session.data.balance_value
func bind(session: GameSession, skill_id: StringName) -> void # skill senza maestria: Log.warn e NO_MASTERY_TEXT
func unbind() -> void                            # anche su closed e in _exit_tree

class_name MasteryActionRow extends PanelContainer   # ui/pages/mastery/mastery_action_row.gd (+ .tscn), interna al pannello
signal select_requested(action_id: StringName)   # l'azione diventa il bersaglio della spesa del pool
func setup(action: ActionDef) -> void            # una volta, dopo l'ingresso nell'albero
func redraw(session: GameSession, selected: bool) -> void   # livello e barra di maestria (mastery_table)
func action_id() -> StringName                   # &"" prima di setup

class_name MasteryNodeTree extends Control       # ui/pages/mastery/mastery_node_tree.gd, interno al pannello
signal buy_requested(node_id: StringName)        # inoltrato dalle carte; il pannello manda mastery.buy_node
func setup(nodes: Array[MasteryNodeDef], data: GameData) -> void   # una carta per nodo, posta per pos [col, riga]
func redraw(session: GameSession) -> void        # carte e collegamenti (oro se il prerequisito è comprato)
func clear() -> void                             # libera le carte e dimentica la sessione

class_name MasteryNodeView extends PanelContainer   # ui/pages/mastery/mastery_node_view.gd (+ .tscn), carta di un nodo
signal buy_requested(node_id: StringName)
func setup(node: MasteryNodeDef, data: GameData) -> void   # nome, modificatori (ItemTooltipLines.modifier_lines)
func redraw(session: GameSession) -> void        # costo (mastery.node_cost), stato, pulsante Acquista
func node_id() -> StringName                     # &"" prima di setup
func grid_pos() -> Vector2i                      # pos dei dati
func required_ids() -> Array[StringName]         # requires dei dati
static func state_of(session: GameSession, id: StringName) -> StringName   # MasteryTexts.STATE_*: owns_node, poi
                                                 # can_buy_node(id): ok -> buyable, pool_insufficient -> unaffordable,
                                                 # altri motivi -> locked

class_name MasteryTexts extends RefCounted       # ui/pages/mastery/mastery_texts.gd, solo statiche e costanti
const STATE_OWNED / STATE_BUYABLE / STATE_LOCKED / STATE_UNAFFORDABLE   # &"owned", &"buyable", &"locked", &"unaffordable"
const REASON_TEXTS: Dictionary[StringName, String]   # motivi di spend_pool_on_action/buy_node; altri: REASON_TEXT_DEFAULT
const WINDOW_TITLE: String                       # "Maestria: %s"
static func reason_text(reason: StringName) -> String
static func state_text(state: StringName) -> String   # stato sconosciuto: testo di STATE_LOCKED

class_name ItemSlotView extends PanelContainer  # ui/components/item_slot/item_slot.gd (+ .tscn)
signal pressed(item_id: StringName)
func set_item(item: ItemDef, count: int, locked: bool = false) -> void   # count 0 = quantità non mostrata; altrimenti
                                                # NumberFormat.format_compact, etichetta tagliata (il tooltip ha il numero intero)
func clear() -> void
func item_id() -> StringName                    # &"" se vuota
static func icon_of(path: String) -> Texture2D  # icona dei dati; file assente: Log.warn e UiStyle.MISSING_ICON

class_name ActionProgressBar extends ProgressBar   # ui/components/progress/action_progress_bar.gd
func set_progress(value: float) -> void            # 0..1, animazione continua

class_name XpBar extends Control                   # ui/components/progress/xp_bar.gd (+ .tscn)
func set_xp(table: XpTable, xp: int) -> void       # xp cumulativa; "<xp> / <xp del livello dopo> XP"
func shown_progress() -> float                     # frazione del livello disegnata (test, accessibilità)
func shown_text() -> String

class_name ConfirmDialog extends ConfirmationDialog   # ui/components/confirm_dialog/confirm_dialog.gd
static func ask(parent: Node, title: String, text: String) -> bool   # coroutine

# ui/screens/main_menu/main_menu.gd (scena principale, senza class_name): variabili iniettabili, prima di _ready
var game: GameScript = null                        # preload di core/autoload/game.gd; null = autoload Game
var data: GameData = null                          # dati da controllare; null = DataRegistry.data
var scene_changer: Callable = Callable()           # (path: String) -> Error; non valido = change_scene_to_file

class_name SlotSelect extends Control              # ui/screens/slot_select/slot_select.gd (+ .tscn), figlia del menu
signal game_started                                # solo dopo new_game/continue_game con ok
signal closed                                      # "Menu principale": il menu torna visibile
const MODE_NEW := &"new"                           # = SlotRow.MODE_NEW
const MODE_CONTINUE := &"continue"                 # = SlotRow.MODE_CONTINUE
var game: GameScript = null                        # null = autoload Game; da impostare prima di open
func open(mode: StringName) -> void                # rilegge list_slots() e mostra l'elenco

class_name SlotRow extends PanelContainer          # ui/screens/slot_select/slot_row.gd (+ .tscn), interna a SlotSelect
signal chosen(slot: int)
signal delete_requested(slot: int)
func setup(info: SlotInfo, mode: StringName) -> void   # dopo l'ingresso nell'albero; tiene solo il numero dello slot

class_name SlotTexts extends RefCounted            # ui/screens/slot_select/slot_texts.gd, solo statiche e costanti
const STATE_EMPTY / STATE_OK / STATE_CORRUPTED / STATE_UNSUPPORTED  # i valori di SlotInfo.state
static func reason_text(reason: StringName) -> String   # invalid_name con i limiti di balance.json (Game.NAME_*_KEY)
static func state_text(state: StringName) -> String
static func slot_title(info: SlotInfo) -> String        # "Slot 2" o "Slot 2  ·  Aria"
static func slot_details(info: SlotInfo) -> String      # data, tempo di gioco, livello totale; o il testo dello stato
static func play_time(ms: int) -> String                # "12 min", "1 h 05 min"
static func saved_at(unix_ms: int) -> String            # data e ora locali "03/11/2026 14:05"

class_name ToastManager extends Control            # ui/components/toast/toast_manager.gd (nella MainScreen)
var events: GameEvents = null                      # null = autoload EventBus; i test passano GameEvents.new()
var time_source: Callable = Time.get_ticks_msec    # () -> int, millisecondi
var name_resolver: Callable                        # (id: StringName) -> String; default: l'id stesso
func push(text: String, kind: StringName) -> void  # kind: &"info" | &"success" | &"warning"

class_name Toast extends PanelContainer            # ui/components/toast/toast.gd (+ toast.tscn), interno a ToastManager
signal dismissed                                   # fine della dissolvenza, prima di queue_free
func setup(text: String, kind: StringName) -> void # kind sconosciuto: Log.warn e mostrato come info
func dismiss() -> void                             # idempotente

class_name CustomTooltip extends PanelContainer    # ui/components/tooltip/custom_tooltip.gd (+ .tscn), interno a Tooltips
func setup_item(item: ItemDef, count: int, data: GameData) -> void
func setup_text(title: String, body: String) -> void   # body può contenere BBCode
func show_at(cursor_pos: Vector2) -> void          # globale; spostato di UiStyle.TOOLTIP_MOUSE_OFFSET, nel viewport
func hide_tooltip() -> void                        # nasconde e svuota i testi
func is_shown() -> bool
func title_text() -> String                        # testi senza BBCode (test, accessibilità)
func body_text() -> String
func footer_text() -> String

class_name ItemTooltipLines extends RefCounted     # ui/components/tooltip/item_tooltip_lines.gd, solo statiche
static func subtitle(item: ItemDef, count: int) -> String          # categoria e, se count > 0, "Quantità: 1.250"
static func body(item: ItemDef, data: GameData) -> PackedStringArray   # requisiti, arma, modificatori, cibo, valore
static func modifier_lines(mods: Array[Modifier], data: GameData) -> PackedStringArray   # una riga per (stat, scope): i modificatori con la stessa stat e lo stesso scope si sommano (ordine di prima comparsa, M5-00)
static func colored_title(text: String, color: Color) -> String    # nome in grassetto nel colore dato (nome del pezzo nel colore della rarità, M5-00)
const SETUP_LABEL: String                                          # "Assetto" (M5-00)
const SETUP_SOURCE_TEXT: String                                    # "Assetto: %s", sorgente setup:<id> (M5-00)
const COMBAT_TEXT: String                                          # "Combattimento": voce della sidebar e categoria combat dello shop, definizione unica (M5-00)
static func format_stat(format: String, value: float) -> String    # pct "+5%", flat "+8", flag "Sì"/"No"
static func category_name(category: StringName) -> String
static func escape(text: String) -> String                         # BBCode dei testi dei dati
const STYLE_NAMES: Dictionary[StringName, String]                  # Q42: blade/marksmanship/arcana -> Lama/Mira/Arcano (testi della UI, M4-08)
const CHARACTER_REQUIREMENT_TEXT: String                           # Q42: "Richiede il livello %d del personaggio"
static func style_name(style: StringName) -> String                # stile sconosciuto: Log.warn e l'id
static func requirement_text(key: StringName, needed: int, data: GameData) -> String   # chiave character (CharacterSystem.REQUIREMENT_KEY) o skill
static func weapon_line(weapon: WeaponInfo) -> String              # "Stile <nome>, un attacco ogni N s[, a due mani]"

class_name UiStyle extends RefCounted              # ui/theme/ui_style.gd, costanti di presentazione e helper
static func rarity_color(rarity: StringName) -> Color              # RARITY_COMMON/MAGIC/RARE; altro: RARITY_UNKNOWN (M4-08)
static func build_theme() -> Theme                                 # inoltro a UiThemeBuilder.build() (tools/build_ui_theme.gd, test del tema)

class_name UiThemeBuilder extends RefCounted       # ui/theme/ui_theme_builder.gd, solo statiche (M4-08)
static func build() -> Theme                       # tema da UiStyle; riftstone_idle_theme.tres rigenerato con tools/build_ui_theme.gd
# Variante WindowPanel opaca (UiStyle.BG_WINDOW_OPAQUE): la usano GameWindow (maestria), menu e SlotSelect; nessuna
# scena ridefinisce lo sfondo dei pannelli con un override locale.

class_name NumberFormat extends RefCounted         # ui/theme/number_format.gd, solo statiche; unica definizione dei formati
static func format_int(value: int) -> String                       # "1.250"
static func format_number(value: float) -> String                  # "1.250,5" (al massimo due decimali)
static func format_seconds(ms: int) -> String                      # "3,0 s", "2,7 s", "0,25 s": da uno a due decimali
static func format_compact(value: int) -> String                   # < COMPACT_FROM (10000) come format_int; poi tre cifre
                                                # significative troncate e suffisso K, M, Mld, Bln, Bld, Trl:
                                                # 12345 -> "12,3K", 999999 -> "999K", 1200000 -> "1,2M"; per celle strette

class_name GameWindow extends PanelContainer       # ui/components/game_window/game_window.gd; figlio "VBox" con la pagina
signal opened
signal closed
@export var title: String
@export var close_tooltip: String
@export var default_size: Vector2                  # prima apertura: centrata, al massimo lo spazio libero
func toggle() -> void
func open_window() -> void                         # emette opened
func close_window() -> void                        # emette closed solo se era aperta
```
`Tooltips`/`ItemTooltipLines`: ogni riga di modificatore prende nome e formato da `StatRegistry.info()`; una stat non
registrata non ha riga (e `Log.warn`); senza `GameData` valido requisiti e modificatori non si mostrano (e `Log.warn`).
I requisiti sono in grigio: il tooltip non legge la sessione.
`ToastManager`: le variabili iniettabili si impostano prima di aggiungere il nodo all'albero (connessione in
`_enter_tree`, disconnessione in `_exit_tree`). Ascolta `notification_requested`, `bank_changed` (solo `delta > 0`,
sommati per oggetto in una finestra di `UiStyle.TOAST_GROUP_MS` dal primo aumento), `level_up`, `action_stopped`
(nessun toast per `stopped_by_user` e `replaced`); `session_ended` scarta i gruppi aperti. Al massimo
`UiStyle.TOAST_MAX_VISIBLE` toast visibili, gli altri in coda. Le costanti di presentazione sono `UiStyle.TOAST_*`.
`ConfirmDialog.ask` aggiunge il dialogo (esclusivo) sotto `parent`, aspetta la risposta (Conferma → `true`; Annulla, Esc,
chiusura → `false`) e lo libera; il segnale interno `_answered` non fa parte del contratto. I test rispondono emettendo
`confirmed`/`canceled` sul figlio `ConfirmDialog`.
Menu e `SlotSelect` (M1-13): nessun file scritto aprendo e chiudendo il menu (solo `list_slots`); Nuova partita/Continua
solo con `data.is_valid()`, Continua solo con uno slot `ok`. `SlotSelect` rilegge `list_slots()` a ogni ridisegno, chiede
conferma prima di sovrascrivere uno slot `ok` e prima di `delete_slot`; danneggiati e non supportati si possono solo
eliminare; ogni comando fallito mostra `SlotTexts.reason_text`. Il menu cambia scena solo dopo `game_started`; se il cambio
fallisce: `Log.error`, `end_session(true)` e messaggio. I test usano una sottoclasse di `game.gd` mai aggiunta all'albero.
Le pagine non tengono stato di gioco: solo riferimenti alla sessione e ai nodi. Ogni ridisegno legge dai getter.
Pagine e schermata principale (M1-14): ogni pagina si collega a `session.events` (non all'autoload `EventBus`) in `bind`
e scollega tutto in `unbind`. `PageHost.show_page` istanzia la scena della rotta, imposta `page_id`, la aggiunge e chiama
`bind`; la pagina precedente riceve `unbind` ed è liberata; una pagina non disponibile (`has_page` falso) o la mancanza
di sessione danno `Log.warn` e lasciano la pagina corrente; la stessa pagina non si ricrea. `MainScreen` legge la
sessione in `_ready` (non aspetta `session_started`), crea il `ToastManager` con `events = session.events`, apre la
prima pagina di skill disponibile (altrimenti `bank`) e su `session_ended` scollega TopBar, Sidebar, PageHost e toast;
lo stesso quando la schermata esce dall'albero. Le voci della Sidebar senza pagina sono disabilitate con "In arrivo"
(`is_available` = `PageHost.has_page`); il livello delle skill si ridisegna su `level_up`, la TopBar su `gold_changed` e
`bank_capacity_changed`. Numeri via `NumberFormat`; costanti di presentazione di tooltip e GameWindow in
`UiStyle.TOOLTIP_*`/`UiStyle.WINDOW_*`.
Pagina skill (M1-15): `SkillPage` legge la skill da `PageHost.argument_of(page_id)` in `bind` (skill sconosciuta:
`Log.warn`, pagina vuota), crea per ogni azione di `actions_for_skill` una `ActionCard` (una `RecipeCard` se ha `inputs`) e si collega a sei segnali di
`session.events`: `xp_gained`, `level_up`, `action_started`, `action_stopped`, `mastery_xp_gained`, `modifiers_changed`
(più `bank_changed` se ha ricette, per ridisegnare solo le `RecipeCard`; tutti scollegati in `unbind` e in `_exit_tree`). `_process` è attivo solo tra `bind` e `unbind` e legge soltanto
`actions.get_progress()` (la carta dell'azione in corso riceve il progresso, le altre 0). L'intervallo mostrato è
`actions.current_interval_ms`; una carta sotto il livello richiesto è bloccata (pulsante disabilitato). Un `start`
rifiutato mostra `REFUSED_TEXTS` sotto l'intestazione; i motivi di stop del runner diventano toast nel `ToastManager`.
`ItemSlotView` tiene l'`ItemDef` e la
quantità dell'ultimo `set_item` solo per il proprio tooltip (copia di presentazione, mai letta da altri): chi la usa
chiama di nuovo `set_item` quando la quantità cambia. Costanti di presentazione di menu, slot e dialogo:
`UiStyle.MENU_PANEL_WIDTH`, `SLOT_PANEL_WIDTH`, `MENU_BUTTON_HEIGHT`, `MENU_TITLE_FONT_SIZE`, `DIALOG_SIZE`.
Bank minima (M1-18): `BankPage` disegna una `ItemSlotView` per voce di `bank.stacks()`, nell'ordine della bank (caselle
riusate per indice, quelle in più liberate; nessuna casella vuota disegnata), il contatore "Caselle: usate / capienza"
da `bank.used()`/`bank.capacity()`, la riga di bank piena (`used >= capacity`) e "La bank è vuota.". Si collega a
`bank_changed` e `bank_capacity_changed` di `session.events` e a ognuno rilegge tutto (nessuna copia delle quantità oltre
quella di presentazione di `ItemSlotView`); scollega in `unbind` e in `_exit_tree`. Solo vista: blocco, ordine,
spostamento e vendita arrivano con M2-04/M3-06.
Bank completa (M2-04): ricerca per nome (sottostringa senza distinzione di maiuscole, ordine della bank conservato;
nessun risultato: `NO_MATCH_TEXT`), "Ordina" = `bank.sort_stacks()`, click su una casella (`ItemSlotView.pressed`) apre
il `BankItemPanel` accanto alla griglia, che si rilegge a ogni ridisegno e si chiude quando l'oggetto lascia la bank.
Trascinamento con `set_drag_forwarding` (dati `{"kind": &"bank_stack", "item": id}`): rilascio su una casella →
`move_stack` all'indice di quella casella nella bank (anche con la ricerca attiva); rilascio sulla griglia fuori dalle
caselle (spaziature comprese) → ultimo indice. Un comando rifiutato non cambia nulla e mostra `REFUSED_TEXTS` sopra la
griglia; la griglia cambia solo attraverso gli eventi della bank. Stato di presentazione ammesso: testo della ricerca,
oggetto del pannello, casella sotto il mouse (il suo tooltip si rilegge dopo ogni ridisegno e si chiude se la casella
sparisce). Costanti di presentazione: `UiStyle.BANK_*` (margine, separazioni, `BANK_CELL_SIZE`, pannello, ricerca).
Vendita, equipaggia e cibo nel pannello: M3-06/M3-07, con segnali nuovi del pannello e comandi mandati dalla pagina. I secondi mostrati dalla UI passano tutti da `NumberFormat.format_seconds`.
Pannello della maestria (M2-03): `SkillPage` mostra `%MasteryButton` ("Maestria", nell'intestazione) solo per le skill
con `has_mastery`; il pulsante crea il `MasteryPanel` alla prima pressione (figlio della pagina, liberato con essa), lo
collega con `bind(session, skill_id)` e lo apre, o lo chiude se è aperto; l'`unbind` della pagina chiude il pannello.
Il pannello è collegato a `session.events` solo mentre è aperto, a tre segnali: `mastery_pool_changed` (pool e albero),
`mastery_node_purchased` (albero), `mastery_xp_gained` (riga dell'azione); `closed`, `unbind` e `_exit_tree` li
scollegano. Barra del pool `get_pool`/`get_pool_cap`; l'avviso (testo e barra in `UiStyle.BAD`) compare con
`pool × 100 >= cap × mastery.pool_warning_pct` (`balance.json`, letta da `session.data`). Righe: una per
`mastery_actions_for_skill`, la prima è il bersaglio iniziale della spesa. Spesa: cursore da 1 al pool (al pool
all'apertura), "Spendi" = `mastery.spend_pool_on_action(bersaglio, importo)`. Albero: una carta per
`mastery_nodes(skill)` in una griglia per `pos` (`UiStyle.MASTERY_NODE_SIZE`, `MASTERY_NODE_GAP`), collegamenti dai
prerequisiti; lo stato è sempre `MasteryNodeView.state_of` (nessuna copia dei nodi comprati); "Acquista" visibile per
comprabile e pool insufficiente (disabilitato), = `mastery.buy_node`. Ogni comando rifiutato mostra
`MasteryTexts.reason_text` e non cambia nulla; il modello cambia solo con i comandi e la vista solo con gli eventi.
Stato di presentazione ammesso: azione bersaglio e valore del cursore. Costanti di presentazione: `UiStyle.MASTERY_*`.

### 7.y UI della Guida (M11; nessuno stato di gioco, solo letture dei dati; la cronologia è stato di presentazione)
```gdscript
class_name GuidePage extends Page              # ui/pages/guide/guide_page.gd (+ .tscn), rotta guide (voce "Guida" della sidebar, sezione Partita)
func open_entry(entry_id: StringName) -> void # apre una pagina (id di GuideIndex.entry o di una pagina a mano); sconosciuta: Log.error e resta dov'è
func go_back() -> bool                         # false se la cronologia è vuota
func search(query: String) -> Array[StringName]   # pagine il cui titolo contiene query (senza maiuscole/accenti); vuota: indice completo
signal entry_opened(entry_id: StringName)
# Nodi per i test: IndexTree, ContentView, SearchEdit, BackButton, ResultsList. Contenuto da GuideText/GuideTables/GuideIndex; i link chiamano open_entry.
class_name HelpButton extends Button           # ui/components/help/help_button.gd (+ .tscn): "?" nell'intestazione di ogni pagina di gioco
@export var guide_entry: StringName            # pagina di Guida da aprire; deve esistere (verificato da test)
signal guide_requested(entry_id: StringName)  # la shell apre la rotta guide e chiama open_entry
```
- Tooltip (`ItemTooltipLines`): in fondo "Si ottiene da: …" e "Serve a: …" con `GuideIndex.summary_line` (3 voci + "e altro"); riga omessa se la
  lista è vuota. Il tooltip delle stat usa la descrizione di `stats.json` (`Tooltips.show_text`). Nessuna copia dei dati nella UI.
- Nessun testo di Guida è scritto nel codice: titoli e contenuti vengono da `data/guide/` e dai dati.

## 8. Helper dei test (`res://tests/helpers/`)

```gdscript
class_name TestFactory extends RefCounted          # tests/helpers/test_factory.gd
static func fixture_data() -> GameData             # contenuto: res://tests/fixtures/data, config: res://data/config
static func real_data() -> GameData                # res://data
static func session(seed_value: int = 1234, data: GameData = null) -> GameSession   # GameEvents nuovo, new_game() fatto
static func give(session: GameSession, item_id: StringName, qty: int) -> void        # via bank.add, assert ok
static func set_level(session: GameSession, skill_id: StringName, level: int) -> void # via skills.add_xp con xp_for_level
static func set_character_level(session: GameSession, level: int) -> void            # M4-03: via character.add_xp
static func give_piece(session: GameSession, base_id: StringName, rarity: StringName = &"common", ilvl: int = 1) -> int
    # M4-05: via armory.create, assert uid > 0; restituisce l'uid
```
`give` di un oggetto `equipment`/`tool` da M4-05 fallisce (`not_stackable`): i test usano `give_piece`.
`fixture_data()`/`real_data()` caricati una volta per esecuzione e condivisi (`GameData` è immutabile); `session()` crea
un `GameEvents` figlio della sessione (si libera con lei), mai l'autoload `EventBus`, mai slot veri. `give` (M1-07) e
`set_level` (M1-08) sono implementati: in caso di fallimento `push_error` + `assert`. GUT segnala `test_factory.gd`
come ignorato (prefisso `test_` ma non estende `GutTest`): avviso innocuo.
`tests/helpers/gut_pre_run.gd` (`extends GutHookScript`, M2-05): imposta `SaveService.base_dir = save_dir()` e svuota
la cartella. Tutti i worktree condividono la stessa `user://`, quindi ogni cartella scritta dai test sta sotto una radice
propria della checkout:
```gdscript
static func checkout_root() -> String          # user://test_runs/<primi 12 caratteri dell'md5 di globalize_path("res://")>
static func test_dir(name: String) -> String   # checkout_root()/<name>: cartella di lavoro di un file di test
static func save_dir() -> String               # test_dir("test_saves"): base_dir di SaveService nei test
```
I test lo raggiungono con `const PreRun := preload("res://tests/helpers/gut_pre_run.gd")` (nessun `class_name`).
Ogni test libera la sessione con `autofree()` (GUT) o `session.free()`.

### Strumento `tools/sim_combat.gd` (non è un'API di gioco)
Opzioni aggiunte in M7-07, oltre a quelle di M5-06: `loot=0|1` (con 1 stampa anche le tabelle di M7: pezzi/ora per rarità,
Pietre del Rift, scontro con la Pietra e costo atteso della raffinazione) e `loadout=none|auto` (con `auto` riempie gli slot
aperti di tratti e abilità con i primi sbloccati consentiti dall'assetto; default `none`). `scope=easiest` include le Pietre.
