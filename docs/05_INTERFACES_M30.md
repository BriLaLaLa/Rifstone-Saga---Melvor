# 05. Interfacce, M30: Tutorial e incarichi «Primi passi» (§3g, §4f, §5.41-§5.43, §6g, §7.ab, §8b)

Estensione di `05_INTERFACES.md` (che supera le 400 righe): **è contratto** con le stesse regole (lo modifica solo il Reviewer; un task che ha bisogno di una firma nuova si ferma e la
chiede). Dove contraddice `05_INTERFACES.md` (§5.3 sessione, §5.15 Hint, §6 save, §5.40 Posta) o `_M24`…`_M28` vale questo file. Design `01_GDD_M30.md` (§41), dati
`04_DATA_SCHEMA_M30.md` (§34). Accanto a ogni firma il task che la scrive (M30-02 CORE, M30-03 DATA, M30-04 UI). Nessuna sorgente nuova in `ModifierService`, nessuna formula nuova.

## 3g. Segnali (`core/autoload/event_bus.gd`, M30-02; dopo `hint_triggered`)
```gdscript
signal tutorial_step_changed(step_id: StringName, index: int, total: int)   # entra in un passo (dopo la fine del precedente); mai in new_game/from_save
signal tutorial_progress(step_id: StringName, progress: int, target: int)    # solo passi `event` con count > 1: a ogni evento che conta
signal tutorial_completed()                                                  # una volta, quando finisce l'ultimo passo
signal starter_quest_completed(quest_id: StringName)                         # l'obiettivo diventa vero (una volta per sessione e incarico; mai al load)
signal starter_quests_changed()                                              # attivazione (fine tutorial), riscossione, progresso di un evento contato
```
Ordine alla fine di un passo: `tutorial_step_changed` del successivo (o `tutorial_completed` poi `starter_quests_changed` se era l'ultimo). `test_event_bus.gd` conta i segnali.

## 4f. Dati (`core/data/`, M30-02)
```gdscript
class_name TutorialCondition extends RefCounted   # core/data/defs/tutorial_condition.gd (§34.2)
var type: StringName                               # &"ack", &"event", &"metric"
var signal_name: StringName; var args: Dictionary  # event: filtro (chiavi = nomi degli argomenti; valori scalare, Array o {gte,lte,gt,lt})
var count: int = 1
var metric: StringName; var arg: StringName; var gte: int = 0
class_name TutorialStepDef extends RefCounted     # core/data/defs/tutorial_step_def.gd (§34.1)
var id: StringName; var page: StringName; var target: String; var title: String; var text: String
var done_when: Array[TutorialCondition]            # basta una
var gift_money: int = 0; var gift_items: Array[ItemQty] = []   # on_enter.mail (kind sempre tutorial_gift); 0 / [] = nessun regalo
class_name StarterQuestDef extends RefCounted     # core/data/defs/starter_quest_def.gd (§34.3)
var id: StringName; var group: StringName; var name: String; var description: String
var goal: TutorialCondition
var reward_money: int = 0; var reward_items: Array[ItemQty] = []; var reward_character_xp: int = 0
# GameData (core/data/game_data.gd; indice in core/data/tutorial_index.gd)
func tutorial_steps() -> Array[TutorialStepDef]    # ordine di file
func tutorial_step(step_id: StringName) -> TutorialStepDef   # null se assente
func tutorial_stuck_ms() -> int
func tutorial_always_open() -> Array[StringName]
func starter_groups() -> Array[Dictionary]         # [{"id": StringName, "title": String}], ordine di file
func starter_quests() -> Array[StarterQuestDef]    # ordine di file
func starter_quest(quest_id: StringName) -> StarterQuestDef  # null se assente
```
Validatore: `core/data/data_validator_tutorial.gd` (`DataValidatorTutorial`: `ROUTES`, `TARGETS`, `DENIED_SIGNALS`, `METRICS` letta da `TutorialMetrics`), agganciato in `data_validator.gd`;
`DataValidatorMail.KINDS` + `tutorial_gift`, `starter_reward` (§34.5).

## 5.41 TutorialSystem (`systems/tutorial/tutorial_system.gd`, M30-02) — dipendenze: data, events, mail, wallet, bank, character, disciplines, village, quests, combat (solo letture)
```gdscript
class_name TutorialSystem extends RefCounted
const SAVE_KEY := &"tutorial"
var starter: StarterQuests                                    # creato nel costruttore (§5.42); un solo modulo di sessione
func _init(session: GameSession) -> void
# --- letture ---
func is_active() -> bool                                      # false se completato
func is_completed() -> bool
func step_count() -> int                                      # = tutorial_steps().size()
func step_index() -> int                                      # 0..step_count()-1; step_count() se completato
func current_step() -> TutorialStepDef                        # null se completato
func step_progress() -> int                                   # eventi contati nel passo corrente (count > 1); 0 altrimenti
func step_target_count() -> int                               # `count` della prima condizione `event` del passo; 1 altrimenti
func current_page() -> StringName                             # route mostrata, volatile (da notify_page_opened); &"" prima della prima notifica
func required_route() -> StringName                           # `page` del passo corrente; &"" se completato o `page` vuota
func needs_navigation() -> bool                               # passo con pagina e current_page() diversa (la UI mostra "Vai a ...")
func is_page_open(route: StringName) -> bool                  # completato -> true; `always_open` -> true; passo corrente con `page` vuota -> true;
                                                              # altrimenti route in {page dei passi 0..index} (le pagine già "scoperte" e quella richiesta)
func has_visited(route: StringName) -> bool                   # persistente (anche a tutorial completato e negli slot migrati: parte vuoto)
func can_acknowledge() -> bool                                # passo corrente con una condizione `ack`
func can_skip_step() -> bool                                  # attivo, nessuna condizione `ack`, session.play_time_ms - since_ms >= tutorial_stuck_ms()
# --- comandi ---
func notify_page_opened(page_id: StringName) -> void          # la UI dice la pagina mostrata ("skill:forestry" -> route `skill`); registra la visita, poi ricontrolla metriche
func acknowledge() -> CommandResult                           # tutorial_inactive (completato), wrong_step (il passo non ha `ack`); non controlla la pagina: lo fa la UI
func skip_step() -> CommandResult                             # tutorial_inactive, not_stuck (can_skip_step falso); passa al passo dopo (stessi segnali di una fine normale)
func new_game() -> void                                       # attivo dal passo 0, nulla visitato, incarichi azzerati (starter.new_game)
func to_save() -> Dictionary; func from_save(d: Dictionary) -> void
```
- **Avanzamento**: la fine di un passo lo chiude e apre il successivo **subito** (nello stesso istante dell'evento), ricontrolla le condizioni `metric` del nuovo passo (già vera → finisce
  ancora; ciclo con tetto = `step_count()`), consegna l'`on_enter` (regalo: `mail.post(kind, {"money": n})` o `{"items": [...]}`; se la Posta è piena la consegna avviene comunque, §5.40) e emette `tutorial_step_changed`.
  Ultimo passo finito → `completed = true`, `tutorial_completed`, `starter` si attiva (`starter_quests_changed`).
- **Eventi**: i segnali delle condizioni `event` del **solo passo corrente** si collegano a `session.events` quando il passo entra e si scollegano quando esce (la sessione `free()` li scollega:
  nessun riferimento ciclico). Il collegamento è generico: per ogni segnale lo script di `GameEvents` dà i nomi degli argomenti (`get_script_signal_list`); il filtro (`TutorialConditions.matches`)
  confronta per nome. Il conteggio `count` si salva (`progress`).
- **Metriche**: ogni metrica ha i segnali che la fanno rileggere (§5.42); un passo `metric` ricontrolla solo quelli. Nessun `advance`, nessun timer, nessun tempo reale: la valvola usa `play_time_ms`.
- **Pagine**: `notify_page_opened` aggiunge la route a `visited`; **non** avanza nulla da sola (i passi non hanno condizioni sulla pagina). Se `needs_navigation()`, la UI illumina la voce `nav.<route>`.
- **Offline e suggerimenti**: gli eventi della simulazione offline contano come online. `HintsSystem._fire` non fa nulla se `session.tutorial != null and session.tutorial.is_active()` (nessun segno di visto;
  `bank_full`, `player_died`, `first_level_10` ritornano a scattare dopo). `session_started_new` non fa nulla di nuovo (`first_action` inerte).
- **Tolleranza** (`from_save`, `Log.warn`): `completed` non bool → `true`; `step` assente o sconosciuto (anche dati cambiati) → **`completed = true`** (mai intrappolare); `progress` non intero o < 0 → 0 (ed ≤ `count`);
  `since_ms` non intero o < 0 o > `play_time_ms` → `play_time_ms` (il tempo della valvola riparte); `visited` ripulito dalle route sconosciute; `starter` come in §5.42. Nessun segnale.
- **Reasons nuovi** (`core/common/reasons.gd`, M30-02): `TUTORIAL_INACTIVE := &"tutorial_inactive"`, `WRONG_STEP := &"wrong_step"`, `NOT_STUCK := &"not_stuck"`, `ALREADY_CLAIMED := &"already_claimed"`.
  `UNKNOWN_ID`, `QUEST_INCOMPLETE`, `MAILBOX_FULL` esistono già. `test_reasons.gd` aggiornato.
- **Sessione**: campo `var tutorial: TutorialSystem  # M30-02`; in `_create_systems()` **in fondo** (dopo `discoveries`, perché `HintsSystem` e `Discoveries` non ne dipendono e il tutorial legge tutto il resto):
  `tutorial = TutorialSystem.new(self)` e `_join(TutorialSystem.SAVE_KEY, tutorial.new_game, tutorial.to_save, tutorial.from_save)` (3 righe con il commento: `MAX_SESSION_LINES` di
  `tests/core/session/test_game_session.gd` da 246 a **249**; la composizione resta composizione). `tutorial.starter` non ha un `_join` suo. Nessuna fase `advance`.
  `GameSession.from_save`: un modulo `tutorial` mancante vale **partita nuova** (comportamento invariato): per questo serve la migrazione (§6g).

## 5.42 Condizioni, metriche, incarichi (`systems/tutorial/`, M30-02)
```gdscript
class_name TutorialConditions extends RefCounted     # logica pura, funzioni statiche
static func matches(args_filter: Dictionary, arg_names: PackedStringArray, values: Array) -> bool   # §34.2: per nome, scalare / array (uno qualsiasi) / {gte,lte,gt,lt}; filtro vuoto = true
static func signal_arg_names(events: GameEvents, signal_name: StringName) -> PackedStringArray       # dallo script; vuoto + push_error se il segnale non esiste
class_name TutorialMetrics extends RefCounted        # logica pura, legge il modello
const METRICS: Dictionary[StringName, Array] = {     # metrica -> segnali che la rileggono
	&"character_level": [&"character_level_up"], &"kills_total": [&"monster_killed"], &"disciplines_learned": [&"discipline_changed"],
	&"page_visited": [], &"mail_collected": [&"mail_changed"], &"village_levels": [&"village_upgraded"], &"quests_completed": [&"quest_completed"]}
static func value(session: GameSession, metric: StringName, arg: StringName = &"") -> int
	# character_level = character.get_level(); kills_total = somma di combat.total_kills(); disciplines_learned = quante di disciplines.learned(arg) (arg &"gathering"|&"artisan"; &"" = tutte);
	# page_visited = 1 se tutorial.has_visited(arg) (arg obbligatorio: una route), altrimenti 0; mail_collected = mail.collected_total();
	# village_levels = somma di village.level(b) per ogni edificio (arg &"" ) oppure village.level(arg); quests_completed = quests.completed_total()
class_name StarterQuests extends RefCounted          # systems/tutorial/starter_quests.gd (compreso in TutorialSystem)
func _init(session: GameSession, tutorial: TutorialSystem) -> void
func is_enabled() -> bool                            # tutorial.is_completed()
func quests() -> Array[StarterQuestDef]              # tutti, ordine di file
func progress(quest_id: StringName) -> int           # 0..target: misura = min(value, gte); evento = contatore salvato (min con count); 0 se non attivo/sconosciuto
func target(quest_id: StringName) -> int             # gte della misura o count dell'evento
func is_complete(quest_id: StringName) -> bool       # progress >= target (anche se già riscosso)
func is_claimed(quest_id: StringName) -> bool
func claimable() -> Array[StarterQuestDef]           # completi e non riscossi, ordine di file
func next_open() -> StarterQuestDef                  # il primo non riscosso in ordine di file; null se tutti riscossi
func claimed_count() -> int; func total() -> int
func can_claim(quest_id: StringName) -> CommandResult  # in ordine: unknown_id, tutorial_inactive (non attivo), already_claimed, quest_incomplete, mailbox_full
func claim(quest_id: StringName) -> CommandResult      # character.add_xp(reward_character_xp) se > 0; mail.post(&"starter_reward", {"money": n} o {"items": [...]}); claimed += id; starter_quests_changed
func new_game() -> void; func to_save() -> Dictionary; func from_save(d: Dictionary) -> void   # chiamati da TutorialSystem
```
- **Eventi contati**: gli `event` di tutti gli incarichi non riscossi si collegano alla **prima attivazione** (fine tutorial o `from_save` con `completed`) e restano collegati; con gli incarichi non
  attivi (tutorial in corso) un evento non conta. Il contatore sale fino a `count` e si salva; `starter_quests_changed` a ogni salita (non a ogni evento filtrato fuori).
- **Misure**: si rileggono ai segnali di `METRICS`, **solo** se esiste un incarico `metric` di quella metrica non ancora notificato (`starter_quest_completed` una volta per sessione; al load si calcola
  l'insieme già vero senza emettere). Niente ricalcolo a ogni uccisione dopo che tutti gli incarichi `kills_total` sono notificati (la simulazione offline di 12 h non deve rallentare).
- **Ordine di `claim`**: `can_claim` → XP (`character.add_xp`) → `mail.post` → `claimed` → `starter_quests_changed`. Atomico: un rifiuto non cambia nulla.
- **Posta**: `MailBox.KINDS` + `&"tutorial_gift"` e `&"starter_reward"`; **mai fusi** (`_merge_target` solo per i kind della Casa d'Aste). `MailBox.collected_total() -> int`: messaggi **ritirati**
  (`collect` e `collect_all`) in tutta la partita; salvato in `modules.mail.collected` (additivo: assente/non intero/negativo → 0 con `Log.warn` se non assente); `new_game` lo azzera. `tests/systems/mail/` esteso.

## 6g. Salvataggio v12 (M30-02)
`SaveMigrator.CURRENT_VERSION` = **12**; catena v5…v11 → v12. Modulo nuovo `tutorial` (in `to_save`, ordine di join = ultimo):
```json
"tutorial": {
  "completed": false, "step": "combat_kills", "progress": 1, "since_ms": 482300,
  "visited": ["character", "equipment", "combat"],
  "starter": {"claimed": ["level_3"], "progress": {"beat_arcane": 2}}
}
```
- `step`: id del passo corrente (stringa vuota se `completed`); `progress`: eventi contati nel passo (0 se non serve); `since_ms`: `play_time_ms` all'ingresso nel passo; `visited`: route in ordine di prima visita;
  `starter.claimed`: id in ordine di file; `starter.progress`: **solo** gli incarichi `event` con progresso > 0 e non riscossi (le misure non si salvano: si rileggono).
  `to_save` di un tutorial completato: `{"completed": true, "step": "", "progress": 0, "since_ms": 0, "visited": [...], "starter": {...}}`.
  `starter.from_save` tollerante, con `Log.warn`: `claimed` non array o con id sconosciuti → ripulito; `progress` con id sconosciuti, non `event` o non interi → scartato; valori > `count` → `count`; già riscosso → scartato.
- **`core/save/migrations/migration_11_to_12.gd`** (`static func migrate(d: Dictionary) -> Dictionary`, copia profonda, nessuna lettura dei dati): se `modules` è un oggetto e **non** ha `tutorial` →
  `modules["tutorial"] = {"completed": true, "step": "", "progress": 0, "since_ms": 0, "visited": [], "starter": {"claimed": [], "progress": {}}}`; se `tutorial` esiste già (impossibile in v11, per sicurezza) resta;
  `modules` assente o non oggetto → invariato. Nient'altro cambia. Costante storica `V12_TUTORIAL_DONE` non necessaria (il blocco è letterale nel file).
- **Tests**: `tests/core/save/test_migration_11_to_12.gd` (blocco aggiunto, altri moduli identici, `modules` assente, `tutorial` già presente, catena v9 → v12), `test_save_migrator.gd` con 12; **slot v11 reale**
  `tests/fixtures/saves/slot_v11.json` scritto da una **sessione vera con il codice di main prima di M30-02** (stesso procedimento di `slot_v10.json`), caricato senza perdite: tutorial completato e Primi passi attivi, il resto uguale.

## 7.ab UI del tutorial e dei Primi passi (M30-04; nessuno stato di gioco nella UI, solo letture e comandi)
```gdscript
class_name TutorialOverlay extends Control            # ui/screens/tutorial/tutorial_overlay.gd (+ .tscn); figlio di MainScreen, dopo HintCard e prima di OfflineSummaryView/SettingsPanel
var is_blocked: Callable                                # () -> bool; vuoto = "Game.state è offline"; true = overlay nascosto (come HintCard)
func bind(session: GameSession, page_host: PageHost, sidebar: Sidebar, top_bar: TopBar) -> void; func unbind() -> void
func refresh() -> void                                  # ridisegna da session.tutorial (passo, "Passo n di N", testo, Avanti / Continua comunque, bersaglio, blocchi)
class_name TutorialPanel extends PanelContainer         # titolo, testo, "Passo %d di %d", pulsante Avanti (acknowledge) o "Continua comunque" (skip_step) o riga "Vai a <pagina>"
class_name TutorialTargets extends RefCounted           # ui/screens/tutorial/tutorial_targets.gd: tabella id (§34.4) -> come trovare il controllo (nome univoco nella scena); static func resolve(id: String, main: Control) -> Control (null se assente o non visibile)
class_name TutorialBlockers extends Control             # i rettangoli STOP sopra barra laterale e barra in alto, ricalcolati dai rettangoli reali; lasciano libero: il tasto menu, la voce nav richiesta, l'area della pagina
class_name TutorialTexts extends RefCounted             # testi italiani di presentazione ("Passo %d di %d", "Avanti", "Continua comunque", "Vai a %s", "Lo scoprirai nel tutorial")
class_name StarterWidget extends PanelContainer         # ui/screens/main/starter_widget.gd: riquadro in fondo alla barra laterale; signal open_requested; bind(session); nascosto con tutorial attivo o 20/20
class_name StarterPage extends Page                     # ui/pages/starter/starter_page.gd (+ .tscn), route &"starter"; StarterRow (riga: nome, descrizione, barra, ricompensa, Riscuoti)
class_name StarterTexts extends RefCounted             # testi italiani; la ricompensa si compone dai modelli con Money.text / MoneyLabel e il nome dell'oggetto
```
- **Notifica della pagina**: `MainScreen` chiama `session.tutorial.notify_page_opened(page_id)` a ogni `PageHost.page_changed` e una volta dopo la prima `show_page` (anche per `skill:<id>`).
- **PageHost** (`page_host.gd`): `ROUTES` + `&"starter"`; `show_page` rifiuta (senza `Log.warn`, solo `Log.info`) una route per cui `session.tutorial.is_page_open(route)` è falso e restituisce senza cambiare la pagina;
  non si applica alla pagina iniziale scelta da `MainScreen._first_page()` quando il passo ha `page` vuota (il passo 1 la lascia aperta).
- **Sidebar** (`sidebar.gd`): ogni riga di pagina chiusa (`is_page_open` falso) è **disabilitata** con suggerimento «Lo scoprirai nel tutorial»; si ridisegna su `tutorial_step_changed` e `tutorial_completed`. Ogni riga espone
  il proprio rettangolo al `TutorialOverlay` con il nome `nav.<route>` (per `skill`: la prima riga di mestiere appreso). Il riquadro `StarterWidget` sta fuori dall'elenco scorrevole.
- **HintCard**: `MainScreen` imposta `is_blocked` a «offline **o** tutorial attivo»; `HintCard.refresh` su `tutorial_completed`.
- **Regole dell'overlay**: (1) mostra il passo solo quando `not needs_navigation()`; se `needs_navigation()` mostra «Vai a <pagina>» e lascia premibile **solo** la voce `nav.<required_route>`;
  (2) blocca barra laterale e barra in alto **salvo** il tasto menu; l'area della pagina resta usabile; (3) cornice sul bersaglio (`TutorialTargets.resolve`), area della pagina se manca; (4) il pannello non copre il
  bersaglio (angolo opposto) e rispetta 1280×720 e 1600×900 (larghezza massima 440 px, altezza 240 px); (5) Avanti solo se `can_acknowledge()`, «Continua comunque» solo se `can_skip_step()`;
  (6) niente tempo reale nella logica: il pannello si ridisegna sui segnali `tutorial_*` e `PageHost.page_changed`, la cornice ogni frame; (7) con `tutorial.is_completed()` il nodo si libera.
- **Esc e menu**: invariati (`MainScreen._unhandled_key_input`, `SettingsPanel`), aperti **sopra** l'overlay; «Salva ed esci» funziona in ogni passo.
- **File**: ogni script e scena ≤ 400 righe (`main_screen.gd` ha ~168, `sidebar.gd` ~294, `page_host.gd` ~139: le aggiunte stanno in file nuovi).
- **Guida**: `help:` non cambia; `guide` e `help` sono in `always_open`.

## 8b. Helper dei test (`tests/helpers/test_factory.gd`, M30-02)
`TestFactory.session(...)` e `session_no_kit(...)` **completano il tutorial** dopo `new_game()` (`session.tutorial.from_save({"completed": true, "step": "", "visited": []})`): tutti i test esistenti di
pagine, hint e flussi restano com'erano (nessun overlay, nessuna pagina chiusa, i Suggerimenti scattano). Parametro nuovo `with_tutorial: bool = false` (ultimo, anche in `session_no_kit`): `true` lascia il tutorial attivo al passo 1.
I fixture dei dati (`tests/fixtures/data/` e `m10/`) hanno `tutorial/steps.json` e `tutorial/starter_quests.json` minimi (§34.6).
