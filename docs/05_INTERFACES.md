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
const LANE_UNAVAILABLE := &"lane_unavailable"   # M12: solo per una corsia diversa da MAIN (le corsie parallele non esistono più: nessun uso reale)
const SKILL_IN_OTHER_LANE := &"skill_in_other_lane"   # M12: costante rimasta, nessun uso reale (corsie parallele eliminate, W3)
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
const DEPOSIT_NOT_EMPTY := &"deposit_not_empty"   # M12: togliere la borsa lascerebbe più caselle usate che capienza (F-100)
const NOT_A_BAG := &"not_a_bag"                   # M12: l'oggetto non è una borsa (categoria bag)
const BAG_SLOT_OCCUPIED := &"bag_slot_occupied"   # M12: lo slot borsa non è vuoto
const NOT_A_CONTRACT := &"not_a_contract"         # M12: l'oggetto non è un contratto (categoria contract)
const NO_HELPER := &"no_helper"                   # M12: il mestiere non ha un aiutante
const HELPER_NOT_BETTER := &"helper_not_better"   # M12: il contratto non supera il grado dell'aiutante attuale (non si consuma)
const BLUEPRINT_DONE := &"blueprint_done"   # M10: motivo di stop di fine progetto (action_stopped)
const FRACTURE_ACTIVE := &"fracture_active"             # M13: c'è già una Frattura in corso
const FRACTURE_BAG_PENDING := &"fracture_bag_pending"   # M13: la borsa della Frattura precedente non è stata consegnata del tutto
const NO_FRACTURE := &"no_fracture"                     # M13: nessuna Frattura in corso (abbandona) o nessun bottino in attesa (raccogli)
const FRACTURE_WON := &"fracture_won"                   # M13: motivo di stop del combattimento a Frattura vinta (solo se non c'era un'area a cui tornare)
const FRACTURE_ABANDONED := &"fracture_abandoned"       # M13: idem, per l'abbandono
```
Le costanti nuove le aggiunge il primo task che le usa (M4-01 per quelle di M4), con il test di `reasons.gd`. A fine M12 la lista chiusa conta **50** costanti; M13 ne aggiunge 5 (**55**).

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
const CURRENT_VERSION: int = 5                 # 5 da M14 (3 da M10, 4 da M12; vedi §6); nessuna migrazione 1 → 2 né 2 → 3: un save v1 o v2 è version_unsupported (nessun giocatore reale ancora)
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
| ~~`bank_capacity_changed`~~ | — | — | **tolto in M12** (sostituito da `deposit_changed`) |
| `deposit_changed` | `used: int, capacity: int` | Deposit | M12: variano le caselle usate (Bank o Armory) o la capienza (borse); emesso solo se uno dei due valori cambia davvero |
| `bags_changed` | — | Deposit | M12: uno slot borsa è cambiato (`equip_bag`/`unequip_bag`) |
| `bank_rejected` | `item_id: StringName, qty: int` | Bank | `add` fallita per bank piena |
| `gold_changed` | `new_amount: int, delta: int` | Wallet | |
| `equipment_changed` | `slot_id: StringName, uid: int` | Equipment | M4: `uid` 0 = slot vuoto (prima: `item_id`; il segnale non si usa più per cibo e stance) |
| `food_changed` | `item_id: StringName` | Equipment | M4: cibo scelto (`&""` = nessuno) |
| `character_xp_gained` | `amount: int` | CharacterSystem | M4: ogni guadagno > 0 |
| `character_level_up` | `new_level: int` | CharacterSystem | M4: un evento per livello |
| `player_renamed` | `new_name: String` | PlayerName | P-03: emesso da `PlayerName.rename` quando il nome cambia davvero; la TopBar lo ascolta e aggiorna l'etichetta |
| `traits_changed` | — | Loadout | M6: tratti o abilità equipaggiati cambiati |
| `armory_changed` | `uid: int, change: StringName` | Armory | M4: `change` = `&"added"`, `&"removed"`, `&"updated"` (blocco, raffinazione, indossato) |
| ~~`armory_capacity_changed`~~ | — | — | **tolto in M12** (sostituito da `deposit_changed`) |
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
| `loot_lost` | `item_id: StringName, qty: int` | LootBag | impilati a borsa piena, o morte (anche i pezzi); mai per un pezzo (M15) |
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
| `helper_changed` (M12) | `skill_id: StringName, grade: StringName, action_id: StringName` | HelperSystem | assunzione, cambio di azione o stop (`grade` e `action_id` vuoti se assenti) |
| `helper_completed` (M12) | `skill_id: StringName, action_id: StringName, outputs: Dictionary` | HelperSystem | fine di un ciclo dell'aiutante (`outputs`: `{item_id: qty}`) |
| `helper_blocked` (M12) | `skill_id: StringName, blocked: bool` | HelperSystem | l'aiutante attende (Deposito pieno) o riparte; emesso solo al cambio |
| `mastery_milestone_reached` (M12) | `skill_id: StringName, action_id: StringName, at: int` | MasterySystem | un traguardo (25/50/99) raggiunto in gioco, dopo `mastery_level_up`; mai in `from_save` |
| `fracture_opened` (M13) | `grade: int` | FractureSystem | la Carta è consumata e la Frattura parte (sostituisce la vecchia firma `fracture_id, duration_ms`) |
| `fracture_group_cleared` (M13) | `index: int, total: int` | CombatEngine | gruppo `index` (da 1) superato |
| `fracture_boss_started` (M13) | `boss_id: StringName` | CombatEngine | parte l'incontro del boss |
| `fracture_finished` (M13) | `outcome: StringName, grade: int, groups: int, cards: int, pieces: int` | CombatEngine | `outcome` = `&"won"`, `&"died"`, `&"abandoned"`; `groups` = gruppi superati; `cards`/`pieces` = quelli nella borsa (consegnati o persi); emesso prima della consegna (5.23) |
| `fracture_bag_changed` (M13) | `stacks: int, pieces: int, cards: int` | FractureSystem | cambia il contenuto della borsa della Frattura in corso o in attesa |
| `fracture_loot_lost` (M13) | `stacks: int, pieces: int, cards: int` | FractureSystem | sconfitta o abbandono: la borsa è persa (X4) |
| `card_changed` (M13) | `uid: int, change: StringName` | CardStore | `change` = `&"added"`, `&"removed"`, `&"updated"` (blocco, Cristallo) |
| `card_rejected` (M13) | `grade: int` | CardStore | Carta non aggiunta per Deposito pieno |
| `item_obtained` (M14) | `item_id: StringName, qty: int` | Bank, LootBag, Armory, CardStore | ogni volta che un oggetto entra in possesso del giocatore (pezzi e Carte: id di base, qty 1); lo ascolta `Discoveries` (F-124) |
| `item_discovered` (M14) | `item_id: StringName` | Discoveries | la prima volta che un oggetto viene ottenuto nello slot (sblocca la Guida, toast) |

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
func map_base(grade: int) -> ItemDef                  # M13: la Carta del grado 1..10 (null + Log.error se manca)
func map_mods() -> Array[MapModDef]                   # M13: nell'ordine del file
func map_mod(id: StringName) -> MapModDef             # M13: null se sconosciuto
func boss_for_grade(grade: int) -> BossDef            # M13: il boss del grado
func boss(id: StringName) -> BossDef                  # M13
func fracture_grade(grade: int) -> FractureGradeDef   # M13: riga di fracture.grades (F-110)
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
  per rarità ≤ 6, `combat.max_pack_size` ≤ 8, da M17-03) sono costanti di queste classi; i limiti che dipendono dal bilanciamento
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
  per equip, rune ed effetti dello shop. In `MasteryBonusRule` lo `scope` dei dati è ignorato e i modificatori sono
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
  var map_grade: int; func is_map() -> bool                 # M13: Carta della Frattura (categoria map, 04 §11.1); 0 se non Carta
class_name EquipInfo  ; var slot: StringName; var requirements: Dictionary[StringName, int]   # chiave &"character" = personaggio
                        var modifiers: Array[Modifier]; var weapon: WeaponInfo   # null se non arma
                        var kind: StringName; var grade: int      # M4-01: &"" se lo slot non è weapon/offhand
                        var unique: bool; var upgrade_extras: Array[ToolExtra]   # M10: attrezzo unico (04 §5); extras vuoto se assente
                        var material: StringName; var masterwork: bool; var legendary: LegendaryInfo   # M14 (§5.24); grade 1..15
class_name ToolExtra  ; var at: int; var modifiers: Array[Modifier]   # M10: bonus cumulativi dal passo `at` (F-94)
class_name BlueprintInfo ; var base_id: StringName; var grade: int; var inputs: Array[ItemQty]; var rare_components: Array[ItemQty]   # M10; M14: grade = grado del materiale, due componenti rari diversi (F-119, §5.24)
class_name WeaponInfo ; var style: StringName; var attack_interval_ms: int; var two_handed: bool; var dmg_min: int; var dmg_max: int   # M14: dmg_min/dmg_max, F-22 (§5.24)
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
                        var level_min: int; var level_max: int; var map_pos: Vector2   # M17-04: livelli coperti (F-130, §8.5) e posizione 0..1 sulla mappa (M17-05)
class_name PackDef    ; var weight: int; var monster_ids: Array[StringName]   # M4-01 (ripetibili, ordine = posizioni)
class_name MonsterDef
  var id: StringName; var name: String; var description: String; var icon: String
  var hp: int; var xp: int; var style: StringName; var attack_interval_ms: int      # xp: M4-01
  var attack_level: int; var power_level: int; var defence_level: int
  var accuracy_bonus: int; var power_bonus: int; var evasion_bonus: int; var damage_reduction: float
  var gold_min: int; var gold_max: int; var rift_shard_chance: float; var drops: Array[DropEntry]
class_name MilestoneDef (M12)   ; var at: int; var type: StringName; var item: StringName; var modifiers: Array[Modifier]   # 5.22
class_name LootTableDef (M12)   ; var id: StringName; var entries: Array[DropEntry]
class_name ShopEntryDef
  var id: StringName; var name: String; var description: String; var category: StringName
  var cost_gold: int                                    # M12: sempre un prezzo fisso (cost_formula eliminato)
  var max_purchases: int                                # 0 = illimitato
  var req_entries: Array[StringName]; var req_skills: Dictionary[StringName, int]; var req_total_level: int
  var req_character: int                                # M4-01; 0 = nessun requisito
  var effect_modifiers: Array[Modifier]; var effect_item: ItemQty   # uno dei due
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
class_name MapEffectDef (M13) ; var type: StringName; var min_value: float; var max_value: float
class_name MapModDef (M13)    ; var id: StringName; var name: String; var description: String; var min_grade: int; var weight: int
                               var risk: MapEffectDef; var reward: MapEffectDef
class_name BossAbilityDef (M13); var type: StringName; var every_ms: int; var mult: float; var duration_ms: int; var shield_pct: int
                               var count: int; var max_alive: int; var monsters: Array[StringName]   # solo i campi del tipo (F-112)
class_name BossDef (M13) extends MonsterDef ; var grade: int; var ability: BossAbilityDef; var dust_min: int; var dust_max: int
class_name FractureGradeDef (M13); var areas: Array[StringName]; var level_bonus: int; var hp_mult: float; var damage_mult: float
                               var reward_mult: float; var piece_grade: int; var recommended_level: int   # F-110
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
var excluded_sources: Array[StringName]   # M12: sorgenti ignorate da total/breakdown con questo contesto (default vuoto)
static func for_helper(skill_id: StringName, action_id: StringName) -> ModifierContext   # M12, F-101: come for_action con excluded_sources = [equipment:tool_<skill>]

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
`level_modifiers` della skill, ricostruiti da `SkillsSystem` a ogni `level_up` e in `rebuild_modifiers`), `fracture:<uid>` (M13: uid della Carta in corso; stat dei premi, F-111; tolta a fine Frattura).

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
var deposit: Deposit; var helpers: HelperSystem   # M12-01 / M12-02 (null prima)
var cards: CardStore; var fractures: FractureSystem   # M13-01 / M13-02 (null prima)
var village: Village              # M19-02 (null prima): edifici del Villaggio, 5.27
var slot: int; var player_name: String; var created_at_unix_ms: int; var play_time_ms: int
func _init(game_data: GameData, game_events: GameEvents, rng_seed: int) -> void
func new_game() -> void                                  # stato iniziale 01_GDD §1.1 + rebuild_modifiers
func advance(delta_ms: int) -> void                      # ordine: actions, helpers, combat, play_time (M13: le Fratture non hanno timer)
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
const _PHASE_FRACTURES: int; const _PHASE_ACTIONS: int; const _PHASE_HELPERS: int; const _PHASE_COMBAT: int   # _PHASE_HELPERS: M12-02
```
- `advance`: ordine fisso fratture → azioni → aiutanti → combattimento (solo le fasi registrate), poi `play_time_ms`; indipendente
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
  chiavi finte non devono coincidere con le `SAVE_KEY` dei sistemi veri (oggi `lanes`, `combat`, `fractures`, `cards`): il task
  che registra un sistema con la stessa chiave rinomina quella finta.

- **M12**: `_create_systems()` crea `deposit` subito dopo `wallet` e prima di `bank`; `bank` e `armory` si registrano con `deposit.register_occupant(&"bank", bank.used)` e
  `(&"armory", armory.used)`; `helpers` dopo `mastery` e `actions` (`_tick(_PHASE_HELPERS, helpers.advance)`, senza `rebuild_fn`). `to_save`/`from_save` aggiungono i moduli `deposit` e `helpers` (§6).

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
func capacity() -> int                             # M12: delega a deposit.capacity() (F-100)
func free_boxes() -> int                           # M12: caselle libere del Deposito condiviso (deposit.free_slots())
func used() -> int
func stacks() -> Array[Dictionary]                 # copie: [{"item": StringName, "count": int, "locked": bool}] in ordine
func is_locked(item_id: StringName) -> bool
func set_locked(item_id: StringName, locked: bool) -> CommandResult   # unknown_id se non presente
func move_stack(item_id: StringName, new_index: int) -> CommandResult
$1func equip_bag(slot_index: int, item_id: StringName) -> CommandResult   # M12, 5.20: invalid_amount, unknown_id, not_a_bag, bag_slot_occupied, not_enough_items
func unequip_bag(slot_index: int) -> CommandResult                      # M12, 5.20: invalid_amount, slot_empty, deposit_not_empty
```
- **M12 (W1)**: la capienza è unica e sta in `Deposit` (F-100, 5.20): `Bank.used()` conta i tipi di oggetto, `Bank.capacity()` rimanda a `deposit.capacity()`. Un oggetto
  nuovo richiede `deposit.has_room()` (lo spazio è condiviso con l'Armeria). Dopo ogni variazione di caselle `Bank` chiama `deposit.notify_changed()` (→ `deposit_changed`).
  La stat `bank_slots`, `bank.*` di `balance.json` e `bank_capacity_changed` non esistono più. `sort_stacks` ordina le categorie: material, bag, contract, food, infusion, misc.
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
  `rebuild_modifiers` che li segue non emette segnali di capienza (la capienza sta in `Deposit`).
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
func add_xp(skill_id: StringName, base_amount: int, ctx: ModifierContext = null, share_pct: float = 100.0) -> int   # F-02, poi × share_pct/100 con floor (M12, F-102); restituisce XP data
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
static func helper_share(mastery_xp: int, share_pct: float) -> int  # M12, F-102: quota di maestria dell'aiutante, round(mastery_xp × share_pct / 100)
static func pool_cap(action_count: int, per_item: int) -> int       # F-13
static func node_cost(pool_cap: int, cost_pct: float) -> int        # F-15
static func rule_multiplier(rule: MasteryBonusRule, level: int) -> int   # F-11: floor(L/k) o 0/1   # M14: tolta con F-11 (sostituita da step_bonus, §5.24)

class_name MasterySystem extends RefCounted
const SAVE_KEY := &"mastery"
func get_mastery_xp(action_id: StringName) -> int
func get_mastery_level(action_id: StringName) -> int
func get_skill_ratio(skill_id: StringName) -> float                # R di F-10
func get_pool(skill_id: StringName) -> int
func get_pool_cap(skill_id: StringName) -> int
func add_for_action(action: ActionDef, share_pct: float = 100.0) -> int                      # F-10 + F-12; restituisce mxp
func spend_pool_on_action(action_id: StringName, amount: int) -> CommandResult   # F-14; invalid_amount, pool_insufficient, mastery_max
func node_cost(node_id: StringName) -> int
func owns_node(node_id: StringName) -> bool
func can_buy_node(node_id: StringName) -> CommandResult            # unknown_id, node_owned, node_prereq_missing, pool_insufficient
func buy_node(node_id: StringName) -> CommandResult
$1func milestones_reached(action_id: StringName) -> Array[int]     # M12: soglie (25/50/99) raggiunte dall'azione di raccolta, in ordine; [] per le altre
func milestone_active(action_id: StringName, at: int) -> bool      # M12: livello di maestria dell'azione ≥ at
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

- **M12 (W4, F-103, F-108)**: `add_for_action(action, share_pct)` con `share_pct < 100` (aiutante, F-102) dà `round(F-10 × share_pct/100)` e la quota F-12 su quel valore.
  Per le azioni di **raccolta** le sorgenti diventano: `mastery_item:<action_id>` = modificatori del traguardo `resource` (scope `action:<id>`) se `L ≥ resource_at`, e **`mastery_trade:<skill_id>`**
  = somma dei modificatori dei traguardi `trade` delle azioni con `L ≥ trade_at` (scope `skill:<id>`; nessun modificatore → `clear_source`). Le `mastery_bonuses` per oggetto (F-11) valgono solo per
  l'artigianato. Dopo un `mastery_level_up` che attraversa 25/50/99 emette `mastery_milestone_reached(skill, action, at)` (una volta per soglia, mai in `from_save`/`new_game`) e, se serve, ricostruisce le sorgenti in un solo batch.
  Il sottoprodotto (25) lo tira il resolver (5.8), non la maestria.

### 5.8 Azioni (`systems/actions/`) — dipendenze: data, events, modifiers, bank, skills, mastery, rng, combat (solo `stop`)
```gdscript
class_name ActionMath extends RefCounted
static func interval_ms(base_ms: int, interval_pct: float, min_ms: int) -> int          # F-03

class_name ActionOutcome extends RefCounted
var ok: bool; var reason: StringName
var outputs: Dictionary[StringName, int]; var consumed: Dictionary[StringName, int]
var xp: int; var mastery_xp: int; var shard: bool

class_name GatheringResolver extends RefCounted
static func resolve(session: GameSession, action: ActionDef, helper_grade: StringName = &"") -> ActionOutcome   # 01_GDD §4, F-06, F-07, F-103 (M12); helper_grade non vuoto = profilo aiutante (F-102, ModifierContext.for_helper)

class_name ArtisanResolver extends RefCounted
static func can_start(session: GameSession, action: ActionDef) -> CommandResult       # missing_inputs
static func resolve(session: GameSession, action: ActionDef) -> ActionOutcome         # 01_GDD §5, F-08

class_name ActionRunner extends RefCounted
const SAVE_KEY := &"actions"
const MAIN := &"main"
func start(skill_id: StringName, action_id: StringName, lane: StringName = MAIN) -> CommandResult
    # unknown_id, level_too_low, missing_inputs, lane_unavailable (lane ≠ MAIN); nella corsia main ferma il combattimento (REPLACED)
func stop(lane: StringName = MAIN, reason: StringName = Reasons.STOPPED_BY_USER) -> void
func is_running(lane: StringName = MAIN) -> bool
func get_lane(lane: StringName = MAIN) -> Dictionary     # {} oppure {"skill", "action", "elapsed_ms", "interval_ms"}
func get_progress(lane: StringName = MAIN) -> float      # F-04
func current_interval_ms(action_id: StringName, lane: StringName = MAIN) -> int
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
- `GatheringResolver`: tiri sempre in quest'ordine su `session.rng`: doppio (F-06), poi frammento (F-07, quantità 1), poi (M12, F-103) il sottoprodotto del traguardo 25 se attivo
  (`roll_pct(mastery.milestones.byproduct_chance_pct)`, quantità 1, mai raddoppiato; l'oggetto entra in `outputs`). Lo spazio per il sottoprodotto si controlla insieme agli altri oggetti nuovi.
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
static func hit_pct(accuracy: int, evasion: int, data: GameData) -> int                     # F-129 (M17-03): floor(100 x hit + 0,5)
static func xp_level_mult(diff: int, data: GameData) -> float                                # F-130 (diff = livello mostro - livello personaggio)
static func monster_xp(level: int, data: GameData) -> int                                    # F-130: round(base x growth^(level-1))
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
var attack_interval_ms: int; var damage_reduction: float; var max_hp: int; var block_chance: float   # M14: damage_reduction solo mostri; giocatore: var armor: int; var barrier: int (F-117), var weapon_min: int; var weapon_max: int (F-22), vedi §5.24
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
func pieces() -> Array[ItemInstance]       # M15 (Z1): pezzi in attesa nel Bottino (sola lettura; uid 0)
func add_piece(inst: ItemInstance) -> void # M15: vedi §5.25
func collect_pieces() -> void              # M15-08: solo i pezzi nell'Armeria (come collect_all); lo usano collect_all e OfflineSimulator a ogni blocco
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
    #  "hand", "between_ms", "enemies": [{"monster", "hp", "max_hp", "timer_ms", "interval_ms", "hit_pct", "enemy_hit_pct"}], "target": int,
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
  `effects` `{}`, così save -> load -> save è identico); `KillRewards` (`kill_rewards.gd`, `grant(session, loot, def, area_id = &"")`, `grant_summoned(session, loot, def, area_id = &"")` (M17-06: nessuna XP, oro, frammento né pezzo del pool; solo drop e tabelle con la chance × `combat.summon_drop_pct`/100) e il parametro `chance_mult: float = 1.0` di `roll_drops`/`roll_tables`:
  xp, oro, drop propri, tabelle dell'area (se `area_id` non vuoto) e del mostro, frammento; statici anche `base_xp`, `roll_drops`, `roll_tables`, `roll_piece`, `monster_ilvl`); `EffectSet` (`effects/effect_set.gd`: effetti dei tratti di `Loadout.active_traits()`,
  dispatch degli agganci, emette `trait_triggered`) e `TraitEffect` con un file per tipo di F-81. Per M6-03: i colpi
  delle abilità passano da `EffectSet.hit(ctx, damage)` (altrimenti `leech_pct` non cura).

- **Fratture (M13)**: lo stesso motore esegue le Fratture (`start_fracture`, scala dei mostri, boss, borsa separata, ritorno all'area): contratto in 5.23.

### 5.11 Shop (`systems/shop/shop.gd`) — dipendenze: data, events, modifiers, bank, wallet, skills, character, armory
```gdscript
const SAVE_KEY := &"shop"
func purchase_count(entry_id: StringName) -> int
func price(entry_id: StringName) -> int               # M12: cost_gold (F-17/F-82 eliminate)
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
di `bank_full`; ~~`price` con `cost_formula = &"armory_slot"` → F-82~~ (M12: eliminato; le voci di spazio non esistono più). `sell_instance` toglie il pezzo dall'Armeria e
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

### 5.12 RiftAltar (`systems/rift/rift_altar.gd`, M8; M12: il mestiere `riftbinding` è l'Incisore, API invariata; le rune hanno 5 gradi con effetto F-107, ognuna è un oggetto con il suo id) — dipendenze: data, events, modifiers, bank, skills
```gdscript
const SAVE_KEY := &"rift"
const SKILL := &"riftbinding"
func socket_total() -> int                     # numero di voci in rift.sockets
func is_unlocked(index: int) -> bool
func get_socket(index: int) -> StringName      # &"" se vuota
func socket(index: int, item_id: StringName) -> CommandResult   # socket_locked, socket_occupied, not_equippable, not_enough_items, requirement_not_met (unique)
func clear_socket(index: int) -> CommandResult  # slot_empty; distrugge la runa
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
var fractures: Array[Dictionary]               # M13: [{"grade", "outcome", "groups", "cards", "pieces"}], una per fracture_finished durante l'offline (5.23)
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
# chiavi: window_mode, window_size, ui_scale, vsync, fps_limit, volume, log_level, reduced_fx (`KEY_REDUCED_FX`, bool, default false: M17-07 spegne scosse, pulsazioni e animazioni della pagina di combattimento)
```

### 5.15 Hint (M9) (le Fratture di M13 sono in 5.23)
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
Le corsie parallele sono eliminate (M12, W3): niente `SECONDARY`, `lanes_available()` né F-51; le sostituisce `HelperSystem` (5.21). Le Fratture
come mappe (M13, Carta + incursione) sono in 5.23.

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
# capacity(): TOLTA in M12 (capienza unica nel Deposito, F-100; il contatore è deposit.used()/capacity())
func used() -> int                             # pezzi non indossati (occupante "armory" del Deposito, F-100)
func can_add(count: int = 1) -> bool          # M12: deposit.has_room(count)
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
- `add`/`create` emettono `armory_changed(uid, &"added")` e (via `deposit.notify_changed()`) `deposit_changed`; `remove`, `set_locked`,
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
- **M12**: `GuideIndex.sources_of` considera anche le `loot_tables` di aree, mostri e Monoliti (e le ricette dell'Incisore e del Falegname per le borse) e i traguardi di maestria (sottoprodotti); `GuideRef.kind` aggiunge
  `loot_table`, `milestone`, `helper_contract`. `GuideTables.ids()` aggiunge `bags`, `helper_grades`, `engraver_recipes`, `mastery_milestones:<skill>`. I contratti hanno "Serve a: assumere l'aiutante".

### 5.20 Deposit (`systems/deposit/deposit.gd`, M12; F-100) — dipendenze: data, events (foglia)
```gdscript
class_name Deposit extends RefCounted
const SAVE_KEY := &"deposit"
func capacity() -> int                          # F-100: deposit.base_slots + extra_slots()
func used() -> int                              # somma degli occupanti registrati (Bank: tipi di oggetto; Armory: pezzi non indossati)
func free_slots() -> int                        # max(0, capacity() − used()); non si chiama free() perché collide con Object.free()
func has_room(count: int = 1) -> bool           # free_slots() >= count
func register_occupant(occupant_id: StringName, used_fn: Callable) -> void   # used_fn: () -> int; id duplicato → assert; la chiamano Bank e Armory in _create_systems()
func bag_slot_count() -> int                    # deposit.bag_slots (6)
func get_bag(slot_index: int) -> StringName     # id della borsa nello slot, &"" se vuoto o indice fuori
func bags() -> Array[StringName]                # copia, lunghezza bag_slot_count()
func extra_slots() -> int                       # Σ bag.slots delle borse negli slot
func assign_bag(slot_index: int, item_id: StringName) -> void   # INTERNO: solo Bank.equip_bag/unequip_bag; &"" svuota; emette bags_changed
func sync_known() -> void                       # registra used/capacity attuali come già annunciati, senza segnale; Bank e Armory la chiamano dopo un cambio silenzioso (new_game, from_save, set_worn quieto)
func is_bag(item_id: StringName) -> bool        # l'oggetto è una borsa (categoria bag)
func notify_changed() -> void                   # emette deposit_changed(used, capacity) se uno dei due è diverso dall'ultima emissione; la chiamano Bank e Armory dopo ogni variazione di caselle
func new_game() -> void; func to_save() -> Dictionary; func from_save(d: Dictionary) -> void
```
- Sostituisce `bank_capacity_changed` e `armory_capacity_changed` (tolti dall'EventBus): un solo segnale `deposit_changed(used, capacity)` per le caselle e `bags_changed` per gli slot borsa.
- **Comandi sulle borse** stanno in `Bank` (spostano uno stack tra casella e slot; `Deposit` non conosce `Bank`):
```gdscript
# in Bank (5.5)
func equip_bag(slot_index: int, item_id: StringName) -> CommandResult
    # in ordine: invalid_amount (slot_index fuori da 0..bag_slot_count()−1), unknown_id, not_a_bag (categoria ≠ bag), bag_slot_occupied (slot non vuoto:
    # prima unequip_bag), not_enough_items. Effetto: 1 borsa tolta dalla Bank (bank_changed −1), poi deposit.assign_bag → bags_changed, deposit_changed
func unequip_bag(slot_index: int) -> CommandResult
    # in ordine: invalid_amount, slot_empty, deposit_not_empty (F-100: dopo l'operazione used' > capacity'). Effetto: slot svuotato, la borsa torna nella Bank (bank_changed +1)
```
- `used()` conta anche le borse non messe negli slot (sono oggetti della Bank). Le borse negli slot non occupano caselle.
- Save (§6): `{"bags": [id | "", …]}` con esattamente `bag_slot_count()` voci. `from_save` tollerante: `bags` non lista → tutto vuoto; voce non stringa, id sconosciuto o non `bag` → `Log.warn` e slot vuoto; lista più lunga → troncata, più corta → completata con vuoti. Non controlla la capienza (le caselle già occupate non si perdono). Nessun segnale; `new_game` = slot vuoti.
- Ordine in `_create_systems()`: `wallet`, **`deposit`**, `bank` (si registra come occupante), … `armory` (si registra come occupante). `from_save` ricarica `deposit` prima di `bank`.
- **M19 (F-133)**: `Deposit` riceve il `ModifierService` e somma `floor(total(deposit_slots))` a `capacity()`; ascolta `modifiers_changed` e chiama `notify_changed()`. Dettagli in 5.27.

### 5.21 HelperSystem (`systems/helpers/helper_system.gd`, M12; F-101, F-102) — dipendenze: data, events, modifiers, bank, deposit, skills, mastery, rng
```gdscript
class_name HelperSystem extends RefCounted
const SAVE_KEY := &"helpers"
func is_helper_skill(skill_id: StringName) -> bool       # skill di categoria gathering (forestry, quarrying, angling)
func get_grade(skill_id: StringName) -> StringName       # id di helper.grades ("apprentice"…) o &"" se nessun aiutante
func grade_rank(skill_id: StringName) -> int             # 0 = nessuno, 1..4 (posizione in helper.grades)
func get_action(skill_id: StringName) -> StringName      # azione assegnata, &"" se nessuna
func is_blocked(skill_id: StringName) -> bool            # in attesa perché il Deposito è pieno
func get_progress(skill_id: StringName) -> float         # F-04
func interval_ms(skill_id: StringName, action_id: StringName = &"") -> int   # F-101; action_id vuoto = azione corrente; 0 se manca l'aiutante o l'azione
func available_actions(skill_id: StringName) -> Array[StringName]   # azioni della skill con level ≤ livello del giocatore (ordine dei dati)
func hire(contract_item_id: StringName) -> CommandResult
    # in ordine: unknown_id, not_a_contract, not_enough_items, helper_not_better (grado ≤ aiutante attuale: il contratto NON si consuma)
func set_action(skill_id: StringName, action_id: StringName) -> CommandResult   # unknown_id (skill non gathering o azione di un'altra skill), no_helper, level_too_low
func stop(skill_id: StringName) -> void                  # toglie l'azione (l'aiutante resta); no-op senza azione
func advance(delta_ms: int) -> void                      # fase _PHASE_HELPERS, dopo le azioni
func new_game() -> void; func to_save() -> Dictionary; func from_save(d: Dictionary) -> void
```
- **Un solo aiutante per mestiere**, a un solo grado. `hire`: toglie 1 contratto dalla Bank, imposta il grado (sostituisce quello di grado più basso), **conserva
  l'azione assegnata** se esiste e azzera il progresso; `helper_changed`.
- `set_action` con la stessa azione già assegnata: no-op ok. Altrimenti progresso a 0 e `helper_changed`.
- `advance`: per ogni mestiere con aiutante e azione, accumula il tempo; l'intervallo è F-101 fissato all'inizio di ogni ciclo (come F-03 per il giocatore); a fine
  ciclo chiama `GatheringResolver.resolve(session, action, grade_id)` (profilo aiutante: `ModifierContext.for_helper`, XP e maestria in quota F-102, stessi tiri
  di F-06/F-07/F-103). Esito riuscito: `helper_completed(skill, action, outputs)`. Deposito pieno per un oggetto nuovo (come `bank_full` della raccolta): il ciclo non
  conta, `blocked = true` con `helper_blocked(skill, true)` una sola volta e una `notification_requested` (warning); a ogni `advance` riprova e, quando c'è posto,
  `helper_blocked(skill, false)` e riparte (il progresso non si perde). Lavora in parallelo a qualunque cosa faccia il giocatore (azione, progetto, combattimento) e **anche offline**.
- Nessuna sorgente di modificatori e nessun `rebuild_modifiers`. Non usa l'attrezzo del giocatore (`ModifierContext.for_helper`); i nodi, i traguardi di maestria e le
  rune valgono anche per lui.
- Save (§6): `{skill_id: {"grade": id, "action": id | "", "elapsed_ms": int}}`, solo i mestieri con aiutante. `from_save` tollerante: skill non gathering, grado
  sconosciuto → `Log.warn` e scartato; azione sconosciuta/di un'altra skill/oltre il livello → aiutante senza azione; `elapsed_ms` non intero o negativo → 0.
- Contratto: oggetto `category: contract` (`contract.skill`, `contract.grade`); si usa con `hire` dalla Bank (UI: pulsante "Assumi" sul pannello dell'oggetto e sulla riga
  Aiutante del mestiere).

### 5.22 Incisore e tabelle di drop (M12; F-103…F-107)
```gdscript
class_name EngraverResolver extends RefCounted   # systems/actions/engraver_resolver.gd — azioni con kind = crystallize
static func crystal_chance_pct(engraver_level: int, data: GameData) -> float        # F-104 (40…90)
static func fail_loss(qty: int, data: GameData) -> int                              # F-104: floor(qty × crystal_fail_loss_pct / 100)
static func can_start(session: GameSession, action: ActionDef) -> CommandResult     # missing_inputs
static func resolve(session: GameSession, action: ActionDef) -> ActionOutcome       # un solo tiro roll_pct su session.rng per ciclo
```
- `ActionOutcome` ha un campo nuovo `var failed: bool` (tiro fallito: il ciclo conta, `consumed` parziale, nessun output). `ActionRunner` smista per `action.kind`:
  `crystallize` → `EngraverResolver`; tutte le altre azioni dell'Incisore (Lastra, Fondere, Incidere, Potenziare) sono ricette ordinarie di `ArtisanResolver` (F-08 e F-06 valgono come per ogni artigianato).
- `crystallize`: spazio controllato **prima** del tiro come in `ArtisanResolver` (Cristallo nuovo senza casella libera, al netto di quelle liberate dalla Polvere → stop `bank_full`, nessun tiro).
  Riuscito: consuma `N` Polvere, +1 Cristallo, XP e maestria pieni. Fallito: consuma `fail_loss(N)`, XP = `floor(xp × lost / N)`, nessuna maestria, `action_completed` con `outputs` vuoto e il ciclo ripete se restano `N` Polvere (altrimenti `missing_inputs`).
- `data.loot_table(id)` / `data.loot_tables()` (`LootTableDef`: `id`, `entries: Array[DropEntry]`). `AreaDef`, `MonsterDef` e `RiftStoneDef` hanno `loot_tables: Array[StringName]`.
  **Ordine alla morte di un mostro** (aggiunge a 5.10): oro (F-31), `drops` propri nell'ordine dei dati (F-32), poi le tabelle dell'**area** nell'ordine, poi quelle del **mostro**,
  ogni voce con un tiro di probabilità e poi uno di quantità (F-32), infine il frammento (F-07). Per un Monolito: `drops` propri, poi le `loot_tables` **del Monolito** (non quelle dell'area).
  Gli oggetti vanno nella borsa del bottino (o nella Bank con `auto_loot`), come ogni drop.
- `MilestoneDef` (`core/data/defs/milestone_def.gd`): `var at: int; var type: StringName; var item: StringName; var modifiers: Array[Modifier]`. `ActionDef` ha `var kind: StringName` (`&"craft"` default,
  `&"crystallize"`) e `var milestones: Array[MilestoneDef]` (vuoto per le azioni non di raccolta). `ItemDef` ha `bag_slots: int` (0 se non borsa), `contract_skill: StringName`,
  `contract_grade: StringName`, `infusion_grade: int` (default 1), `infusion_family: StringName`; `is_bag()`, `is_contract()`. `class_name HelperGradeDef` (`id`, `interval_mult`);
  `GameData.helper_grades() -> Array[HelperGradeDef]` (ordine di grado), `helper_grade(id)`, `contract_for(skill_id, grade_id) -> ItemDef`.
- **Helper interni di `core/data/`** (non API per gli altri moduli, esistono per il limite di righe di `game_data.gd`): `HelperIndex` (`helper_index.gd`: `grades`, `by_id`,
  `build(balance, items)`, `contract_for`, `clear`), `LootIndex` (`loot_index.gd`: `by_id`, `list`, `build(raw, errors)`, `clear`; `combat/loot_tables.json` è un file obbligatorio),
  `DataBuildUtil` (`data_build_util.gd`: statici `curve`, `action_before`, `list`). `MasteryMilestones` (`systems/mastery/mastery_milestones.gd`, helper di `MasterySystem`):
  `is_gathering`, `changes_sources`, `crossed`, `reached`, `resource_modifiers`, `trade_modifiers` (sorgenti `mastery_item:<action>` e `mastery_trade:<skill>`).
- **Guida (M12)**: `GuideHelperGradeNames` = `HelperGradeNames` (`core/guide/helper_grade_names.gd`, `static func name_of(grade_id) -> String`: nome italiano del grado, l'id se
  sconosciuto; solo presentazione). `GuideRef` ha i tipi `KIND_LOOT_TABLE`, `KIND_MILESTONE`, `KIND_BAG`, `KIND_CONTRACT`; `GuideIndex` le pagine `PAGE_DEPOSIT` (`guide_deposit`)
  e `PAGE_HELPERS` (`guide_helpers`); `GuideTables` le tabelle `bags`, `helper_grades`, `engraver_recipes` e `mastery_milestones:<skill>`.

### 5.23 Carte e Fratture (M13; `01_GDD.md` §17, `02_FORMULAS.md` §7, `04_DATA_SCHEMA.md` §11) — cartella `systems/fractures/`
`CardStore`, `MapCard`, `MapCardRoller` (CORE, M13-01); `FractureSystem`, `FractureRun`, `FractureBag`, `FractureScaler` e l'integrazione nel motore (COMBAT, M13-02); boss (COMBAT, M13-03). Dipendenze di `CardStore`: data, events, rng, modifiers
(solo `item_rarity_pct`), bank (solo `has`/`remove`/`add` di Cristalli e Polvere), deposit. Dipendenze di `FractureSystem`: data, events, modifiers, rng, bank, armory, cards, combat, equipment (cibo).
```gdscript
class_name MapModRoll extends RefCounted       # systems/fractures/map_mod_roll.gd
var mod_id: StringName; var step: int          # F-109: i valori si ricalcolano dai dati

class_name MapCard extends RefCounted          # systems/fractures/map_card.gd
var uid: int; var base_id: StringName; var grade: int; var rarity: StringName   # base_id = fracture_card_<grado>
var mods: Array[MapModRoll]; var locked: bool
func duplicate_card() -> MapCard
func to_dict() -> Dictionary; static func from_dict(d: Dictionary, data: GameData) -> MapCard   # null se non valida

class_name MapCardRoller extends RefCounted    # logica pura, nessuno stato
static func roll_rarity(rarity_pct: float, data: GameData, rng: RngService) -> StringName      # F-109: un randf; &"common"/&"magic"/&"rare"
static func create(grade: int, rarity: StringName, data: GameData, rng: RngService) -> MapCard  # uid 0; modificatori di F-109
static func extend_mods(card: MapCard, rarity: StringName, data: GameData, rng: RngService) -> Array[MapModRoll]   # aggiunge fino al numero della rarità, senza duplicare id né tipo di rischio
static func effects(card: MapCard, data: GameData) -> Array[Dictionary]
    # [{"mod": id, "risk_type": StringName, "risk": float, "reward_type": StringName, "reward": float}] con i valori di F-109 (per il motore e per la UI)

class_name CardStore extends RefCounted
const SAVE_KEY := &"cards"
func used() -> int                             # Carte nel Deposito (occupante "cards", F-100)
func can_add(count: int = 1) -> bool           # deposit.has_room
func add(card: MapCard) -> int                 # assegna il uid e lo restituisce; 0 + card_rejected(grade) se il Deposito è pieno
func create(grade: int, rarity: StringName) -> int   # MapCardRoller.create + add; 0 se piena o grado non valido
func get_card(uid: int) -> MapCard             # copia; null se assente
func cards() -> Array[MapCard]                 # copie, ordine di inserimento
func has(uid: int) -> bool
func set_locked(uid: int, locked: bool) -> CommandResult      # unknown_id
func use_currency(uid: int, currency_id: StringName) -> CommandResult
    # un Cristallo dalla Bank (F-109): unknown_id, not_equippable (non è un Cristallo), item_locked, requirement_not_met (rarità non adatta), not_enough_items; atomico; card_changed(uid, updated)
func salvage(uid: int) -> CommandResult        # F-114: unknown_id, item_locked, bank_full (nulla cambia); la Polvere va nella Bank; card_changed(uid, removed)
func take(uid: int) -> MapCard                 # INTERNO: solo FractureSystem.open; toglie la Carta e la restituisce (null se assente); card_changed(uid, removed)
func roll_rarity() -> StringName               # F-109: rarità di una Carta che cade, con `item_rarity_pct` della sessione (`MapCardRoller.roll_rarity`)
func salvage_dust(grade: int, rarity: StringName) -> int   # F-114: `floor(dust_per_grade × grado × rarity_mult)`, la Polvere che darebbe lo smantellamento
func new_game() -> void; func to_save() -> Dictionary; func from_save(d: Dictionary) -> void
```
- `add`/`create` emettono `card_changed(uid, added)` e `deposit.notify_changed()`; `uid` crescenti da 1 (`next_uid` salvato), mai riusati. Il drop di una Carta (tabelle di drop F-32 con `item` di categoria `map`, e F-113) passa da `cards.create`-equivalente
  con la rarità di F-109 (`item_rarity_pct` globale). Il registro come occupante: `deposit.register_occupant(&"cards", cards.used)` in `_create_systems()` dopo `armory`.
- Save (§6): `{"next_uid": int, "items": [MapCard.to_dict()]}` con `to_dict` = `{"uid", "base", "rarity", "mods": [{"mod", "step"}], "locked"}`. `from_save` tollerante: voce non valida, base non Carta, grado ≠ quello della base, modificatore sconosciuto o
  `step` fuori da `0..fracture.intensity_steps` (voce scartata), `uid` duplicato → `Log.warn` e Carta scartata; `next_uid` ≤ massimo `uid` → massimo + 1. Non controlla la capienza. Nessun segnale.

```gdscript
class_name FractureBag extends RefCounted      # systems/fractures/fracture_bag.gd — borsa della Frattura (nessun limite di caselle)
func add_stack(item_id: StringName, qty: int) -> void
func add_piece(inst: ItemInstance) -> void     # uid 0 fino alla consegna
func add_card(card: MapCard) -> void           # uid 0 fino alla consegna
func stacks() -> Array[Dictionary]             # [{"item": StringName, "qty": int}] in ordine di inserimento
func pieces() -> Array[ItemInstance]; func cards() -> Array[MapCard]
func is_empty() -> bool; func clear() -> void
func to_save() -> Dictionary; func from_save(d: Dictionary, data: GameData) -> void
    # {"stacks": [{"item", "qty"}], "pieces": [ItemInstance.to_dict()], "cards": [MapCard.to_dict()]}; tollerante come LootBag/Armory (voci non valide saltate con Log.warn)

class_name FractureScaler extends RefCounted   # systems/fractures/fracture_scaler.gd — logica pura
static func scale_monster(def: MonsterDef, grade: int, effects: Array[Dictionary], data: GameData) -> MonsterDef   # F-110 poi F-111 (rischi); copia, il dato originale non cambia
static func total(effects: Array[Dictionary], type: StringName) -> float    # somma dei valori (rischio o premio) di quel tipo
static func pack_size(base_size: int, effects: Array[Dictionary], data: GameData) -> int    # `pack_bonus`, limitato a combat.max_pack_size

class_name FractureRun extends RefCounted      # systems/fractures/fracture_run.gd — stato di una Frattura in corso (dati puri, nessun segnale)
var card: MapCard; var grade: int; var groups_total: int
var group: int                                 # 0 = nessun gruppo ancora; 1..groups_total = gruppo in corso o appena superato
var boss_started: bool; var return_area: StringName    # area da riprendere alla fine (&"" = nessuna)
var bag: FractureBag; var effects: Array[Dictionary]   # effects = MapCardRoller.effects(card)
var groups_cleared: int
func next_pack(rng: RngService, data: GameData) -> Array[MonsterDef]   # F-50: sceglie il gruppo (F-77 sull'unione dei gruppi delle aree del grado), lo scala (F-110, F-111), `group += 1`
func boss_def(data: GameData) -> BossDef
func to_save() -> Dictionary; static func from_save(d: Dictionary, data: GameData) -> FractureRun   # null se non valida

class_name FractureSystem extends RefCounted   # systems/fractures/fracture_system.gd
const SAVE_KEY := &"fractures"
func is_active() -> bool
func run() -> FractureRun                      # null fuori dalla Frattura; il motore la legge, non la modifica
func state() -> Dictionary                     # copia per la UI: {} fuori; altrimenti {"grade", "card": MapCard, "group", "groups", "boss": bool, "bag": {"stacks": [...], "pieces": int, "cards": int}}
func open(card_uid: int) -> CommandResult
    # in ordine: unknown_id, fracture_active, fracture_bag_pending. Effetto: cards.take, FractureRun, combat.start_fracture (ferma combattimento e azione, `replaced`, ricorda `return_area`), rebuild_modifiers, fracture_opened(grade)
func abandon() -> CommandResult                # no_fracture; come la sconfitta (combat.abandon_fracture)
func pending() -> Dictionary                   # {} se nulla in attesa; altrimenti {"stacks": [...], "pieces": int, "cards": int} (copia per la UI)
func collect() -> CommandResult                # F-116: no_fracture (nulla in attesa); `bank_full` se restano oggetti, `armory_full` se restano Carte (caselle del Deposito); i pezzi entrano sempre (`armory.add_drop`); ciò che entra si sposta comunque
func has_pending() -> bool
func recommended_level(grade: int) -> int      # F-110 (solo informazione)
func rebuild_modifiers() -> void               # sorgente fracture:<uid>: stat dei premi item_rarity_pct, skill_xp_pct (global), gold_drop_pct (F-111) mentre la Frattura è in corso; nessuna sorgente fuori
func new_game() -> void; func to_save() -> Dictionary; func from_save(d: Dictionary) -> void
```
- **Niente `advance`**: la Frattura non ha timer (X1); la fa avanzare il motore del combattimento. Quindi `GameSession.advance` non chiama più `fractures`.
- Il bottino: `KillRewards.grant` scrive su un **sink** (`add(item_id, qty)`, `add_piece(inst)`, `add_card(card)`): `LootBag` fuori dalla Frattura (pezzi → `add_piece` nel Bottino fino a `collect_all`, M15; Carte → `cards`), `FractureBag` dentro (tutto resta nella borsa: pezzi e Carte
  si consegnano alla vittoria, F-116). L'oro e l'XP vanno subito al portafoglio e al personaggio. Le tabelle di drop dentro la Frattura sono quelle dei mostri (F-32); `loot_qty_pct`, `dust_pct`, `blueprint_pct` (F-111) e le Carte (F-113) si applicano nel sink.
- `fracture_finished` (emesso dal motore) fa scattare nel `FractureSystem`, in modo sincrono: **vittoria** → consegna F-116 (la parte in attesa va in `pending`), **sconfitta/abbandono** → `fracture_loot_lost`, borsa svuotata; poi `fracture_bag_changed` e
  `rebuild_modifiers` (sorgente `fracture:<uid>` tolta). Solo dopo il motore torna all'area (`return_area`) o si ferma.
- Save (§6): `{"run": {} | FractureRun.to_save(), "pending": {} | FractureBag.to_save()}`, con `FractureRun.to_save()` = `{"card": MapCard.to_dict(), "group": int, "groups_cleared": int, "boss_started": bool, "return_area": str, "bag": FractureBag.to_save()}`.
  `from_save` tollerante: `run` non valida (Carta sconosciuta, gruppo fuori da `0..groups_total`) → nessuna Frattura (`Log.warn`; il motore ricaricato non è in Frattura: cfr. sotto) e la sua borsa è persa; `pending` non valido → vuoto. Nessun segnale.

**Classi di appoggio del motore e del boss (COMBAT, M13-02/M13-03)**:
```gdscript
class_name ScaledMonsterDef extends MonsterDef   # systems/fractures/scaled_monster_def.gd — un mostro come appare nella Frattura (F-110/F-111)
var damage_mult: float; var risk_damage_pct: float; var risk_speed_pct: float; var risk_defence_pct: float; var is_boss: bool
static func copy_of(source: MonsterDef) -> ScaledMonsterDef   # livelli, PV, XP e oro già scalati; `CombatantStats.for_monster` legge i moltiplicatori

class_name LootSink extends RefCounted           # systems/combat/loot_sink.gd — dove vanno i drop di un'uccisione (base neutra)
func add(item_id: StringName, qty: int) -> bool; func add_piece(inst: ItemInstance) -> void; func drop_card(grade: int) -> void
func drop_chance(base: ItemDef, chance_pct: float) -> float; func drop_qty(base: ItemDef, qty: int) -> int   # i valori dei dati, invariati
# LootBag (fuori dalla Frattura) e FractureSink (dentro) la specializzano; KillRewards parla solo con questa interfaccia

class_name FractureSink extends LootSink         # systems/combat/fracture_sink.gd — tutto nella borsa della Frattura; applica loot_qty_pct, dust_pct, blueprint_pct (F-111)
func _init(session: GameSession, run: FractureRun); func add_card(card: MapCard) -> void   # drop_card tira la rarità con CardStore.roll_rarity

class_name FractureCombat extends RefCounted     # systems/combat/fracture_combat.gd — la parte del motore specifica della Frattura (nessun flusso proprio)
const PULSE_SOURCE: int = -2                     # attaccante di `combat_hit` dell'impulso (F-111 `pulse`): nessuna posizione di nemico (-1 è il giocatore)
func active() -> bool; func begin(run: FractureRun) -> void; func end() -> void; func sink() -> LootSink
func next_encounter() -> Encounter; func tick(ms: int) -> void; func after_kill(enemy, encounter) -> StringName; func reward(enemy) -> bool
func use_ability(enemy, encounter, me, summoned) -> Dictionary; func absorb(enemy, damage: int) -> int   # abilità e scudo del boss
func view() -> Dictionary; func to_save() -> Dictionary; func from_save(d: Dictionary) -> void

class_name BossAbility extends RefCounted        # systems/fractures/boss_ability.gd — F-112, solo numeri, nessuno stato
static func heavy_strike(boss: CombatantStats, defender: CombatantStats, ability: BossAbilityDef, rng: RngService, …) -> Dictionary   # niente tiro di precisione, solo parata (F-75)
static func shield_amount(max_hp: int, ability: BossAbilityDef) -> int
static func summon_defs(ability: BossAbilityDef, alive: int, used: int, max_pack: int, grade: int, …) -> Array[MonsterDef]   # mai oltre `max_alive` evocati vivi né oltre `max_pack` nemici

class_name BossRewards extends RefCounted        # systems/fractures/boss_rewards.gd — F-115
static func grant(session: GameSession, sink: LootSink, run: FractureRun, boss: MonsterDef) -> void   # pezzo almeno magico + Polvere nella borsa tramite il sink
static func dust_qty(dust: int, dust_pct: float) -> int; static func piece_bases(class_def: ClassDef, grade: int, data: GameData) -> Array[ItemDef]
```
- **Il motore è diviso in due file** per la dimensione: `CombatFight` (`systems/combat/combat_fight.gd`, `extends RefCounted`) contiene la **meccanica** (stato, timer, attacchi, uccisioni, fine della Frattura); `CombatEngine extends CombatFight`
  (`class_name CombatEngine`) contiene l'API pubblica, i comandi e il salvataggio. Il contratto di 5.10 e 5.23 resta quello di `CombatEngine`.

**Motore (aggiunte a 5.10)**:
```gdscript
# in CombatEngine
func start_fracture(run: FractureRun) -> CommandResult    # solo FractureSystem.open: fracture_active se già in Frattura. Ferma l'azione (REPLACED) e l'area (replaced), `run.return_area` = area attuale, PV al massimo, mano 0, combat_started(&""), primo gruppo (run.next_pack)
func abandon_fracture() -> void                           # FractureSystem.abandon e stop(): sconfitta con outcome &"abandoned". Solo `abandon_fracture` e le fini naturali (vittoria, morte) riportano all'area; `stop()` abbandona ma NON riporta (il combattimento resta fermo)
func in_fracture() -> bool
func fracture_run() -> FractureRun                        # null fuori
```
- Stato: gli stati di 5.10 restano; `in_fracture()` è un flag, `area_id()` è `&""` e `get_state()` ha `"fracture": {"group", "groups", "boss": bool, "boss_id", "boss_ability_ms", "shield", "shield_ms"}` (assente fuori dalla Frattura). `enemies` contiene i mostri scalati (`monster` = id del mostro del dato) e,
  per il boss, `monster` = id del boss; gli evocati hanno `summoned = true`. Una `monster_killed(index, monster_id)` per gli evocati non produce bottino (F-112).
- Regole nella Frattura: nessun tiro di Monolito, nessun conteggio F-87, nessun cambio di tratti/abilità (`combat_active`); il cibo e l'auto-cibo (con `food_heal_pct`, F-111) funzionano come fuori; `pulse` (F-111) ha un timer proprio (`fracture.pulse_ms`) salvato; la morte non
  fa `lose_all` sulla borsa del bottino (che non è in gioco: resta com'era) ma sulla borsa della Frattura. A ogni gruppo superato `fracture_group_cleared(index, total)`; dopo l'ultimo e `combat.respawn_ms` parte il boss (`fracture_boss_started(boss_id)`, abilità F-112);
  boss ucciso → vittoria. Nell'ordine: `fracture_finished(outcome, grade, groups, cards, pieces)` → consegna/perdita del `FractureSystem` → ritorno all'area di `return_area` (`start`, PV al massimo, la sua borsa del bottino com'era) oppure stop con `fracture_won`/`player_died`/
  `fracture_abandoned` se non c'era un'area. `stop(reason)` durante la Frattura = abbandono **senza** ritorno all'area (il combattimento resta fermo); solo `abandon_fracture` e le fini naturali riportano all'area. Il ritorno è **differito a fine istante** (dopo l'evento in corso, non dentro di esso). L'impulso emette `combat_hit(FractureCombat.PULSE_SOURCE, PLAYER, …)`; boss ed evocati non entrano in `kills` (F-87) e i Monoliti sono sospesi per tutta la Frattura; lo scudo del boss si rinnova solo se esaurito; l'evocazione non supera mai `max_alive`.
- Save: in `combat` (additivo, `format_version` invariata): `enemies[i].summoned` (bool, assente = false) e `fracture = {"pulse_ms": int, "boss": {"ability_ms": int, "shield": int, "shield_ms": int}}` (assente fuori dalla Frattura). `from_save` risolve i nemici
  sul `FractureRun` già caricato (`FractureSystem.from_save` prima di `combat.from_save`); se `combat` dice di essere in Frattura ma `fractures.run` manca o non è valido → `idle` con `Log.warn`.
- `OfflineSummary` ha `var fractures: Array[Dictionary]` (`[{"grade", "outcome", "groups", "cards", "pieces"}]`, una voce per `fracture_finished` durante l'offline, riempita da `OfflineSimulator` ascoltando il segnale) e `is_empty()` ne tiene conto; `OfflineTexts.fracture_line(entry) -> String`.
- Ordine in `_create_systems()`: `cards` subito dopo `armory` (si registra come occupante del Deposito), `fractures` dopo `equipment` e **prima** di `combat` (accede a `session.combat` solo al momento dei comandi); `from_save`: `armory`, `cards`, `equipment`, `fractures`, `combat`.
  `GameSession.rebuild_modifiers` chiama `fractures.rebuild_modifiers`; `new_game` di `cards` e `fractures` = vuoti.

### 5.24 Alpha (M14; `01_GDD.md` §27.1 e §28, `02_FORMULAS.md` §5e e §8.4, `04_DATA_SCHEMA.md` §21)
Contratto dei task M14-01…M14-09. Dove una firma di un'altra sezione cambia, vale questa. Nessuna `Reasons` nuova (si riusano `not_equippable`, `unknown_id`, `item_locked`, `item_equipped`, `armory_full`).

**Dati (`core/data/`)**
```gdscript
class_name WeaponInfo (aggiunte M14)  ; var dmg_min: int; var dmg_max: int                    # F-22: obbligatori con slot weapon
class_name EquipInfo  (aggiunte M14)  ; var material: StringName                              # &"plate" / &"leather" / &"cloth"; &"" se non armatura
                                        var masterwork: bool; var legendary: LegendaryInfo   # null se non leggendario; grade 1..15
class_name LegendaryInfo extends RefCounted   # core/data/defs/legendary_info.gd
var source_type: StringName                   # &"boss" / &"monolith"
var source_id: StringName; var chance_pct: float
var effects: Array[ItemEffectDef]
class_name ItemEffectDef extends RefCounted   # core/data/defs/item_effect_def.gd
var type: StringName; var params: Dictionary  # tipi e parametri di F-81 / F-120 (stesso formato di un effetto di tratto)
# GameData (aggiunte M14)
func material_grade(piece_grade: int) -> int                  # F-118: equipment.grade_material[g−1]
func grade_level(piece_grade: int) -> int                     # equipment.grade_levels[g−1]
func legendaries() -> Array[ItemDef]                          # tutti i leggendari, in ordine dei dati
func legendaries_from(source_type: StringName, source_id: StringName) -> Array[ItemDef]
func is_equipment_pool_base(base_id: StringName) -> bool      # base che può cadere dal pool F-121 (non masterwork, non legendary)
```
- `ItemInstance.rarity` ammette `&"masterwork"` e `&"legendary"` (ordine `Rarities.ORDER` = common, magic, rare, masterwork, legendary; `filter` di `Armory.set_filter` accetta tutti e 5). `ItemRoller.create` impone la rarità della base se `masterwork` o `legendary`.
- **Basi tolte/cambiate**: `blueprint.rare_component` → `rare_components: Array[ItemQty]` (2, diversi); `BlueprintInfo.grade` = grado del materiale; la stat `damage_reduction` non esiste più (`CombatantStats.damage_reduction` resta solo per i mostri).

**Combattimento (`systems/combat/`)**
```gdscript
class_name WeaponMath extends RefCounted      # systems/combat/weapon_math.gd (logica pura)
static func damage_range(inst: ItemInstance, data: GameData) -> Vector2          # (dmg_min, dmg_max) con moltiplicatore di rarità (F-119/F-120) e raffinazione (F-86); float
static func dps(inst: ItemInstance, attack_interval_pct: float, data: GameData) -> float   # F-22: (min + max)/2 / (intervallo F-26 / 1000)
class_name ArmorMath extends RefCounted       # systems/combat/armor_math.gd (logica pura)
static func reduction_pct(x: int, attacker_level: int, data: GameData) -> float   # F-117: min(cap_pct, 100·X/(X + k·(L + off)))
static func set_budget(piece_grade: int, data: GameData) -> Dictionary           # F-118: {"armor": int, "evasion": int} per i generatori e i test
# CombatantStats (cambiate): var armor: int; var barrier: int            # giocatore (F-117); damage_reduction: float solo mostri (F-25)
#   for_player usa W_max/W_min dell'arma che colpisce (F-22): var weapon_min: float; var weapon_max: float (0 senza arma; float perché il moltiplicatore di rarità e la raffinazione li rendono frazionari)
class_name EquipmentDrop extends RefCounted   # systems/combat/equipment_drop.gd (logica pura, F-121)
static func candidate_grades(monster_level: int, data: GameData) -> Array[int]
static func roll(monster_level: int, data: GameData, rng: RngService) -> StringName   # id di base del pezzo caduto, &"" se niente (ordine dei tiri: chance, tipo, materiale, grado)
static func roll_blueprint(monster_level: int, data: GameData, rng: RngService) -> StringName   # id del progetto, &"" se niente
class_name LegendaryRoller extends RefCounted # systems/combat/legendary_roller.gd (logica pura, F-120)
static func roll(source_type: StringName, source_id: StringName, data: GameData, rng: RngService) -> Array[StringName]   # id di base, uno tiro per leggendario in ordine
```
- Il giocatore applica la riduzione in `CombatFight`: `rid = ArmorMath.reduction_pct(armor o barrier, attacker.power_level, data)` secondo lo stile del mostro (F-117); `armor_pierce_pct` solo per il giocatore.
- **Effetti dei leggendari**: `Equipment.item_effects() -> Array[ItemEffectDef]` (effetti dei leggendari indossati, con sorgente `equipment:<slot>`); `EffectSet` li costruisce come i tratti (F-81) e aggiunge i tipi di F-120 e gli agganci `on_block` (in `CombatFight` alla parata, F-75), `on_gather` (in `GatheringResolver`, solo giocatore) e `on_monolith` (alla morte del Monolito). Il motore non conosce i leggendari per nome.
- **Fonti**: alla vittoria sul boss `FractureSystem` tira `LegendaryRoller.roll(&"boss", boss_id)` e mette i pezzi nella borsa della Frattura (F-116); alla morte di un Monolito il combattimento tira `LegendaryRoller.roll(&"monolith", area_id)` (fonte = id di area) e li passa a `LootBag.add_piece` (M15). Il Deposito pieno perde il pezzo con `armory_rejected` (notifica e riepilogo offline).
- `MapCardRoller` (F-123): `static func risk_points(mod: MapModDef, step: int, data: GameData) -> float`, `static func risk_cap(grade: int, data: GameData) -> float`; la scelta del modificatore riduce lo `step` come in F-123 (stesso ordine dei tiri su `rng`).

**Armeria ed equipaggiamento**
- `Armory.is_filtered` è `false` per `legendary`. `Armory.upgrade` e `upgrade_tool` su un attrezzo leggendario → `not_equippable`. `Equipment.equip(uid, slot)` su `tool_*` accetta un attrezzo leggendario (requisito: livello del mestiere): l'attrezzo unico tornato non indossato resta in Armeria (`item_unique` per vendita e smantellamento).
- `Armory.sort() -> void` (slot, grado decrescente, rarità decrescente, uid) e `Bank.sort() -> void` (categoria, `sort_order`, id) per il pulsante "Riordina" (comandi del modello, emettono `armory_changed`/`bank_changed` come oggi; nessuna nuova capienza).
- Smantellamento: i pezzi senza progetto restituiscono 0 componenti (F-95).

**Maestria (F-122)**
```gdscript
# MasteryMath (aggiunte M14; rule_multiplier tolta con F-11)
static func step_bonus(level: int, kind: StringName, data: GameData) -> Array[Modifier]   # kind &"gathering" / &"crafting"; n × i modificatori di mastery.step.<kind>, scope vuoto (lo imposta MasterySystem)
static func next_step(level: int, kind: StringName, data: GameData) -> Dictionary         # {"level": int, "modifiers": Array[Modifier]}; {} a livello 99
# MasterySystem (aggiunte M14)
func step_info(skill_id: StringName, action_id: StringName) -> Dictionary     # {"level": int, "n": int, "current": Array[Modifier], "next": Dictionary} per la UI (sola lettura)
```
- I modificatori `mastery_step:<action_id>` entrano nel `ModifierService` con ambito `mastery_item:<action_id>`, ricostruiti a ogni `mastery_level_up` (come i vecchi bonus per oggetto).

**Scoperte (F-124)**
```gdscript
class_name Discoveries extends RefCounted     # systems/discovery/discoveries.gd — dipendenze: data, events
const SAVE_KEY := &"discoveries"
func _init(data: GameData, events: GameEvents) -> void       # ascolta item_obtained
func note(item_id: StringName) -> bool        # true se nuovo; emette item_discovered(item_id); id sconosciuto: Log.warn e false
func has(item_id: StringName) -> bool
func items() -> Array[StringName]             # copia, ordine di scoperta
func new_game() -> void                       # vuoto, poi note() per ogni oggetto del kit iniziale
func to_save() -> Dictionary                  # {"items": [id…]}
func from_save(d: Dictionary) -> void         # tollerante: id sconosciuti scartati con Log.warn; assente = vuoto
# GuideIndex (aggiunte M14, sola lettura)
func drops_of(kind: StringName, id: StringName) -> Array[GuideRef]   # kind &"monster" / &"area" / &"rift_stone" / &"boss" / &"action": tutto ciò che può dare, con GuideRef.item e GuideRef.chance_pct (F-124); la UI blocca le voci con !discoveries.has(ref.item)
# GuideRef (aggiunte): var item: StringName; var chance_pct: float   # −1 se non applicabile
```
- Emettono `item_obtained(item_id, qty)`: `Bank.add` (a ogni aggiunta riuscita), `LootBag.add`, `Armory.add`/`add_drop` (id di base, qty 1), `CardStore.add`/`create` (id della base della Carta), il kit iniziale (via `Discoveries.new_game`). `Discoveries` non emette per quantità 0 né per oggetti già noti.
- Il tooltip e `GuideIndex.sources_of` non cambiano di firma: è la UI a nascondere la sezione "Si ottiene da" se `!discoveries.has(item)` e a non mostrarla nei tooltip (§7.u). `Guida` e `Discoveries` non si conoscono: li compone la UI con `session.discoveries`.

**Aggiunte di fine M14** (sono nel codice di M14-03…M14-10; sola lettura salvo dove indicato)
```gdscript
# GameData
func has_action(id: StringName) -> bool                       # true se l'azione esiste (nessun errore se manca)
func has_balance(path: String) -> bool                        # true se il percorso esiste in balance.json (nessun errore se manca; i dati senza pool F-121 restano validi)
# EquipmentPool (core/data/equipment_pool.gd, logica pura, F-121: descrizione e percentuali del pool)
static func table(level: int, data: GameData) -> Dictionary[StringName, float]   # id di base -> % per uccisione di un mostro di quel livello (pezzi, poi progetti); {} senza pool nei dati
static func chance_of(base_id: StringName, level: int, data: GameData) -> float
# EquipmentDrop usa la stessa tabella dei tiri; KillRewards.roll_pool lo chiama dopo il tiro della scheggia (anche nelle Fratture)
# Upgrade (systems/armory/upgrade.gd, F-86)
const DUST_ITEM: StringName = &"rift_dust"
static func cost(level: int, grade: int, data: GameData) -> Dictionary    # {gold, ingot, ingots, shards, dust}: `dust` da upgrade.levels[].dust, controllata in check e pagata in pay
static func material_grade(inst: ItemInstance, data: GameData) -> int     # grado del materiale 1..8 usato per il costo (non il grado del pezzo 1..15)
# MasterySteps (systems/mastery/mastery_steps.gd, F-122, funzioni pure su GameData)
static func scoped(level: int, category: StringName, action_id: StringName, data: GameData) -> Array[Modifier]   # scope action:<id>
static func info(level: int, category: StringName, data: GameData) -> Dictionary   # {"level", "n", "current", "next": {"level", "modifiers", "text"} o {}}; MasterySystem.step_info lo chiama
# MasteryMath (aggiunte): static func step_count(level: int, data: GameData) -> int; static func step_kind(category: StringName) -> StringName
# MapCardRoller (aggiunte): static func total_risk_points(mods: Array[MapModRoll], data: GameData) -> float; static func fitting_step(mod: MapModDef, step: int, room: float, data: GameData) -> int
# GuideIndex (core/guide/, sola lettura; `discoveries` è session.discoveries passato come Object, la Guida non conosce Discoveries)
func drops_view(kind: StringName, id: StringName, discoveries: Object) -> Array[Dictionary]   # [{ref: GuideRef, item, unlocked: bool, name ("???" se bloccato), chance_pct (-1 se bloccato)}]; kind come drops_of
func sources_visible(item_id: StringName, discoveries: Object) -> Array[GuideRef]             # sources_of se l'oggetto è scoperto, [] altrimenti
# GuideDrops (core/guide/guide_drops.gd): static func is_unlocked(item_id: StringName, discoveries: Object) -> bool; static func pct_text(value: float) -> String   # fino a 4 decimali, senza zeri inutili
# GuideRef: nuovi tipi KIND_POOL, KIND_BOSS, KIND_ACTION; GuideRef.item e GuideRef.chance_pct anche in sources_of
# Bank.sort() / Armory.sort(): comandi del modello (vedi sopra); Armory ha l'ordinamento nella classe di UI ArmorySort per la vista
```
- **Effetti dei leggendari, agganci aggiunti a `TraitEffect`** (con default neutro; `EffectSet` li compone): `cap_damage(ctx, damage: int) -> int` (`hit_cap_pct`, dopo F-25, minimo 1) e `damage_mult_against(ctx, target_hp: int, target_max_hp: int) -> float` (`execute_mult`; prodotto dei fattori degli effetti). Sono in `EffectSet` e non nei segnali di `EventBus`.
- **Chiavi lette dal codice** (valori in `balance.json`, tarati in M14-10): `fracture.risk_cap`, `fracture.risk_unit`, `mastery.step`, `loot.equipment`, `loot.blueprint`, `upgrade.levels[].dust`.

**Sessione e salvataggio**: `GameSession.discoveries: Discoveries` (modulo `discoveries`, ultimo della composizione); `SaveMigrator.CURRENT_VERSION` = **5** (6 da M15, §6); `format_version` 4 → `version_unsupported`. Le chiavi tolte/cambiate sono quelle dei dati (Armatura, basi nuove), non della struttura del save.
### 5.25 Monoliti da Metin e Bottino con i pezzi (M15; `01_GDD.md` §24b, §10.13-10.14, `02_FORMULAS.md` §5f, `04_DATA_SCHEMA.md` §22)

**LootBag** (pezzi nel Bottino, Z1; `systems/combat/loot_bag.gd`)
```
func pieces() -> Array[ItemInstance]
func add_piece(inst: ItemInstance) -> void
    # nessun filtro e nessun limite di pezzi (niente loot_lost per Bottino pieno): con auto_loot (T ≥ 1) → armory.add_drop(inst) subito; altrimenti il pezzo attende in lista; loot_bag_changed
func collect_pieces() -> void          # ogni pezzo con armory.add_drop(inst): il filtro (Armory.is_filtered) agisce QUI (scartato = smantellato, item_salvaged); Armeria piena → smantellato, leggendario → armory_rejected;
    # i pezzi lasciano sempre il Bottino; loot_bag_changed alla fine. Usato da collect_all e dall'OfflineSimulator a ogni blocco da 60 s
func collect_all() -> CommandResult    # collect_pieces + impilati nella bank; bank_full se qualcosa degli impilati resta
func lose_all() -> void                # morte: un loot_lost per tipo e per pezzo
func to_save() -> Dictionary           # {"stacks": [{"item", "qty"}], "pieces": [ItemInstance.to_dict() senza uid]}; from_save tollerante (voci non valide saltate con Log.warn; accetta anche l'Array v5)
```
- Un pezzo nel Bottino **non è nell'Armeria** (`armory.get`/`can_add` non lo contano) e non è indossabile; `KillRewards.grant` usa il sink `add_piece` (anche per i leggendari dei Monoliti, F-120). La conservazione degli oggetti
  (QA) vale su Bottino + Armeria + smantellati.
- `Armory.add(inst)` è l'unico ingresso senza filtro; `add_drop` resta per la Frattura e per i test.

**Monolito a ondate** (`systems/combat/`; il motore resta `CombatEngine`, la logica nuova in classi di supporto, es. `StoneFight`)
- `GameData.rift_stones_for_area(area_id) -> Array[RiftStoneDef]` (pool ordinato per `level`); alla comparsa (F-87) il motore sceglie un Monolito con `rng` e salva `stone_id`; `rift_stone_appeared(stone_id)` invariato.
- PV massimi F-125 (non nel dato), impulso fisso `metin.pulse_damage` che **non** passa da F-25/F-75, ondate F-126 (`StoneFight.waves_crossed(hp_after: int, hp_max: int, fired: Array[int], thresholds_list: Array[int]) -> Array[int]`, pura e testabile),
  bottino F-127 (`MonolithLoot.guaranteed_piece(level: int, rng: RngService, session: GameSession) -> ItemInstance`, puro), salto F-128.
- `RiftStone.reward(loot: LootSink, def: RiftStoneDef, loot_mult: float = 1.0) -> void` consegna il bottino del Monolito; la **fonte del leggendario** è l'**id di area** (`LegendaryRoller.drops(SOURCE_MONOLITH, def.area_id, …)`), non l'id del Monolito.
- Nuovi segnali (CombatEngine): `rift_stone_wave(stone_id: StringName, threshold: int, count: int)` (`threshold` 100 = primo colpo, poi 75, 50, 25), `rift_stone_skipped(stone_id: StringName)` (Monolito scartato da F-128),
  `skip_stone_changed(level: int)`.
- Impostazione di salto (**stato dello slot**, modulo `combat`): `func skip_stone_level() -> int`; `func set_skip_stone_level(level: int) -> CommandResult` (`invalid_choice` se fuori da 0..99, nessun cambio). Il nuovo slot
  parte da `balance.combat.skip_stone_level`.
- `CombatEngine.get_state()` espone per la UI (sola lettura): `stone = {"id", "level", "hp", "max_hp", "fired": [int]}` (`{}` fuori dal Monolito), `skip_stone_level`, `enemies_alive: int` (nemici vivi; la UI confronta con
  `combat.crowd_threshold`) e `enemies[i].summoned`. Nessuno stato di gioco nella UI.
- **UI (M15-06/07)**: vista compatta con gruppi per tipo dal solo `get_state()`; sezione "Pezzi" del Deposito e pagina Equipaggiamento (solo pezzi) leggono `loot.pieces()` e `armory`; comandi solo
  `combat.set_skip_stone_level` e `combat.loot.collect_all`.
- **Chiavi lette dal codice**: `metin.*`, `combat.crowd_threshold` (solo UI), `combat.skip_stone_level` (default del nuovo slot).

### 5.26 Aggiunte di M16-M18 (R-07)
- **V10**: nessun cambiamento di contratto. La sezione Pezzi del Deposito e la pagina Equipaggiamento leggono entrambe `Armory` (pezzi non indossati) e `LootBag` (pezzi non raccolti); nessuna copia, nessun segnale o metodo nuovo.
- **V1, V2, V11**: le firme (precisione visibile, moltiplicatore XP, riduzione del drop degli evocati) le fissa M17-01 dopo F-129/F-130; fino ad allora valgono le firme esistenti. Save `format_version` 6 invariata.

### 5.27 Village (`systems/village/village.gd`, M19; `01_GDD.md` §30, `02_FORMULAS.md` F-131…F-133, `04_DATA_SCHEMA.md` §24) — dipendenze: data, events, modifiers, bank, wallet, skills
```gdscript
class_name Village extends RefCounted
const SAVE_KEY := &"village"
func _init(session: GameSession) -> void                       # come Shop: legge data, events, modifiers, bank, wallet, skills dalla sessione
func buildings() -> Array[StringName]                          # id di tutti gli edifici, compresi i segnaposto, in ordine di `order`
func is_buildable(building_id: StringName) -> bool             # false per i segnaposto (market, noticeboard) e per id sconosciuti
func level(building_id: StringName) -> int                     # 0 = non costruito; 0 per id sconosciuti
func max_level() -> int                                        # balance village.max_level
func effect_at(building_id: StringName, at_level: int) -> float   # F-132: per_level × at_level (0 se at_level < 1 o id non costruibile)
func next_cost(building_id: StringName) -> Dictionary          # costo del livello successivo: {"gold": int, "items": [{"item": StringName, "qty": int}], "requires_woodwright": int}; {} se al massimo, segnaposto o sconosciuto
func can_upgrade(building_id: StringName) -> CommandResult     # in ordine: unknown_id, not_buildable, max_level, level_too_low, not_enough_gold, not_enough_items
func upgrade(building_id: StringName) -> CommandResult         # stessi controlli; poi spende l'oro, toglie gli oggetti dal Bank (anche se bloccati), level + 1, rebuild della sorgente, village_upgraded
func rebuild_modifiers() -> void                               # sorgente `village:<id>` per ogni edificio con livello ≥ 1: un Modifier {stat, value = effect_at(id, level), scope}; nessuna sorgente a livello 0
func new_game() -> void; func to_save() -> Dictionary; func from_save(d: Dictionary) -> void
```
- **Un solo comando** per costruire e migliorare (`upgrade`): costruire è il passaggio 0 → 1. Nessun timer, nessun `advance`, nessun caso offline, nessuna demolizione. I controlli di `can_upgrade` non cambiano nulla;
  `upgrade` è atomico: dopo `can_upgrade` ok non può fallire a metà (oro con `Wallet.spend`, poi `Bank.remove` per ogni riga; se una riga fallisse comunque, `push_error` e oro restituito: caso non raggiungibile da `can_upgrade` ok).
- `level_too_low`: `skills.get_level(&"woodwright") < requires_woodwright`. `max_level`: `level(id) ≥ max_level()` (motivo nuovo, §Reasons). `not_buildable`: nuovo motivo. `not_enough_gold`/`not_enough_items` esistono già in `Reasons`.
- I costi e gli effetti vengono dai livelli generati in `buildings.json` (`levels[n−1]`), non si ricalcolano a runtime; il test di coerenza con F-131 sta nel validatore e in `test_village_cost.gd`.
- **Segnale** nuovo in `EventBus`: `signal village_upgraded(building_id: StringName, new_level: int)` (emesso dopo i modificatori). `modifiers_changed` lo emette già il `ModifierService`. Nessun altro segnale (la UI si aggiorna anche con `bank_changed`, `gold_changed`, `level_up`).
- **Reasons nuovi** (`core/common/reasons.gd`): `NOT_BUILDABLE := &"not_buildable"`, `MAX_LEVEL := &"max_level"`.
- **Save** (§6): `modules.village = {"levels": {building_id: int}}`, solo gli edifici con livello ≥ 1. `from_save` tollerante, con `Log.warn`: `levels` non oggetto → tutto a 0; id sconosciuto o segnaposto → scartato; valore non intero o ≤ 0 → scartato; valore oltre `max_level` → limitato. Chiave assente = partita nuova (nessun edificio).
  **Nessuna migrazione e `format_version` invariata (7)**: è un modulo nuovo e additivo, come `discoveries` e `cards` (§6, "chiavi assenti in `modules` = stato di partita nuova"); un save v7 senza `village` si carica con tutti gli edifici a 0 e un save con `village` caricato da una build che non lo conosce lo scarta con `Log.warn` (modulo sconosciuto, §5.3). M20 (Mercato, Bacheca) aggiungerà i suoi dati con la stessa regola o con una migrazione se cambia un formato esistente.
- **Composizione** in `GameSession` (§5.3): campo `var village: Village` (null prima di M19-02). In `_create_systems()`, dopo `shop` (dipende da bank, wallet, skills): `village = Village.new(self)` e
  `_join(Village.SAVE_KEY, village.new_game, village.to_save, village.from_save, village.rebuild_modifiers)`. `rebuild_modifiers` va dopo `skills` e `deposit`; `_tick`: nessuno. La chiave `village` non è usata dai `FakeSystem` dei test. `game_session.gd` resta sotto il limite di ~400 righe del progetto (M19: 213 righe, tetto corrente nel test `MAX_SESSION_LINES`).
- **Dati**: `GameData.village_building(id) -> VillageBuildingDef` e `village_buildings() -> Array[VillageBuildingDef]` (ordine di `order`); campi di `VillageBuildingDef`: `id`, `name`, `description`, `icon`, `order`, `buildable`, `milestone`, `effect_stat`, `effect_scope`, `effect_per_level`, `levels: Array[Dictionary]` (voci di §24 con `items` come `[{item: StringName, qty: int}]`). La UI usa solo `Village` e i `*Def` per nome, descrizione, icona e testi.
- **Deposit** (modifica a 5.20): `Deposit.capacity()` = `deposit.base_slots + extra_slots() + floor(modifiers.total(&"deposit_slots"))` (F-133). Il costruttore `Deposit.new(session)` legge `session.modifiers` (nessun `bind_modifiers`: `GameSession` crea i `modifiers` prima della composizione) (dipendenza nuova: `modifiers`; resta senza dipendenze da `Bank`/`Armory`/`Village`). `Deposit` ascolta `events.modifiers_changed` e chiama `notify_changed()` (emette `deposit_changed` solo se `capacity` è cambiata). `unequip_bag` usa la `capacity'` che include `deposit_slots`.
- **UI** (§7.t, sola lettura e comandi): la pagina legge `session.village`, `session.data`, `session.skills`, `session.wallet`, `session.bank`; nessuna copia di stato; si aggiorna con `village_upgraded`, `bank_changed`, `gold_changed`, `level_up`.

### 7.t UI del Villaggio (M19-03; nessuno stato di gioco nella UI, solo letture e comandi; `01_GDD.md` §30)
- Cartella `ui/pages/village/`: `village_page.gd/.tscn`, `village_box.gd/.tscn` (un box per edificio), `village_texts.gd` (testi italiani: nomi dei motivi di `can_upgrade`, "Costruisci", "Migliora", "In arrivo", "Livello n/8", "Richiede Falegname n", "Mancano k" per riga); ogni file < 400 righe.
- `page_host.gd`: voce `&"village"` → `res://ui/pages/village/village_page.tscn`; `sidebar.gd`: voce `{"page": &"village", "text": "Villaggio", "icon": ...}` dopo `shop`.
- Il box mostra: nome, `Livello n/8`, effetto attuale e del livello successivo (da `Village.effect_at`), costo (`Village.next_cost`) riga per riga con "posseduti/richiesti" (da `Bank.get_count`), oro, requisito del Falegname, e il pulsante (`Costruisci` se livello 0, `Migliora` altrimenti, nascosto a livello massimo con la scritta "Livello massimo"); disabilitato se `can_upgrade` non è ok, con il motivo accanto. I segnaposto sono box grigi "In arrivo" senza pulsante.
- Layout leggibile a 1280×720 (Q87): 5 + 2 box in una griglia che va a capo.


## 6. Formato del salvataggio (`user://saves/slot_<n>.json`)

Versione **7 da M17** (M19: il modulo `village` è additivo, versione invariata) (v6 da M15 e v5 da M14 si migrano; vedi sotto); v5 da M14 (v4 da M12, v3 da M10, v2 da M4-03, D3). Un save v1, v2, v3 o **v4 non si carica** (`version_unsupported`, nessuna migrazione: nessun giocatore reale ancora; M14 cambia il significato di `damage_reduction`, le basi dei pezzi e aggiunge `discoveries`). `SaveMigrator.CURRENT_VERSION` = 5.
**Save v7 e migrazione v6 → v7 (M17-04, `core/save/migrations/migration_6_to_7.gd`)**: `SaveMigrator.CURRENT_VERSION` = 7; v5 e v6 si migrano in catena, v1-v4 restano `version_unsupported`. Le 10 aree strette sostituiscono le 4 larghe (`02_FORMULAS.md` §8.5). Nessuna chiave nuova, cambiano i valori in `modules`:
- `combat.area` e `fractures.run.return_area`: se non nomina più un'area esistente diventa **l'area che contiene il livello del personaggio** (la più alta il cui `level_min` non supera il livello; livello 1 se manca l'XP); un'area ancora esistente resta.
- Incontro in corso (`encounter`, `riftstone`, `between`): riparte come `between` con `enemies = []` ed `effects = {}` (i mostri vecchi hanno altre statistiche); `wave` rimosso; il Monolito in attesa è annullato e il contatore riparte (`stone` = `{since: 0, pending: false, stone_id: ""}`). Bottino, uccisioni, morti, cibo e stato delle Fratture restano.

**Save v6 e migrazione v5 → v6 (M15, `core/save/migrations/migration_5_to_6.gd`)**: `SaveMigrator.CURRENT_VERSION` = 6; v5 si migra, v1-v4 restano `version_unsupported`. Chiavi nuove o cambiate, tutte in `modules.combat`:
- `loot`: da Array `[{"item","qty"}]` a `{"stacks": [...], "pieces": [ItemInstance.to_dict()]}` (pezzi in attesa nel Bottino, Z1). Migrazione: `stacks` = il vecchio array, `pieces` = `[]`.
- `skip_stone_level`: int (Z7); migrazione: 0.
- `stone`: `{since, pending, stone_id}`; `stone_id` = Monolito scelto alla comparsa ("" se nessuno). Migrazione: `stone_id` = ""; una Pietra `pending` della v5 diventa `pending = false` (id e livelli dei Monoliti cambiano con M15-02).
- `wave`: `{"fired": [int]}` (soglie già scattate: 100 = primo colpo, 75, 50, 25; solo nello stato `riftstone`; assente = nessuna). In stato `riftstone` i PV del Monolito sono in `enemies[0].hp`; il massimo si ricalcola da F-125.
  Migrazione: un combattimento v5 in stato `riftstone` diventa `between` con `enemies = []` (il vecchio Monolito sparisce senza perdite; Bottino e contatori restano).
`from_save` tollerante: `stone_id` sconosciuto → `pending = false` con `Log.warn`; `skip_stone_level` non intero o fuori 0..99 → 0; `wave.fired` malformato → vuoto. Nessun altro modulo cambia.
```json
{
  "format_version": 7,
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
               "loot": {"stacks": [{"item": "boar_tusk", "qty": 2}], "pieces": []}, "skip_stone_level": 0,
               "stone": {"since": 41, "pending": false, "stone_id": ""}, "kills": {"plains_boar": 41}, "deaths": 1, "food_eaten": 12},
    "shop": {"purchases": {"loot_pocket": 2, "auto_eat_1": 1}},
    "deposit": {"bags": ["bag_canvas", "bag_leather", "", "", "", ""]},
    "helpers": {"forestry": {"grade": "journeyman", "action": "cut_redbirch", "elapsed_ms": 4200}},
    "rift": {"sockets": ["inf_swift_hands", "", "", "", ""]},
    "hints": {"seen": ["first_action"]},
    "cards": {"next_uid": 3, "items": [{"uid": 2, "base": "fracture_card_2", "rarity": "magic", "mods": [{"mod": "sturdy", "step": 5}], "locked": false}]},
    "fractures": {"run": {}, "pending": {}},
    "discoveries": {"items": ["redbirch_log", "emberbronze_sword"]},
    "village": {"levels": {"storehouse": 3, "forge": 1}}
  }
}
```
Regole: chiavi assenti in `modules` = stato di partita nuova per quel sistema (così aggiungere un sistema non richiede
migrazioni); id sconosciuti al caricamento vengono scartati con `Log.warn`; enum sempre come stringhe; `total_level`,
`player_name`, `saved_at_unix_ms`, `play_time_ms` in testa servono al menu senza caricare tutto. I modificatori e le
statistiche derivate non si salvano (M12: anche la capienza del Deposito). Lo stato del giocatore non esiste fuori da questo file. In `combat.enemies` ogni
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
# deposit_changed (M12), equipment_changed, character_level_up (scollegati in unbind).
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
func show_hit(hit: bool, damage: int, blocked: bool, color: Color) -> void   # (EnemyZone.show_hit(index, text, color, big, flash, damage: int = 0): damage opzionale per i numeri aggregati) danno, CombatTexts.MISS_TEXT o BLOCKED_TEXT, dissolvenza sul posto
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

class_name NumberFormat extends RefCounted         # core/common/number_format.gd, solo statiche; unica definizione dei formati
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
`deposit_changed` (M12; era bank_capacity_changed). Numeri via `NumberFormat`; costanti di presentazione di tooltip e GameWindow in
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
`bank_changed` e `deposit_changed` (M12) di `session.events` e a ognuno rilegge tutto (nessuna copia delle quantità oltre
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

Opzioni di M12-07: `helpers=0|1` (simula i tre aiutanti Maestro e stampa XP/ora di mestiere con e senza aiutanti, per l'invariante F-102), `engraver=0|1` (polvere, schegge e cristalli per ora e tempo per un Cristallo), `deposit=0|1` (caselle usate nel tempo e perdita di oggetti con la borsa del bottino piena).

### 7.z UI di P-01/P-02 (pagina Personaggio, Banco del fabbro, slot Cibo)
```gdscript
# core/session/player_name.gd (P-01/P-03): rinomina del personaggio dello slot corrente
static func rename(session: GameSession, new_name: String) -> CommandResult   # invalid_name (nome dopo strip fuori da
                                  # `player_name.min_length`..`max_length` di balance.json); salva lo slot; emette `player_renamed`
class_name ForgeBench extends VBoxContainer       # ui/pages/skill/forge_bench.gd (P-02): sezione "Banco del fabbro" della pagina Fabbro
func bind(session: GameSession) -> void           # collega gli eventi; comandi: armory.upgrade, socket_stone, clear_socket, use_currency
func unbind() -> void
func select(uid: int) -> void                     # sceglie il pezzo (indossato o in Armeria)
func selected_uid() -> int
class_name FoodSlotView extends PanelContainer    # ui/pages/equipment/food_slot_view.gd (P-02): slot "Cibo" della bambola; solo presentazione
signal food_chosen(item_id: StringName); signal clear_requested; signal open_requested
func show_food(food: ItemDef, count: int) -> void # count = quantita' nel deposito (il cibo non esce dalla bank)
func open_menu(foods: Array[Dictionary]) -> void
func food_id() -> StringName; func menu() -> PopupMenu; func clear_button() -> Button
```


### 7.w UI della Riforma 2 (M12-06; nessuno stato di gioco nella UI, solo letture e comandi)
```gdscript
# BankPage (rotta bank) diventa la pagina "Deposito" a due schede sulla stessa capienza (W1)
class_name DepositTabs extends TabContainer     # ui/pages/bank/deposit_tabs.gd (+ .tscn), dentro BankPage; nodo "DepositTabs"
# Scheda "Oggetti": bank.stacks() (come oggi). Scheda "Equipaggiamento": armory.instances() non indossate (armory.is_worn).
# Entrambe disegnano `deposit.capacity()` caselle: le piene dai dati, le vuote come nodi "EmptyCell" (decorativi, nessun dato) fino alla capienza;
# il contatore "usate / capienza" viene da deposit.used()/capacity(); su deposit_changed e bags_changed rileggono tutto. Nessuna copia dei dati.
class_name BagSlotsBar extends HBoxContainer    # ui/pages/bank/bag_slots_bar.gd (+ .tscn), in cima alla BankPage; nodi "BagSlot_0" … "BagSlot_5"
signal equip_requested(slot_index: int, item_id: StringName)   # la pagina chiama bank.equip_bag
signal unequip_requested(slot_index: int)                      # la pagina chiama bank.unequip_bag
func redraw(session: GameSession) -> void       # deposit.bags(), nome e caselle della borsa; uno slot vuoto offre le borse possedute (bank.stacks con is_bag)
# Rifiuti in MessageLabel con BagTexts.REFUSED (deposit_not_empty: "Libera prima le caselle in più", bag_slot_occupied, not_a_bag, not_enough_items).
class_name HelperRow extends HBoxContainer      # ui/pages/skill/helper_row.gd (+ .tscn), interna a SkillPage dei tre mestieri di raccolta; nodo "HelperRow"
signal change_requested(skill_id: StringName, action_id: StringName)   # la pagina chiama helpers.set_action
signal stop_requested(skill_id: StringName)                            # helpers.stop
signal hire_requested(contract_item_id: StringName)                    # helpers.hire
func redraw(session: GameSession) -> void       # "Aiutante: <grado> — lavora: <risorsa> [Cambia] [Ferma]"; senza aiutante "Aiutante: nessuno" e i contratti posseduti per "Assumi";
                                                # barra da helpers.get_progress, intervallo da helpers.interval_ms; se is_blocked "In attesa: Deposito pieno"
# Scelta della risorsa: helpers.available_actions (nomi = solo il nome della risorsa). Redraw su helper_changed, helper_completed, helper_blocked, bank_changed, level_up.
```
- **Pagina dell'Incisore**: la `SkillPage` generica per `riftbinding` (nessuna pagina nuova); le sezioni per tipo di azione (Lastra, Fondere, Cristalli, Incidere,
  Potenziare) sono raggruppamenti di presentazione dei dati (`ActionDef.kind`, id con prefisso); ogni azione `crystallize` mostra "Probabilità: N%"
  (`EngraverResolver.crystal_chance_pct` al livello attuale) e "Fallimento: perdi M Polvere" (`fail_loss`). Nessuna ricetta mostra produzione "dal nulla": gli ingredienti
  sono sempre drop, e la card dice da dove vengono (stessa fonte di `GuideIndex.sources_of`).
- **TopBar** mostra `deposit.used()/capacity()` e si aggiorna su `deposit_changed` (non più `bank_capacity_changed`); `ArmoryPage`/`EquipmentPage` mostrano il contatore del Deposito
  (stesse `used/capacity`) e si ridisegnano su `deposit_changed` al posto di `armory_capacity_changed`.
- **Pannello dell'oggetto** (`BankItemPanel`): per una `bag` il pulsante "Metti nello slot" (primo slot libero → `equip_requested`); per un `contract` il pulsante "Assumi" (`hire`).
- **Shop**: scompaiono le voci di spazio e la bottega "deposito"; **Combattimento/Guida/testi**: "Monolito del Rift" al posto di "Pietra del Rift" (bersaglio speciale), "Incisore" al posto
  di "Legatura del Rift", i nomi di pietre/valute/rune di `NOMI.md`; testi in `UiStyle`/file di testi centralizzati, nessuna stringa vecchia visibile (test).
- **Toast/feedback**: `mastery_milestone_reached` → toast "Traguardo di maestria: <risorsa> (25/50/99)"; `helper_blocked(true)` → avviso "L'aiutante del <mestiere> è fermo: Deposito pieno".
- **Guida** (M12-06): pagine scritte a mano nuove (`data/guide/`): Deposito e borse, Aiutanti, Maestria per risorsa, Incisore, Monoliti del Rift (sezioni e `help_for` di
  `04_DATA_SCHEMA.md` §19; "?" nelle pagine Deposito e dell'Incisore); tabelle generate nuove in `GuideTables`: `bags`, `helper_grades`, `engraver_recipes`, `mastery_milestones:<skill>`.


### 7.v UI di M13 (Fratture come mappe; nessuno stato di gioco nella UI, solo letture e comandi)
```gdscript
class_name FracturesPage extends Page           # ui/pages/fractures/fractures_page.gd (+ .tscn), rotta fractures (voce "Fratture" della sidebar, sezione Partita)
# Fuori dalla Frattura: elenco delle Carte (session.cards.cards(), ordinate per grado decrescente poi uid) con grado, rarità, e per ogni modificatore nome, rischio e premio
# (valori da MapCardRoller.effects) e il livello consigliato (session.fractures.recommended_level); comandi per Carta: "Apri" (fractures.open), "Blocca/Sblocca" (cards.set_locked),
# "Smantella" (cards.salvage, mostra la Polvere), "Cristalli" (cards.use_currency con i Cristalli posseduti). Se session.fractures.has_pending(): riquadro "Bottino in attesa" con "Raccogli" (fractures.collect).
# Durante la Frattura: barra "Gruppo N/30" e "Boss" (fractures.state()), modificatori attivi, borsa della Frattura (fractures.state()["bag"]), "Abbandona" con conferma (ConfirmDialog; fractures.abandon).
# Rifiuti in MessageLabel con FractureTexts.REFUSED (unknown_id, fracture_active, fracture_bag_pending, item_locked, requirement_not_met, not_enough_items, bank_full).
class_name FractureTexts extends RefCounted     # ui/pages/fractures/fracture_texts.gd — testi italiani; static func effect_line(effect: Dictionary) -> String ("PV dei mostri +40%"), rarity_name, outcome_text(outcome)
class_name FractureRunPanel extends VBoxContainer   # ui/pages/fractures/fracture_run_panel.gd — avanzamento, modificatori, borsa; func redraw(session: GameSession) -> void
class_name CardRow extends PanelContainer       # ui/pages/fractures/card_row.gd — una Carta; signals open_requested(uid), lock_requested(uid, locked), salvage_requested(uid), currency_requested(uid)
```
- Redraw su `card_changed`, `deposit_changed`, `fracture_opened`, `fracture_group_cleared`, `fracture_boss_started`, `fracture_finished`, `fracture_bag_changed`, `fracture_loot_lost`, `bank_changed` (Cristalli).
- **Combattimento**: con `combat.in_fracture()` la pagina mostra "Frattura di grado N — gruppo i/N" al posto dell'area, i nemici come sempre (il boss con il suo nome e l'abilità in corso, scudo se attivo), niente scelta dell'area né Monoliti; le zone "borsa del bottino"
  e "Raccogli tutto" restano per la borsa del bottino normale (non toccata). Un rimando alla pagina Fratture per la borsa e per "Abbandona".
- **Toast**: `fracture_finished` → "Frattura vinta!" (con il numero di Carte e pezzi) / "Frattura persa: bottino perduto" / "Frattura abbandonata"; `card_rejected` → "Carta persa: Deposito pieno". **Riepilogo offline**: `OfflineSummaryView` mostra le righe di `OfflineSummary.fractures`.
- **Guida**: pagina scritta a mano nuova `guide_fractures` ("Fratture", `data/guide/`; `GuideIndex.PAGE_FRACTURES`), tabelle generate nuove in `GuideTables`: `fracture_grades` (F-110), `map_mods` (F-111), `bosses` (F-112); ogni Carta (`category: map`) è documentata nella pagina dell'oggetto; "?" nella pagina Fratture.

### 7.u UI di M14 (Alpha; nessuno stato di gioco nella UI, solo letture e comandi; `01_GDD.md` §29)
```gdscript
class_name ItemCard extends PanelContainer       # (esistente, scheda del pezzo) — M14: arma = danno minimo-massimo (WeaponMath.damage_range), velocità (F-26) e danno al secondo (WeaponMath.dps);
                                                 # armatura = Armatura e Barriera in % contro un attaccante del livello del giocatore (ArmorMath.reduction_pct, solo informativo); leggendario = effetti (ItemEffectDef → testo) e "Fonte" solo se scoperto
class_name RarityColors extends RefCounted       # ui/theme/rarity_colors.gd — static func color(rarity: StringName) -> Color: bianco, blu, giallo, viola (masterwork), arancione (legendary)
class_name SubTabBar extends HBoxContainer       # ui/components/sub_tab_bar/sub_tab_bar.gd — signal tab_selected(id: StringName); func setup(tabs: Array[Dictionary]) -> void  # [{"id","label"}]
class_name LockedCell extends PanelContainer     # ui/components/locked_cell/locked_cell.gd — casella bloccata della Guida: func setup(data: GameData) -> void; func show_locked() -> void; func show_item(item_id: StringName, chance_pct: float) -> void
# Barra XP del personaggio in Combattimento: riusa la `XpBar` esistente (nessuna `PlayerXpBar`), alimentata da session.character (F-71) e da character_xp_gained / character_level_up
class_name MasteryStepRow extends HBoxContainer  # ui/pages/mastery/mastery_step_row.gd — func show_info(info: Dictionary) -> void  # da MasterySystem.step_info: bonus attuali e "Al livello N: …"
```
- **Combattimento**: barra XP del personaggio; "In fila" → "**Altri nemici**"; etichetta del triangolo: "**Forte contro di te**" (il mostro è in vantaggio), "**Debole contro di te**" (in svantaggio), "**Alla pari**" (testi in `CombatTexts`).
- **Shop**: la descrizione di ogni voce si compone dai dati (`ShopTexts.describe(entry, data)`: PV curati, %, effetti, numeri letti da `shop.json` e `balance.json`, mai scritti a mano).
- **Incisore**: `SubTabBar` con Lastre, Fondere, Cristalli, Rune; **Fabbro**: Lingotti, Piastre, Progetti, Banco del fabbro. Le sottoschede sono solo vista: la scheda scelta non si salva.
- **Deposito**: pulsante **Riordina** nella scheda aperta (`Bank.sort()` o `Armory.sort()`, §5.24).
- **Fratture**: `CardRow` più bassa, un modificatore per riga compatta (rischio e premio sulla stessa riga).
- **Guida**: l'oggetto non scoperto è una `LockedCell`; la pagina di un oggetto scoperto mostra "Si ottiene da" (`GuideIndex.sources_of`); le pagine di mostro, area, Monolito, boss e attività usano `GuideIndex.drops_of` con `LockedCell`. I tooltip (`Tooltips`) non contengono mai "Si ottiene da".
- **Toast**: `item_discovered` → "Nuovo: <oggetto>" (raggruppati come gli altri toast, solo una riga per scoperta; non per il kit iniziale).
- **Maestria**: ogni carta dell'azione mostra `MasteryStepRow`; il pannello della maestria resta com'è.
- **Colori** dei pezzi con `RarityColors` ovunque appaia un pezzo (inventario, scheda, tooltip, Armeria, toast).
