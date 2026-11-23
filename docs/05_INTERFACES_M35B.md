# 05. Interfacce, M35B: Risorse per zona con percentuali (V45)

Estensione di `05_INTERFACES.md` (contratto: lo cambia solo il Reviewer). Design `01_GDD_M35B.md` (§43), formule `02_FORMULAS_M35B.md` (F-200…F-203), dati `04_DATA_SCHEMA_M35B.md` (§36).
Task: M35B-1 CORE, M35B-2 DATA, M35B-3 UI (`07_TASKS_M35B.md`). **Sostituisce** `05_INTERFACES_M35.md` §3h (segnale), §5.46, la parte `focus` di §6h e la parte focus di §7.ac.

## 3i. Segnali (`core/autoload/event_bus.gd`)
**Tolto** `gather_focus_changed(skill_id, action_id)`. Nessun segnale nuovo (la tabella delle zone è dato fisso; la risorsa di un nodo è già in `node_started`).

## 4h. Motivi di rifiuto (`core/common/reasons.gd`)
`LEVEL_TOO_LOW` si **toglie solo se** nessun altro comando lo usa (il CORE lo verifica con `Grep`); `NOT_LEARNED` e `UNKNOWN_ID` restano.

## 5.47 Risorse per zona (`core/data/`, `systems/encounters/`, M35B-1)
```gdscript
# core/data/area_nodes_def.gd (AreaNodesDef) e nuova classe core/data/node_resource_def.gd
class_name NodeResourceDef extends RefCounted
var action: StringName
var weight: int                                         # percentuale della zona (somma 100 per disciplina)
# AreaNodesDef: ogni NodeEntryDef guadagna  var resources: Array[NodeResourceDef]  (ordine di livello crescente)
func resources_of(skill_id: StringName) -> Array[NodeResourceDef]   # [] se la disciplina non ha nodi nella zona
# GameData
func zones_of_action(action_id: StringName) -> Array[Dictionary]    # [{"area": StringName, "pct": int}], ordinate per pct decrescente, a parità per area.order; [] se mai
# EncounterCycle (static; sostituisce worked_action)
static func eligible_resources(data: GameData, area_id: StringName, skill_id: StringName, skill_level: int) -> Array[NodeResourceDef]   # F-200 passo 1
static func fallback_action(data: GameData, skill_id: StringName, skill_level: int) -> ActionDef   # F-200 passo 4: livello più alto <= skill_level; null solo per dati errati
static func pick_resource(session: GameSession, area_id: StringName, skill_id: StringName, skill_level: int, skipped: bool) -> ActionDef   # F-200; UN solo pick_weighted se >= 2 idonee e non saltato
static func resource_odds(data: GameData, area_id: StringName, skill_id: StringName, skill_level: int) -> Array[Dictionary]
#   F-202: [{"action": ActionDef, "weight": int, "pct_nominal": int, "pct_effective": float, "workable": bool}] in ordine della tabella; se la zona non ha la disciplina: []
# NodeWork.begin: chiama pick_resource (prima di roll_pct del nodo ricco, F-199); non legge né emette più focus
```
Stato del nodo (`get_state()["node"]`): **tolti** `"focused"` e `"focus_blocked"`; `"ne"` e le altre chiavi invariate. `Disciplines`: **tolti** `focus_of`, `set_focus` e la classe
`GatherFocus` (file `systems/disciplines/gather_focus.gd` cancellato); `reset_skill` e `unlearn` non toccano più nulla di focus. `EncounterCycle.worked_action` **non esiste più**
(chiamanti: `NodeWork`, `tools/sim_encounters.gd`, i test elencati in `07_TASKS_M35B.md`).

## 6i. Salvataggio (v12, invariato)
```
"disciplines": {"learned": {...}, "recipes": [...], "extra": [...]}      # nessun "focus"
```
- `to_save` **non scrive** `disciplines.focus`. `from_save`: se la chiave `focus` c'è, si **ignora** (nessun errore, nessun log sopra `debug`); non si migra in nulla.
- Un nodo in corso salvato conserva `action` e `ne`: **nessun tiro** in `from_save`. `format_version` resta **12**; un v12 prodotto dal build M35 (con `focus`) si carica.

## 7.ad UI (M35B-3; contratto interno a `SkillPage`, nessuna logica)
```gdscript
class_name ResourceTable extends VBoxContainer         # ui/pages/skill/resource_table.gd (+ resource_row.gd)
func setup(data: GameData, skill_id: StringName) -> void
func redraw(session: GameSession) -> void              # legge bank, uses_of, mastery, NodeColorPreview, GameData.zones_of_action, EncounterCycle.resource_odds (zona attuale)
# Tolti: signal focus_requested, FocusButton_<id>, AutoButton, badge «Mirata»; le righe non emettono segnali.
# Colonne: icona e nome, livello, scorta, «Serve a», prezzo, maestria + prossimo bonus, colore ora, «Si trova in» (una riga «Zona NN%» per voce di zones_of_action; la zona attuale
#   in evidenza; tooltip con pct_effective al livello attuale); filtro (LineEdit + CheckBox «Solo con scorta»). Nodi: ResourceRow_<action_id>, WhereLabel_<action_id>, FilterEdit, StockOnly.
```
`NodeCard` **non legge** più `focused`/`focus_blocked` e non ha più `FocusLabel`. Nessun calcolo nella UI (percentuali, colore, scorta dal modello). Ridisegno su `armory_changed`,
`bank_changed`, `level_up`, `mastery_*`, `combat_started` (cambio zona).
