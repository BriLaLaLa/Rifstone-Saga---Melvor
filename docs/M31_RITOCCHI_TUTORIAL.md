# M31: Ritocchi al tutorial e ai «Primi passi» (V40)

Piccola modifica sullo stesso flusso di M30 (`01_GDD_M30.md` §41, `04_DATA_SCHEMA_M30.md` §34, `05_INTERFACES_M30.md` §5.41-§5.42, §6g, §7.ab). Questo file è **fonte unica**
per gli id, le chiavi e le firme nuovi: GDD, schema e contratto di M30 rimandano qui. Fonte del design: richiesta dell'utente del 2026-11-21 (V40 in `DECISIONS_LOG.md`, Q193-Q198 in
`OPEN_QUESTIONS.md`), task in `07_TASKS_M31.md`. Nessuna formula nuova, nessun valore di design nel codice: tutto in `data/`.

## 1. Cosa cambia (riassunto)
| # | Richiesta | Soluzione |
|---|---|---|
| 1 | Contatore «1 su 3 nemici uccisi» | La logica **è già per uccisione** (`monster_killed` ×3, emesso da `combat_fight.gd` a ogni nemico morto; il pannello mostra `tutorial_progress`). Manca solo l'**etichetta**: oggi il pannello scrive un numero nudo «0 / 3». Campo di dato `progress_text` (§2.1) |
| 2 | Si mangia nel primo combattimento sicuro; **il tempo si ferma**; la UI mostra il cibo; dopo Ok si riparte | Due passi nuovi al posto del 7: `combat_eat` (si ferisce il personaggio e si aspetta il pasto) e `combat_food` (**combattimento congelato nel modello** finché si preme Ok). Congelamento del motore, §3 |
| 3 | Più cibo / forzare lo spawn del nodo | **Tutte e due**: `start.items` da 20 a 30 pezzi (dato) **e** `force_node` al passo `nodes` (il primo viaggio dopo l'ingresso è un nodo della disciplina appresa). §4 |
| 4 | Bonus finale ai 20 incarichi | «Stemma del Pioniere» (oggetto da collezione, nessun effetto) + 30 Trote alla griglia + 300 XP, per Posta. §5 |
| 5 | Pallino di notifica | Il riquadro «Primi passi» ha **già** un pallino dorato, ma si aggiorna solo su `starter_quests_changed`: le **misure** che diventano vere (livello 3, 25 uccisioni…) emettono `starter_quest_completed` e non lo accendevano. §6 |

## 2. Dati (`data/tutorial/`, schema esteso: sostituisce/estende `04_DATA_SCHEMA_M30.md` §34.1 e §34.3)
### 2.1 Passi: cinque campi facoltativi nuovi (`steps.json`)
| Campo | Tipo | Vincoli (validatore `DataValidatorTutorial`) |
|---|---|---|
| `progress_text` | String | 1..40 caratteri, **esattamente due `%d`** (corrente, totale); solo se `done_when` ha un `event` con `count` > 1 |
| `ack_text` | String | 1..12 caratteri; solo con `done_when` `ack`; vuoto/assente = il testo di default della UI («Avanti») |
| `freeze_combat` | bool | solo con `ack`; mentre il passo è corrente il combattimento è fermo (§3) |
| `force_node` | bool | solo con un `event` `node_started` nel `done_when`; il primo viaggio dopo l'ingresso è un nodo (§4) |
| `wound_hp_pct` | int 1..99 | solo con un `event` `food_eaten`; porta i PV del personaggio a quella percentuale (§3.2) |

`TutorialStepDef` (`core/data/defs/`) guadagna `progress_text: String`, `ack_text: String`, `freeze_combat: bool`, `force_node: bool`, `wound_hp_pct: int` (0 = assente).

### 2.2 I 22 passi: cosa cambia rispetto a `01_GDD_M30.md` §41.4 (la tabella è già aggiornata)
- Il passo 7 **`combat_food`** si divide in **7 `combat_eat`** e **8 `combat_food`**; i passi seguenti scalano di 1 (21 → **22**; `nodes` = 14, `mail` = 18, `finish` = 22). Gli **id** dei passi esistenti non cambiano.
- **5 `combat_kills`**: `"progress_text": "Nemici sconfitti: %d su %d"` (resto invariato).
- **7 `combat_eat`**: pagina `combat`, bersaglio `combat.eat_button`, titolo «Il personaggio è ferito», `done_when` `{"type":"event","signal":"food_eaten"}`, **`"wound_hp_pct": 30`**.
  Testo: «I nemici ti hanno fatto male. Il cibo cura i punti vita: premi Mangia, oppure aspetta, le Razioni da campo mangiano da sole quando la vita è bassa.»
- **8 `combat_food`**: pagina `combat`, bersaglio `combat.eat_button`, titolo «Il cibo, e a cosa serve», `done_when` `ack`, **`"freeze_combat": true`**, **`"ack_text": "Ok"`**.
  Testo: «Il combattimento è in pausa. Il pulsante Mangia usa il cibo che indossi e ne mostra le scorte: cura i punti vita. Le Razioni da campo mangiano da sole quando la vita scende.
  Il bottino finisce nella borsa: Raccogli lo porta nel Deposito. Premi Ok per ripartire.» (≤ 280 caratteri: la lunghezza la controlla il validatore).
- **14 `nodes`**: `done_when` `{"type":"event","signal":"node_started","args":{"skipped":false}}`, **`"force_node": true`**; testo: «Torna al Combattimento: finito lo scontro in corso, lungo la strada compare un nodo
  da lavorare con il mestiere che hai imparato. Se il combattimento è fermo, riavvialo dalla Mappa.»
- Il testo del vecchio passo 7 («Se muori, la borsa va persa») passa nella Guida («Combattimento»): `data/guide/` non cambia salvo la voce `first_steps` (§5).
- `target` `combat.eat_button` esiste già (§34.4): **nessun id di bersaglio nuovo** (il pulsante Mangia mostra il cibo indossato e le scorte).

### 2.3 Bonus finale (`starter_quests.json`, chiave di primo livello `final_reward`)
```json
"final_reward": {"id": "pioneer", "name": "Il Pioniere del Rift", "description": "Hai completato tutti i Primi passi: il Villaggio ti dà il suo stemma.",
                 "reward": {"items": [{"item": "pioneer_emblem", "qty": 1}, {"item": "seared_brookfin", "qty": 30}], "character_xp": 300}}
```
`name` 1..40, `description` 1..140; `reward` con **le stesse regole** di §34.3 (`money` **o** `items`; `character_xp` 1..1000; oggetti esistenti, vendibili, **nessuna** delle categorie
`FORBIDDEN_REWARD_CATEGORIES`). `final_reward` è **obbligatorio**; un file senza di esso è rifiutato (nessun fallback).
Oggetto nuovo in `data/items/misc.json`: `pioneer_emblem`, «Stemma del Pioniere», categoria `misc`, `value` 5000, `sort_order` libero, nessun campo di effetto, icona `assets/icons/items/pioneer_emblem.svg`
(SVG semplice e originale), descrizione «Uno stemma di bronzo battuto, dato a chi ha percorso tutti i primi passi del Villaggio.»
**Economia** (nessuna ritaratura): 5.000 + 30 × 200 = **11.000 rame** di valore + 300 XP ≈ 1,4 incarichi di Bacheca di grado 1 (8.000 rame); è il 27% del totale dei 20 incarichi (40.800). Nessun potere diretto:
lo Stemma non ha effetti, le Trote sono cibo di base, 300 XP sono meno di mezzo livello a livello 10 e già nulla dopo (F-01/F-71).
**Cibo iniziale**: `balance.json` `start.items[0].qty` **20 → 30** (Trote alla griglia). Costo: 10 × 200 = 2.000 rame di valore una tantum; i test che contano 20 pezzi iniziali si aggiornano (documentato in `07_TASKS_M31.md`).

## 3. Congelamento del combattimento (il tempo si ferma)
### 3.1 Motore (`systems/combat/combat_engine.gd`, API nuova, ≤ 400 righe: se serve, un file nuovo `combat_tutorial.gd`)
```gdscript
func set_frozen(frozen: bool) -> void        # solo TutorialSystem; non emette segnali, non si salva
func is_frozen() -> bool                     # la UI lo legge per l'etichetta «In pausa»
func set_force_node(on: bool) -> void        # §4; non si salva
func is_force_node() -> bool
func wound_to_pct(pct: int) -> void          # solo TutorialSystem; no-op se il combattimento è fermo, in Frattura o in Dungeon
```
- `advance(delta_ms)`: se `_frozen`, **non consuma nulla** e ritorna; il ciclo `while` di §5.10 esce **appena** `_frozen` diventa vero (cioè alla fine dell'istante in cui è arrivato il pasto: i timer restano esattamente dove
  sono). Il tempo restante del blocco si perde (con un blocco offline di 60 s o con tick da 100 ms lo stato finale è lo stesso: **l'equivalenza 12 h = 100 ms = 60 s resta**, perché il punto di arresto è
  un istante del modello, non un limite di blocco).
- **RNG**: congelato non si consuma nessun tiro (il ciclo non gira, `GameSession` non chiama altre fasi che tirino senza lavori in corso: durante il tutorial nessuna coda né frattura). Si prova confrontando `session.rng.to_save()` prima e dopo `advance`.
- `play_time_ms` **continua** a salire (è il tempo di gioco totale e la base della valvola, che nei passi `ack` non conta). Con `freeze_combat` il resto della sessione avanza come sempre.
- `new_game()` e `from_save()` del motore azzerano `_frozen` e `_force_node`: non sono stato salvato del combattimento; li **deriva** `TutorialSystem` dal passo corrente (§3.3).
- `wound_to_pct(pct)`: `hp = min(hp, ceil(max_hp × pct / 100))` con `_set_hp` (stesso percorso dei PV di sempre, segnali compresi); mai sotto 1.

### 3.2 `TutorialSystem` (`systems/tutorial/tutorial_system.gd`, firme nuove)
```gdscript
func step_progress_text() -> String          # progress_text del passo corrente ("" se assente o tutorial completato)
func ack_text() -> String                    # ack_text del passo corrente ("" = default della UI)
func is_combat_frozen() -> bool              # tutorial attivo e il passo corrente ha freeze_combat
```
- **Ingresso in un passo** (`_begin_step`, dopo `on_enter`): `session.combat.set_frozen(step.freeze_combat)`; `set_force_node(step.force_node)`; se `step.wound_hp_pct > 0` e il combattimento è attivo →
  `combat.wound_to_pct(step.wound_hp_pct)` **una volta** (flag volatile `_wounded`), altrimenti l'effetto si applica al **primo** `encounter_started` mentre il passo è corrente (segnale collegato come gli eventi del passo).
- **Uscita** (fine, `skip_step`, completamento): `set_frozen(false)`, `set_force_node(false)`. `acknowledge()` su `combat_food` = **Ok**: sblocca e passa al passo 9.
- **Caricamento** (`from_save`, dopo il motore: il modulo `tutorial` è l'ultimo): riapplica gli stessi effetti del passo corrente (`combat_food` → di nuovo congelato; `nodes` → di nuovo forzato; `combat_eat` → una nuova ferita, una volta).
  **Salvare a metà pausa** (menu → «Salva ed esci») è consentito e riprende congelato con il bottone Ok. Con l'overlay offline il combattimento congelato non avanza: il riepilogo è vuoto. Tutorial
  illeggibile → completato → sbloccato (mai intrappolare).
- **Garanzia del pasto**: il passo 7 ferisce il personaggio al 30% (dato) e il **primo colpo subito** lo porta a ≤ 30% = soglia dell'auto-mangiare di livello 1 (`combat.auto_eat_tiers`, acquisto iniziale `auto_eat_1`): mangia da solo (30 Trote: il cibo c'è).
  Oppure preme Mangia lui. In ogni caso arriva `food_eaten` e il passo 8 congela. Se il combattimento è fermo o il personaggio muore, la ferita arriva al prossimo scontro; la valvola dopo `stuck_ms` resta (passo non-`ack`).
  Un meccanismo di scongelamento non esiste oltre a Ok e all'uscita dal passo: l'unico scongelamento è `acknowledge` (o `skip_step`, non offerto sui passi `ack`).
- **Incarico `eat_once`** («Un pasto sul campo»): il pasto del tutorial **non** lo conta (gli incarichi si attivano a fine tutorial): resta un obiettivo per dopo, come oggi.

### 3.3 UI (stessa schermata: nessuna pagina nuova)
- Il pannello mostra «Ok» (`ack_text`) invece di «Avanti»; la cornice evidenzia `combat.eat_button` (il bottone Mangia mostra il cibo indossato e le scorte): **dove sta il cibo e a cosa serve** sono nel testo del passo.
- La pagina Combattimento mostra, a `is_frozen()`, una riga «In pausa» (testo in `CombatTexts`, nessuno stato proprio); le animazioni a tempo del modello non partono perché il modello non avanza.
- L'area della pagina resta usabile (§41.2): Mangia e Mappa funzionano; Ok è solo nel pannello.

## 4. Spawn del nodo (`force_node`, F-156)
- Regola del ciclo (`EncounterCycle.next_kind`, F-155/F-156): con `force_node` attivo e `forced_fight` falso, il viaggio è un **nodo** della **prima disciplina appresa in ordine di voce** dell'area (`encounters/nodes.json`); **non si tira
  né l'RNG della probabilità né quello dei pesi** (nessuna ricaduta sulle formule: il flag vale solo nel passo `nodes`, una volta). Nessuna disciplina appresa tra quelle dell'area → regola normale. Un Monolito o un miniboss in attesa
  (`forced_fight`) **vincono** sul nodo forzato (restano precedenza assoluta, F-139/F-87): il nodo viene dopo.
- Il flag **non si consuma da solo**: lo spegne l'uscita dal passo (il passo finisce con `node_started` con `skipped` falso, che un nodo forzato dà sempre). Dopo il tutorial il ciclo è quello di sempre: **F-156, `sim_encounters` e l'economia non cambiano.**
- **Perché tutte e due** (cibo +10 **e** nodo forzato): il nodo forzato toglie il caso peggiore (nessun nodo per molti viaggi, ~5% di non vederne in 10 con la probabilità attuale) e dà sempre un nodo **lavorato** (la
  condizione `skipped` falso: uno saltato non insegna nulla); i 10 pezzi in più coprono il tempo fra il pasto del passo 7 (e i colpi dei passi 5-14) senza toccare lo Shop. Solo il cibo non basta (resta il caso peggiore); solo il nodo forzato non basta
  (il tutorial dura dei minuti di combattimento e il cibo iniziale è il margine di sicurezza dell'utente).

## 5. Bonus finale: comando e stato (`StarterQuests`, `05_INTERFACES_M30.md` §5.42 esteso)
```gdscript
class_name StarterFinalDef extends RefCounted      # core/data/defs/starter_final_def.gd: id, name, description, reward_money(0), reward_items: Array[ItemQty], reward_character_xp
func final_reward() -> StarterFinalDef             # da data/tutorial/starter_quests.json ("final_reward")
func is_final_available() -> bool                  # attivi e claimed_count() == total() e non riscosso
func is_final_claimed() -> bool
func can_claim_final() -> CommandResult            # in ordine: tutorial_inactive, already_claimed, quest_incomplete (non tutti riscossi), mailbox_full
func claim_final() -> CommandResult                # stesso ordine di claim: can_claim_final -> character.add_xp -> mail.post(&"starter_reward", {"items": [...]}) -> final_claimed = true -> starter_quests_changed
func all_done() -> bool                            # 20/20 e bonus riscosso (il riquadro sparisce qui)
```
- **Consegna** come gli altri: Posta (kind `starter_reward`, solo oggetti) + XP diretta; stessi rifiuti (`quest_incomplete`, `already_claimed`, `mailbox_full`, `tutorial_inactive`: motivi esistenti, nessun `Reasons` nuovo).
- **Nessun segnale nuovo** (il conteggio di `test_event_bus.gd` non cambia): il bonus diventa disponibile esattamente quando l'ultimo incarico viene riscosso (`starter_quests_changed` già emesso da `claim`).
- **Save additivo, nessuna versione nuova** (resta **v12**): `tutorial.starter` guadagna `"final_claimed": bool` (assente = `false`, non è un errore e non emette `Log.warn`; non bool → `false` con `Log.warn`). `to_save` lo scrive sempre.
  Gli slot v12 già salvati con 20/20 incarichi mostreranno il bonus come disponibile (comportamento voluto). I passi: un salvataggio a un passo già esistente riprende invariato; il nuovo id `combat_eat` esiste solo nei dati nuovi.
  Un salvataggio fermo su `combat_food` del vecchio ordine riprende sullo stesso id (ora congelato, con Ok): accettato, nessun test di migrazione.
- **Guida** (§5): la voce `first_steps` (≤ 160 parole) cita il bonus **senza numeri** (`data/guide/tutorial.json`).

## 6. Pallino di notifica
- **Esiste già** in `StarterWidget` (`_dot`, `Panel` dorato 10 px, acceso da `not starter.claimable().is_empty()`). **Manca**: (a) il riaggancio su `starter_quest_completed` (misure e fine di un evento contato) → `refresh`
  (collegato in `bind`, scollegato in `unbind`); (b) l'accensione per il **bonus finale** (`is_final_available()`); (c) la visibilità del riquadro finché il bonus non è riscosso (oggi sparisce a 20/20 riscossi: ora a `all_done()`);
  (d) il segno **pulsa** (stessa tempistica di `ActiveDot`: costanti `PULSE_*`, tween nel widget, nessuno stato di gioco) e passa a 12 px (`UiStyle.STARTER_DOT_SIDE`) per vedersi a 1280×720.
- **Riquadro con 20/20**: titolo, `20/20`, nome = `final_reward().name`, barra piena, pallino acceso finché il bonus non è riscosso; il clic apre la pagina `starter` come oggi.
- **Pagina `starter`**: sotto i gruppi, una riga «Ricompensa finale» (nome, descrizione, ricompensa composta dai modelli, Riscuoti) **disattivata** con la riga «Riscuoti tutti i Primi passi» finché non 20/20;
  Riscuoti → `claim_final`, avviso nella pagina come gli altri, errore `mailbox_full` come gli altri. Nodo `FinalRow` (nome univoco) con pulsante `ClaimButton` per i test.
- **Voce Bacheca**: **nessun pallino** (le sue ricompense sono un altro sistema; dubbio in Q197). **Posta**: nessun pallino nuovo (Q198).
- Si aggiorna **solo** dal modello: `starter_quests_changed`, `starter_quest_completed`, `tutorial_completed` (e `tutorial_step_changed` già via `Sidebar`). Nessuno stato nella UI: il pallino è una funzione di `claimable()` e `is_final_available()`.

## 7. Testi: dove stanno
`TutorialTexts` (UI): `NEXT_TEXT` resta il default; `ack_text` e `progress_text` vengono dai dati. `StarterTexts`: «Ricompensa finale», «Riscuoti tutti i Primi passi», avviso di riscossione del bonus. `CombatTexts`: «In pausa».
Nessun testo di gioco nel codice del modello.
