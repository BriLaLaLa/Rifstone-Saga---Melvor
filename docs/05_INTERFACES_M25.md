# 05. Interfacce, M25: Nodi con tentativi (§3c, §5.33b, §5.33c, §6b, §7.p) e ritocchi dopo Alpha 1 (§5.31b, §6c, §7.p1, §7.p2)

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
func is_over() -> bool                                         # il nodo finisce adesso: saltato → elapsed >= duration; lavorato → is_complete()
func end_reason() -> StringName                                # motivo di node_finished: skip_reason (saltato), bank_full (chiuso), altrimenti node_done
func next_event_ms() -> int                                    # ms al prossimo tentativo (o alla fine di un nodo saltato); 0 se finito
func yield_pct(session) -> int; func units_planned(session) -> int   # F-162 di adesso (0 per un nodo saltato)
func color(session) -> Dictionary                              # invariato nel significato: colore di adesso
func to_save() -> Dictionary
static func from_save(raw: Dictionary, data: GameData, area_id: StringName) -> NodeWork   # area_id dà la difficoltà (F-161); null se malformato
# toglie `finish` (sostituita da resolve_attempt)
```
- **Deposito pieno**: se in un tentativo **nessuna** unità trova posto, `resolve_attempt` restituisce `ok` false con motivo `bank_full`, il tentativo **non conta**
  (`attempt` e `units` invariati, nessun segnale del tentativo) e il nodo si chiude (`is_complete()` true, `end_reason()` = `bank_full`); con almeno un'unità
  messa il tentativo conta (`ok` true, `reason` `bank_full`) e poi il nodo si chiude.
`CombatEngine`: in `node`, a ogni avanzamento `elapsed += delta`; finché `due_attempts() > 0` risolve in ordine e emette i segnali di §3c, poi `node_finished`. Il resto del
ciclo (`travel`, `fight`, morte, `stop`) è come in M24 (§5.33): un nodo interrotto perde **solo i tentativi non ancora risolti**: ciò che è già nel Deposito resta.

**`get_state()["node"]`** (`{}` fuori dal nodo): `skill`, `action`, `duration_ms`, `elapsed_ms`, `skipped`, `skip_reason`, `color` (di adesso), `attempts`, `attempt` (risolti),
`rich`, `difficulty`, `level` (della disciplina), `yield_pct` (di adesso, F-162), `units` (unità **messe finora** nel nodo, somma dei tentativi risolti),
`units_planned` (unità **previste** per tutto il nodo alla resa di adesso, `floor(Ne × y / 100)`; non è la somma garantita dei tentativi), `last_attempt`
(`{}` o `{"units": int, "color": StringName, "xp": int}` dell'ultimo tentativo). `xp` è letta dai segnali/risultato del motore, mai calcolata dalla UI.

**Dati (M25-03)**: `AreaNodesDef.difficulty_of(skill) -> int`, `min_level_of(skill) -> int`. Il validatore (`core/data/data_validator_disciplines.gd`)
accetta nelle voci di `nodes.json` i campi facoltativi `difficulty` e `min_level` (interi 1..livello massimo) e rifiuta `min_level` > difficoltà effettiva
(`difficulty` o, se assente, il `max_level` dell'area), come `04_DATA_SCHEMA_M25.md` §30.1.

## 5.33c Strumento "Avanza il tempo" (M25-07; `01_GDD_M25.md` §36.9b)
```
# core/offline/debug_time_skip.gd
class_name DebugTimeSkip extends RefCounted
static func max_hours(session) -> int                          # ore intere permesse dal tetto offline.cap_ms (almeno 1)
static func elapsed_ms(session, hours: int) -> int             # clamp(hours × 3.600.000, 0, offline.cap_ms)
func run(session, hours: int, yield_frames: bool = true) -> OfflineSummary   # coroutine (await): da offline.min_ms in su OfflineSimulator.run
                                                               # (eventi su session.events, riepilogo); sotto, advance_silently e null
# core/settings/game_settings.gd
const KEY_DEBUG_SKIP_HOURS := "debug_skip_hours"               # default 1; solo user://settings.cfg, mai nello slot
```
- UI: `SettingsPanel` (`ui/settings/settings_panel.gd`) ha la sezione **"Debug"** solo con una sessione aperta: SpinBox delle ore (1..`max_hours`) e pulsante
  "Avanza"; mette in pausa `GameClock` durante il salto, salva la scelta in `GameSettings` e apre `OfflineSummaryView` con il riepilogo. Nessuno stato nella UI.

## 6b. Salvataggio: `format_version` resta **8**, additivo (M25-02)
`combat.node` (solo se lavorato) guadagna `attempts: int`, `attempt: int`, `rich: bool`, `units: int` accanto a `skill`, `action`, `elapsed_ms`, `duration_ms`, `skipped`.
Un nodo **saltato** guadagna invece `skip_reason: String` (`not_learned` | `too_hard`; additivo: se manca o è diverso da `too_hard` vale `not_learned`).
Lettura tollerante (`NodeWork.from_save(raw, data, area_id)`): **se manca uno dei quattro campi** (nodo lavorato di un salvataggio della M24 in corso) il nodo riparte
con `elapsed_ms` 0, `attempt` 0, `units` 0, `rich` false, `attempts` = `encounters.attempts` e la **`duration_ms` salvata** (F-155 non è cambiata; nessuna perdita di oggetti); valori incoerenti (`attempt` > `attempts`, negativi) → viaggio verso scontro, come un nodo malformato di M24. Salva → carica → salva identico.
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
- Layout verificato a 1280×720 e 1600×900 (M25-06) con `tools/shot_ui.tscn` (`timeout 90 Godot --path . --resolution 1280x720 res://tools/shot_ui.tscn -- <out_dir> 1280x720`).
- **Come è stata fatta (M25-04)**: senza file in `assets/nodes/<skill>/` (oggi) `NodeArt.build_frames` usa un segnaposto disegnato da codice (Q134);
  `LootList` ha **una sola** `LootRow` (la risorsa del nodo, `units`), perché lo stato non porta il bottino per oggetto (Q133).
- **Da M25-13 (V29)** la scheda sta nell'`Arena` al posto di `EnemyZone` e `TravelMap` è tolta: vale §7.p2.

---
# Aggiunte di M25-10 (V27-V29; `01_GDD_M25.md` §37): §5.31b, §6c, §7.p1, §7.p2

## 5.31b Disciplines e Altare con l'Incisore come disciplina (M25-11; `01_GDD_M25.md` §37.1-§37.2)
Nessun motivo nuovo, nessun segnale nuovo. `riftbinding` diventa disciplina **solo nei dati** (§30.4 dello schema): `can_learn`/`learn`/`train`/`unlearn`,
`level_cap`, `xp_max` e `ActionRunner.enqueue` (`not_learned`) lo trattano già. Aggiunte e cambi in `systems/disciplines/disciplines.gd` (§5.31 di `05_INTERFACES_M24.md`):
```gdscript
func free_slots(category: StringName) -> int    # CAMBIATA: maxi(0, disciplines.max_per_category − apprese) (mai negativa con un posto in più)
func is_extra(skill_id: StringName) -> bool     # NUOVA: true se la disciplina appresa occupa un posto in più (§37.2, `extra` del save)
```
- `is_learned` invariata (una skill nota che non è disciplina resta `true`: nei dati veri non ce ne sono più, nelle fixture sì).
- **Posto in più** (`extra`): solo la migrazione v8 → v9 lo crea; nessun comando lo aggiunge. `can_learn` di una disciplina della categoria → `discipline_slots_full`
  finché `free_slots` è 0. Dopo `unlearn(s)`: `s` esce da `extra`; se le apprese della categoria sono ≤ `max_per_category`, `extra` perde le voci di quella categoria.
  Nessun segnale in più (`discipline_changed(s, 0)` come oggi).
- `from_save` (tollerante, aggiunta): `extra` = Array di id; voci non apprese, non discipline o sconosciute → `Log.warn` e scartate; per categoria il limite di
  lettura è `max_per_category` + le voci di `extra` della categoria (oltre: prime per `order`, come oggi); se dopo la lettura le apprese sono ≤ `max_per_category`,
  `extra` della categoria si svuota. `to_save` scrive sempre `extra` (ordine `order`, `[]` se vuoto). `new_game`: `extra` vuoto.
- File oltre 400 righe: se `disciplines.gd` (321 oggi) supera il limite, il salvataggio passa in un helper interno `systems/disciplines/disciplines_save.gd` (non API).
- **RiftAltar** (`systems/rift/rift_altar.gd`): la sorgente `rift_socket:<i>` esiste solo se l'incavo ha una runa **ed è sbloccato**; `rebuild_modifiers()` anche
  su `level_up(riftbinding, …)` e `skill_reset(riftbinding)`. `from_save` **tiene** le rune negli incavi bloccati (correggere il commento che dice "dropped").
  `socket()` su incavo bloccato → `socket_locked` (invariato); `clear_socket()` su incavo bloccato con runa: permesso (la runa si distrugge, `infusion_removed`).
  Lettura nuova: `func is_active(index: int) -> bool` (runa presente e incavo sbloccato).
- `SaveMigrator.CURRENT_VERSION` = **9**.

## 6c. Salvataggio v9 (M25-11; `01_GDD_M25.md` §37.2)
```json
"disciplines": {"learned": {"forging": 3, "woodwright": 1, "riftbinding": 2, "forestry": 2, "angling": 1}, "recipes": [], "extra": ["riftbinding"]}
```
- **`migration_8_to_9.gd`** (`core/save/migrations/`, `static func migrate(d) -> Dictionary`, copia profonda; legge `res://data/skills/skills.json` (categorie),
  `res://data/disciplines/trainers.json` (tetti dei gradi) e `res://data/config/balance.json` (`xp_curve`, `disciplines.max_per_category`) come
  `migration_7_to_8.gd`); costante storica `ENGRAVER := "riftbinding"`. Tutto in `modules`:
  1. **avanzamento** = `skills.riftbinding.xp` > 0 **oppure** almeno un lavoro di `actions.jobs` con `skill` = `riftbinding`;
  2. con avanzamento e `riftbinding` non già in `disciplines.learned`: `learned.riftbinding` = il grado più piccolo con `cap ≥` livello (F-158, la funzione
     `_grade_for` di `migration_7_to_8.gd`), senza oro; se le altre `artisan` apprese sono già ≥ `max_per_category` → `extra` = `["riftbinding"]`, altrimenti `extra` = `[]`;
  3. senza avanzamento: nessun cambio (`extra` = `[]`);
  4. tutto il resto invariato (`skills`, `mastery`, `actions`, `rift`, `combat`).
- **`migration_7_to_8.gd` congelata**: costante storica (es. `V8_NON_DISCIPLINES: Array[String] = ["riftbinding"]`) esclusa da `_learn`, `_drop_unlearned` e dal
  controllo di `_jobs` (l'Incisore resta com'era in M24 qualunque sia `skills.json`). `tests/core/save/test_migration_7_to_8.gd` resta verde con i dati nuovi.
- Catena: v5, v6, v7, v8 → v9. Test della versione (`SaveMigrator.CURRENT_VERSION` = 9) nei test di migrazione che oggi controllano 8.

## 7.p1 Menu laterale (M25-12; `01_GDD_M25.md` §37.3)
```gdscript
# ui/screens/main/sidebar.gd — Sidebar: firme e segnali invariati (page_requested, bind, unbind, set_current; §7 di 05_INTERFACES.md)
# SECTIONS + SECTIONS_TITLE ("Partita") sostituite da GROUPS: Array di {"title": String, "entries": [{"page", "text", "icon"}]} nell'ordine di §37.3;
# poi i gruppi RACCOLTA e PRODUZIONE dai dati (solo disciplines.is_learned, ordine `order`); in fondo Guida, senza titolo.
# Tolto il caso speciale ENGRAVER_PAGE (l'Incisore è una voce di PRODUZIONE come le altre, con il livello a lato).
# Titolo di un gruppo vuoto nascosto. Testi dei titoli in un file *_texts (es. ui/screens/main/sidebar_texts.gd).
```
- Icone nuove in `assets/icons/ui/` (Tabler, MIT): `home`, `school`, `clipboard-list`, `gavel`, `book` (Q142). Nessuna rotta nuova o cambiata.
- **TrainersPage/TrainerRow**: quattro righe nel riquadro Produzione; con un posto in più l'intestazione mostra le apprese sul limite (es. "3/2 posti") e la riga
  dell'Incisore il testo `EXTRA_SLOT_TEXT` ("Posto in più dal salvataggio precedente") se `disciplines.is_extra`; una produzione senza `fed_by` mostra
  `FED_BY_DROPS_TEXT` ("Si alimenta con i drop dei mostri"). Testi in `trainers_texts.gd`.
- **Pagina dell'Altare** (`ui/pages/rift/`): se `!disciplines.is_learned(&"riftbinding")` un testo (`RiftTexts`) "Le rune si incidono con l'Incisore: imparalo dai
  Maestri del Villaggio"; un incavo con runa e `!rift.is_active(i)` mostra "Spenta: incavo bloccato". Nessun calcolo nella UI.
- Smoke test: `tests/ui/test_sidebar_groups.gd` (ordine dei gruppi, nessuna icona ripetuta tra le voci fisse confrontando `resource_path`, voce `skill:riftbinding`
  presente solo se appreso, gruppo vuoto senza titolo); `test_sidebar_dungeon_lock.gd` e `test_trainers_page_smoke.gd` aggiornati, non duplicati.

## 7.p2 Area del bersaglio e mappetta (M25-13; `01_GDD_M25.md` §37.4)
```gdscript
# ui/pages/combat/target_view.gd — class_name TargetView extends RefCounted (solo presentazione)
static func for_state(state: Dictionary) -> StringName   # &"travel" se state["state"] == "travel"; &"node" se "node"; &"enemies" altrimenti
# ui/pages/combat/travel_minimap.gd — class_name TravelMiniMap extends Control (disegno in _draw(), nessuno stato di gioco)
func refresh(state: Dictionary) -> void   # legge solo "area", "travel_ms", "travel_total_ms"; ridisegna se cambia l'area
func progress() -> float                  # clamp(1 − travel_ms / travel_total_ms, 0, 1); 1 se travel_total_ms ≤ 0
# nodi per i test: HeroIcon (TextureRect: icona della classe dai dati, altrimenti UiStyle "user"), TravelLabel ("In viaggio…", testo in combat_texts.gd)
```
- `EnemyZone`, `NodeCard` e `TravelMiniMap` sono fratelli nello stesso posto dell'`Arena` (`Margin/Main/Arena`, a destra di `PlayerColumn`); se ne vede **uno** secondo
  `TargetView.for_state`; `VsBox` visibile solo con `EnemyZone`; stessa dimensione minima per tutte e tre.
- Decorazioni della mappetta: deterministiche dall'id dell'area (`hash` della stringa), nessun `RandomNumberGenerator` con seme casuale, nessun accesso a
  `RngService`. Dondolio dell'icona fermo con "Effetti visivi ridotti".
- **Tolti**: `ui/pages/combat/travel_map.gd` (+ `.uid`), `tests/ui/test_travel_map_smoke.gd` (+ `.uid`), la scheda del nodo in `_main` sotto l'`Arena`.
  §7.o di `05_INTERFACES_M24.md` (TravelMap) e la riga "TravelMap invariata" di §7.p sono superate.
- `combat_page.gd` è a 397 righe: la scelta della vista va in `TargetView` e il resto del cablaggio in un helper interno se serve; nessun file oltre 400 righe.
- Smoke test: `tests/ui/test_travel_minimap_smoke.gd` (`progress` a inizio, metà, fine e con totale 0; `HeroIcon` avanza; `TargetView.for_state` per i tre casi);
  `tests/ui/test_combat_page_smoke.gd` aggiornato (in `travel` è visibile solo la mappetta, in `node` solo la scheda).
