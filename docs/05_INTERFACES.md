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
```

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
var base_dir: String = "user://saves"     # i test lo cambiano in user://test_saves
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
const CURRENT_VERSION: int = 1
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
var session: GameSession = null
var active_slot: int = -1
var state: StringName = &"menu"          # &"menu", &"loading", &"offline", &"playing"
var last_offline_summary: OfflineSummary = null
func list_slots() -> Array[SlotInfo]
func new_game(slot: int, player_name: String) -> CommandResult
    # nome 1-24 caratteri dopo strip (invalid_name); crea sessione, new_game(), salva, avvia autosave, state playing
func continue_game(slot: int) -> CommandResult
    # legge, from_save, rebuild_modifiers, poi offline (asincrono: state offline fino alla fine), poi salva e playing
func save_now() -> CommandResult          # slot_not_selected se session == null
func end_session(save: bool = true) -> void   # ferma autosave, salva se richiesto, session.free(), state menu
func delete_slot(slot: int) -> CommandResult  # slot_active se è lo slot della sessione
```
`Game` emette `session_started`/`session_ended` sull'`EventBus`, collega `GameClock.ticked` a `session.advance` in
`playing`, salva su `NOTIFICATION_WM_CLOSE_REQUEST`.

Comportamenti di `Game` (M1-11):
- `_ready`: mette in pausa `GameClock`; con dati validi chiama `GameClock.configure(tick_ms, max_catchup_ms)`,
  `SaveService.configure(slots.count)` e legge `autosave_interval_ms` (tutto da `balance.json`). Dati non validi →
  `Log.error` e nessuna configurazione: ogni slot è fuori intervallo (`io_error`). Non esiste un motivo `data_invalid`:
  la UI controlla `DataRegistry.data.is_valid()` prima di offrire Nuova partita/Continua.
- Clock in pausa in `menu`; si avvia all'ingresso in `playing` e torna in pausa in `end_session` (anche in `_exit_tree`).
- Errori di avvio, nell'ordine: `new_game` → `invalid_name` (nome dopo `strip_edges` fuori da 1-24), poi entrambi →
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
| `equipment_changed` | `slot_id: StringName, item_id: StringName` | Equipment | `&""` = slot vuoto; anche per `&"food"` e `&"stance"` (item_id = id cibo / stance) |
| `modifiers_changed` | — | ModifierService | una volta per modifica o per batch |
| `combat_started` | `area_id: StringName, monster_id: StringName` | CombatEngine | |
| `combat_stopped` | `reason: StringName` | CombatEngine | |
| `monster_spawned` | `monster_id: StringName` | CombatEngine | |
| `combat_hit` | `attacker: StringName, hit: bool, damage: int` | CombatEngine | `attacker` = `&"player"` o `&"monster"` |
| `player_hp_changed` | `hp: int, max_hp: int` | CombatEngine | |
| `monster_hp_changed` | `hp: int, max_hp: int` | CombatEngine | |
| `monster_killed` | `monster_id: StringName` | CombatEngine | |
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
| `hint_triggered` (M6) | `hint_id: StringName` | HintsSystem | |
| `fracture_opened` (M7) | `fracture_id: StringName, duration_ms: int` | FractureSystem | |
| `fracture_closed` (M7) | `fracture_id: StringName` | FractureSystem | |

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
func shop_entry(id: StringName) -> ShopEntryDef
func shop_entries() -> Array[ShopEntryDef]
func hints() -> Array[HintDef]                        # M6: lo aggiunge M6-04 (non esiste in M1-04)
func fractures() -> Array[FractureDef]                # M7: lo aggiunge M7-01 (non esiste in M1-04)
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
const REQUIRED_BALANCE_KEYS: PackedStringArray       # tutte le chiavi di 02_FORMULAS.md §9 dell'MVP
static func validate(raw: Dictionary, errors: PackedStringArray) -> void
    # raw = {"balance", "stats", "skills", "items", "actions", "mastery", "areas", "monsters", "shop"}
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
- `DataValidatorRules` (`data_validator_rules.gd`: strumenti per campi, tipi, intervalli, riferimenti, modificatori;
  regole di maestria, aree, mostri) e `DataValidatorItems` (`data_validator_items.gd`: regole di oggetti, azioni, shop)
  sono classi **interne** di `DataValidator`, non API per gli altri moduli. I limiti di formato dello schema
  (regex degli id, `cost_pct` ≤ 50, `pos` 0..5, max 4 drop, `name` delle stat ≤ 40) sono costanti di queste classi;
  i limiti che dipendono dal bilanciamento si leggono dai dati (`xp_curve.max_level`, `mastery_curve.max_level`,
  `action.min_interval_ms`, `combat.min_attack_interval_ms`, `max` della stat `damage_reduction`).
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
  func is_equippable() -> bool; func is_food() -> bool; func is_infusion() -> bool
class_name EquipInfo  ; var slot: StringName; var requirements: Dictionary[StringName, int]
                        var modifiers: Array[Modifier]; var weapon: WeaponInfo   # null se non arma
class_name WeaponInfo ; var style: StringName; var attack_interval_ms: int; var two_handed: bool
class_name SkillDef
  var id: StringName; var name: String; var description: String; var category: StringName
  var order: int; var icon: String; var color: Color; var has_mastery: bool
  var mastery_bonuses: Array[MasteryBonusRule]
class_name MasteryBonusRule ; var every_levels: int; var at_level: int; var modifiers: Array[Modifier]
class_name ActionDef
  var id: StringName; var skill_id: StringName; var name: String; var level: int
  var interval_ms: int; var xp: int; var mastery: bool; var icon: String
  var inputs: Array[ItemQty]; var outputs: Array[ItemQty]
  func is_artisan() -> bool       # inputs non vuoto
class_name MasteryNodeDef
  var id: StringName; var skill_id: StringName; var name: String; var description: String
  var cost_pct: float; var requires: Array[StringName]; var pos: Vector2i; var modifiers: Array[Modifier]
class_name AreaDef    ; var id: StringName; var name: String; var description: String; var order: int
                        var requirements: Dictionary[StringName, int]; var monster_ids: Array[StringName]
class_name MonsterDef
  var id: StringName; var name: String; var description: String; var icon: String
  var hp: int; var style: StringName; var attack_interval_ms: int
  var attack_level: int; var power_level: int; var defence_level: int
  var accuracy_bonus: int; var power_bonus: int; var evasion_bonus: int; var damage_reduction: float
  var gold_min: int; var gold_max: int; var rift_shard_chance: float; var drops: Array[DropEntry]
class_name ShopEntryDef
  var id: StringName; var name: String; var description: String; var category: StringName
  var cost_gold: int; var cost_formula: StringName      # &"" oppure &"bank_slot"
  var max_purchases: int                                # 0 = illimitato
  var req_entries: Array[StringName]; var req_skills: Dictionary[StringName, int]; var req_total_level: int
  var effect_modifiers: Array[Modifier]; var effect_item: ItemQty   # uno dei due
class_name HintDef (M6)    ; var id: StringName; var title: String; var text: String; var trigger: StringName
class_name FractureDef (M7); var id: StringName; var name: String; var description: String; var weight: int
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
func breakdown(stat: StringName, ctx: ModifierContext = null) -> Array[Dictionary]   # [{source, value}] per i tooltip
func begin_batch() -> void           # sospende modifiers_changed
func end_batch() -> void             # emette una sola volta se qualcosa è cambiato
```
Id delle sorgenti: `equipment:<slot>`, `mastery_item:<action_id>`, `mastery_node:<node_id>`, `shop:<entry_id>`,
`rift_socket:<index>`, `fracture:<id>` (M7).

### 5.3 Sessione (`res://core/session/game_session.gd`)
```gdscript
class_name GameSession extends Node
var data: GameData; var events: GameEvents; var rng: RngService; var modifiers: ModifierService
var wallet: Wallet; var bank: Bank; var skills: SkillsSystem; var mastery: MasterySystem
var equipment: Equipment; var actions: ActionRunner; var combat: CombatEngine
var shop: Shop; var rift: RiftAltar
var hints: HintsSystem            # M6 (null prima)
var fractures: FractureSystem     # M7 (null prima)
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
static func take(session: GameSession) -> SessionSnapshot
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
  presenti (xp/livelli M1-08, bank/oro M1-07, kills/deaths/food_eaten M4-xx).
- `game_session.gd` ≤ 200 righe (test). Da M1-07 i partecipanti al salvataggio stanno in
  `core/session/session_participants.gd` (`class_name SessionParticipants extends RefCounted`, con la classe interna
  `_Participant`): **helper interno** di `GameSession`, non un'API per gli altri moduli (nessuno lo usa o lo referenzia
  fuori da `game_session.gd`). `_join` delega a `SessionParticipants.join`; `new_game`, `to_save`, `from_save` (moduli
  assenti, non oggetti o sconosciuti come sopra) e `rebuild_modifiers` iterano tramite lui, nell'ordine di `_join`.
- Ordine attuale di `_create_systems()`: `wallet`, `bank`, `skills`, `mastery` (`rebuild_fn = mastery.rebuild_modifiers`),
  `actions` (senza `rebuild_fn`; `_tick(_PHASE_ACTIONS, actions.advance)`). I task successivi aggiungono in coda, in ordine
  di dipendenza.
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
func get_count(item_id: StringName) -> int
func has(item_id: StringName, qty: int) -> bool
func can_add(item_id: StringName) -> bool          # già presente o casella libera
func add(item_id: StringName, qty: int) -> CommandResult      # unknown_id, invalid_amount, bank_full
func remove(item_id: StringName, qty: int) -> CommandResult   # invalid_amount, not_enough_items
func capacity() -> int                             # F-16
func used() -> int
func stacks() -> Array[Dictionary]                 # copie: [{"item": StringName, "count": int, "locked": bool}] in ordine
func is_locked(item_id: StringName) -> bool
func set_locked(item_id: StringName, locked: bool) -> CommandResult   # unknown_id se non presente
func move_stack(item_id: StringName, new_index: int) -> CommandResult
func sort_stacks() -> void                         # per categoria (ordine: material, food, equipment, tool, infusion, misc), sort_order, id
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
  `clear_source`). `rebuild_modifiers` (in M1-09) registra solo `mastery_item:*`; `mastery_node:*` arriva con M2-01.
- Metodi dei nodi fino a M2-01: `node_cost` → 0, `owns_node` → false, `can_buy_node`/`buy_node` → `unknown_id`.
- Save (§6): `{skill_id: {"pool": int, "actions": {action_id: xp}, "nodes": []}}` per ogni skill con maestria (`nodes`
  vuoto e ignorato al caricamento fino a M2-01). `new_game` e `from_save` non emettono segnali. `from_save` tollerante:
  skill sconosciute o senza maestria, voci non oggetto, azioni sconosciute o di un'altra skill, valori non interi o
  negativi (i float interi del JSON sono accettati) → `Log.warn` e scartati (a 0); `actions` non oggetto → azioni a 0
  (il pool resta); pool oltre il tetto e xp oltre il 99 → limitati (pool con `Log.warn`).

### 5.8 Azioni (`systems/actions/`) — dipendenze: data, events, modifiers, bank, skills, mastery, rng, combat (solo `stop`)
```gdscript
class_name ActionMath extends RefCounted
static func interval_ms(base_ms: int, interval_pct: float, min_ms: int) -> int          # F-03
static func secondary_interval_ms(interval_ms: int, penalty_pct: float) -> int          # F-51 (M8)

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
const SECONDARY := &"secondary"                    # M8
func start(skill_id: StringName, action_id: StringName, lane: StringName = MAIN) -> CommandResult
    # unknown_id, level_too_low, missing_inputs, lane_unavailable, skill_in_other_lane; nella corsia main ferma il combattimento (REPLACED)
func stop(lane: StringName = MAIN, reason: StringName = Reasons.STOPPED_BY_USER) -> void
func is_running(lane: StringName = MAIN) -> bool
func get_lane(lane: StringName = MAIN) -> Dictionary     # {} oppure {"skill", "action", "elapsed_ms", "interval_ms"}
func get_progress(lane: StringName = MAIN) -> float      # F-04
func current_interval_ms(action_id: StringName, lane: StringName = MAIN) -> int
func lanes_available() -> int                            # 1 nell'MVP; F-51 in M8
func stop_reasons_log() -> Array[StringName]              # motivi di stop dall'ultima lettura (per OfflineSummary), poi svuota
func advance(delta_ms: int) -> void
```
Comportamento (M1-10):
- `start`: ordine dei controlli `lane_unavailable` (ogni corsia diversa da `main` fino a M8) → `unknown_id` (skill o
  azione sconosciuta, azione di un'altra skill, azione con `inputs` fino a M3-01) → `level_too_low`; un errore non cambia
  nulla. Avviare l'azione già in corso nella corsia è un no-op `ok` (il ciclo continua, nessun segnale). Altrimenti
  l'azione in corso si ferma con `replaced`, poi `action_started`. Nella corsia main ferma anche il combattimento
  (`replaced`): la riga arriva con M4-03.
- `stop` di una corsia ferma: no-op, nessun segnale. Ogni stop emette `action_stopped` e accoda il motivo al log;
  `stop_reasons_log()` restituisce **tutti** i motivi dall'ultima lettura, in ordine (anche `stopped_by_user` e `replaced`),
  poi svuota; il log non è salvato e `new_game`/`from_save` lo svuotano.
- Intervallo F-03 fissato all'inizio di ogni ciclo (un cambio di modificatori vale dal ciclo successivo); `advance`
  completa tutti i cicli che entrano nel passo. Dopo `from_save` l'intervallo è "da fissare" e si calcola al primo
  `advance` (i modificatori si ricostruiscono dopo il caricamento); `get_lane`/`get_progress` intanto usano quello attuale.
- `get_lane` restituisce l'`interval_ms` del ciclo corrente; `current_interval_ms` quello che avrebbe un ciclo avviato ora
  (id sconosciuto → 0 con `Log.error` di `GameData.action`; la corsia non conta fino a M8).
- `GatheringResolver`: tiri sempre in quest'ordine su `session.rng`: doppio (F-06), poi frammento (F-07, quantità 1).
  Lo spazio nella bank si controlla **prima** di aggiungere (`can_add` e caselle libere per gli oggetti nuovi, frammento
  compreso): se non c'è, il ciclo non conta, nulla cambia e la corsia si ferma con `bank_full` (nessun `bank_rejected`:
  il feedback è `action_stopped(bank_full)`). Ciclo riuscito: `bank_changed` → `xp_gained`/`level_up` →
  segnali della maestria → `action_completed` (`outputs` comprende `rift_shard` se è uscito).
- Save (§6): `{"lanes": {lane: {"skill", "action", "elapsed_ms"}}}`, corsie ferme assenti. `from_save` tollerante: corsia
  sconosciuta, voce non oggetto, azione sconosciuta/di un'altra skill/non avviabile ora (livello, `inputs`) → `Log.warn`
  e corsia ferma; `elapsed_ms` non intero o negativo → `Log.warn` e ciclo da 0. Nessun segnale.

### 5.9 Equipment (`systems/equipment/equipment.gd`) — dipendenze: data, events, modifiers, bank, skills, combat (solo `is_active`)
```gdscript
const SAVE_KEY := &"equipment"
const SLOTS: Array[StringName] = [&"head", &"body", &"legs", &"feet", &"hands", &"neck", &"ring",
    &"weapon", &"offhand", &"tool_forestry", &"tool_quarrying", &"tool_angling"]
const STANCES: Array[StringName] = [&"offensive", &"balanced", &"defensive"]
func get_item(slot: StringName) -> StringName            # &"" se vuoto
func equip(item_id: StringName) -> CommandResult         # unknown_id, not_equippable, requirement_not_met, not_enough_items, bank_full, combat_active (solo arma)
func unequip(slot: StringName) -> CommandResult          # slot_empty, bank_full, combat_active (solo arma)
func get_food() -> StringName
func set_food(item_id: StringName) -> CommandResult      # &"" toglie; not_food; l'oggetto deve essere nella bank
func get_stance() -> StringName
func set_stance(stance: StringName) -> CommandResult     # unknown_id
func weapon() -> ItemDef                                 # null = mani nude
func style() -> StringName                               # stile dell'arma o combat.unarmed.style
func base_attack_interval_ms() -> int
func rebuild_modifiers() -> void                         # sorgenti equipment:<slot>
```

### 5.10 Combattimento (`systems/combat/`) — dipendenze: data, events, modifiers, rng, bank, wallet, skills, equipment, actions (solo `stop`)
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
static func max_hp(vitality_level: int, flat: float, data: GameData) -> int                  # F-27
static func combat_xp(damage: int, style: StringName, stance: StringName, data: GameData) -> Dictionary  # F-28 {skill_id: xp base}

class_name CombatantStats extends RefCounted
var style: StringName; var accuracy: int; var evasion: int; var max_hit: int; var min_hit: int
var attack_interval_ms: int; var damage_reduction: float; var max_hp: int
static func for_player(session: GameSession) -> CombatantStats
static func for_monster(monster: MonsterDef, data: GameData) -> CombatantStats

class_name AutoEat extends RefCounted
static func eat_one(session: GameSession, hp: int, max_hp: int) -> int      # nuovo hp; -1 se nessun cibo (F-29)
static func after_hit(session: GameSession, hp: int, max_hp: int) -> int   # F-30; nuovo hp

class_name LootBag extends RefCounted
func _init(session: GameSession) -> void
func items() -> Array[Dictionary]          # [{"item": StringName, "qty": int}]
func used() -> int
func capacity() -> int                     # F-33
func add(item_id: StringName, qty: int) -> bool    # con auto_loot prova prima la bank; false = perso (loot_lost)
func collect_all() -> CommandResult        # bank_full se qualcosa resta
func lose_all() -> void                    # morte
func to_save() -> Array
func from_save(a: Array) -> void

class_name CombatEngine extends RefCounted
const SAVE_KEY := &"combat"
var loot: LootBag
func start(area_id: StringName, monster_id: StringName) -> CommandResult    # unknown_id, requirement_not_met; ferma la corsia main (REPLACED)
func stop(reason: StringName = Reasons.STOPPED_BY_USER) -> void
func is_active() -> bool
func get_state() -> Dictionary
    # {"area", "monster", "player_hp", "player_max_hp", "monster_hp", "monster_max_hp",
    #  "player_timer_ms", "player_interval_ms", "monster_timer_ms", "monster_interval_ms", "respawn_ms"}
func eat() -> CommandResult                 # no_food, not_running
func player_stats() -> CombatantStats
func monster_stats() -> CombatantStats      # null se non in combattimento
func kills(monster_id: StringName) -> int
func total_kills() -> Dictionary[StringName, int]
func deaths() -> int
func food_eaten() -> int
func stop_reasons_log() -> Array[StringName]
func advance(delta_ms: int) -> void
```

### 5.11 Shop (`systems/shop/shop.gd`) — dipendenze: data, events, modifiers, bank, wallet, skills
```gdscript
const SAVE_KEY := &"shop"
func purchase_count(entry_id: StringName) -> int
func price(entry_id: StringName) -> int               # F-17 per formula, altrimenti cost_gold
func can_buy(entry_id: StringName) -> CommandResult   # unknown_id, max_purchases, requirement_not_met, not_enough_gold, bank_full
func buy(entry_id: StringName) -> CommandResult
func sell_value(item_id: StringName, qty: int) -> int # F-18
func sell(item_id: StringName, qty: int) -> CommandResult   # item_locked, not_sellable, not_enough_items, invalid_amount
func rebuild_modifiers() -> void                      # sorgenti shop:<id> (F-19)
```

### 5.12 RiftAltar (`systems/rift/rift_altar.gd`) — dipendenze: data, events, modifiers, bank, skills
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
func run(session: GameSession, elapsed_ms: int, capped: bool, yield_frames: bool = true) -> OfflineSummary
    # coroutine (await): blocchi da offline.chunk_ms (F-41); emette offline_started/progress/completed su session.events;
    # con yield_frames = false (test) non aspetta frame

class_name OfflineSummary extends RefCounted
var elapsed_ms: int; var capped: bool
var xp: Dictionary[StringName, int]; var levels: Dictionary[StringName, Vector2i]   # x = da, y = a
var items: Dictionary[StringName, int]         # differenza (positiva = ottenuti, negativa = consumati)
var gold_delta: int; var kills: Dictionary[StringName, int]; var deaths: int; var food_eaten: int
var stop_reasons: Array[StringName]
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
# chiavi: window_mode, window_size, ui_scale, vsync, fps_limit, volume, log_level
```

### 5.15 M6-M8
```gdscript
class_name HintsSystem extends RefCounted      # systems/hints/hints_system.gd (M6); dipendenze: data, events
const SAVE_KEY := &"hints"
func is_seen(hint_id: StringName) -> bool
func mark_seen(hint_id: StringName) -> void
func connect_triggers() -> void                # ascolta session.events ed emette hint_triggered una volta per slot

class_name FractureSystem extends RefCounted   # systems/fractures/fracture_system.gd (M7); dipendenze: data, events, modifiers, rng, combat
const SAVE_KEY := &"fractures"
func active_id() -> StringName
func time_left_ms() -> int
func next_in_ms() -> int
func bonus_monster_for_area(area_id: StringName) -> StringName
func advance(delta_ms: int) -> void            # F-50
func rebuild_modifiers() -> void               # sorgente fracture:<id>
```
M8 non aggiunge classi: estende `ActionRunner` (corsia `SECONDARY`, `lanes_available()` con F-51).

## 6. Formato del salvataggio (`user://saves/slot_<n>.json`)

```json
{
  "format_version": 1,
  "game_version": "0.1.0",
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
    "skills": {"forestry": {"xp": 15320}, "blade": {"xp": 4100}},
    "mastery": {"forestry": {"pool": 2210, "actions": {"cut_redbirch": 9800}, "nodes": ["forestry_n1_quick_axe"]}},
    "equipment": {"slots": {"weapon": "emberbronze_blade", "tool_forestry": "emberbronze_hatchet"},
                  "food": "seared_brookfin", "stance": "balanced"},
    "actions": {"lanes": {"main": {"skill": "forestry", "action": "cut_redbirch", "elapsed_ms": 1200}}},
    "combat": {"active": false, "area": "", "monster": "", "player_hp": 0, "monster_hp": 0,
               "player_timer_ms": 0, "monster_timer_ms": 0, "respawn_ms": 0,
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
statistiche derivate non si salvano. Lo stato del giocatore non esiste fuori da questo file.

## 7. Contratti della UI (`res://ui/`)

```gdscript
class_name Page extends Control                 # ui/pages/page.gd; base di tutte le pagine
var page_id: StringName
func bind(session: GameSession) -> void         # virtuale: collega EventBus, prima lettura dello stato
func unbind() -> void                           # virtuale: scollega tutto

class_name PageHost extends Control             # ui/screens/main/page_host.gd
signal page_changed(page_id: StringName)
func setup(session: GameSession) -> void
func show_page(page_id: StringName) -> void     # &"skill:<id>", &"bank", &"shop", &"equipment", &"combat", &"rift", &"settings"

class_name ItemSlotView extends PanelContainer  # ui/components/item_slot/item_slot.gd
signal pressed(item_id: StringName)
func set_item(item: ItemDef, count: int, locked: bool = false) -> void
func clear() -> void

class_name ActionProgressBar extends ProgressBar   # ui/components/progress/action_progress_bar.gd
func set_progress(value: float) -> void            # 0..1, animazione continua

class_name XpBar extends Control                   # ui/components/progress/xp_bar.gd
func set_xp(table: XpTable, xp: int) -> void

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
static func reason_text(reason: StringName) -> String   # invalid_name con Game.PLAYER_NAME_MIN/MAX_LENGTH
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
func show_at(cursor_pos: Vector2) -> void          # globale; spostato del mouse_offset e tenuto nel viewport
func hide_tooltip() -> void                        # nasconde e svuota i testi
func is_shown() -> bool
func title_text() -> String                        # testi senza BBCode (test, accessibilità)
func body_text() -> String
func footer_text() -> String

class_name ItemTooltipLines extends RefCounted     # ui/components/tooltip/item_tooltip_lines.gd, solo statiche
static func subtitle(item: ItemDef, count: int) -> String          # categoria e, se count > 0, "Quantità: 1.250"
static func body(item: ItemDef, data: GameData) -> PackedStringArray   # requisiti, arma, modificatori, cibo, valore
static func modifier_lines(mods: Array[Modifier], data: GameData) -> PackedStringArray
static func format_stat(format: String, value: float) -> String    # pct "+5%", flat "+8", flag "Sì"/"No"
static func category_name(category: StringName) -> String
static func format_int(value: int) -> String                       # "1.250"
static func format_number(value: float) -> String                  # "1.250,5" (al massimo due decimali)
static func escape(text: String) -> String                         # BBCode dei testi dei dati

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

## 8. Helper dei test (`res://tests/helpers/`)

```gdscript
class_name TestFactory extends RefCounted          # tests/helpers/test_factory.gd
static func fixture_data() -> GameData             # contenuto: res://tests/fixtures/data, config: res://data/config
static func real_data() -> GameData                # res://data
static func session(seed_value: int = 1234, data: GameData = null) -> GameSession   # GameEvents nuovo, new_game() fatto
static func give(session: GameSession, item_id: StringName, qty: int) -> void        # via bank.add, assert ok
static func set_level(session: GameSession, skill_id: StringName, level: int) -> void # via skills.add_xp con xp_for_level
```
`fixture_data()`/`real_data()` caricati una volta per esecuzione e condivisi (`GameData` è immutabile); `session()` crea
un `GameEvents` figlio della sessione (si libera con lei), mai l'autoload `EventBus`, mai slot veri. `give` (M1-07) e
`set_level` (M1-08) sono implementati: in caso di fallimento `push_error` + `assert`. GUT segnala `test_factory.gd`
come ignorato (prefisso `test_` ma non estende `GutTest`): avviso innocuo.
`tests/helpers/gut_pre_run.gd`: imposta `SaveService.base_dir = "user://test_saves"` e svuota la cartella.
Ogni test libera la sessione con `autofree()` (GUT) o `session.free()`.
