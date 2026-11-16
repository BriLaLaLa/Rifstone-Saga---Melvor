# 05. Interfacce, M25: Nodi con tentativi (§3c, §5.33b, §6b, §7.p)

Estensione di `05_INTERFACES_M24.md` §3b, §5.33, §6b, §7.o. Dove c'è conflitto vale questo file. Formule in `02_FORMULAS_M25.md`.

## 3c. Segnali dell'EventBus (M25-02)
| Segnale | Parametri | Emesso da | Quando |
|---|---|---|---|
| `node_attempt_done` | `skill_id: StringName, action_id: StringName, attempt: int, attempts: int, units: int, total_units: int, color: StringName` | CombatEngine | dopo ogni tentativo lavorato, **dopo** `bank_changed`, XP, maestria e `action_completed(node, …)` di quel tentativo; `units` = unità del tentativo, `total_units` = del nodo finora, `color` = id F-154 di quel tentativo |
- `node_started(skill_id, action_id, skipped, duration_ms)` **invariato**; un nodo ricco/difficile si legge da `get_state()["node"]` subito dopo.
- `node_finished(skill_id, action_id, units, reason)`: `units` = totale del nodo; `reason` guadagna **`too_hard`** (saltato per `min_level`) accanto a `node_done`, `bank_full`, `not_learned`.
- `action_completed(lane = &"node", …)`: ora **uno per tentativo** con almeno un'unità (prima: uno per nodo), emesso prima di `node_attempt_done`.
- Ordine di un tentativo: `bank_changed` … → `xp_gained`/`level_up`/`xp_capped` → maestria → `action_completed(node, …)` → `node_attempt_done`; all'ultimo (o a `bank_full`): `node_finished` → `travel_started`.
- `Reasons.TOO_HARD` (valore `&"too_hard"`) nuovo in `core/common/reasons.gd` (conteggio di `test_reasons.gd` +1).

## 5.33b Logica dei tentativi (M25-02) — dipendenze invariate
```
# EncounterCycle (aggiunte, funzioni pure; i numeri vengono da session.data.balance, mai nel codice)
static func difficulty(session, area_id, skill_id) -> int                      # F-161
static func yield_pct(session, level: int, difficulty: int) -> int             # F-162
static func attempts_for(session, rich: bool) -> int                           # F-161
static func attempt_units(session, k: int, attempts: int, rich: bool, yield_pct: int) -> int   # F-162, k 1-based
static func attempt_time_ms(duration_ms: int, attempts: int, k: int) -> int    # F-161 t_k
static func expected(p: Dictionary) -> Dictionary                              # F-165: p gains rich_chance_pct, rich_ms_pct, rich_units_pct, yield: {skill: int}
# NodeWork (cambiata)
var attempts: int; var attempt: int; var rich: bool; var units: int; var skip_reason: StringName   # skip_reason: not_learned | too_hard | &""
static func begin(session, area_id, skill_id) -> NodeWork      # F-154, F-161, un solo roll_pct F-164 se lavorato
func due_attempts() -> int                                     # tentativi con t_k <= elapsed non ancora risolti
func resolve_attempt(session) -> ActionOutcome                 # F-162/F-163: riusa GatheringResolver.resolve_units(units, xp_pct del colore di adesso); attempt += 1
func is_complete() -> bool                                     # attempt == attempts (o chiuso da bank_full)
func color(session) -> Dictionary                              # invariato nel significato: colore di adesso
# toglie `finish` (sostituita da resolve_attempt)
```
`CombatEngine`: in `node`, a ogni avanzamento `elapsed += delta`; finché `due_attempts() > 0` risolve in ordine e emette i segnali di §3c, poi `node_finished`. Il resto del
ciclo (`travel`, `fight`, morte, `stop`) è come in M24 (§5.33): un nodo interrotto perde **solo i tentativi non ancora risolti**: ciò che è già nel Deposito resta.

**`get_state()["node"]`** (`{}` fuori dal nodo): `skill`, `action`, `duration_ms`, `elapsed_ms`, `skipped`, `skip_reason`, `color` (di adesso), `attempts`, `attempt` (risolti),
`rich`, `difficulty`, `level` (della disciplina), `yield_pct` (di adesso, F-162), `units` (messe finora), `units_planned` (`floor(Ne × y / 100)` di adesso), `last_attempt`
(`{}` o `{"units": int, "color": StringName, "xp": int}` dell'ultimo tentativo). `xp` è letta dai segnali/risultato del motore, mai calcolata dalla UI.

## 6b. Salvataggio: `format_version` resta **8**, additivo (M25-02)
`combat.node` (solo se lavorato) guadagna `attempts: int`, `attempt: int`, `rich: bool`, `units: int` accanto a `skill`, `action`, `elapsed_ms`, `duration_ms`, `skipped`.
Lettura tollerante: **se mancano** (nodo di un salvataggio della M24 in corso) il nodo riparte con `elapsed_ms` 0, `attempt` 0, `rich` false, `attempts` = `encounters.attempts`,
durata ricalcolata (nessuna perdita di oggetti); valori incoerenti (`attempt` > `attempts`, negativi) → viaggio verso scontro, come un nodo malformato di M24. Salva → carica → salva identico.
Niente `migration_8_to_9`; `SAVE_VERSION` non cambia (verificare il test di versione).

## 7.p UI di M25 (nessuno stato di gioco nella UI; `01_GDD_M25.md` §36.5)
```
# ui/pages/combat/node_card.gd — class_name NodeCard extends PanelContainer; refresh(state: Dictionary, data: GameData); sostituisce NodePanel (da togliere con i suoi test)
# nodi per i test: NodeArt (Control che contiene un AnimatedSprite2D "NodeSprite" con SpriteFrames da assets/nodes/<skill>/ e CPUParticles2D "NodeParticles"),
#   ResourceLabel, ColorLabel, RichBadge (visibile se rich), AttemptsRow (AttemptPip_<i>, i = 1..attempts; stato fatto/corrente/da fare), TimeBar (elapsed/duration),
#   LootList (una LootRow per oggetto con numero che sale con un tween), XpLabel, LockedLabel (nodo saltato: motivo, lucchetto)
# ui/pages/combat/node_card_texts.gd — testi (it); ui/pages/combat/node_art.gd — NodeArt.build_frames(skill_id) -> SpriteFrames (da file per convenzione §30.3)
```
- Nello stato `node` la pagina Combattimento mostra `NodeCard` **al posto** del riquadro del bersaglio (`EnemyZone` resta per `fight`); `TravelMap` invariata.
- Sul segnale `node_attempt_done` la scheda anima il numero del bottino e il segnaposto; tra un tentativo e l'altro legge solo `get_state()`; nessun calcolo di resa.
- Particelle e sprite: nodi di Godot (`AnimatedSprite2D`, `CPUParticles2D`, `Tween`), non GIF; con `Window` ridotta o `reduced motion` (impostazione già esistente, se c'è) si fermano.
- Layout verificato a 1280×720 e 1600×900 (M25-06).
