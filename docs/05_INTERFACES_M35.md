# 05. Interfacce, M35-D: Attrezzi con teste e raccolta mirata (§3h, §4g, §5.44-§5.46, §6h, §7.ac)

Estensione di `05_INTERFACES.md` (che supera le 400 righe): **è contratto** con le stesse regole (lo modifica solo il Reviewer; un task che ha bisogno di una firma nuova si
ferma e la chiede). Dove contraddice `05_INTERFACES.md` (§5.8 Equipment, §5.9 Armory, §6 save, §7 ToolUpgradePanel/ActionCard) o `_M24`…`_M30` vale questo file. Design
`01_GDD_M35.md` (§42), formule `02_FORMULAS_M35.md` (F-195…F-199), dati `04_DATA_SCHEMA_M35.md` (§35). Task: M35-D1 CORE, M35-D2 DATA, M35-D3 UI (`07_TASKS_M35.md`).

## 3h. Segnali (`core/autoload/event_bus.gd`, M35-D1)
```gdscript
signal gather_focus_changed(skill_id: StringName, action_id: StringName)   # set_focus riuscito o scelta tolta (action_id = &""); mai in new_game/from_save
```
`armory_changed(uid, updated)` esistente si emette anche dopo `choose_tool_head` (`updated = true`).

## 4g. Motivi di rifiuto (`core/common/reasons.gd`, M35-D1)
Nuovi: `HEAD_LOCKED = &"head_locked"`, `UNKNOWN_HEAD = &"unknown_head"`, `INVALID_STEP = &"invalid_step"`, `HEAD_UNCHANGED = &"head_unchanged"`. Esistenti riusati: `unknown_id`,
`not_a_tool`, `not_equippable`, `not_enough_gold`, `not_learned`, `level_too_low`.

## 5.44 Stat nuove (`ModifierService`, nessuna sorgente nuova)
`node_units_pct`, `node_rich_pct`, `byproduct_chance_pct` (registro `data/config/stats.json`, §35.3). Letture con `ModifierContext.for_action(skill, action)`:
`NodeWork.begin` (u di F-198, `p` di F-199), `GatheringResolver` (sottoprodotto, F-199). Nessun'altra sorgente: le teste sono modificatori `equipment:<slot>` come oggi.

## 5.45 Armory e Equipment (`systems/armory/armory.gd`, `systems/equipment/equipment.gd`, `systems/armory/armory_kit.gd`, M35-D1)
```gdscript
# Equipment
const SLOTS: Array[StringName] = [... , &"tool_forestry", &"tool_quarrying", &"tool_angling", &"tool_herbalism"]   # un quarto slot attrezzo

# Armory (solo attrezzi unici; teste di F-197, costi di F-198)
func tool_heads(uid: int) -> Array[StringName]          # 3 elementi (passi di tool_upgrade.head_steps), &"" = nessuna scelta; [] se non è un attrezzo unico
func choose_tool_head(uid: int, step: int, head_id: StringName) -> CommandResult   # step ∈ head_steps (3, 6, 9); rifiuti nell'ordine di F-198; atomico; paga solo un cambio
func tool_head_cost(uid: int, step: int) -> int         # 0 se il passo è senza scelta, altrimenti respec_gold(step) (F-198); sola lettura per la UI
func tool_next_step(uid: int) -> Dictionary             # invariata; guadagna "head_step": int (0 se il passo non è 3/6/9) per un avviso «Scegli una testa»

# ArmoryKit (nuovo)
static func ensure_tools(session: GameSession) -> bool   # per ogni base in balance start.tools: se l'attrezzo unico non esiste (né indossato né in Armeria) lo crea a +0 e lo equipaggia; true se ha creato
```
- `Armory.get_instance(uid)` per un attrezzo unico guadagna `"heads": Array` nel dizionario; `Equipment`/`ModifierService` ricostruiscono i modificatori di `equipment:<slot>` da
  `base × raffinazione (F-196) + teste attive (F-197)` a ogni `armory_changed` dell'attrezzo e a `equip`/`unequip`.
- `GameSession.from_save` chiama `ArmoryKit.ensure_tools` **dopo** il caricamento di armory ed equipment e prima di `modifiers.rebuild`; `new_game` usa lo stesso kit (nessun codice doppio).
- `upgrade_tool` e `choose_tool_head` su un leggendario → `not_equippable`. L'attrezzo unico tornato in Armeria conserva `heads`.

## 5.46 Raccolta mirata (`systems/disciplines/disciplines.gd`, `systems/encounters/encounter_cycle.gd`, `systems/encounters/node_work.gd`, M35-D1)
```gdscript
# Disciplines
func focus_of(skill_id: StringName) -> StringName        # &"" = Automatico
func set_focus(skill_id: StringName, action_id: StringName) -> CommandResult   # F-195; &"" toglie; unknown_id / not_learned / level_too_low; emette gather_focus_changed
# reset_skill e unlearn tolgono focus[skill_id] (emettono gather_focus_changed con &"" se c'era una scelta)

# EncounterCycle (F-195)
static func worked_action(data: GameData, skill_id: StringName, skill_level: int, max_level: int, focus: StringName = &"") -> ActionDef
# NodeWork.begin: passa session.disciplines.focus_of(skill); calcola u (F-198) e p (F-199); salva node.ne
```
Stato del nodo (`get_state()["node"]`) guadagna `"ne": int` (nodo lavorato) e `"focused": bool` (la risorsa è quella scelta; false se Automatico o se il nodo non la permette);
`"focus_blocked": bool` è true se la scelta c'è ma il nodo l'ha ignorata (per il testo «Qui lavori solo fino a …»).

## 6h. Salvataggio (v12 additivo)
```
"disciplines": {"learned": {...}, "recipes": [...], "extra": [...], "focus": {"quarrying": "quarry_emberbronze"}}
"armory": {"items": [{"uid": 3, "base": "unique_pick", ..., "upgrade": 5, "heads": ["pick_vein", "", ""]}]}
"combat": {"node": {..., "ne": 87}}
"equipment": {"slots": {..., "tool_herbalism": 7}}
```
- `from_save`: `focus` — chiavi non di raccolta, discipline non apprese o `action_id` non dello stesso skill sono **ignorate** (nessun errore); `heads` — lunghezza ≠ 3 o id sconosciuto →
  `&""` in quella posizione; `ne` assente → `N` senza `node_units_pct`. Nessun campo mancante è un errore (v12 «vecchio» deve caricarsi). **`format_version` resta 12**; `to_save`
  scrive sempre i campi nuovi.

## 7.ac UI (M35-D3; contratto interno a `SkillPage`, nessuna logica)
```gdscript
class_name ToolUpgradePanel extends PanelContainer     # ui/pages/skill/tool_upgrade_panel.gd: guadagna la sezione «Teste»
signal head_chosen(uid: int, step: int, head_id: StringName)   # la pagina chiama armory.choose_tool_head; il rifiuto va in MessageLabel
# Teste: tre righe (+3, +6, +9) con due pulsanti (nome, effetto da modifiers/dati, «gratis» o costo da tool_head_cost); stato «bloccata (serve +N)»; evidenzia la scelta corrente;
# conferma se costa oro (cambio). Avviso «Scegli una testa» se tool_next_step.head_step > 0 o c'è un passo raggiunto senza scelta. Nodi: HeadRow_<step>, HeadButton_<step>_<head_id>.
class_name ResourceTable extends VBoxContainer        # ui/pages/skill/resource_table.gd (+ righe in resource_row.gd), sostituisce l'elenco di ActionCard delle discipline di raccolta
func setup(data: GameData, skill_id: StringName) -> void
func redraw(session: GameSession) -> void             # legge bank, uses_of, mastery, colore (NodeColorPreview), disciplines.focus_of
signal focus_requested(skill_id: StringName, action_id: StringName)   # la pagina chiama session.disciplines.set_focus; &"" = Automatico
# Colonne: icona e nome, livello, scorta, «Serve a» (GuideIndex.uses_of, max 3 voci + «e altro»), prezzo, maestria + prossimo bonus, colore ora, «Raccogli questa»; badge «Mirata»;
# filtro (LineEdit + CheckBox «Solo con scorta»); pulsante «Automatico» in testa. Nodi: ResourceRow_<action_id>, FocusButton_<action_id>, AutoButton, FilterEdit, StockOnly.
```
La scheda del nodo (`NodeCard`) legge `focused` e `focus_blocked` e mostra l'etichetta «Mirata» o la riga «Qui lavori solo fino a …». Nessun calcolo nella UI (colore, resa, costi dal modello).
Ridisegno su `gather_focus_changed`, `armory_changed`, `bank_changed`, `level_up`, `mastery_*`.
