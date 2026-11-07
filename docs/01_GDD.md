# 01. Game Design Document

Ogni sistema ha: **regole**, **stati**, **casi limite** e **interazioni**. I numeri stanno in `02_FORMULAS.md` (citati
come `F-xx`); i parametri hanno un'unica definizione in `res://data/config/balance.json`; le stat dei modificatori
sono elencate in `res://data/config/stats.json` (sezione 15). Le firme dei metodi sono in `05_INTERFACES.md`.

Indice: 1 Slot e sessione · 2 Tempo di gioco · 3 Skill ed esperienza · 4 Azioni di raccolta · 5 Azioni di
artigianato · 6 Maestria · 7 Bank · 8 Oro e shop · 9 Equipaggiamento e attrezzi · 10 Combattimento a gruppi ·
11 Legatura del Rift e Altare (M8) · 12 Progressione offline · 13 Feedback e notifiche · 14 Suggerimenti ·
15 Modificatori e stat · 16 Impostazioni · 17 Fratture del Rift (M11) · 18 Azioni in parallelo (M12) ·
19 Personaggio e classe · 20 Tratti e abilità (M6) · 21 Armeria · 22 Rarità e affissi · 23 Raffinazione (M7) ·
24 Pietre del Rift (M7) · 25 Smantellamento e filtro (M7) · 26 Castoni e valute del Rift (M8)

Direzione del gioco da M4 (decisioni D1-D6 in `DECISIONS_LOG.md`): il **combattimento è il cuore** (gruppi di mostri,
bottino con rarità e affissi, potenziamento, build di tratti e abilità); raccolta e artigianato sono il ciclo di
supporto alla Melvor e producono ciò che serve al combattimento e al potenziamento.

Riforma del bottino e dei nomi da M10 (decisioni R1-R4 e B1-B5 in `DECISIONS_LOG.md`): l'**equipaggiamento è
fondamentale** e non si produce più in serie. I pezzi arrivano **dai mostri** (fonte principale), dal **kit iniziale** o da
un **singolo craft** (un progetto = un pezzo, §5.1). Le skill artigiane producono **componenti**; gli attrezzi di raccolta
sono **tre oggetti unici** potenziati con la raffinazione (§23.1). I nomi visibili seguono `NOMI.md` (gli **id** non
cambiano, Q52): in questo documento i nomi delle skill sono quelli di `00_VISION.md` e la UI dice "Deposito" dove qui
si legge "bank" (il modulo e gli id restano `bank`).

---

## 1. Slot di salvataggio e sessione

**Regole**
- Ci sono 4 slot (`slots.count`). Ogni slot è una partita indipendente: **tutto** lo stato del giocatore (skill,
  maestria, personaggio e classe, tratti e abilità equipaggiati, Armeria e filtro, bank, oro, equipaggiamento, cibo
  scelto, azione in corso, combattimento in corso, acquisti dello shop, prese dell'Altare, suggerimenti visti, fratture)
  sta nel file dello slot. Nessuno stato di gioco è fuori.
- All'avvio si apre il **menu principale**: Nuova partita, Continua, Impostazioni, Esci. Fino alla scelta di uno slot
  non esiste una sessione e **nessun file viene scritto** (l'unico file scrivibile prima è `user://settings.cfg`).
- Nuova partita: si sceglie uno slot (se è occupato serve una conferma di sovrascrittura), si dà un nome (1-24
  caratteri, spazi ai bordi tolti; i limiti sono definiti in `balance.json`, `player_name`); si crea la sessione con lo stato iniziale (sezione 1.1) e si salva subito.
- Continua: si sceglie uno slot esistente; il file viene letto, migrato alla versione corrente, caricato; poi parte la
  progressione offline (sezione 12).
- Durante la sessione: salvataggio automatico ogni `autosave_interval_ms` (10 s), alla chiusura della finestra,
  al ritorno al menu, dopo la fine dell'offline, dopo un acquisto nello shop.
- Elimina slot: solo dal menu, con conferma; non si può eliminare lo slot della sessione attiva.

### 1.1 Stato iniziale di una partita nuova
Tutte le skill al livello 1 (0 XP), maestria a 0, pool vuoti, 0 nodi; personaggio al livello 1 (0 XP) della classe
`character.start_class` (nell'MVP la scelta è fissa, §19), nessun tratto e nessuna abilità equipaggiati; bank vuota con
capienza base; oro `start.gold`; oggetti iniziali `start.items` (materiali e cibo, definiti in `balance.json`);
**kit iniziale** (R1, Q51): l'Armeria contiene i pezzi di `start.armory` (spada, spadone e scudo comuni di grado 1,
senza affissi) e i tre attrezzi unici a +0 di `start.tools`, che sono già indossati; l'Armeria ha il filtro "tieni
tutto"; spada e scudo sono indossati (assetto spada e scudo), lo spadone resta nell'Armeria; il bank contiene 20 pesci
cotti di grado 1 (`start.items`) e il cibo scelto è quello; acquisti dello shop di `start.purchases` (le Razioni da campo I, B2/Q12,
già possedute); nessuna azione in corso; prese dell'Altare vuote; seme casuale nuovo.

**Stati**: `MENU` (nessuna sessione) → `LOADING` → `OFFLINE_SIM` (se serve) → `PLAYING` → (`SAVING_AND_EXIT`) → `MENU`.

**Casi limite**
- File illeggibile o JSON non valido: lo slot appare "danneggiato" nel menu; si prova il file `.bak`; se anche quello
  fallisce, lo slot si può solo eliminare. Nessun crash.
- Versione del file più nuova di quella del gioco: lo slot appare "versione non supportata" e non si carica.
- Errore di scrittura (disco pieno, permessi): notifica di avviso, il gioco continua, riprova al giro successivo;
  il file precedente resta integro (scrittura atomica, vedi `03_ARCHITECTURE.md`).
- Orologio di sistema spostato indietro: il tempo offline vale 0 (sezione 12).

**Interazioni**: tutti i sistemi (ognuno salva e carica la sua parte), progressione offline, impostazioni (globali,
fuori dallo slot per scelta: non sono stato di gioco).

## 2. Tempo di gioco

**Regole**
- La logica avanza a **passi fissi** di `tick_ms` (100 ms) accumulati dal tempo reale. Ogni sistema riceve
  `advance(delta_ms)` e deve dare lo stesso risultato sia con un passo da 1000 ms sia con dieci da 100 ms (più eventi
  dentro un passo si risolvono in ordine).
- Tutte le durate sono in millisecondi interi.
- L'ordine di aggiornamento in un passo è fisso: fratture (M11) → corsie delle azioni → combattimento → tempo di gioco.
  Il combattimento è un motore a eventi (§10.10): salta da un timer all'altro, con lo stesso risultato del passo fisso.
- Il tempo di gioco (`play_time_ms`) cresce solo durante `PLAYING` (non durante l'offline, che ha il suo totale).

**Casi limite**: finestra ridotta a icona o gioco bloccato per alcuni secondi: il tempo accumulato si recupera nei
passi successivi fino a `max_catchup_ms` (5 s) per frame; oltre, il resto si scarta (evita la "spirale"). Pause lunghe
reali (computer in sospensione con il gioco aperto) sono trattate come offline al ritorno se superano
`offline_min_ms` (vedi sezione 12).

## 3. Skill ed esperienza

**Regole**
- 7 skill di supporto (tabella in `00_VISION.md`: 3 di raccolta, 3 di artigianato, Legatura del Rift), tutte
  disponibili dall'inizio. Le 5 skill di combattimento non esistono più: le sostituisce il **livello del personaggio**
  (§19, D3), che segue regole analoghe con la sua curva (F-71).
- L'esperienza è un intero cumulativo per skill. Il livello si ricava dall'XP con la tabella `F-01` (livelli 1-99).
  L'XP continua a crescere oltre il 99 fino a `xp_curve.xp_cap`, ma il livello resta 99.
- L'XP guadagnata passa sempre da `skill_xp_pct` (F-02).
- Salire di livello sblocca azioni, ricette, aree, prese dell'Altare, equipaggiamento (requisiti nei dati).
- Ogni salita di livello emette `level_up` (anche più livelli in un colpo: un evento per livello).

**Stati**: per skill solo `xp`. Livello e progresso sono derivati, mai salvati.

**Casi limite**: XP negativa non ammessa (assert, ignorata); XP oltre il tetto troncata; salto di più livelli.

**Interazioni**: azioni, maestria, requisiti degli attrezzi (gli equipaggiamenti richiedono il livello del personaggio),
Altare del Rift. Il combattimento dà XP solo al personaggio (F-28).

## 4. Azioni di raccolta (Selvicoltura, Cavatura, Lenza)

**Regole**
- Ogni skill di raccolta ha una lista di azioni (es. "Abbattere betulla rossa") con: livello richiesto, intervallo
  base, XP, oggetto prodotto e quantità.
- Si avvia un'azione dalla pagina della skill; parte una barra di progresso. Alla fine dell'intervallo (F-03):
  1. si calcolano i prodotti: quantità base, raddoppiata se riesce il tiro `double_item_chance` (F-06);
  2. si tenta il frammento del Rift con probabilità F-07 (`rift_shard` ×1);
  3. si aggiunge tutto alla bank; se un oggetto **nuovo** non trova posto, l'azione **non** conta (niente XP né
     maestria), si ferma con motivo `bank_full` e nulla va perso;
  4. si danno XP (F-02) e maestria (F-10);
  5. l'azione riparte da sola (ciclo infinito) finché il giocatore non la ferma.
- Una sola azione alla volta nella corsia principale (fino a M12): avviarne un'altra ferma la precedente; avviare il
  combattimento ferma l'azione; avviare un'azione ferma il combattimento.
- L'**attrezzo unico** della skill (slot `tool_<skill>`, §9, §23.1) dà modificatori alla skill (`skill_interval_pct`
  negativo e, ai passi alti della raffinazione, `double_item_chance` o `rift_shard_chance`).

**Stati**: corsia `IDLE` / `RUNNING(skill, action, elapsed_ms)`. `elapsed_ms` è salvato: ricaricando, la barra riprende.

**Casi limite**: livello insufficiente (non si avvia: `level_too_low`); dati mancanti (`unknown_id`); intervallo
ridotto sotto il minimo (`action.min_interval_ms`); cambio di attrezzo durante l'azione (vale dal ciclo successivo:
l'intervallo si ricalcola a ogni avvio di ciclo).

## 5. Azioni di artigianato (Fabbro, Cuoco, Falegname, Legatura del Rift)

**Regole**
- Ogni ricetta ha: livello richiesto, intervallo, XP, **ingredienti** (`inputs`, oggetto e quantità) e **prodotti**
  (`outputs`).
- All'**inizio** di ogni ciclo si controlla che gli ingredienti ci siano tutti; se mancano, l'azione si ferma
  (`missing_inputs`). Gli ingredienti si consumano alla **fine** del ciclo:
  1. tiro di conservazione `preservation_chance` (F-08): se riesce, nessun ingrediente viene consumato;
  2. altrimenti si tolgono tutti gli ingredienti (se nel frattempo sono spariti, ad es. venduti, il ciclo fallisce e
     l'azione si ferma con `missing_inputs`, senza XP);
  3. prodotti con `double_item_chance` (F-06); aggiunta alla bank (se non c'è posto: come nella raccolta, ma gli
     ingredienti **non** vengono consumati);
  4. XP e maestria come nella raccolta.
- Il frammento del Rift (F-07) **non** si tenta nelle azioni di artigianato.
- **Dalla riforma (R2) nessuna ricetta produce equipaggiamento in serie**: le ricette ripetibili producono solo
  oggetti di bank (lingotti, **componenti**, cibo, infusioni, pietre, valute). Le ricette di armi, armature, scudi e
  attrezzi a gradi sono eliminate con le loro maestrie per azione.
- **Fabbro** (`forging`): minerale → lingotto; 2 lingotti → **piastra** (componente di grado, ricette in `02_FORMULAS.md` §8.2); inoltre le
  azioni a ciclo unico dei progetti (§5.1). **Falegname** (`woodwright`): legno → **impugnatura**, **telaio dello
  scudo**, **manico** (componenti di grado). **Cuoco** (`hearthcraft`): pesce cotto, invariato.

### 5.1 Progetti: il craft singolo (R1)
- Un **progetto** (`blueprint`) è un oggetto di bank (categoria `blueprint`) che indica la **base** da produrre (un
  modello di spada, spadone, scudo, elmo, corpo, gambe, piedi o mani) e il suo **grado**. Un progetto = un pezzo.
  Anelli e amuleti non hanno progetto (solo drop, Q30).
- Fonti dei progetti: **drop rari dei mostri** e **Pietre del Rift** (più spesso), pesati sul grado dell'area
  (`Q49`: circa 1 progetto all'ora nell'area del proprio livello, 1 su 3 Pietre); un'area di grado `g` lascia progetti
  di grado `g` e `g+1`.
- Si avvia dalla pagina del **Fabbro**, sezione "Progetti". Requisiti: il livello del Fabbro del grado (livello di
  F-90 = livello del grado di 8.1), il progetto in bank, i **materiali** (componenti del Fabbro e del Falegname del
  grado, quantità nei dati del progetto, tabella in `02_FORMULAS.md` §8.2) e **un componente raro** (un drop dei
  mostri dell'area del grado, es. "Nucleo di golem").
- È un'**azione a ciclo unico** nella corsia principale: dura molto (Q48: 10 minuti al grado 1, 60 al grado 8, F-90),
  dà molta XP al Fabbro (F-90), **non** ha maestria e **si ferma da sola** alla fine (motivo `blueprint_done`).
  Progetto, materiali e componente raro si consumano **all'avvio** (se si ferma prima il giocatore li riceve indietro:
  `stopped_by_user` e `replaced` restituiscono tutto; il resto non tocca il bank), il pezzo nasce alla fine.
  Si può fare **offline**: la durata passa nel tempo simulato. Avviare un altro lavoro lo sostituisce (restituzione).
- Risultato: mai un pezzo comune; rarità **almeno magica** (F-91): `magic` oppure `rare` con probabilità che cresce
  con il livello del Fabbro. Affissi F-85 con `ilvl` = livello del grado. Dal livello del Fabbro Q50 (50) il giocatore
  **sceglie un affisso** garantito (grado fisso, F-92) prima di avviare il craft: l'affisso scelto conta nel numero
  di affissi della rarità.
- Armeria piena: l'avvio è rifiutato (`armory_full`); se si riempie durante il lavoro, alla fine il lavoro resta al
  100% e riprova a ogni passo (notifica `armory_full` una volta), senza perdere nulla.
- Un solo lavoro alla volta (la corsia principale); la corsia secondaria (M12) non può eseguire progetti.

**Stati**: corsia `RUNNING(forging, blueprint_craft, elapsed_ms, durata, progetto, affisso scelto)`; lo stato extra sta nel
salvataggio di `actions`. **Casi limite**: livello insufficiente (`level_too_low`), materiali o componente raro
mancanti (`missing_inputs`), affisso scelto non ammesso dallo slot o livello < Q50 (`invalid_choice`), progetto
sconosciuto (`unknown_id`).

**Casi limite**: ingrediente bloccato nella bank (il blocco impedisce solo la vendita: si può usare); oggetto
equipaggiato come ingrediente (non conta, è fuori dalla bank); un ingrediente che è anche il cibo scelto (si consuma
dalla bank: il cibo disponibile cala).

## 6. Maestria

### 6.1 Maestria per oggetto
- Ogni azione di raccolta e artigianato (`mastery: true` nei dati) ha un livello di maestria 1-99 (tabella F-09).
- A ogni ciclo completato si guadagna maestria di quell'azione (F-10). Il valore cresce con: durata dell'azione,
  livello di maestria dell'azione, maestria totale della skill, `mastery_xp_pct`.
- I bonus della maestria per oggetto sono definiti per skill (`mastery_bonuses` nel file della skill): ad es.
  "ogni 10 livelli +1 punto di `double_item_chance` per questa azione". Sono modificatori con ambito azione (F-11).
- Tutte le 7 skill hanno maestria; il livello del personaggio no (D3).

### 6.2 Pool della maestria
- Ogni skill con maestria ha un **pool**. Una quota di ogni guadagno di maestria (`mastery.pool_share_pct`, 20%) va
  anche nel pool (F-12), fino al tetto `items × mastery.pool_cap_per_item` (F-13). Oltre il tetto il surplus si perde
  (la UI avvisa quando il pool è al 95%).
- Il pool si spende in due modi:
  1. **alzare la maestria di un'azione**: 1 XP del pool = 1 XP di maestria (F-14); non oltre il livello 99;
  2. **comprare nodi** (6.3).

### 6.3 Nodi della maestria (differenza rispetto al modello di riferimento)
- Ogni skill con maestria ha un albero di 6-8 nodi (`data/mastery/<skill>.json`). Un nodo ha: costo in percentuale
  del tetto del pool (F-15), prerequisiti (altri nodi), modificatori con ambito skill.
- Comprare un nodo toglie il costo dal pool; il nodo è **permanente** (non si perde se il pool cala).
- Nessuna soglia del pool dà bonus: solo i nodi.

**Casi limite**: pool insufficiente (`pool_insufficient`); prerequisito mancante (`node_prereq_missing`); nodo già
comprato (`node_owned`); spesa che porterebbe la maestria oltre il 99 (si spende solo il necessario); importo ≤ 0
(`invalid_amount`).

**Interazioni**: azioni (guadagno), modificatori (bonus), UI pannello maestria.

## 7. Bank

**Regole**
- La bank è l'**unico** contenitore degli oggetti impilabili posseduti (materiali, cibo, infusioni, pietre, valute;
  esclusi la borsa del bottino e le prese dell'Altare). Equipaggiamenti e attrezzi **non** entrano nella bank: sono
  istanze dell'Armeria (§21); `add` di un oggetto `equipment`/`tool` è rifiutata (`not_stackable`). Ogni tipo di oggetto occupa **una** casella, con quantità illimitata (intero a 64 bit).
- Capienza = `bank.base_slots` (24) + somma della stat `bank_slots` (caselle comprate nello shop, F-17).
- Aggiungere un oggetto già presente non occupa caselle; aggiungerne uno nuovo richiede una casella libera, altrimenti
  l'aggiunta fallisce (`bank_full`) e il chiamante decide cosa fare (le azioni si fermano, la borsa del bottino tiene
  l'oggetto, l'acquisto non avviene).
- Quando la quantità arriva a 0 la casella si libera.
- Ogni casella può essere **bloccata**: un oggetto bloccato non si vende (né singolo né "vendi tutto").
- Ordine: quello di inserimento; il giocatore può spostare le caselle (trascinamento) o usare "Ordina" (per categoria,
  poi per `sort_order` dell'oggetto).
- Dal pannello dell'oggetto: vendi (quantità con cursore, "tutti tranne 1", "tutti"), blocca, scegli come cibo,
  incastona (infusioni, M8). Si equipaggia dall'Armeria (§21).

**Casi limite**: capienza che scende sotto le caselle usate (non può succedere nell'MVP: le caselle comprate non si
perdono); oggetto sconosciuto in un salvataggio (scartato al caricamento, con avviso nel log); quantità ≤ 0 (rifiutata).

## 8. Oro e shop

**Regole**
- Unica valuta: **Oro** (`gold`, intero ≥ 0).
- Vendere: oro = `item.value × quantità` (F-18). Oggetti con `value = 0` non si vendono.
- Lo shop ha voci (`data/shop/shop.json`), per categoria:
  - **Deposito** (categoria `bank`): "Spazio nel deposito" (+1 `bank_slots`), prezzo crescente F-17, massimo = `max_purchases` della voce `bank_slot` in `shop.json`;
    "Spazio nell'armeria" (+1 `armory_slots`), prezzo crescente F-82, massimo = `max_purchases` di `armory_slot` (Q33);
  - **Combattimento**: "Razioni da campo I/II/III" (stat `auto_eat_tier`, una alla volta, in ordine; **le Razioni da
    campo I sono già possedute a partita nuova**, B2/Q12: `start.purchases`, la voce resta nei dati),
    "Raccolta automatica del bottino" (`auto_loot`), "Tasca della borsa" (+4 `loot_bag_slots`, max 3);
  - **Materiali**: oggetti base comprabili (es. sale, spago) a prezzo fisso;
  - ~~Attrezzi del novizio~~: tolti con la riforma (R3); gli attrezzi unici arrivano con il kit iniziale (§1.1). La
    categoria `tools` dello shop non esiste più;
  - **Corsie** (M12): "Secondo pensiero" (`parallel_lanes` +1).
- Ogni voce ha: costo (oro fisso o formula), massimo di acquisti, requisiti (livello del personaggio, skill/livello,
  altra voce, livello totale), effetto (modificatori o oggetto).
- Gli effetti a modificatore valgono `valore × numero di acquisti` (sorgente `shop:<id>`).

**Casi limite**: oro insufficiente (`not_enough_gold`); massimo raggiunto (`max_purchases`); requisito mancante
(`requirement_not_met`); acquisto di un oggetto con bank piena (`bank_full`, oro non speso).

## 9. Equipaggiamento e attrezzi

**Regole**
- Slot: `head`, `body`, `legs`, `feet`, `hands`, `neck`, `ring`, `weapon`, `offhand`, `tool_forestry`,
  `tool_quarrying`, `tool_angling`. Più una scelta che non è uno slot: il **cibo** (riferimento a un oggetto della
  bank). La stance non esiste più (D3, Q9 chiusa).
- Ogni slot contiene il `uid` di un'istanza dell'Armeria (§21), mai una copia: il pezzo resta nell'Armeria, segnato
  come indossato. Equipaggiare un pezzo in uno slot occupato rimette il precedente tra i pezzi non indossati; se
  l'Armeria non ha posto per i pezzi che tornano l'operazione fallisce (`armory_full`) e nulla cambia.
- Requisiti (`equip.requirements`): gli equipaggiamenti chiedono il livello del personaggio (`{"character": n}`), gli
  attrezzi il livello della propria skill. Senza requisiti: `requirement_not_met`.
- **Classe e tipi d'arma** (D2, D6): un'arma o un offhand il cui `kind` non è ammesso dalla classe (§19) non si
  equipaggia (`requirement_not_met`). L'`offhand` accetta uno scudo (`shield`) **oppure** una seconda spada (`sword`),
  se la classe ha un assetto con quella combinazione; equipaggiare una spada chiede lo slot di destinazione
  (`weapon` di default, `offhand` per la seconda).
- Arma a due mani (spadone): per equipaggiarla l'`offhand` torna tra i pezzi non indossati; equipaggiare un `offhand`
  con un'arma a due mani toglie l'arma. Senza arma l'offhand può essere solo uno scudo: togliere l'arma con una spada
  nell'offhand toglie anche quella.
- L'**assetto** (`greatsword`, `sword_shield`, `dual_swords`, `sword`, o `unarmed` senza arma) deriva
  dall'equipaggiamento (F-72), non si sceglie a parte. I suoi modificatori valgono come sorgente `setup:<id>`.
- I modificatori di un pezzo (base × raffinazione F-86 + affissi, §22) valgono finché è indossato (sorgente
  `equipment:<slot>`).
- L'arma decide lo **stile** (`blade` per tutte le spade) e l'intervallo d'attacco (F-26; con due spade F-73); senza
  arma si combatte a mani nude (valori `combat.unarmed`).
- Il cibo scelto si mangia **direttamente dalla bank**: nessuna copia separata.
- Gli **attrezzi** sono tre oggetti **unici**, uno per mestiere (Accetta, Piccone, Canna da pesca): hanno sempre il
  loro slot `tool_<skill>`, non si tolgono, non si vendono, non si smantellano, non hanno rarità né affissi (Q32
  superata dalla riforma R3). Danno modificatori con ambito della loro skill, che dipendono dalla raffinazione
  +0…+9 (§23.1). Esiste un solo esemplare per mestiere, creato dal kit iniziale (§1.1) e sempre usabile (nessun requisito di
  livello per indossarlo: il livello del mestiere serve per raffinarlo).
- Durante un **incontro** si può cambiare tutto tranne arma e offhand (`combat_active`): l'assetto non cambia a metà
  incontro. Il cambio di armatura vale subito (le statistiche si ricalcolano).

## 10. Combattimento a gruppi

### 10.1 Struttura
- **Aree** (4 nell'MVP), ognuna con una lista di **gruppi** pesati (`packs`, 1..`combat.max_pack_size` mostri) e un
  requisito di livello del personaggio. Il giocatore sceglie l'area e avvia; un **incontro** è un gruppo pescato (F-77).
  Uccisi tutti i nemici, dopo `combat.respawn_ms` (stato `BETWEEN`) parte un nuovo incontro.
- Il combattimento occupa la corsia principale (ferma l'azione in corso e viceversa).

### 10.2 Stili e triangolo
- Tre stili: **Lama** (`blade`), **Mira** (`marksmanship`), **Arcano** (`arcana`). Nell'MVP il giocatore è sempre
  `blade` (classe di sole spade, D6); i mostri hanno uno dei tre stili.
- Triangolo: **Lama batte Arcano, Arcano batte Mira, Mira batte Lama** (F-24): i mostri arcani sono prede facili, gli
  arcieri sono pericolosi. Con le classi future il triangolo conta anche dal lato del giocatore.
- Precisione, evasione, danno e PV del giocatore vengono dal livello del personaggio (F-70) e dai modificatori.

### 10.3 Timer e risoluzione
- Il giocatore ha il timer dell'attacco base e un timer per abilità (M6); ogni nemico ha il suo timer d'attacco (F-26).
  Allo scadere di un timer l'attaccante tira la precisione (F-23): se colpisce, tira il danno (F-22), applica triangolo
  e riduzione del difensore (F-24, F-25). Con lo scudo un colpo nemico può essere **parato** (F-75).
- Ordine fisso a parità di istante (F-76): attacco base del giocatore, abilità in ordine di slot, nemici per posizione.
  A parità di seme lo stesso incontro dà sempre lo stesso esito.
- **Bersaglio** del giocatore: regola `first` (il primo vivo della fila), cambiabile da un tratto (`target_rule`). Le
  abilità ad area colpiscono tutti o i primi N.
- **Tutti** i nemici vivi attaccano il giocatore: più nemici, più pressione.
- Con due spade gli attacchi base alternano le mani, ognuna con le sue stat d'attacco (F-73, F-74).

### 10.4 Esperienza
- Ogni nemico ucciso dà al personaggio l'`xp` del mostro moltiplicato per `combat.kill_xp_mult` (F-28, F-71). Niente
  XP per danno, niente stance (D3, Q9). Obiettivo di ritmo (B1): livello 99 in circa 300 ore di combattimento nell'area
  giusta, offline compreso; da 50 a 60 in una notte (12 ore offline); il valore si fissa con `tools/sim_combat.gd`.

### 10.5 Cibo e razioni da campo
- Pulsante "Mangia": consuma 1 cibo scelto e cura `heal × (1 + food_healing_pct/100)` (F-29), senza superare il massimo.
- Razioni da campo (livelli 1-3 dallo shop, stat `auto_eat_tier`): dopo ogni colpo subito (non parato), se i PV sono ≤
  soglia del livello, mangia un pezzo alla volta finché i PV non superano la soglia obiettivo o il cibo finisce (F-30).
- Senza cibo il combattimento continua (rischio di morte). Le razioni da campo di livello 1 sono **gratuite
  dall'inizio** (B2): con un cibo scelto si mangia da soli fin dalla prima partita. Se si avvia un combattimento
  **senza cibo scelto** (o a quantità 0) la pagina mostra un avviso, senza impedire l'avvio.

### 10.6 Bottino
- Alla morte di ogni nemico: oro (F-31) direttamente nel portafoglio; oggetti dalla sua tabella dei drop (ogni voce tira
  la sua probabilità, F-32) e frammento del Rift (F-07, probabilità del mostro) nella **borsa del bottino**. I drop di
  equipaggiamento (M7) diventano istanze dell'Armeria (§21, §25), non entrano nella borsa. I mostri sono la **fonte
  principale dei pezzi** (R1): le probabilità sono tarate perché il giocatore si vesta da solo, circa **un pezzo utile
  del proprio grado ogni 20-40 minuti** nell'area del proprio livello. I **progetti** (§5.1) sono una voce di drop
  rara dei mostri e delle Pietre; i **componenti rari** (es. Nucleo di golem) sono materiali di drop dell'area.
- La borsa ha `combat.loot_bag_base_slots` (12) + `loot_bag_slots` caselle (una per tipo, quantità illimitata). Se è
  piena, gli oggetti nuovi si perdono (notifica).
- "Raccogli tutto" sposta tutto nella bank (ciò che non entra resta nella borsa). Con `auto_loot` ≥ 1 ogni drop va
  direttamente nella bank; se la bank è piena va nella borsa.

### 10.7 Morte
- Se i PV del giocatore arrivano a 0: il combattimento si ferma (`player_died`), **il contenuto della borsa del bottino
  si perde**, i PV tornano al massimo. Equipaggiamento, Armeria e bank non si toccano.

### 10.8 Stati
`IDLE` → `ENCOUNTER(area, nemici [monster, hp, timer], player_hp, timer base, timer delle abilità, stato dei tratti)` ⇄
`BETWEEN(respawn_ms)` → `IDLE`. `RIFTSTONE` è un incontro speciale (§24, M7). I PV del giocatore fuori dal
combattimento sono sempre al massimo; restano quelli dell'incontro durante `BETWEEN`. Tutto lo stato del combattimento
è salvato (ricaricando, l'incontro riprende dallo stesso punto). I tratti si cambiano solo fuori da `ENCOUNTER` (§20).

### 10.9 Casi limite
Cambio di equipaggiamento (non arma) durante l'incontro (PV massimi ricalcolati; i PV attuali non superano il nuovo
massimo); salita di livello del personaggio durante l'incontro (stat ricalcolate, PV attuali invariati); mostro con 0 di
evasione (vale la formula, con i limiti del 5-95%); danno minimo sempre ≥ 1 dopo la riduzione (0 solo se parato); cibo
finito; bank piena con raccolta automatica; due nemici uccisi nello stesso istante (bottino nell'ordine delle
posizioni); l'ultimo nemico e il giocatore che muoiono nello stesso istante (vale l'ordine F-76: se il giocatore uccide
per primo, l'incontro è vinto e i nemici morti non attaccano).

### 10.10 Motore a eventi
- Il motore **non** simula ogni passo da 100 ms: calcola il prossimo timer che scade, **salta lì**, risolve gli eventi
  di quell'istante (F-76) e ripete; `advance(delta_ms)` consuma eventi finché il tempo basta e conserva il resto nei timer.
- Il risultato è identico al passo per passo: stesso seme, `advance(1000)` contro dieci `advance(100)` (§2).
- Obiettivo: 12 ore di offline con gruppi da 6 in **meno di 10 s** (test di prestazione in M9).

### 10.11 Interfaccia
Pagina del combattimento: carta del giocatore (PV, timer, abilità con ricarica, tratti attivi, assetto), una carta per
nemico (PV, timer, evidenziatore sul bersaglio), numeri del danno, borsa del bottino, scelta dell'area. Nessuna
animazione di posizione.

### 10.12 Strumento di bilanciamento
`tools/sim_combat.gd`: simula N ore di combattimento in headless (classe, livello, equipaggiamento, tratti, abilità,
area) e stampa uccisioni/ora, morti, oro/ora, XP/ora, cibo consumato. Si usa a ogni cambio dei dati di combattimento
(criteri in `02_FORMULAS.md` §8.5). Opzioni `loot=1` (tabelle di bottino, Pietre e costo della raffinazione) e
`loadout=auto` (tratti e abilità sbloccati negli slot aperti): vedi `05_INTERFACES.md` §8.

## 11. Legatura del Rift e Altare del Rift (M8)

**Regole**
- **Frammenti del Rift** (`rift_shard`): cadono con piccola probabilità dalle azioni di raccolta e dai mostri (F-07),
  in quantità dalle Pietre del Rift (§24) e dallo smantellamento (§25). Servono anche alla raffinazione da +6 (§23).
- La Legatura produce anche le pietre da incastonare e le valute del Rift (§26).
- **Legatura del Rift** è una skill di artigianato (con maestria): le ricette consumano frammenti e materiali e
  producono **infusioni** (oggetti di tipo `infusion`, ognuna con una lista di modificatori).
- **Altare del Rift**: 5 prese, sbloccate ai livelli di Legatura `rift.sockets[].level` (1, 20, 40, 60, 80).
  Incastonare un'infusione la toglie dalla bank (1 pezzo) e attiva i suoi modificatori (sorgente `rift_socket:<i>`).
- Togliere un'infusione dalla presa la **distrugge** (scelta di design: le infusioni sono un consumo). Rimpiazzarla
  richiede prima di toglierla (conferma nella UI).
- Una stessa infusione può stare in più prese (i modificatori si sommano), salvo il campo `unique: true`.

**Casi limite**: presa non sbloccata (`socket_locked`); presa occupata (`socket_occupied`); oggetto non infusione
(`not_equippable`); infusione unica già incastonata (`requirement_not_met`).

## 12. Progressione offline

**Regole**
- Al caricamento di uno slot: `elapsed = now − saved_at`, limitato a `offline_cap_ms` (12 ore) (F-40).
- Se `elapsed ≥ offline_min_ms` (60 s) si mostra la schermata "Mentre eri via…" con una barra; la simulazione usa lo
  **stesso motore** del gioco online (`GameSession.advance`), a blocchi di `offline_chunk_ms` (60 s) con una pausa di un
  frame tra un blocco e l'altro; l'input del giocatore è bloccato.
- Alla fine: riepilogo con tempo simulato (e se è stato limitato), XP e livelli per skill e del personaggio, oggetti
  ottenuti e consumati, pezzi entrati nell'Armeria e smantellati dal filtro, oro, mostri uccisi, morti, cibo mangiato,
  motivo dell'eventuale stop (es. "Ingredienti finiti alle 3h 12m"). Poi salvataggio. Il tempo di uno stop è il
  **tempo vero** in cui è avvenuto (B3): una morte dopo 3 h 12 m dice "dopo 3h 12m", mai "dopo 0 s" (il tempo si ricava
  dall'avanzamento della simulazione, non da un contatore azzerato a ogni blocco).
- Un progetto in corso (§5.1) avanza anche offline e può finire durante l'assenza.
- Il combattimento offline usa il motore a eventi (§10.10) e il filtro automatico dell'Armeria (§25).
- Se `elapsed < offline_min_ms` si simula senza schermata.
- La simulazione si può **non** interrompere nell'MVP (vedi `OPEN_QUESTIONS.md`).

**Casi limite**: orologio indietro (`elapsed = 0`, avviso nel log); azione ferma (si simula comunque il tempo: nulla
succede, il riepilogo lo dice); morte durante l'offline (il combattimento si ferma e il resto del tempo passa a vuoto).

**Requisito di prestazioni**: 12 ore di raccolta o combattimento (gruppi da 6) simulate in meno di 10 s su un PC di
sviluppo.

## 13. Feedback e notifiche ("anima visiva")

- Toast in basso a destra (max 4 visibili) per: oggetti ottenuti (raggruppati per 1 s), livello, maestria 99,
  nodo comprato, bank piena, azione fermata, morte, salvataggio fallito.
- **Più livelli in un colpo (B5)**: un solo toast per skill, "Boscaiolo: livello 2 → 5" (la UI raggruppa i `level_up`
  ravvicinati della stessa skill; gli eventi del modello restano uno per livello). Vale anche per il personaggio.
- Banner centrale al passaggio di livello (Cinzel oro, 2 s).
- Barra di progresso dell'azione con riempimento continuo; piccola esplosione di particelle all'ottenimento di un
  frammento del Rift.
- Numeri del danno sopra le barre dei PV nel combattimento.
- Nessuna emoji nella UI (i font non le hanno).
- Tutto il feedback è puramente visivo: ascolta i segnali dell'EventBus e non cambia lo stato.

## 14. Suggerimenti (M9)

- Carte di suggerimento contestuali (prima azione, bank piena, primo nodo comprabile, primo frammento, prima morte).
  Ogni suggerimento si vede una sola volta **per slot** (`hints.seen` nel salvataggio).
- **Primo suggerimento (B4)**: porta al combattimento (si parte con il kit iniziale, §1.1), non alla raccolta.

## 15. Modificatori e stat

**Regole**
- Esiste **un solo** sistema di modificatori. Un modificatore è `{stat, value, scope}`; lo scope è `global`,
  `skill:<id>` o `action:<id>`. Le sorgenti sono: equipaggiamento (pezzo base × raffinazione + affissi + castoni),
  assetto, tratti, buff delle abilità (temporanei), maestria per oggetto, nodi della maestria, shop, prese dell'Altare,
  fratture (M11).
- Il valore finale di una stat in un contesto è la **somma** dei modificatori applicabili, limitata da `min`/`max`
  della stat (F-05). Ogni formula dice come usa la stat.
- I modificatori **non si salvano**: si ricostruiscono dallo stato salvato (cosa è indossato, quali nodi, quanti
  acquisti, cosa è incastonato) a ogni caricamento.
- Ogni stat esiste in `stats.json` con: effetto, formula di `02_FORMULAS.md`, test GUT. Una stat senza effetto non può
  esistere; un modificatore su una stat sconosciuta fa fallire la validazione dei dati.

Elenco delle stat dell'MVP (dettagli in `02_FORMULAS.md` §11):
`skill_interval_pct`, `skill_xp_pct`, `mastery_xp_pct`, `double_item_chance`, `preservation_chance`,
`rift_shard_chance`, `bank_slots`, `accuracy_bonus`, `accuracy_pct`, `power_bonus`, `power_pct`, `evasion_bonus`,
`evasion_pct`, `damage_reduction`, `attack_interval_pct`, `max_hp_flat`, `food_healing_pct`, `gold_drop_pct`,
`loot_bag_slots`, `auto_loot`, `auto_eat_tier`, `armory_slots`, `item_rarity_pct` (M4), `block_chance` (M5),
`upgrade_success_pct` (M7). Dopo l'MVP: `fracture_duration_pct` (M11), `parallel_lanes` (M12).
Gli effetti dei tratti che non sono somme di stat (es. "evasione a 0") non sono stat: sono tipi di effetto (F-81).

## 16. Impostazioni

Globali (non per slot, perché non sono stato di gioco): modalità finestra, dimensione, scala UI, VSync, limite FPS,
volume, livello dei log. File `user://settings.cfg`. Pannello dal menu e in partita (Esc).

## 17. Fratture del Rift (M11, dopo l'MVP)

Da rivedere a inizio M11: le Fratture diventano "mappe" con modificatori (`VISIONE_V2.md` §7). Le regole sotto sono quelle
di partenza.

- Ogni `fractures.interval_min_ms`-`interval_max_ms` (2-4 ore) di tempo di sessione (online + offline) si apre una
  Frattura casuale da `data/fractures/fractures.json`, per `fractures.duration_ms` (30 min) ×
  `(1 + fracture_duration_pct/100)`.
- Una Frattura applica modificatori globali (sorgente `fracture:<id>`) e/o rende disponibile un mostro speciale
  in un'area. Alla chiusura tutto torna normale. Stato salvato (prossima apertura, frattura attiva, tempo rimasto).

## 18. Azioni in parallelo (M12, dopo l'MVP)

- La stat `parallel_lanes` (base 1) apre una seconda corsia `secondary` per un'azione **non di combattimento**.
- L'azione della corsia secondaria ha intervallo × `(1 + parallel.interval_penalty_pct/100)` (+40%).
- Le due corsie non possono usare la stessa skill; ingredienti presi dalla stessa bank (ordine di risoluzione: corsia
  principale, poi secondaria).
- Il combattimento resta solo nella corsia principale.

## 19. Personaggio e classe

**Regole**
- **Classe** (D2): un file di dati `data/classes/<id>.json` con nome, descrizione, tipi d'arma ammessi (`weapon_kinds`,
  `offhand_kinds`), **assetti** (`setups`), abilità e tratti (`04_DATA_SCHEMA.md` §14). Il motore non conosce le classi
  per nome. MVP: **una classe**, "Spadaccino" (`rift_blade`, R4: il vecchio nome "Lama del Rift" non è più visibile), solo spade (D6): spadone, spada e
  scudo, due spade. Archi e bastoni tornano con le classi future (Q37).
- La classe si fissa alla creazione della partita (`character.start_class`; nell'MVP nessuna scelta nella UI) ed è
  salvata nello slot.
- **Livello del personaggio** (D3): uno solo, 1-99 (Q34), curva F-71. L'XP arriva solo dalle uccisioni (F-28) e passa
  da `skill_xp_pct` con i soli modificatori `global`. Ogni salita emette `character_level_up` (un evento per livello).
- Dal livello vengono i valori base di combattimento (F-70); il resto viene da equipaggiamento, assetto, tratti, Altare.
- Requisiti con la chiave riservata `character` (`{"character": n}`) in equipaggiamenti, aree e shop. Il livello totale
  (`total_level`) = somma dei livelli delle 7 skill + livello del personaggio.

**Stati**: classe, XP del personaggio; tratti e abilità equipaggiati (M6). Livello e slot aperti sono derivati.

**Casi limite**: classe del save sconosciuta (`Log.warn`, classe `character.start_class`); XP oltre il tetto troncata;
più livelli in un colpo (un evento per livello).

## 20. Tratti e abilità (M6)

### 20.1 Tratti (D4)
- Ogni tratto della classe si sblocca a un livello del personaggio (`unlock_level`). Se ne equipaggiano pochi: gli
  **slot** si aprono ai livelli `traits.slot_levels` (F-78, Q35). Tutti gli slot sono uguali; un tratto sta in un solo slot.
- Un tratto è una lista di **effetti tipizzati** (agganci del motore, §20.3; tipi in F-81) più, se serve, modificatori
  (sorgente `trait:<id>`). Un tratto solo di modificatori è vietato (sarebbe una stat).
- Si cambiano liberamente fuori dal combattimento o in `BETWEEN`, mai in `ENCOUNTER` (`combat_active`).
- Un tratto con `setups` vale solo con uno di quegli assetti (altrimenti resta equipaggiato ma spento).
- MVP: **12 tratti** costruiti sugli 8 tipi di effetto di F-81, con nomi e testi originali.

### 20.2 Abilità attive
- Slot: `abilities.slot_levels` (F-78, Q36: 2, il 3° al livello 30). Partono **da sole** quando la ricarica scade e c'è
  un bersaglio valido (F-79); ordine di slot a parità di istante (F-76).
- Tipi: `strike` (colpo pesante su un bersaglio), `cleave` (tutti o i primi N), `heal` (cura), `buff` (modificatori
  temporanei, sorgente `ability:<id>`) (F-80).
- La classe dell'MVP ha **6 abilità**: 2 per assetto (spadone, spada e scudo, due spade), con ruoli diversi (area o
  bersaglio singolo, difesa o attacco). Un'abilità non ammessa dall'assetto attuale resta equipaggiata ma spenta.
- Si cambiano con le stesse regole dei tratti. Dopo l'MVP: supporti da incastonare nelle abilità.

### 20.3 Agganci del motore
Eventi esposti: `on_encounter_start`, `on_before_attack`, `on_hit`, `on_kill`, `on_damaged`, `on_low_hp`,
`choose_target`, `modify_stats`. Ogni tipo di effetto è una classe in `systems/combat/effects/` che reagisce a uno o più
agganci con i parametri del dato; un tipo nuovo = una classe nuova e i suoi test; un tratto nuovo = solo dati.
Lo stato degli effetti (es. contatori di `every_nth_attack_all`) è nello stato salvato del combattimento.

**Casi limite**: slot non aperto (`slot_locked`); tratto non sbloccato dal livello (`level_too_low`); tratto già in un
altro slot (`requirement_not_met`); cambio in `ENCOUNTER` (`combat_active`); due tratti con `target_rule` (vale lo slot
più basso).

## 21. Armeria

**Regole**
- Ogni pezzo `equipment` o `tool` è un'**istanza** unica (`uid`, `base`, `rarity`, `ilvl`, `affixes`, `upgrade`,
  `sockets`, `locked`) nell'Armeria. Le istanze nascono da **drop** (§10.6, §24), **progetti** (§5.1) e **kit
  iniziale** (§1.1); i `uid` sono interi crescenti per slot di salvataggio, mai riusati. Gli attrezzi unici (§9) sono
  istanze di basi `tool` con `unique`: indossati dall'inizio, sempre nello slot, `upgrade` = +0…+9 (§23.1).
- Capienza: F-82 (`armory.base_slots` 40 + stat `armory_slots`); contano solo i pezzi non indossati. Armeria piena: il
  progetto non parte (`armory_full`), un drop si smantella (§25), l'acquisto di caselle non è toccato.
- Un pezzo **bloccato** non si smantella né si vende; un pezzo indossato non si smantella né si vende (`item_equipped`).
  Un attrezzo unico non si vende, non si smantella, non si toglie (`item_unique`).
- I pezzi si possono vendere (F-18 con il `value` della base; M4) e smantellare (M7, §25).
- Pagina Armeria: elenco filtrabile per slot e rarità, pannello del pezzo (rarità, affissi, raffinazione, requisiti,
  confronto con il pezzo indossato), equipaggia, blocca, vendi; da M7 raffina e smantella.

**Casi limite**: capienza sotto i pezzi presenti (non succede: le caselle comprate non si perdono; dal save si caricano
tutti i pezzi); `uid` duplicato o base sconosciuta nel save (`Log.warn`, pezzo scartato).

## 22. Rarità e affissi

- Rarità: `common` (0 affissi), `magic` (1-2), `rare` (3-4) (F-85); unici dopo l'MVP (Q29).
- Gli **affissi** (`data/affixes/affixes.json`) sono a **gradi** sbloccati da `ilvl`, solo su **stat del registro**;
  ogni affisso dice in quali slot può uscire. Gli attrezzi unici non hanno rarità né affissi (Q32 superata da R3).
- Rarità dei **progetti**: almeno magica, probabilità di raro che cresce con il livello del Fabbro (F-91, sostituisce
  F-83, sostituita). Rarità nei drop (M7): soglie per fonte (F-84). Entrambe × `(1 + item_rarity_pct/100)`. Il kit iniziale è comune.
- Anelli e amuleti: **solo da drop** (Q30, M7).

## 23. Raffinazione +0…+9 (M7)

Comando istantaneo dall'Armeria (Q31): costa oro, lingotti del grado e, da +6, frammenti del Rift; riuscita
decrescente (F-86). Fallimento: materiali persi; da +4 il pezzo scende di un livello; **mai distrutto** (Q27); il
Sigillo di salvaguardia evita la discesa. Moltiplica solo i modificatori base del pezzo. Massimo +9 (Q28).
**Casi limite**: pezzo a +9 (`upgrade_max`); materiali mancanti (`not_enough_items`, `not_enough_gold`); pezzo
indossato (si raffina; i modificatori si ricostruiscono). Vale per **armi e armature**; il livello del Fabbro dà un
bonus alla riuscita (stat `upgrade_success_pct` dalla sorgente `skill_level:forging`, F-93).

### 23.1 Raffinazione degli attrezzi (R3)
Comando istantaneo (`Armory.upgrade_tool`, F-94) per gli attrezzi unici (§9): **riesce sempre**, non fa mai scendere,
non usa Sigilli. Il freno è il costo: per ogni passo +0…+9 servono **componenti del grado del passo** (piastre del
Fabbro e manici del Falegname), **oro** e un **livello minimo del mestiere** dell'attrezzo (es. +4 richiede il
mestiere al livello 25). La tabella dei passi è in `02_FORMULAS.md` F-94. Ogni + dà `skill_interval_pct` con scope del
mestiere; ai passi alti anche un piccolo bonus di raccolta (`double_item_chance` o `rift_shard_chance`). Nessun
castone sugli attrezzi.

## 24. Pietre del Rift (M7)

Incontro speciale (stato `RIFTSTONE`): dopo un'uccisione c'è una probabilità, con garanzia dopo N uccisioni (F-87), che
il prossimo incontro sia la Pietra del Rift dell'area: molti PV, nessun attacco, un impulso periodico di danno, e
facoltativamente un gruppo evocato. Bottino: frammenti del Rift in quantità, materiali di raffinazione, pietre da
incastonare (M8), gioielli (rarità F-84).

- La Pietra in attesa si consuma al primo nuovo incontro (resta nel salvataggio finché non appare). Nell'incontro la
  Pietra viene per prima, poi l'eventuale gruppo evocato; l'incontro finisce solo con la morte di **tutti** i nemici.
- Le uccisioni durante l'attesa non contano per F-87; quelle della Pietra non contano mai.
- I pezzi dei drop hanno la rarità di F-84 (fonte `rift_stone` per la Pietra) e l'`ilvl` di F-85.

## 25. Smantellamento e filtro (M7)

- Smantellare un pezzo (non bloccato, non indossato) lo distrugge e restituisce **componenti** (piastre,
  impugnature, telai: quelli del progetto del pezzo, F-95) e frammenti. Anelli e amuleti restituiscono solo frammenti.
- **Filtro automatico** per slot di gioco: per ogni slot d'equipaggiamento rarità minima e grado minimo da tenere; i
  pezzi dei **drop** sotto il filtro si smantellano subito. Con l'Armeria piena un drop si smantella (nessuna perdita
  silenziosa: notifica e riepilogo offline). Obbligatorio per l'offline.

## 26. Castoni e valute del Rift (M8)

Castoni sui pezzi (F-89, da rarità e raffinazione); pietre incastonabili (categoria `stone`, con modificatori) da Pietre
del Rift e Legatura; tre valute (categoria `currency`, prodotte dalla Legatura): comune → magico, magico → raro (aggiunge
affissi fino al numero del raro), ritiro degli affissi (stessa rarità, F-85 di nuovo). Una pietra tolta da un castone si
distrugge (come le infusioni, Q8).
