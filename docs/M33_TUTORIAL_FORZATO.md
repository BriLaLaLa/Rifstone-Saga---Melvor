# M33: Tutorial forzato (V42)

Piccola modifica sullo stesso flusso di M30/M31 (`01_GDD_M30.md` §41, `04_DATA_SCHEMA_M30.md` §34, `05_INTERFACES_M30.md`, `M31_RITOCCHI_TUTORIAL.md`). Questo file è **fonte unica** per gli id, le chiavi e le
firme nuovi: GDD, schema e contratto di M30 rimandano qui. Fonte del design: richiesta dell'utente del 2026-11-22 (V42 in `DECISIONS_LOG.md`, Q204-Q209 in `OPEN_QUESTIONS.md`), task in `07_TASKS_M33.md`.
Nessuna formula nuova, nessun valore di design nel codice: tutto in `data/tutorial/steps.json`. **Resta save v12, nessuna chiave di save nuova** (tutto è derivato dal passo corrente, come in M31).

Testo dell'utente (fonte): «Quando si fa lo scontro... lo scontro è casuale, quindi possono apparire anche 11 nemici o 6, e tu dici di ucciderne 3... uno di questi è sempre l'ariete di roccia che ci fa il culo.
Vorrei che per il tutorial le cose fossero forzate: sia il nodo iniziale che il primo combattimento. E dopo il primo combattimento si stoppasse in automatico per far continuare il tutorial.»

## 1. Diagnosi (sul codice di `main` = `m32-done`)
- Il gruppo di un incontro è **F-77** (`Encounter.spawn`: `rng.pick_weighted` sui `packs` di `data/combat/areas.json`). Nelle Pianure di Roccarossa **12 gruppi su 13 contengono `rock_ram`** (84 PV, `attack_level` 10): l'unico senza è `[plains_boar]` (peso 4 su 100), quindi **il 96% dei gruppi ha l'ariete**,
  e i gruppi hanno da 1 a 8 nemici (`combat.pack_size_weights`). Il passo 5 chiede «3 uccisioni» ma il gruppo è casuale: il giocatore vede da 1 a 8 nemici e l'ariete lo ferisce.
- Il ciclo F-153/F-156 decide a ogni partenza se il prossimo incontro è un nodo (`node_chance_pct`) e lo prende dalla **prima disciplina appresa** nell'ordine delle voci di `data/encounters/nodes.json`
  (M31 `force_node`): oggi vero, ma **implicito** (il passo non dice quale disciplina) e valido solo alla *prossima* partenza.
- Dopo il pasto (passo 8) il combattimento **riparte da solo** e continua a girare (gruppi casuali, ariete compreso, miniboss e Monoliti) mentre il giocatore visita i passi 9-13: può morire e fermarsi senza che il tutorial lo sappia.
- Dopo la terza uccisione (passo 5) il combattimento non si ferma: il passo 6 (triangolo) si legge mentre parte già il gruppo successivo.
- Un miniboss (1,5% dopo ogni gruppo normale, F-139) o un Monolito (0,6% a uccisione, F-87) in attesa **vincono** su ogni regola del ciclo (anche su `force_node`).

## 2. Soluzione (riassunto)
| # | Richiesta | Soluzione |
|---|---|---|
| 1 | Primo combattimento forzato e vincibile | Campo di passo `force_pack` (§3): composizione **fissata dai dati**, solo mostri deboli (soglia in `steps.json`), **nessun tiro RNG** per scegliere gruppo e numero. Usato nei passi 5 (le 3 uccisioni), 7 (il pasto) e 14 (nodo) |
| 2 | Nodo iniziale forzato | Il passo 14 dichiara nei dati **quale** disciplina e **dove** (§4): `force_node` + `force_pack` + `skill_id` nel `done_when`; il motore sostituisce anche il viaggio **già in corso** |
| 3 | Stop automatico dopo il primo combattimento | **Si riusa il congelamento di M31** (`freeze_combat`, §5): nessuno stato nuovo, nessun comando nuovo. Il comando che riparte è **Avanti** del passo 6 (poi Ok del passo 8 e, al passo 14, l'ingresso nel passo) |
| 4 | Morte | Nessun meccanismo di morte impedita: gruppi **piccoli e deboli** + prova su molti semi (§6, Q204); la ferita del passo 7 si ripete finché non arriva il pasto |

## 3. Primo combattimento forzato (`force_pack`)
### 3.1 Dati (`data/tutorial/steps.json`, schema esteso: estende `04_DATA_SCHEMA_M30.md` §34.1 e `M31_RITOCCHI_TUTORIAL.md` §2.1)
Campo facoltativo di passo:
```json
"force_pack": {"area": "redrock_plains", "monsters": ["plains_boar", "ember_rat", "plains_boar"]}
```
Chiave di primo livello nuova di `steps.json`: `"force_pack_max_attack_level": 5` (insieme a `stuck_ms`): è l'unica definizione della soglia di «mostro debole per il livello 1».

| Regola del validatore (`DataValidatorTutorial`) | Perché |
|---|---|
| `area` esiste; `monsters` ha 1..`combat.max_pack_size` id **ripetibili**, tutti nella lista dei mostri dell'area (`AreaDef.monster_ids`) | un gruppo possibile di quell'area |
| ogni mostro: non miniboss, non pietra, `attack_level` ≤ `force_pack_max_attack_level` (**`rock_ram` 10 e `redrock_raider` 8 sono vietati**; `plains_boar` 1, `ember_rat` 3, `dust_jackal` 5 vanno) | mai un pericoloso per il livello 1 |
| se il `done_when` ha un evento `monster_killed` con `count` N: `monsters.size()` ≥ N | le N uccisioni si fanno nel **primo** gruppo |
| `force_node` richiede `force_pack` nello **stesso** passo | ogni guardia ha un gruppo (§3.3) |
| `force_pack_max_attack_level` int 1..20 obbligatoria se esiste un `force_pack` | un valore solo, nei dati |

`TutorialStepDef` guadagna `force_pack_area: StringName` (`&""` = assente) e `force_pack: Array[StringName]`.
**Composizione di partenza (la scelgono i dati, il REV la conferma con i test)**: passo 5 = `plains_boar, ember_rat, plains_boar` (il ratto è Arcano: preda facile del triangolo, due Cinghiali Lama);
passo 7 = `plains_boar, ember_rat` (il pasto: primo colpo subito); passo 14 = `plains_boar` (solo se il combattimento è fermo e riparte dalla Mappa). Se un seme dei test fallisce (§6) si cambiano **solo** i dati.

### 3.2 Motore (`systems/combat/combat_engine.gd`, API nuova; se supera 400 righe, nel file nuovo `combat_tutorial.gd`)
```gdscript
func set_force_pack(area_id: StringName, monster_ids: Array[StringName]) -> void   # solo TutorialSystem; vuoto = spento; non emette segnali, non si salva
func force_pack() -> Array[StringName]                                             # solo lettura, per i test e la UI di debug
func is_guarded() -> bool                                                          # un gruppo forzato per l'area attuale è armato, oppure force_node
```
- **Regola**: finché è armato e `area_id` coincide con l'area del combattimento, **ogni** incontro d'area che inizia (`CombatCycle._area_encounter`, anche all'avvio da fermo con `start`) è `Encounter.of_defs(...)` con quei mostri
  a PV pieni e timer pieni (come un miniboss); **zero tiri su `rng`** (né F-77 né il numero). In una Frattura, in un Dungeon, per un Monolito o un miniboss **non cambia nulla** (il gruppo forzato vale solo per `_area_encounter`).
  Non è «una volta sola»: resta armato finché il passo è corrente (così, se il giocatore muore e riavvia, il gruppo è di nuovo quello). Con il passo che finisce lo disarma il passo successivo (§5.3).
- **Guardia (`is_guarded`)**: un miniboss o un Monolito **in attesa** restano in attesa (nessun flag cancellato, nessun tiro tolto: i tiri F-139/F-87 avvengono come sempre) ma **non vincono** sul ciclo mentre c'è la guardia:
  `_area_encounter` serve il gruppo forzato prima di tutto e `_start_travel` passa `forced_fight = (stone.pending or miniboss_pending) and not is_guarded()`. Appena la guardia cade (fine del passo 14) arrivano
  come sempre. Residuo: dopo il tutorial, circa il 5% delle partite incontra subito un miniboss o un Monolito (Q207).
- `set_force_pack` con il motore **in viaggio** (`STATE_TRAVEL`) e prossimo tipo `node` e **senza** `force_node`: il viaggio diventa `fight` (senza tiro): il pasto non aspetta un nodo.
- `new_game()` e `from_save()` del motore azzerano il gruppo forzato; `stop()` **non** lo tocca (lo deriva TutorialSystem dal passo).

### 3.3 Interazione con la ferita e il pasto (M31 `wound_hp_pct`)
- Il passo 7 arma il gruppo del pasto **e** ferisce al 30% (`wound_to_pct`); il primo colpo del gruppo debole porta il personaggio sotto la soglia dell'auto-mangiare di livello 1 (acquisto iniziale `auto_eat_1`),
  oppure preme Mangia lui. `food_eaten` chiude il passo 7; il passo 8 congela (§5).
- **Ferita ripetuta** (modifica rispetto a M31): finché il passo 7 è corrente, la ferita si applica **a ogni** `encounter_started` (non una volta sola): se il personaggio muore (gruppo debole, caso previsto zero
  nei test) o il gruppo cade senza averlo colpito, il prossimo gruppo trova di nuovo il personaggio al 30% e il pasto arriva comunque. `wound_to_pct` resta `min(hp, tetto)`: non cura mai e mai sotto 1.
- Il passo 5 **non** ferisce: i tre nemici deboli sono il combattimento «normale» (l'auto-mangiare resta com'è).

## 4. Nodo iniziale forzato (passo 14 `nodes`)
Oggi: `force_node` (M31) sceglie la **prima disciplina appresa dell'area in ordine di voce** di `encounters/nodes.json` con il suo `min_level` raggiunto, senza tiri; **non** è mai la Cucina (non è una disciplina di nodi: M32 la lascia
apprendibile sempre ma i nodi dell'area sono solo di raccolta). Cosa cambia, esplicito nei dati:
- `done_when` del passo 14: `{"type":"event","signal":"node_started","args":{"skipped":false,"skill_id":["forestry","quarrying","angling","herbalism"]}}`: la stessa lista del passo 12 `trainers`
  (qualunque delle quattro raccolte imparate dal giocatore); il validatore controlla che ogni `skill_id` sia una disciplina dei nodi dell'area del `force_pack` dello stesso passo e che il passo abbia `force_node` e `force_pack`.
- `force_pack` del passo 14: `{"area":"redrock_plains","monsters":["plains_boar"]}` (§3).
- **Viaggio già in corso**: `set_force_node(true)` con il motore in viaggio (`STATE_TRAVEL`) e prossimo tipo `fight` (o un nodo **saltato**) sostituisce il viaggio con il nodo forzato, **senza tiri**
  (nuova funzione pura `EncounterCycle.forced_node(session, area_id) -> Dictionary`, `{}` se nessuna disciplina è utilizzabile; `next_kind` la usa già internamente come `_forced_skill`). Un combattimento **in corso** (gruppo vivo) finisce prima: poi il viaggio è già un nodo. La guardia (§3.2) lo protegge da miniboss e Monolito.
- Ordine di applicazione all'ingresso del passo: `set_force_node` prima di `set_force_pack` (il nodo ha la precedenza sulla sostituzione «nodo → combattimento» del pasto).
- Testo del passo 14: «Il combattimento riparte: finito lo scontro in corso, lungo la strada compare un nodo da lavorare con il mestiere che hai imparato. Se il combattimento è fermo, riavvialo dalla Mappa.»

## 5. Stop automatico dopo il primo combattimento (congelamento di M31)
### 5.1 Scelta: si riusa `freeze_combat`, nessuno stato nuovo
Alternative scartate (Q205): (a) `stop()` del motore al termine del gruppo: serve un motivo nuovo, un comando per ripartire (pulsante o passo) e il giocatore può restare bloccato con il combattimento fermo;
(b) un flag «tieni fermo dopo il gruppo»: nuovo stato. Il **congelamento di M31** fa già tutto: non si salva, è derivato dal passo, il ciclo esce alla fine dell'istante (l'equivalenza 12 h = 100 ms = 60 s resta), nessun tiro RNG,
il salvataggio a metà pausa riprende congelato, l'overlay offline è vuoto. La pausa è **nel modello** (`CombatEngine.is_frozen()`), la UI mostra solo «In pausa».

### 5.2 Passi congelati, dati (`freeze_combat`)
- `freeze_combat` **non** richiede più `ack` (modifica rispetto a M31 §2.1): ammesso su ogni passo **tranne** quelli il cui `done_when` ha un evento di combattimento (`monster_killed`, `food_eaten`, `node_started`, `encounter_started`,
  `encounter_cleared`, `travel_started`, `node_finished`): sarebbe un passo irraggiungibile (**errore del validatore**). L'ultimo passo non può essere congelato.
- Sequenza (colonna «Combattimento» = stato del motore **durante** il passo):

| # | id | Combattimento | Come si entra / esce |
|---|---|---|---|
| 4 | `combat_start` | fermo (idle) | il giocatore sceglie l'area dalla Mappa: `combat_started` |
| 5 | `combat_kills` | **gruppo A forzato**, gira | 3 uccisioni = l'ultimo nemico del gruppo A (stesso istante: la terza uccisione chiude il passo) |
| 6 | `combat_triangle` | **congelato** (nuovo: `freeze_combat`) | congelato dall'**istante** dell'ultima uccisione (il motore finisce l'istante: fine incontro, viaggio); **Avanti** riparte |
| 7 | `combat_eat` | **gruppo B forzato**, ferita al 30%, gira | il viaggio riprende, arriva il gruppo B; pasto automatico o con Mangia: `food_eaten` |
| 8 | `combat_food` | **congelato** (invariato) | all'istante del pasto; **Ok** passa al 9 e **il combattimento resta congelato** (nuovo) |
| 9-13 | `bank`…`skill` | **congelato** (nuovo: `freeze_combat` su ognuno) | la visita dei luoghi non lascia girare combattimento: niente morte, niente bottino, niente miniboss mentre si legge |
| 14 | `nodes` | **riparte**: gruppo (B in corso o C) e nodo forzato | l'ingresso nel passo scongela; `node_started` con `skipped` falso chiude |
| 15+ | | normale | `_release_combat` all'uscita dal 14 (guardia, forzature, congelamento tutti spenti) |

- **Chi riparte**: (1) passo 6 = il pulsante **Avanti** del pannello (`acknowledge()`); (2) passo 8 **non** riparte più (testo e `ack_text` «Ok» restano); (3) passo 14 = l'**ingresso nel passo** (un giocatore che ha il combattimento fermo lo
  riavvia dalla Mappa, come oggi, e trova il gruppo C debole). Nessun comando nuovo, nessuna firma nuova di `TutorialSystem`, nessun segnale, nessun motivo.
- Testi cambiati (il resto dei passi invariato; limite 280 caratteri, lo controlla il validatore):
  - **6** (`combat_triangle`): aggiungere in fondo «Il combattimento è in pausa: premi Avanti per continuare.»
  - **8** (`combat_food`): sostituire «Premi Ok per ripartire.» con «Premi Ok: il combattimento resta in pausa finché non torni al nodo.»; se la frase del bottino non sta nei 280 caratteri, passa nel passo 9 `bank`.
  - **14** (`nodes`): il testo di §4.
- Dopo il passo 6 il giocatore vede la zona nemici **vuota** (il gruppo A è morto): il triangolo è spiegato dal testo (Q206).

### 5.3 `TutorialSystem` (`systems/tutorial/tutorial_system.gd`; nessuna firma pubblica nuova)
- `_apply_combat_effects(step)` (già chiamata a ogni ingresso e a ogni `from_save`) imposta **sempre tutti** i campi: `set_frozen`, `set_force_node`, `set_force_pack` (vuoto se il passo non ha `force_pack`) e la ferita.
  Il passo successivo disarma da solo quello precedente: nessun «ripristino» sparso. L'uscita dal tutorial (`_release_combat`) azzera anche `set_force_pack`.
- `is_combat_frozen()` resta com'è (lo legge la UI per «In pausa» e per l'etichetta dei bottoni).
- Ferita ripetuta: `_wound_listening` non si spegne al primo `encounter_started` ma all'uscita dal passo (o al `food_eaten`); `_on_encounter_started` ferisce a ogni gruppo.
- Salvataggio/ripresa: **a ogni passo**, anche a metà stop (6, 8-13): `from_save` riapplica gli effetti del passo (congelato, gruppo forzato armato); un salvataggio v12 già in gioco fermo a un passo 6-13 con il combattimento
  attivo riprende **congelato** (voluto: la pausa è la regola nuova), fermo al passo 5 con un gruppo casuale in corso: il gruppo forzato vale dal prossimo incontro (nessuna modifica retroattiva), fermo al passo 14 e successivi invariato.
  Tutorial illeggibile → completato → tutto sbloccato (mai intrappolare, invariato).
- **Sempre completabile da una partita nuova** (nessun passo irraggiungibile, nessun blocco):
  (a) i passi congelati sono `ack` (Avanti/Ok esce) tranne il 12 `trainers` (evento `discipline_changed`, nessun combattimento richiesto) e il validatore vieta il congelamento con eventi di combattimento;
  (b) con il combattimento fermo (idle) al passo 5/7/14 il giocatore riavvia dalla Mappa e trova il gruppo forzato (`start` passa da `_area_encounter`); il passo 4 `combat_start` è l'unico che lo richiede davvero;
  (c) il passo 7 non può mancare il pasto (ferita ripetuta + 30 Trote) e la valvola `stuck_ms` resta come rete;
  (d) il passo 14 non può mancare il nodo: viaggio sostituito (§4), guardia contro miniboss e Monolito; una disciplina utilizzabile esiste sempre perché il passo 12 richiede di impararne una (evento `discipline_changed` con una delle quattro raccolte).

## 6. Prove e rischio
- **Vincibile con certezza (Q204)**: nessuna morte impedita. Test su **≥ 100 semi × 3 assetti** (spada e scudo, spadone, due spade) per il gruppo A dal personaggio di partenza e per il gruppo B con la ferita al 30%:
  **zero morti** e `food_eaten` entro il primo gruppo B; per il gruppo C (14) zero morti da personaggio **già al livello raggiunto** con il tutorial. Se un seme fallisce: **si cambia la composizione o `wound_hp_pct`
  nei dati**; se non basta, si apre Q204 (alternativa: un pavimento a 1 PV per gli incontri forzati, che toglie la sconfitta ma tocca `CombatFight`).
- **Determinismo e offline**: nessun tiro in più né in meno **fuori dal tutorial** (`force_pack` e guardia sono spenti: i golden e `sim_*` non cambiano); dentro il tutorial lo stato dipende solo dai dati e dai tiri del resto del
  combattimento: 12 h = 100 ms × N = 60 s (`test_m30_offline_equivalence`), con la pausa dell'istante come in M31.
- **Rischio** (basso): la zona vuota al passo 6; i 5-8 nemici deboli di mostri nuovi non cambiano XP/oro totali del tutorial più di qualche decina di punti (XP dei tre mostri: 80+88+80).

## 7. Test (per task: `07_TASKS_M33.md`)
Logica (M33-02): composizione forzata, nessun tiro `rng` (confronto di `rng.to_save()`), stop dopo il combattimento, nessun effetto fuori dal tutorial, determinismo su più semi, validatore (un test per caso rifiutato),
ferita ripetuta, nodo forzato in viaggio, guardia. UI (M33-03): **clic vero** con `Viewport.push_input` (GutLayer nascosto) su **Avanti** del passo 6, schermate 1280×720 e 1600×900 guardate con Read.
QA (M33-04): flusso del tutorial a partita nuova con dati veri (aggiornamento di `test_m31_tutorial_flow`/`test_tutorial_playthrough`), ripresa a ogni passo, equivalenza offline, golden.
