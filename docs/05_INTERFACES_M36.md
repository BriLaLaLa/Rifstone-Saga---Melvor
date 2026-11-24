# 05. Interfacce, M36 e M36B: Pagina di raccolta a schede (V46)

Estensione di `05_INTERFACES.md` (contratto: lo cambia solo il Reviewer). Design `01_GDD_M36.md` (§44), formule `02_FORMULAS_M36.md` (F-204…F-208), dati `04_DATA_SCHEMA_M36.md` (§37).
Task: `07_TASKS_M36.md` (UI) e `07_TASKS_M36B.md` (CORE + UI). Save v12 **invariato**. Nessun segnale nuovo, nessun motivo di rifiuto nuovo.

## 3j. Sessione (`core/session/game_session.gd`, M36B-1)
```gdscript
var in_offline: bool = false        # true while an offline run (OfflineSimulator.run, advance_silently, debug time skip) advances the session; never saved
var gather_stats: GatherStats       # created by GameSession (composition only), listens to the events below; no save entry
```
`OfflineSimulator.run` e `OfflineSimulator.advance_silently` mettono `in_offline = true` all'inizio e `false` alla fine (anche per `DebugTimeSkip`, che passa da `advance_silently`);
`core/autoload/game.gd` non cambia.

## 5.48 Statistiche di sessione (`systems/encounters/gather_stats.gd`, M36B-1)
```gdscript
class_name GatherStats extends RefCounted
func _init(session: GameSession) -> void             # connects node_finished, xp_gained; start_ms = session.play_time_ms
func nodes(skill_id: StringName) -> int
func units(skill_id: StringName) -> int
func xp(skill_id: StringName) -> int
func elapsed_ms() -> int                             # session.play_time_ms - start_ms
func rate_units(skill_id: StringName) -> int         # F-204; -1 = not available (elapsed < gather_stats.min_sample_ms)
func rate_xp(skill_id: StringName) -> int            # F-204; -1 = not available
func time_to_level(skill_id: StringName) -> int      # F-205, ms; -1 = not available, -2 = max level
```
Sola lettura, nessuno stato salvato; ignora gli eventi con `session.in_offline`. `GameSession.advance` non cambia.

## 5.49 Fabbisogno e consigli (M36B-2)
```gdscript
# systems/disciplines/gather_needs.gd
class_name GatherNeeds extends RefCounted
static func of(session: GameSession, skill_id: StringName) -> Dictionary
# -> {"entries": Array[Dictionary{"item": StringName, "action": StringName, "source": StringName (&"queue"/&"quest"), "missing": int}],
#     "other": int, "other_skill": StringName}   # F-206; other_skill = the first other discipline involved (&"" if other == 0)
# systems/encounters/gather_advice.gd
class_name GatherAdvice extends RefCounted
static func best_zone(session: GameSession, action_id: StringName) -> Dictionary      # F-207: {"area","pct_nominal","pct_effective"} or {"reason": &"level"/&"access"}
static func next_unlocks(session: GameSession, skill_id: StringName) -> Dictionary    # F-208: {"level": int, "resources": [{"action": StringName, "zones": Array[StringName]}]} or {}
```
Pure, senza stato; leggono `GameData`, `skills`, `character`, `bank`, `actions.jobs()`, `Quests`. La UI non calcola nulla di tutto questo.

## 6j. Dati
`balance.json` → `gather_stats.min_sample_ms` (`04_DATA_SCHEMA_M36.md` §37.1); lettura con `data.balance_value("gather_stats.min_sample_ms")`.

## 7.ae UI di raccolta (M36; contratto interno a `ui/pages/skill/`, nessuna logica)
```gdscript
# ui/pages/skill/gather/gather_body.gd (M36-1)
class_name GatherBody extends VBoxContainer          # replaces ResourceTable/FoundIn/ToolPanel placement in SkillPage for a gathering skill
func setup(session: GameSession, skill_id: StringName) -> void
func redraw(session: GameSession) -> void            # redraws the visible tab only
signal go_to_area_requested(area_id: StringName)     # relayed from ResourceTable.zone_requested
signal tool_upgrade_requested(uid: int)
signal tool_head_chosen(uid: int, step: int, head_id: StringName)
const TAB_OVERVIEW: StringName = &"overview"; const TAB_RESOURCES: StringName = &"resources"; const TAB_TOOL: StringName = &"tool"
func show_tab(tab: StringName) -> void
# Nodes: GatherTabs (TabBar), TabOverview, TabResources, TabTool; Overview: ZoneNowSection, ToolLine (button OpenToolButton), and hidden StatsSection, ProgressSection, NeedsSection (M36B fills them).
# ui/pages/skill/resource_table.gd (M36-2): setup(data, skill_id) and redraw(session) unchanged; signal zone_requested(area_id: StringName); no filter widgets.
# ui/pages/skill/resource_row.gd (M36-2): one compact row + ResourceDetail (resource_detail.gd) opened by a click on the row; one detail open at a time (the table closes the others).
#   Nodes: ResourceRow_<action_id>, DetailBox_<action_id>, GoButton_<action_id>_<area_id>; the compact row has columns Risorsa, Liv., Scorta, Zona, Colore (ball).
# ui/pages/skill/foldable_section.gd (M36-1): class_name FoldableSection extends VBoxContainer; setup(title: String, content: Control); toggle button FoldButton; collapsed by default.
```
`SkillPage` (M36-1) crea `GatherBody` al posto di `ResourceTable`, `GatheringInfo` e `ToolUpgradePanel`; inoltra `go_to_area_requested` a `session.combat.start(area_id)` (un rifiuto → `CombatTexts.REASON_TEXTS`
sotto l'intestazione, come `_show_refusal_text`) e gli altri due segnali ai comandi `armory.upgrade_tool` / `armory.choose_tool_head` già usati. Ridisegno sugli stessi eventi di oggi (`bank_changed`,
`armory_changed`, `level_up`, `mastery_*`, `combat_started`/`combat_stopped`, `modifiers_changed`).

## 7.af UI di raccolta (M36B-3)
`ui/pages/skill/gather/` aggiunge `stats_section.gd`, `progress_section.gd`, `needs_section.gd` (+ testi) che riempiono i contenitori di `GatherBody`; `ResourceRow` legge «Zona» da
`GatherAdvice.best_zone` (mostra «serve livello N» / «serve un personaggio di livello più alto» per i motivi `level` / `access`); `NeedsSection` mostra le voci di `GatherNeeds.of` con «Vai» per
la migliore zona e il contatore «+N di altre discipline» che emette `page_requested(skill:<other_skill>)` attraverso `GatherBody`/`SkillPage`. `StatsSection` e `ProgressSection` ridisegnano con un
timer di 1 s (`_process` accumulato, nessun segnale nuovo: le statistiche non emettono eventi).
