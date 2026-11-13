# 01. Game Design Document

Ogni sistema ha: **regole**, **stati**, **casi limite** e **interazioni**. I numeri stanno in `02_FORMULAS.md` (citati
come `F-xx`); i parametri hanno un'unica definizione in `res://data/config/balance.json`; le stat dei modificatori
sono elencate in `res://data/config/stats.json` (sezione 15). Le firme dei metodi sono in `05_INTERFACES.md`.

Indice: 1 Slot e sessione · 2 Tempo di gioco · 3 Skill ed esperienza · 4 Azioni di raccolta (4.1 Aiutanti) · 5 Azioni di
artigianato · 6 Maestria · 7 Deposito (ex Bank) · 8 Oro e shop · 9 Equipaggiamento e attrezzi · 10 Combattimento a gruppi ·
11 Incisore e Altare del Rift (M8, M12) · 12 Progressione offline · 13 Feedback e notifiche · 14 Suggerimenti ·
15 Modificatori e stat · 16 Impostazioni · 17 Fratture del Rift come mappe (M13) · 18 Azioni in parallelo (eliminate, M12) ·
19 Personaggio e classe · 20 Tratti e abilità (M6) · 21 Armeria · 22 Rarità e affissi · 23 Raffinazione (M7) ·
24 Monoliti del Rift (M7) · 25 Smantellamento e filtro (M7) · 26 Castoni e valute del Rift (M8) · 27 Guida in gioco (M11) · 28 Equipaggiamento vero (M14) · 29 Ritocchi UI dell'Alpha · 30 Villaggio (M19) · 31 Bacheca e Mercato (M20)

Direzione del gioco da M4 (decisioni D1-D6 in `DECISIONS_LOG.md`): il **combattimento è il cuore** (gruppi di mostri,
bottino con rarità e affissi, potenziamento, build di tratti e abilità); raccolta e artigianato sono il ciclo di
supporto alla Melvor e producono ciò che serve al combattimento e al potenziamento.

Riforma del bottino e dei nomi da M10 (decisioni R1-R4 e B1-B5 in `DECISIONS_LOG.md`): l'**equipaggiamento è
fondamentale** e non si produce più in serie. I pezzi arrivano **dai mostri** (fonte principale), dal **kit iniziale** o da
un **singolo craft** (un progetto = un pezzo, §5.1). Le skill artigiane producono **componenti**; gli attrezzi di raccolta
sono **tre oggetti unici** potenziati con la raffinazione (§23.1). I nomi visibili seguono `NOMI.md` (gli **id** non
cambiano, Q52): in questo documento i nomi delle skill sono quelli di `00_VISION.md` e la UI dice "Deposito" dove qui
si legge "bank" (il modulo e gli id restano `bank`).

Riforma 2 da M12 (decisioni W1-W7 in `DECISIONS_LOG.md`, nomi in `NOMI.md`): un **Deposito unico** con **borse** (§7), gli **aiutanti** dei mestieri di raccolta al posto
delle corsie parallele (§4.1, §18), la **maestria per risorsa** con alberi diversi per mestiere (§6.4), l'**Incisore** che trasforma i drop dei mostri (§11) e i
**Monoliti del Rift** (§24). Il formato del salvataggio passa alla versione 4 (5 da M14).

---

## 1. Slot di salvataggio e sessione

**Regole**
- Ci sono 4 slot (`slots.count`). Ogni slot è una partita indipendente: **tutto** lo stato del giocatore (skill,
  maestria, personaggio e classe, tratti e abilità equipaggiati, Armeria e filtro, bank, oro, equipaggiamento, cibo
  scelto, azione in corso, combattimento in corso, acquisti dello shop, incavi dell'Altare, suggerimenti visti, fratture)
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
`character.start_class` (nell'MVP la scelta è fissa, §19), nessun tratto e nessuna abilità equipaggiati; Deposito vuoto con
capienza base e 6 slot borsa vuoti (nessuna borsa, nessun aiutante); oro `start.gold`; oggetti iniziali `start.items` (materiali e cibo, definiti in `balance.json`);
**kit iniziale** (R1, Q51): l'Armeria contiene i pezzi di `start.armory` (spada, spadone e scudo comuni di grado 1,
senza affissi) e i tre attrezzi unici a +0 di `start.tools`, che sono già indossati; l'Armeria ha il filtro "tieni
tutto"; spada e scudo sono indossati (assetto spada e scudo), lo spadone resta nell'Armeria; il Deposito contiene 20 pesci
cotti di grado 1 (`start.items`) e il cibo scelto è quello; acquisti dello shop di `start.purchases` (le Razioni da campo I, B2/Q12,
già possedute); nessuna azione in corso; incavi dell'Altare vuoti; seme casuale nuovo.

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
- L'ordine di aggiornamento in un passo è fisso: fratture (M13) → azioni → aiutanti (M12) → combattimento → tempo di gioco.
  Il combattimento è un motore a eventi (§10.10): salta da un timer all'altro, con lo stesso risultato del passo fisso.
- Il tempo di gioco (`play_time_ms`) cresce solo durante `PLAYING` (non durante l'offline, che ha il suo totale).

**Casi limite**: finestra ridotta a icona o gioco bloccato per alcuni secondi: il tempo accumulato si recupera nei
passi successivi fino a `max_catchup_ms` (5 s) per frame; oltre, il resto si scarta (evita la "spirale"). Pause lunghe
reali (computer in sospensione con il gioco aperto) sono trattate come offline al ritorno se superano
`offline_min_ms` (vedi sezione 12).

## 3. Skill ed esperienza

**Regole**
- 7 skill di supporto (tabella in `00_VISION.md`: 3 di raccolta, 3 di artigianato, Incisore), tutte
  disponibili dall'inizio. Le 5 skill di combattimento non esistono più: le sostituisce il **livello del personaggio**
  (§19, D3), che segue regole analoghe con la sua curva (F-71).
- L'esperienza è un intero cumulativo per skill. Il livello si ricava dall'XP con la tabella `F-01` (livelli 1-99).
  L'XP continua a crescere oltre il 99 fino a `xp_curve.xp_cap`, ma il livello resta 99.
- L'XP guadagnata passa sempre da `skill_xp_pct` (F-02).
- Salire di livello sblocca azioni, ricette, aree, incavi dell'Altare, equipaggiamento (requisiti nei dati).
- Ogni salita di livello emette `level_up` (anche più livelli in un colpo: un evento per livello).

**Stati**: per skill solo `xp`. Livello e progresso sono derivati, mai salvati.

**Casi limite**: XP negativa non ammessa (assert, ignorata); XP oltre il tetto troncata; salto di più livelli.

**Interazioni**: azioni, maestria, requisiti degli attrezzi (gli equipaggiamenti richiedono il livello del personaggio),
Altare del Rift. Il combattimento dà XP solo al personaggio (F-28).

## 4. Azioni di raccolta (Boscaiolo, Minatore, Pescatore)

**Regole**
- Ogni skill di raccolta ha una lista di azioni (es. "Betulla rossa") con: livello richiesto, intervallo
  base, XP, oggetto prodotto e quantità.
- Si avvia un'azione dalla pagina della skill; parte una barra di progresso. Alla fine dell'intervallo (F-03):
  1. si calcolano i prodotti: quantità base, raddoppiata se riesce il tiro `double_item_chance` (F-06);
  2. si tenta il frammento del Rift con probabilità F-07 (`rift_shard` ×1) e, se la maestria dell'azione ha raggiunto il traguardo 25, il sottoprodotto (F-103, §6.4);
  3. si aggiunge tutto alla bank; se un oggetto **nuovo** non trova posto, l'azione **non** conta (niente XP né
     maestria), si ferma con motivo `bank_full` e nulla va perso;
  4. si danno XP (F-02) e maestria (F-10);
  5. l'azione riparte da sola (ciclo infinito) finché il giocatore non la ferma.
- Una sola azione alla volta del giocatore (corsia principale): avviarne un'altra ferma la precedente; avviare il
  combattimento ferma l'azione; avviare un'azione ferma il combattimento. In parallelo lavorano solo gli **aiutanti** (§4.1).
- L'**attrezzo unico** della skill (slot `tool_<skill>`, §9, §23.1) dà modificatori alla skill (`skill_interval_pct`
  negativo e, ai passi alti della raffinazione, `double_item_chance` o `rift_shard_chance`).

**Stati**: corsia `IDLE` / `RUNNING(skill, action, elapsed_ms)`. `elapsed_ms` è salvato: ricaricando, la barra riprende.

**Casi limite**: livello insufficiente (non si avvia: `level_too_low`); dati mancanti (`unknown_id`); intervallo
ridotto sotto il minimo (`action.min_interval_ms`); cambio di attrezzo durante l'azione (vale dal ciclo successivo:
l'intervallo si ricalcola a ogni avvio di ciclo).

### 4.1 Aiutanti (M12, W3; F-101, F-102)

**Regole**
- Ogni mestiere di raccolta (Boscaiolo, Minatore, Pescatore) può avere **un aiutante**, che lavora **mentre il giocatore fa altro** (combatte, lavora un'altra azione, un progetto)
  e **anche offline**. Sostituiscono le corsie parallele (§18).
- Si ottiene con un **Contratto** (oggetto `category: contract`: mestiere e grado) che cade dai mostri (`02_FORMULAS.md` §8.5b). Usarlo (`hire`) assume l'aiutante di quel mestiere
  al grado del contratto e consuma il contratto. I gradi sono **Apprendista, Garzone, Esperto, Maestro**. Un contratto di grado più alto sostituisce quello attuale; uno di grado uguale o
  inferiore non si usa (`helper_not_better`, non si consuma).
- Un aiutante lavora **una risorsa già sbloccata** dal giocatore (livello del mestiere sufficiente), a scelta. Non usa l'attrezzo del giocatore; nodi, traguardi di maestria e
  rune valgono anche per lui.
- Produce **tutte le risorse** (doppio prodotto, Frammenti, sottoprodotti come il giocatore), ma solo il **25% dell'XP** e il 25% della maestria (F-102), ed è **più lento**: l'intervallo
  è il suo (F-101) × 3,0 / 2,5 / 2,0 / 1,5 per grado. I prodotti vanno nel Deposito; se non c'è posto per un oggetto nuovo l'aiutante **aspetta** (nessun progresso perso) e riparte da solo
  quando c'è spazio.
- Il bilanciamento (`tools/sim_combat.gd`, M12-07) verifica che combattere con tre aiutanti attivi non dia più XP di mestiere all'ora del lavorare di persona su un solo mestiere (F-102).
- UI: nella pagina del mestiere una riga "Aiutante: <grado> — lavora: <risorsa> [Cambia] [Ferma]".

**Stati**: per mestiere `{grado, azione, elapsed_ms}` (salvato nello slot, modulo `helpers`); `blocked` è derivato (Deposito pieno).

**Casi limite**: nessun aiutante (`no_helper` su `set_action`); risorsa non ancora sbloccata (`level_too_low`); non è un contratto (`not_a_contract`); risorsa di un altro mestiere
(`unknown_id`); Deposito pieno (attesa); cambio di risorsa (il progresso del ciclo riparte da 0).

**Interazioni**: Deposito (spazio), maestria (traguardi e nodi), skill (XP), modificatori (`for_helper`), offline (fase aiutanti del tick), Guida.

## 5. Azioni di artigianato (Fabbro, Cuoco, Falegname, Incisore)

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
  oggetti di bank (lingotti, **componenti**, cibo, rune, pietre, valute). Le ricette di armi, armature, scudi e
  attrezzi a gradi sono eliminate con le loro maestrie per azione.
- **Fabbro** (`forging`): minerale → lingotto; 2 lingotti → **piastra** (componente di grado, ricette in `02_FORMULAS.md` §8.2); inoltre le
  azioni a ciclo unico dei progetti (§5.1). **Falegname** (`woodwright`): legno → **impugnatura**, **telaio dello
  scudo**, **manico** (componenti di grado) e le **borse** di tela e rinforzata (§7). **Cuoco** (`hearthcraft`): pesce cotto, invariato. **Incisore** (`riftbinding`): trasforma
  i drop dei mostri (§11); le sue ricette consumano drop, tranne la Lastra runica.

### 5.1 Progetti: il craft singolo (R1)
> **M14 (Y4)**: il progetto crea un **Capolavoro** (§28.4): base propria, 1-2 affissi, statistiche +25%, costo circa 3× e due componenti rari diversi. I gradi dei pezzi sono 15; costo, durata e livello del Fabbro seguono il grado del materiale 1…8 (F-90, F-119). Dove il testo sotto dice "magica/rara" valgono F-91 (rivista) e F-119.
- Un **progetto** (`blueprint`) è un oggetto di bank (categoria `blueprint`) che indica la **base** da produrre (un
  modello di spada, spadone, scudo, elmo, corpo, gambe, piedi o mani) e il suo **grado**. Un progetto = un pezzo.
  Anelli e amuleti non hanno progetto (solo drop, Q30).
- Fonti dei progetti: **drop rari dei mostri** e **Monoliti del Rift** (più spesso), pesati sul grado dell'area
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
- Un solo lavoro alla volta (la corsia principale); gli aiutanti (§4.1) lavorano solo risorse di raccolta, mai progetti.

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
- I bonus della maestria per oggetto dell'**artigianato** sono definiti per skill (`mastery_bonuses` nel file della skill): ad es.
  "ogni 10 livelli +1 punto di `preservation_chance` per questa azione". Sono modificatori con ambito azione (F-11). Per la **raccolta** (M12) valgono invece i
  traguardi per risorsa (§6.4).
- Tutte le 7 skill hanno maestria; il livello del personaggio no (D3).

### 6.2 Pool della maestria
- Ogni skill con maestria ha un **pool**. Una quota di ogni guadagno di maestria (`mastery.pool_share_pct`, 20%) va
  anche nel pool (F-12), fino al tetto `items × mastery.pool_cap_per_item` (F-13). Oltre il tetto il surplus si perde
  (la UI avvisa quando il pool è al 95%).
- Il pool si spende in due modi:
  1. **alzare la maestria di un'azione**: 1 XP del pool = 1 XP di maestria (F-14); non oltre il livello 99;
  2. **comprare nodi** (6.3).

### 6.3 Nodi della maestria (differenza rispetto al modello di riferimento)
- Ogni skill con maestria ha un albero di 6-8 nodi (`data/mastery/<skill>.json`); dal M12 l'albero è **diverso per ogni mestiere di raccolta** (§6.4). Un nodo ha: costo in percentuale
  del tetto del pool (F-15), prerequisiti (altri nodi), modificatori con ambito skill.
- Comprare un nodo toglie il costo dal pool; il nodo è **permanente** (non si perde se il pool cala).
- Nessuna soglia del pool dà bonus: solo i nodi.

**Casi limite**: pool insufficiente (`pool_insufficient`); prerequisito mancante (`node_prereq_missing`); nodo già
comprato (`node_owned`); spesa che porterebbe la maestria oltre il 99 (si spende solo il necessario); importo ≤ 0
(`invalid_amount`).

**Interazioni**: azioni (guadagno), modificatori (bonus), UI pannello maestria.

### 6.4 Traguardi per risorsa (M12, W4; F-103, F-108)
- Ogni **risorsa di raccolta** (azione di Boscaiolo, Minatore, Pescatore) ha **3 traguardi** di maestria, raggiunti al livello di maestria **della risorsa**:
  - **25**: un **sottoprodotto raro** della risorsa (es. Betulla → Resina, Rame → Pepita, Trota → Squama), che esce con piccola probabilità a ogni ciclo e serve come componente per
    borse e progetti;
  - **50**: un bonus **solo per quella risorsa** (velocità o doppio prodotto o XP, a seconda del mestiere);
  - **99**: un bonus **permanente per tutto il mestiere**, piccolo e che **si somma tra le risorse**: padroneggiare anche le risorse basse conviene.
- I traguardi valgono anche per l'aiutante (§4.1). Il raggiungimento di un traguardo mostra un toast. Le skill di artigianato non hanno traguardi (restano i bonus per oggetto di F-11).
- Per le skill di raccolta i traguardi **sostituiscono** i vecchi bonus per oggetto ("ogni 10 livelli…"); i nomi delle azioni di raccolta sono solo il nome della risorsa ("Betulla").
- L'**albero dei nodi** (§6.3) è **diverso per ogni mestiere** di raccolta (stat e temi diversi; chiude Q26): vedi `02_FORMULAS.md` §8.8b.

### 6.5 Bonus ogni 10 livelli di maestria (M14, Y8, Q70; F-122)
Nell'Alpha la maestria deve essere **chiara e utile**. Vale per ogni azione con maestria di raccolta e di artigianato:
- ogni **10 livelli** di maestria **dell'azione** dà un bonus **visibile** di quell'azione (raccolta: −2% intervallo e +1% prodotto doppio; artigianato: +2% conservazione degli ingredienti e −2% intervallo), cumulativo fino a 9 volte (livello 99);
- i **traguardi** 25/50/99 restano (§6.4 per la raccolta, sottoprodotto, bonus della risorsa, bonus del mestiere) e si sommano; i vecchi bonus per oggetto dell'artigianato (F-11) sono sostituiti da questa regola;
- la **carta dell'azione** mostra il livello di maestria, i **bonus attuali** e il **prossimo** ("Al livello 40: −2% intervallo, +1% prodotto doppio");
- nei **progetti** del Fabbro il livello di maestria della ricetta di fusione del grado non cambia: la qualità dipende dal livello del Fabbro (F-91).

## 7. Deposito (ex Bank; M12, W1-W2)

**Regole**
- Il Deposito è l'**unico** contenitore degli oggetti posseduti (materiali, cibo, rune, pietre, valute, borse, contratti, progetti, componenti; esclusi la borsa del
  bottino e gli incavi dell'Altare) **, dei pezzi dell'Armeria** non indossati (§21) **e delle Carte della Frattura** (§17, M13). Ha **una sola capienza** (F-100) e **due schede**, Oggetti ed
  Equipaggiamento: sono solo una vista (i moduli `bank` e `armory` e gli id restano). L'inventario della pagina Equipaggiamento mostra gli stessi pezzi della scheda. **V10 (M16)**: i pezzi sono sempre visibili nel Deposito (sezione Pezzi) *e* la pagina Equipaggiamento mostra solo pezzi; entrambe sono viste di `Armory` (e `LootBag` per i pezzi non raccolti), nessuna copia dei dati.
  Un tipo di oggetto impilato occupa **una** casella (quantità illimitata, intero a 64 bit); un pezzo o una Carta occupa una casella come un tipo di oggetto.
- Capienza = `deposit.base_slots` (60) + le caselle delle borse negli **slot borsa** (`deposit.bag_slots` = 6, in cima al Deposito). Le caselle vuote sono visibili fino alla capienza.
- **Borse** (`category: bag`, `bag.slots`): oggetti che si mettono in uno slot e aggiungono le loro caselle. Sono: Borsa di tela +6 (ricetta del Falegname), Borsa di cuoio +10
  (drop delle Pianure e del Bosco), Borsa rinforzata +14 (ricetta del Falegname con sottoprodotti della maestria), Borsa del viandante +18 (drop raro delle Miniere), Borsa
  runica +24 (Monoliti); valori in `02_FORMULAS.md` §8.6b. Una borsa nello slot non occupa caselle. Si toglie dallo slot solo se le caselle in più sono vuote
  (`deposit_not_empty`, F-100); tornando nel Deposito occupa una casella.
- Spariscono "Spazio nel deposito" e "Spazio nell'armeria" dello shop; gli acquisti già fatti nei vecchi salvataggi non contano (salvataggi incompatibili, `format_version` 4).
- Aggiungere un oggetto già presente non occupa caselle; aggiungerne uno nuovo (o un pezzo) richiede una casella libera, altrimenti l'aggiunta fallisce (`bank_full` per gli
  oggetti, `armory_full` per i pezzi) e il chiamante decide cosa fare (le azioni e gli aiutanti si fermano o attendono, la borsa del bottino tiene l'oggetto, l'acquisto non avviene,
  un drop di pezzo si smantella, §25).
- Quando la quantità di un oggetto arriva a 0 la casella si libera.
- Ogni casella (oggetto o pezzo) può essere **bloccata**: un oggetto bloccato non si vende (né singolo né "vendi tutto").
- Ordine: quello di inserimento; il giocatore può spostare le caselle (trascinamento) o usare "Ordina" (per categoria, poi per `sort_order`).
- Dal pannello dell'oggetto: vendi (quantità con cursore, "tutti tranne 1", "tutti"), blocca, scegli come cibo, metti nello slot borsa (borse), assumi (contratti), incastona
  (rune). Si equipaggia dall'Armeria (§21).

**Casi limite**: capienza che scende sotto le caselle usate (non succede: la borsa non si toglie, `deposit_not_empty`; un salvataggio con più caselle usate della capienza si carica
comunque e blocca solo i nuovi ingressi); oggetto sconosciuto in un salvataggio (scartato, con avviso nel log); quantità ≤ 0 (rifiutata); borsa messa in uno slot occupato
(`bag_slot_occupied`); oggetto che non è una borsa (`not_a_bag`).

## 8. Oro e shop

**Regole**
- Unica valuta: **Oro** (`gold`, intero ≥ 0).
- Vendere: oro = `item.value × quantità` (F-18). Oggetti con `value = 0` non si vendono.
- Lo shop ha voci (`data/shop/shop.json`), per categoria:
  - ~~**Deposito**: "Spazio nel deposito" e "Spazio nell'armeria"~~: **tolti in M12** (W2); la capienza cresce con le borse (§7). La categoria `bank` esiste ma non ha voci;
  - **Combattimento**: "Razioni da campo I/II/III" (stat `auto_eat_tier`, una alla volta, in ordine; **le Razioni da
    campo I sono già possedute a partita nuova**, B2/Q12: `start.purchases`, la voce resta nei dati),
    "Raccolta automatica del bottino" (`auto_loot`), "Tasca della borsa" (+4 `loot_bag_slots`, max 3);
  - **Materiali**: oggetti base comprabili (es. sale, spago) a prezzo fisso;
  - ~~Attrezzi del novizio~~: tolti con la riforma (R3); gli attrezzi unici arrivano con il kit iniziale (§1.1). La
    categoria `tools` dello shop non esiste più;
  - ~~**Corsie** (M13): "Secondo pensiero"~~: tolta con le corsie parallele (§18).
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
- **M14**: le armi hanno danno minimo-massimo e velocità proprie (§28.2) e le armature Armatura e Barriera (§28.3). Un **attrezzo leggendario** (§28.5) sta nello slot `tool_*` al posto dell'attrezzo unico, che torna tra i pezzi non indossati (mai vendibile); si può rimettere quando si vuole (anche durante un incontro: gli attrezzi non contano per il combattimento).
- Durante un **incontro** si può cambiare tutto tranne arma e offhand (`combat_active`): l'assetto non cambia a metà
  incontro. Il cambio di armatura vale subito (le statistiche si ricalcolano).

## 10. Combattimento a gruppi

### 10.1 Struttura
- **Aree** (4 nell'MVP; 10 aree strette da M17, §10.15), ognuna con una lista di **gruppi** pesati (`packs`, 1..`combat.max_pack_size` mostri) e un
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
- Dal M12 (W6) si tirano anche le **tabelle di drop** (`data/combat/loot_tables.json`) dell'area, del mostro e del Monolito: Polvere del Rift, Schegge, Pietre, Cristalli,
  Contratti degli aiutanti e borse (§7, §11, `02_FORMULAS.md` §8.5b). Vanno nella borsa del bottino come ogni altro oggetto.
- **M14 (Y6, F-121)**: i pezzi di equipaggiamento e i progetti non sono più voci fisse dei mostri: ogni uccisione tira il **pool** di §28.6 (tutti gli slot del grado vicino al livello del mostro). I leggendari non cadono dai mostri comuni (§28.5).
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

### 10.13 Combattimento affollato (M15, Z6)
Con più di `combat.crowd_threshold` nemici in campo (8) la zona nemici passa alla **vista compatta**: il Monolito fisso in alto con barra dei PV e **tacche** a 75/50/25; i mostri **raggruppati per tipo** ("Lupo del Bosco ×7") con la barra dei PV
del bersaglio e il conteggio; elenco scorrevole; nessuna carta per nemico. Numeri dei colpi e registro **aggregati** (un numero per tipo per tick). Solo vista: lo stato resta nel motore.

### 10.14 Bottino con i pezzi (M15, Z1)
Un pezzo di equipaggiamento che cade (da mostro o Monolito, fuori dalla Frattura) finisce nel **Bottino**, non più direttamente nell'Armeria. "Raccogli tutto" lo sposta nel Deposito (§7), dove compare nella sezione **Pezzi**; la pagina
Equipaggiamento mostra **solo** i pezzi. Un pezzo nel Bottino non è indossabile. Con la tasca del Bottino automatico (`auto_loot`, §7) il pezzo va subito nel Deposito. Il filtro (§25) agisce **al collect**, non alla caduta (il pezzo scartato è smantellato quando viene raccolto). Nessun limite di pezzi nel Bottino e nessun `loot_lost` per Bottino pieno; la morte perde tutto il Bottino, pezzi compresi. Offline i pezzi sono messi al sicuro nell'Armeria a ogni blocco da 60 s, mentre online la morte li perde (Q83 aperta). La fonte di verità resta una (Armeria, F-100): il Bottino tiene i pezzi in attesa, la UI non copia dati.
Nella Frattura non cambia (il sacco della Frattura tiene già i pezzi, F-116). Aperto: caselle del Bottino e del Deposito (Q80, Q81).

### 10.15 Precisione, XP per livello, aree strette, gruppi 1-8 (M16-M18, V1-V4, V11; numeri fissati in M17-01)
- **Precisione visibile (V1)**: nella pagina Combattimento si mostra la % di colpire del giocatore sul bersaglio e quella di ogni nemico sul giocatore, intera (F-129 = la probabilità di F-23, tetti 5% e 95%).
- **XP per differenza di livello (V2)**: l'XP di un'uccisione (§10.4) è moltiplicata per un fattore che dipende da livello del mostro meno livello del personaggio (F-130): zero a 9 o più livelli sotto, cala fino a 1 alla pari, sale del 5% per livello
  fino a +50% (10 livelli sopra). Il livello del mostro è il più alto dei suoi tre livelli; nella Frattura il fattore non si applica. L'XP base del mostro dipende dal suo livello (80 × 1,065^(L−1), generata, mai scritta a mano).
- **Aree strette (V3)**: **10 aree** di circa 10 livelli (1-10, 11-20, … 81-90, 91-99), contigue e senza buchi; ognuna ha almeno 4 mostri propri e gruppi propri; si sblocca al suo livello minimo. La scelta dell'area è una **mappa cliccabile**
  (non più un menu; ogni area ha una posizione `map_pos`). I Monoliti (§24b) seguono i livelli della nuova area (Z2): multipli di 5 tra il suo minimo e il suo massimo.
- **Gruppi (V4)**: 1-8 nemici (`combat.max_pack_size` = 8). Distribuzione per dimensione `[4, 12, 22, 26, 18, 10, 5, 3]` %: il singolo (4%) e gli otto (3%) sono rari, la media è 4,07 (ammessa 3-5 per area).
- **Evocati dei Monoliti (V11)**: droppano poco (riduzione in `balance.json`, valore in M17-06); restano senza XP (Z3).
- Il drop di equipaggiamento (V5) non cambia finché M17-02 non ne misura il tasso reale.
- **Effetti collaterali da gestire in M17**: gli id delle 4 aree vecchie spariscono (migrazione dello slot: area corrente → area nuova che contiene il livello del personaggio, M17-04); i Monoliti e le Fratture che citano le aree
  vecchie si riallineano; il limite del validatore sui gruppi passa da 6 a 8 (`05_INTERFACES.md`, nota sul validatore, già aggiornata).

## 11. Incisore e Altare del Rift (M8; riscritta in M12, W5-W6)

**Regole**
- **Frammenti del Rift** (`rift_shard`): cadono con piccola probabilità dalle azioni di raccolta e dai mostri (F-07), in quantità dai Monoliti (§24) e dallo
  smantellamento (§25). Servono anche alla raffinazione da +6 (§23) e alla Lastra runica.
- L'**Incisore** (`riftbinding`, era Legatura del Rift) è una skill di artigianato (con maestria) che **non crea dal nulla: trasforma i drop dei mostri**.
  Sale di livello **consumando drop** (più l'azione base). Pietre, valute e materia grezza cadono dai mostri e dai Monoliti (§10.6, `02_FORMULAS.md` §8.5b); le valute
  cadono anche già pronte (rare). Non esiste più la produzione di valute e pietre da soli frammenti e materiali di raccolta.
- **Drop dell'Incisore**: **Polvere del Rift** (comune), **Schegge** delle pietre (4 famiglie: di forza, di precisione, di agilità, di tempra), raramente Pietre intere,
  raramente **Cristalli** già pronti (del risveglio, dell'ascesa, del mutamento: gli effetti di §26).
- **Azioni** (`02_FORMULAS.md` §8.7):
  - **Lastra runica** (base, sempre disponibile): minerale di grado 1 del Minatore + Frammenti del Rift; poca XP; serve per le rune.
  - **Fondere**: 3 Schegge → 1 Pietra; 3 Pietre → 1 Pietra perfetta (stessa famiglia), F-105.
  - **Cristallizzare**: Polvere del Rift → un Cristallo con probabilità che cresce con il livello dell'Incisore (40% → 90%); se fallisce si perde metà della Polvere (F-104).
  - **Incidere una runa**: 1 Lastra runica + 3 drop del mostro tematico → Runa di grado I (livello richiesto per runa).
  - **Potenziare una runa**: 3 rune di grado N → 1 di grado N+1, fino al grado V (F-106). L'effetto cresce con il grado (F-107).
- **Altare del Rift**: 5 incavi, sbloccati ai livelli dell'Incisore `rift.sockets[].level` (1, 20, 40, 60, 80). Incastonare una runa la toglie dal Deposito (1 pezzo) e attiva i suoi
  modificatori (sorgente `rift_socket:<i>`). Togliere una runa dall'incavo la **distrugge** (le rune sono un consumo; conferma nella UI). Una stessa runa può stare in più incavi
  (i modificatori si sommano), salvo `unique: true`; rune di gradi diversi della stessa famiglia sono oggetti diversi.

**Casi limite**: incavo non sbloccato (`socket_locked`); incavo occupato (`socket_occupied`); oggetto non runa (`not_equippable`); runa unica già incastonata
(`requirement_not_met`); ingredienti mancanti (`missing_inputs`); Deposito senza posto per un prodotto nuovo (`bank_full`, l'azione si ferma).

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
- Un progetto in corso (§5.1) avanza anche offline e può finire durante l'assenza. Gli **aiutanti** (§4.1) lavorano anche offline (fase `_PHASE_HELPERS` dello stesso motore).
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
  assetto, tratti, buff delle abilità (temporanei), maestria (per oggetto dell'artigianato, traguardi per risorsa e del mestiere, M12), nodi della maestria, shop, incavi dell'Altare,
  fratture (M13). Il contesto dell'aiutante esclude la sorgente dell'attrezzo del giocatore (`ModifierContext.for_helper`).
- Il valore finale di una stat in un contesto è la **somma** dei modificatori applicabili, limitata da `min`/`max`
  della stat (F-05). Ogni formula dice come usa la stat.
- I modificatori **non si salvano**: si ricostruiscono dallo stato salvato (cosa è indossato, quali nodi, quanti
  acquisti, cosa è incastonato) a ogni caricamento.
- Ogni stat esiste in `stats.json` con: effetto, formula di `02_FORMULAS.md`, test GUT. Una stat senza effetto non può
  esistere; un modificatore su una stat sconosciuta fa fallire la validazione dei dati.

Elenco delle stat dell'MVP (dettagli in `02_FORMULAS.md` §11):
`skill_interval_pct`, `skill_xp_pct`, `mastery_xp_pct`, `double_item_chance`, `preservation_chance`,
`rift_shard_chance`, `accuracy_bonus`, `accuracy_pct`, `power_bonus`, `power_pct`, `evasion_bonus`,
`evasion_pct`, `damage_reduction`, `attack_interval_pct`, `max_hp_flat`, `food_healing_pct`, `gold_drop_pct`,
`loot_bag_slots`, `auto_loot`, `auto_eat_tier`, `item_rarity_pct` (M4), `block_chance` (M5),
`upgrade_success_pct` (M7). Tolta la stat `fracture_duration_pct` (R-04: le Fratture non hanno più durata); M13 non aggiunge stat (i modificatori delle Carte usano stat esistenti e tipi del motore, F-111). Tolte in M12: `bank_slots`, `armory_slots` (capienza dalle borse), `parallel_lanes` (corsie eliminate).
Gli effetti dei tratti che non sono somme di stat (es. "evasione a 0") non sono stat: sono tipi di effetto (F-81).

## 16. Impostazioni

Globali (non per slot, perché non sono stato di gioco): modalità finestra, dimensione, scala UI, VSync, limite FPS,
volume, livello dei log. File `user://settings.cfg`. Pannello dal menu e in partita (Esc).

## 17. Fratture del Rift come mappe (M13; decisioni X1-X4)

Una **Frattura** è un'incursione che il giocatore apre **quando vuole** consumando una **Carta della Frattura**: N gruppi di mostri scalati per grado, poi un boss. Non esistono più aperture casuali o a tempo (la vecchia
Frattura ogni 2-4 ore è eliminata: niente `fractures.interval_*`, `duration_ms`, stat `fracture_duration_pct`, modificatori globali di sessione). Idea delle mappe dei giochi d'azione adattata a un idle; nomi e numeri originali.

### 17.1 La Carta
- Oggetto di categoria `map` (`04_DATA_SCHEMA.md` §11), **un'istanza** come i pezzi (`uid`, grado, rarità, modificatori), custodita dal `CardStore` (`05_INTERFACES.md` §5.23). Una casella del Deposito ciascuna (occupante `cards`, F-100); non è
  impilabile né vendibile. Non si può avere una Carta nella Bank.
- **Grado 1-10.** **Rarità** come i pezzi: comune (0 modificatori), magica (1-2), rara (3-4) (F-109).
- **Fonti**: drop dei mostri delle aree e dei Monoliti (gradi bassi, dalle tabelle di drop, F-32; il grado dipende dall'area), **Fratture** (stesso grado o +1, raramente +2; il boss con alta probabilità, F-113). Le Carte di grado più alto cadono
  soprattutto dalle Fratture (X2). Una Carta caduta con il Deposito pieno si perde (`card_rejected`, notifica, riepilogo offline), come un pezzo che non entra.
- **Modificatori** (`data/maps/map_mods.json`): ognuno ha un **rischio** (cambia i mostri o il giocatore dentro la Frattura) e un **premio** (aumenta il bottino), con la stessa intensità (F-109). I tipi di rischio e di premio sono un elenco chiuso del motore
  (F-111), non stat nuove. Le stat esistenti si applicano al giocatore con sorgente `fracture:<uid>` solo mentre la Frattura è in corso. Esempi di partenza: Mostri robusti (+PV; più quantità), Assalto (mostri più rapidi; più rarità), Fame (il cibo cura
  meno; più progetti), Orde (gruppi più numerosi; più XP), Impulsi (danno periodico come i Monoliti; più Polvere del Rift). I modificatori più forti hanno `min_grade` alto.
- **Tetto ai rischi (M14, Q72, F-123)**: la somma dei punti di rischio dei modificatori non supera 40 al grado 1, più 10 per grado; se un modificatore sforerebbe, la sua intensità si riduce (e il premio con lei). Una Carta rara di grado basso non è più punitiva.
- I **Cristalli** funzionano anche sulle Carte (stessi tre effetti dei pezzi, §26): risveglio (comune → magica), ascesa (magica → rara), mutamento (rifà i modificatori). Lo **smantellamento** di una Carta dà Polvere del Rift (F-114).
  Una Carta si **blocca** (non si smantella per errore) come un pezzo.

### 17.2 La Frattura
- Si apre dalla pagina **Fratture** ("Apri") sulla Carta scelta: la Carta si **consuma subito**. Il combattimento normale si ferma e l'azione del giocatore pure (`replaced`); gli **aiutanti continuano**. Una sola Frattura alla volta.
  Non si apre se il Deposito non può ricevere il bottino di una Frattura precedente ancora in attesa (`fracture_bag_pending`).
- **Contenuto**: `fracture.groups` (16, Q63) gruppi di mostri del grado (F-110: mostri delle aree del grado, scalati), uno dopo l'altro come gli incontri di un'area (stesso motore a eventi, `combat.respawn_ms` tra un gruppo e l'altro, stesso triangolo, tratti,
  abilità e cibo), poi il **boss** (§17.3). I modificatori della Carta si applicano a mostri, giocatore e ricompense (F-111). Nei gruppi della Frattura **non appaiono Monoliti** e non si contano uccisioni per F-87.
- **Bottino della Frattura**: tutto quello che cade dentro (oggetti, pezzi, Carte; l'oro invece va nel portafoglio subito, non è a rischio) va nella **borsa della Frattura**, separata dalla borsa del bottino e dal Deposito, senza limite di caselle. XP del
  personaggio e livelli si guadagnano subito e non si perdono.
  - **Vittoria sul boss**: la borsa passa al Deposito (oggetti nella Bank, pezzi nell'Armeria con il filtro automatico, Carte nel `CardStore`) più le ricompense garantite del boss (§17.3). Ciò che non entra per mancanza di caselle resta **in attesa** nella borsa della Frattura finché
    il giocatore non fa spazio e preme "Raccogli" (`collect`); finché c'è qualcosa in attesa non si apre un'altra Frattura.
  - **Morte** (X4): si perdono la Carta (già consumata) e **tutta la borsa della Frattura** (`fracture_loot_lost`); Deposito ed equipaggiamento non si toccano; i PV tornano al massimo.
  - **Abbandona** (comando del giocatore, con conferma): come la morte.
- Dopo la fine (vittoria, morte, abbandono dal comando "Abbandona") il combattimento torna all'**area in cui il giocatore stava combattendo** prima di aprire la Frattura (se combatteva), con la sua borsa del bottino com'era; altrimenti resta fermo. L'azione del giocatore non riparte.
- **Stato salvato**: la Frattura in corso (Carta, gruppo, boss, borsa, contatori) e l'eventuale borsa in attesa sono nello slot (`fractures`); ricaricando, la Frattura riprende dallo stesso punto.
- Funziona **anche offline**, con lo stesso motore a eventi (§10.10): una Frattura può iniziare e finire durante l'assenza (online non parte da sola: è sempre già in corso al momento dell'uscita). Se finisce, il combattimento torna all'area (sopra) e
  prosegue. Il riepilogo "Mentre eri via…" dice per ogni Frattura grado, esito (vinta, persa per morte), gruppi superati, Carte e pezzi ottenuti o persi.

### 17.3 Il boss
- Un boss per grado (10), definito in `data/maps/bosses.json`: un mostro grande (PV e danni molto sopra i mostri del grado) con **una abilità propria** semplice, di un elenco chiuso (F-112): colpo pesante a intervalli, scudo temporaneo, evocazione di un piccolo
  gruppo. **Nessuna meccanica a fasi** in M13.
- **Ricompense garantite** (alla vittoria): un pezzo almeno magico (F-84 con rarità minima magica, `ilvl` di F-110), Polvere del Rift (`fracture.boss.dust`), e la probabilità di una Carta di grado +1 (F-113). Più i drop del boss, che entrano nella borsa come quelli dei mostri.
- Il boss non dà Monoliti, non fa parte dei gruppi, ha il proprio incontro (stato `ENCOUNTER` con il solo boss, più gli evocati).
- Boss ed evocati **non contano nelle uccisioni** (`kills`, F-87) e i **Monoliti sono sospesi** per tutta la Frattura. Lo **scudo** del boss si rinnova solo quando è esaurito; l'**evocazione** non supera mai `max_alive` evocati vivi. Il ritorno all'area alla fine è **differito a fine istante** (dopo l'evento che ha chiuso la Frattura).

### 17.4 Scala e bilanciamento
- Grado 1 ≈ difficoltà delle Miniere; grado 10 ≈ ben oltre la Soglia (fine gioco). Il livello degli oggetti caduti (`ilvl`) cresce con il grado: le Fratture diventano la fonte dei pezzi migliori.
- Obiettivo (sim, M13-06): un personaggio ben equipaggiato del livello consigliato completa una Frattura in **15-30 minuti** e ottiene in media **~1 Carta di grado uguale o superiore** per Frattura (la scala non si interrompe; i gradi alti si raggiungono solo
  migliorando il personaggio). Numeri di partenza in `02_FORMULAS.md` §7, da tarare (Q64).

### 17.5 Casi limite
Carta bloccata o sconosciuta (`unknown_id`, `item_locked` per smantellare); aprire con una Frattura già in corso (`fracture_active`); Deposito pieno alla consegna (attesa, non perdita); morte nello stesso istante in cui muore il boss (vale F-76: se il giocatore uccide
per primo la Frattura è vinta); `stop` del combattimento durante la Frattura (= abbandono, ma **non** riporta all'area: il combattimento resta fermo; solo `abandon_fracture` e le fini naturali riportano all'area, scelta approvata); un tratto/abilità non si cambia durante la Frattura (`combat_active`); caricamento di un salvataggio con Frattura in corso (riprende); Carta con un modificatore o un grado sconosciuto nel
salvataggio (scartata con `Log.warn`; se era la Frattura in corso, la Frattura termina come abbandonata, senza bottino).

## 18. Azioni in parallelo — ELIMINATE (M12, W3)

Le corsie parallele (stat `parallel_lanes`, voce "Secondo pensiero", F-51) **non esistono più**: le sostituiscono gli **aiutanti** (§4.1). Il combattimento e le azioni
del giocatore restano in una sola corsia (`main`).

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
- Capienza: **unica con il Deposito** (§7, F-100, M12); i pezzi non indossati occupano una casella ciascuno, quelli indossati nessuna. Deposito pieno: il
  progetto non parte (`armory_full`), un drop si smantella (§25).
- Un pezzo **bloccato** non si smantella né si vende; un pezzo indossato non si smantella né si vende (`item_equipped`).
  Un attrezzo unico non si vende, non si smantella, non si toglie (`item_unique`).
- I pezzi si possono vendere (F-18 con il `value` della base; M4) e smantellare (M7, §25).
- Pagina Armeria: elenco filtrabile per slot e rarità, pannello del pezzo (rarità, affissi, raffinazione, requisiti,
  confronto con il pezzo indossato), equipaggia, blocca, vendi; da M7 raffina e smantella.

**Casi limite**: capienza sotto i pezzi presenti (non succede: le caselle comprate non si perdono; dal save si caricano
tutti i pezzi); `uid` duplicato o base sconosciuta nel save (`Log.warn`, pezzo scartato).

## 22. Rarità e affissi

- Rarità: `common` (0 affissi), `magic` (1-2), `rare` (3-4) (F-85); da M14 anche `masterwork` (Capolavoro, 1-2 affissi, solo progetti) e `legendary` (leggendario, nessun affisso, effetto unico) (§28.4, F-119, F-120).
- Gli **affissi** (`data/affixes/affixes.json`) sono a **gradi** sbloccati da `ilvl`, solo su **stat del registro**;
  ogni affisso dice in quali slot può uscire. Gli attrezzi unici non hanno rarità né affissi (Q32 superata da R3).
- Rarità dei **progetti**: sempre Capolavoro (M14); cresce con il livello del Fabbro la probabilità di avere 2 affissi invece di 1 (F-91 rivista; era: almeno magica, probabilità di raro; sostituisce
  F-83, sostituita). Rarità nei drop (M7): soglie per fonte (F-84). I drop × `(1 + item_rarity_pct/100)`. Il kit iniziale è comune.
- Anelli e amuleti: **solo da drop** (Q30, M7).

- **Nomi degli affissi (V8, M16-07)**: i testi di tutti gli affissi sono in stile Path of Exile, in italiano ("+X alla Vita massima"); solo `name`/testi, id, stat e valori invariati.

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

## 24. Monoliti del Rift (M7; ex "Pietre del Rift", nome visibile cambiato in M12/W7, id e stato `RIFTSTONE` invariati)

Incontro speciale: dopo un'uccisione c'è una probabilità, con garanzia dopo N uccisioni (F-87), che
il prossimo incontro sia il Monolito del Rift dell'area (il termine "Pietra" resta alle pietre dei castoni): molti PV, nessun attacco, un impulso periodico di danno, e
facoltativamente un gruppo evocato. Bottino: frammenti del Rift in quantità, materiali di raffinazione, gioielli (rarità F-84) e, dal M12, la **tabella dei Monoliti** (Polvere in quantità, Schegge, Pietre, Cristalli, Borsa runica,
Contratti; `02_FORMULAS.md` §8.5b).

- La Pietra in attesa si consuma al primo nuovo incontro (resta nel salvataggio finché non appare). Nell'incontro la
  Pietra viene per prima, poi l'eventuale gruppo evocato; l'incontro finisce solo con la morte di **tutti** i nemici.
- Le uccisioni durante l'attesa non contano per F-87; quelle della Pietra non contano mai.
- I pezzi dei drop hanno la rarità di F-84 (fonte `rift_stone` per la Pietra) e l'`ilvl` di F-85.

## 24b. Monoliti da Metin (M15; decisioni Z1-Z9, R-06)

Dal M15 il Monolito è un incontro "a ondate" (idea ispirata alle pietre di Metin2, solo come meccanica; nomi e numeri originali). Nome e id (`rift_stone`) restano.
- **Livelli (Z2)**: un tipo di Monolito ogni 5 livelli (5, 10, 15…). Il **pool** di un'area sono i multipli di 5 tra il suo livello minimo (arrotondato per eccesso a 5, almeno 5) e il suo livello massimo (= minimo dell'area
  dopo − 1; ultima area: tetto del personaggio, 99), compreso sempre il multiplo di 5 più alto sotto il massimo. Pianure (1-15): 5, 10, 15 (anche al livello 1); Bosco (16-37): 20…35; Miniere (38-64): 40…60; Soglia (65-99): 65…95.
  Quando appare un Monolito (F-87, invariata) se ne sceglie uno del pool con uguale probabilità.
- **Comportamento (Z3)**: PV molti (F-125), nessun danno vero: ogni `pulse_ms` infligge **1 danno fisso** che ignora Armatura e Barriera (e non si para). Al **primo colpo ricevuto** e quando i PV scendono sotto **75%, 50%, 25%**
  evoca un gruppo di mostri dell'area, al livello del Monolito (F-126). Gli evocati attaccano come gli altri ma non danno XP, oro né drop (come i richiami del boss); il Monolito sì. In campo possono esserci 30 mostri o più: vale
  la vista compatta (§10.13). L'incontro finisce solo con la morte di tutti i nemici (invariato).
- **Bottino (Z4, F-127)**: Frammenti (F-87), **un tiro garantito di equipaggiamento** con rarità aumentata e un tiro di Progetto; i valori stanno nei dati e in `balance.json`. Frequenza (Z5): resta F-87; le Pianure passano
  a una probabilità > 0 (default 0,6 come il Bosco), tarata da QA.
- **Salto (Z7, F-128)**: impostazione nella pagina Combattimento, "Salta i Monoliti fino al livello X" (0 = disattivato). Un Monolito di livello ≤ X è scartato prima dell'incontro: non si combatte, non conta come uccisione,
  `since` si azzera e si estrae il gruppo successivo. È stato dello **slot**, non delle impostazioni (`user://settings.cfg`).
- **Miniboss (Z8)**: rimandati in M15; fissati in M22 (§33.1, F-139): uno per area, incontro a sé tirato dopo ogni incontro normale.

## 25. Smantellamento e filtro (M7)

- Smantellare un pezzo (non bloccato, non indossato) lo distrugge e restituisce **componenti** (piastre,
  impugnature, telai: quelli del progetto del pezzo, F-95) e frammenti. Anelli e amuleti restituiscono solo frammenti.
- **Filtro automatico** per slot di gioco: per ogni slot d'equipaggiamento rarità minima e grado minimo da tenere; i
  pezzi dei **drop** sotto il filtro si smantellano subito. Con l'Armeria piena un drop si smantella (nessuna perdita
  silenziosa: notifica e riepilogo offline). Obbligatorio per l'offline.

## 26. Castoni e valute del Rift (M8)

Castoni sui pezzi (F-89, da rarità e raffinazione); pietre incastonabili (categoria `stone`, con modificatori; famiglie di forza, di precisione, di agilità, di tempra; gradi Scheggia → Pietra →
Pietra perfetta) che **cadono dai mostri e dai Monoliti** e si migliorano con Fondere dell'Incisore (F-105); tre valute (categoria `currency`), che **cadono dai mostri** o si ottengono
con Cristallizzare (F-104): Cristallo del risveglio (comune → magico), Cristallo dell'ascesa (magico → raro, aggiunge affissi fino al numero del raro), Cristallo del mutamento (ritira gli affissi, stessa rarità, F-85 di nuovo). Una pietra tolta da un castone si
distrugge (come le rune, Q8).

## 27. Guida in gioco (M11)

Decisioni G1-G2 (`DECISIONS_LOG.md`): la wiki sta **dentro il gioco** (pagina "Guida") e arriva **prima delle mappe**. Ispirata alla
**struttura** delle wiki dei giochi idle (pagina per mestiere, oggetto, mostro, meccanica), mai ai testi.

**Principi**
- **Generata dai dati**: tabelle, drop, ricette, statistiche e numeri si leggono da `data/`, `balance.json` e `stats.json` a ogni apertura.
  Nessun numero ricopiato nei testi: un testo cita un valore con un segnaposto che la Guida sostituisce (`04_DATA_SCHEMA.md` §19).
- **A mano** solo i testi delle meccaniche e dei primi passi (`data/guide/*.json`, in italiano, al massimo ~150 parole per pagina di meccanica).
- Logica separata dalla UI: l'indice "da dove viene / a cosa serve" è una classe testata (`05_INTERFACES.md` §5.19).
- Ogni oggetto, mostro, area, mestiere, stat, tratto e abilità ha **la sua pagina**.

**Struttura** (pagina nella sidebar, sezione Partita: indice a sinistra, contenuto a destra, ricerca in alto, cronologia "indietro")

| Sezione | Pagine | Origine |
|---|---|---|
| Primi passi | la prima ora: combattere, mangiare, raccogliere il bottino, equipaggiare, i mestieri | testo a mano |
| Personaggio e combattimento | livello, assetti, triangolo, tratti, abilità, cibo e Razioni, morte e borsa del bottino, gruppi e bersaglio | testo a mano + tabelle dai dati (tratti, abilità con sblocco e ricarica) |
| Bottino | rarità, affissi (tabella dei gradi), raffinazione (costi e probabilità), castoni e pietre, valute, smantellamento e filtro, Monoliti del Rift, progetti | testo a mano + tabelle dai dati |
| Mestieri | una pagina per mestiere: cosa fa, tabella delle azioni (livello, XP, durata, ingredienti, prodotto), maestria e nodi, attrezzo e raffinazione | testo breve a mano + tabelle dai dati |
| Oggetti | descrizione, valore, **Si ottiene da** (mostri con area e %, ricette, shop, Pietre, smantellamento, kit iniziale; **solo dopo la scoperta**, M14), **Serve a** (ricette, progetti, raffinazione, castoni, Altare, cibo) | tutto dai dati |
| Mostri e aree | area: livello richiesto, gruppi, mostri; mostro: statistiche, stile, intervallo, **tutto ciò che può dare** (caselle bloccate fino alla scoperta, M14) | tutto dai dati |
| Altare del Rift | incavi, livelli di sblocco, rune con effetto e gradi | dai dati + testo breve |
| Deposito e borse (M12) | capienza unica, slot borsa, tabella delle borse | testo a mano + tabella `bags` |
| Aiutanti (M12) | contratti, gradi (tabella `helper_grades`), XP e velocità, Deposito pieno | testo a mano + tabella dai dati |
| Maestria per risorsa (M12) | traguardi 25/50/99 di ogni risorsa (tabella `mastery_milestones:<skill>`), alberi dei nodi | testo a mano + tabelle dai dati |
| Incisore (M12) | azioni e ricette (tabella `engraver_recipes`), probabilità di Cristallizzare, gradi delle rune, Monoliti del Rift | testo a mano + tabelle dai dati |
| Statistiche | glossario: nome, descrizione, limiti (da `stats.json`) | dai dati |
| Offline | come funziona, limite di ore, cosa prosegue e cosa no | testo a mano con segnaposto |

Testi a mano (≈ 25 pagine brevi; dal M12 anche Deposito e borse, Aiutanti, Maestria per risorsa, Incisore, Monoliti del Rift): Primi passi; Livello del personaggio; Assetti; Triangolo; Tratti; Abilità; Cibo e Razioni; Morte;
Gruppi e bersaglio; Rarità e affissi; Raffinazione; Castoni e pietre; Valute; Smantellamento e filtro; Monoliti del Rift; Progetti;
Maestria; Attrezzi; Altare del Rift; Offline.

**Collegamenti, "?" e tooltip**
- Ogni nome di oggetto, mostro, area, mestiere, stat, tratto o abilità nella Guida è un **collegamento** che apre la sua pagina.
- **Pulsante "?"** nell'intestazione di ogni pagina del gioco (Combattimento, Equipaggiamento, Personaggio, Altare, Deposito, Shop, pagine
  dei mestieri): apre la pagina di Guida pertinente.
- **Tooltip degli oggetti** (M14, Y7): una riga in fondo, "Serve a: …" (al massimo 3 voci, poi "e altro"), dallo stesso indice della Guida. **Non** dice più da dove si ottiene l'oggetto: la fonte si scopre (§27.1).
- **Tooltip delle stat** (personaggio ed equipaggiamento): la descrizione da `stats.json`.

**Accettazione**
- La Guida si apre dalla sidebar; ricerca per nome; ogni nome è un collegamento; "indietro" funziona.
- Ogni entità elencata sopra ha la sua pagina; ogni oggetto **scoperto** (§27.1) mostra "Si ottiene da" e "Serve a"; un oggetto senza fonte o senza uso è
  segnalato dal test, salvo eccezioni dichiarate nei dati.
- Nessun numero scritto a mano nei testi (solo segnaposto); nessun segnaposto o collegamento non risolto.
- Ogni pagina del gioco ha il suo "?". Nomi da `NOMI.md`. Layout a 1600×900 e 1280×720.
- Nessuno stato di gioco nella Guida: legge i dati e (M14) l'insieme delle scoperte, che sta nel modello e nel salvataggio dello slot (§27.1).

### 27.1 Guida a scoperta (M14, Y7; F-124)
- Nuovo stato **per slot**: le **scoperte** (`discoveries.items`, `05_INTERFACES.md` §5.24), cioè gli oggetti ottenuti almeno una volta. Si riempie da solo (segnale `item_obtained`), anche offline e con il kit iniziale; non si perde mai.
- Un oggetto **non ancora ottenuto** appare nella Guida come **casella bloccata** ("???", icona in ombra) e non ha pagina. La **prima volta** che lo ottieni si sblocca la pagina con **da dove si ottiene** (mostro, area, attività, Monolito, boss) e la **percentuale base**.
- La pagina del **mostro**, dell'**area**, del **Monolito**, del **boss** o dell'**attività** mostra **tutto ciò che può dare**, in caselle bloccate finché non lo trovi; sbloccate mostrano nome e percentuale.
- Restano sempre visibili le **meccaniche** (testi), le statistiche dei mostri, le tabelle di mestiere e il "Serve a" degli oggetti sbloccati. Il tooltip degli oggetti non dice mai dove si ottengono.
- Logica nel modello (`Discoveries`, `GuideIndex.sources_of` ancora completo ma filtrato dalla UI tramite `Discoveries.has`); nessuno stato nella UI. Test: oggetto non scoperto = bloccato, scoperto = sbloccato; mai un "Si ottiene da" in un tooltip.


## 28. Equipaggiamento vero (M14, Alpha; decisioni Y1-Y6, Q66-Q77)

Fonte `ALPHA.md` (storica dopo R-05); formule in `02_FORMULAS.md` §5e e §8.4. L'equipaggiamento è il cuore del gioco: più modelli, più gradi, armi e armature con identità, un Capolavoro dai progetti, leggendari che cambiano le regole.

### 28.1 Gradi e modelli (Y3)
- **15 gradi del pezzo** con requisito di livello del personaggio 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90 (Q66). Ogni slot (spada, spadone, scudo, elmo, corpo, gambe, piedi, mani, anello, collo) ha **un modello per grado**, con nome proprio in `NOMI.md` (classici in basso, esotici in alto).
- Il **grado del materiale** (1…8: metalli, legni) resta quello dei mestieri: più gradi di pezzo condividono lo stesso materiale (tabella in F-118). Costi di raffinazione, progetti e smantellamento seguono il grado del materiale; i requisiti e gli affissi seguono il livello del pezzo.
- Gli **attrezzi unici** non cambiano (un attrezzo per mestiere, raffinazione +0…+9); si aggiungono gli attrezzi leggendari (§28.5).

### 28.2 Armi (Y2)
- Ogni arma ha **danno minimo e massimo** e **velocità d'attacco** (intervallo) propri. La **spada** è più rapida e di danno medio; lo **spadone** è lento e di danno alto (valori di partenza in F-118, Q77). Il danno dell'arma sostituisce il vecchio `power_bonus` come base del colpo (F-22 rivista); livello del personaggio e affissi lo modificano.
- Con due spade ogni colpo usa danno e velocità dell'arma che colpisce (F-73, F-74). La **scheda** dell'arma mostra danno minimo-massimo, velocità e **danno al secondo** (F-22).

### 28.3 Armature: Piastre, Cuoio, Tessuto runico (Y2, Q67, Q74)
- Elmo, corpo, gambe, piedi, mani e scudo esistono in **tre materiali**: **Piastre** (Armatura alta, niente Barriera), **Cuoio** (Armatura media, poca Barriera, molta Schivata), **Tessuto runico** (Armatura bassa, Barriera alta). Anelli e colli non hanno materiale.
- **Armatura** (stat `armor`) riduce in % il danno **fisico** (mostri `blade` e `marksmanship`); **Barriera** (stat `barrier`) riduce il danno **arcano** (mostri `arcana`). Rendimenti decrescenti, massimo 75% (F-117). Il vecchio valore piatto `damage_reduction` del giocatore diventa l'Armatura; il campo `damage_reduction` dei mostri resta una percentuale.
- Scelta di gioco: contro un'area di mostri `arcana` conviene la Barriera; il triangolo (F-24) e le armature si sommano.

### 28.4 Rarità (Y4, Y5)
| Rarità | Colore | Affissi | Fonte |
|---|---|---|---|
| Comune | bianco | 0 | drop |
| Magico | blu | 1-2 | drop |
| Raro | giallo | 3-4 | drop |
| **Capolavoro** | viola | **1-2** (uno scelto dal Fabbro dal livello 50) e statistiche base **+25%** | **solo progetti** |
| **Leggendario** | arancione | nessuno; statistiche fisse (×1,4) e **un effetto che cambia le regole** | boss delle Fratture, Monoliti |
- **Progetti** (Y4, §5.1): un progetto crea un **Capolavoro** (modello con nome proprio, diverso dai drop), con 1 o 2 affissi (più probabile averne 2 al crescere del livello del Fabbro, F-91), 2 castoni e **costo alto**: circa 3× i materiali di prima più **due componenti rari diversi**, durata invariata (F-119). I progetti di armature riguardano le **Piastre** (Q75: Cuoio e Tessuto runico
  vengono solo dai drop e dai leggendari finché non esiste un mestiere che li produca).

### 28.5 Leggendari (Y5, F-120)
- **3 per slot** nell'alpha (Q73): elmo, corpo, gambe, piedi, mani, collo, anello, spada, spadone, scudo, **accetta, piccone, canna** (39 in tutto; nomi, effetto e fonte in `NOMI.md`).
- Ognuno ha statistiche fisse e **un effetto che cambia una regola**, costruito sul sistema degli effetti dei tratti (nuovi tipi nello stesso elenco chiuso): ad es. lo spadone fa partire subito il prossimo attacco a ogni uccisione; lo scudo restituisce PV a ogni parata; l'anello raddoppia il bottino dei Monoliti; la canna ogni tanto dà il pesce del grado
  superiore; il piccone dà a volte una Scheggia.
- **Fonte dichiarata nei dati** (un boss di Frattura o un Monolito) e mostrata dalla Guida a scoperta. Gli **attrezzi leggendari** sostituiscono l'attrezzo unico nello slot (che torna nell'Armeria).
- Un leggendario non viene mai smantellato dal filtro. Con il Deposito pieno si perde, come una Carta.

### 28.6 Drop di equipaggiamento (Y6, F-121, Q69)
- Ogni mostro può far cadere **tutti gli slot** del grado vicino al proprio livello (non più 1-2 modelli fissi), con probabilità tarate perché cadano **3-5 pezzi ogni 30 minuti** nell'area del proprio livello, circa **1 magico ogni 30 minuti** e **1 raro ogni 2-3 ore**. I progetti cadono con lo stesso schema (circa 1 all'ora).
- I **leggendari** non cadono dai mostri comuni: circa 1 ogni 15-30 ore di Fratture del grado giusto.

### 28.7 Polvere del Rift (Q71)
Cade meno (8% per uccisione, 1 pezzo; `02_FORMULAS.md` §8.5b) e serve a più cose: **Cristalli** (Incisore, F-104), **raffinazione dal +5** (F-86), **borse** rinforzate e oltre, smantellamento di Carte (F-114). Il tooltip dice "Serve a" chiaramente.

## 29. Ritocchi UI dell'Alpha (Y9)

| Dove | Ritocco |
|---|---|
| Combattimento | **barra XP del personaggio** nella carta del giocatore; "In fila" diventa **"Altri nemici"**; etichetta del triangolo: "**Forte contro di te**" / "**Debole contro di te**" / "**Alla pari**" |
| Shop | descrizioni con i **numeri** letti dai dati (PV curati, %, effetti) |
| Incisore | **sottoschede**: Lastre, Fondere, Cristalli, Rune |
| Fabbro | **sottoschede**: Lingotti, Piastre, Progetti, Banco del fabbro |
| Deposito | pulsante **Riordina** (ordine della categoria e `sort_order`) |
| Equipaggiamento | scheda dell'arma con danno minimo-massimo, velocità e danno al secondo; armature con Armatura e Barriera; colori **viola** (Capolavoro) e **arancione** (leggendario) |
| Fratture | carte della pagina più basse: ogni modificatore su una riga compatta |
| Guida / oggetti | caselle bloccate e pagine a scoperta (§27) |
| Maestria | su ogni carta: livello, bonus attuali, prossimo bonus (§6.5) |

**Accettazione dell'Alpha** (`07_TASKS.md` M14): armi con danno min-max, velocità e danno al secondo; armature con materiali, Armatura % e Barriera %; 15 gradi per slot; Capolavori solo dai progetti; almeno 3 leggendari per slot (attrezzi compresi) con effetto e fonte; la sim dà 3-5 pezzi ogni 30 minuti nell'area giusta, 1 magico ogni 30 minuti, 1 raro ogni 2-3 ore;
la Guida nasconde oggetti e drop finché non trovati e nessun tooltip dice "Si ottiene da"; maestria con bonus visibili e prossimo bonus; tutti i ritocchi di §29.

## 30. Villaggio (M19; decisione V7, `M19_VILLAGGIO.md`; formule F-131, F-132, F-133)

**Idea.** Una pagina **Villaggio** con pochi **edifici unici**. Ognuno ha una sola riga di **livelli** (1…8); si costruisce (livello 0 → 1) e si migliora pagando
**oro e materiali**: componenti del Falegname (impugnature, manici, telai dello scudo dei legni 1-8), piastre del Fabbro e cibo cotto del Cuoco. Dà uno scopo ai
legni alti e lega le skill di artigianato. Gli effetti sono solo di **comodità** (caselle, bottino, XP di un mestiere, velocità di un mestiere, cibo): **nessun potere
di combattimento diretto**. Nel Falegname non c'è un'"asse": i componenti sono quelli del §5 (id reali `<legno>_grip`, `<legno>_handle`, `<legno>_shieldcore`).

**Clean room.** Niente popolazione, felicità, istruzione, salute, tasse o risorse da gestire (il Township di Melvor non è un modello): nessun contatore che
cresce o cala da solo, nessun timer. Costruire è **istantaneo**: nessun caso offline.

**Edifici di M19** (5, ordine della pagina; formule in `02_FORMULAS.md` F-131/F-132, parametri in `data/village/buildings.json` e `balance.json` `village`):
| Id | Nome | Effetto per livello (livelli 1…8) | Stat (scope) |
|---|---|---|---|
| `storehouse` | Magazzino | +4 caselle di Deposito (massimo +32) | `deposit_slots` (globale) |
| `inn` | Locanda | +3% di cura del cibo (massimo +24%) | `food_healing_pct` (globale) |
| `forge` | Fucina | +3% di XP del Fabbro (massimo +24%) | `skill_xp_pct` (`skill:forging`) |
| `sawmill` | Segheria | −2% di intervallo del Falegname (massimo −16%) | `skill_interval_pct` (`skill:woodwright`) |
| `loot_shed` | Rimessa del bottino | +2 caselle della borsa del bottino (massimo +16) | `loot_bag_slots` (globale) |

**Mercato e Bacheca (M20, §31)**: dalla M20 sono i due edifici **costruibili** 6 e 7 (`market`, `noticeboard`), con gli stessi livelli e costi di F-131 e un effetto proprio (§31). Fino a M20-04 stanno nei dati come segnaposto (`buildable: false`, `milestone: 20`, box grigi "In arrivo"). Il Santuario del Rift della proposta non serve in M19 (nessuna
comodità che non sia già coperta): rimandato.

**Regole**
- Ogni edificio parte a **livello 0** (non costruito, nessun effetto). Il livello massimo è `village.max_level` (8). Il livello `n` richiede **livello del Falegname**
  `village.woodwright_levels[n−1]` (1, 10, 20, 30, 45, 60, 75, 90: il livello del gradino di legno `n`, `02_FORMULAS.md` §8.1) e il costo di F-131 (oro + materiali
  dei gradi `n`: legno, metallo e pesce del gradino `n`).
- **Costruisci** (livello 0) e **Migliora** sono lo stesso comando `upgrade`: controlla i requisiti, toglie oro e materiali **insieme** (o niente), sale di un livello,
  ricostruisce gli effetti e annuncia `village_upgraded`. Non si può saltare un livello né tornare indietro (nessuna demolizione, nessun rimborso).
- Gli effetti sono **fissi** (F-132) e valgono finché l'edificio esiste, anche mentre si combatte o si fa altro; passano dal `ModifierService` (sorgente
  `village:<id>`). La capienza del Deposito include `deposit_slots` (F-133): non occupa nulla e non si perde mai (i livelli non scendono).
- **Stati** di un edificio per la UI (derivati, mai salvati): `locked_placeholder` (M20), `unbuilt` (livello 0), `built` (1 ≤ livello < massimo), `maxed`. Per i
  primi tre il box mostra anche **perché** il prossimo livello non è acquistabile (primo motivo di `can_upgrade`).
- **Casi limite**: materiali insufficienti → `not_enough_items` (nessun cambiamento; il box mostra quanti ne mancano); oro insufficiente → `not_enough_gold`;
  Falegname sotto il livello richiesto → `level_too_low` (il box mostra il livello richiesto); livello massimo → `max_level`; segnaposto → `not_buildable`; id
  sconosciuto → `unknown_id`. Gli oggetti **bloccati** (§7) si possono spendere (il blocco impedisce solo di venderli). Gli oggetti dei costi non finiscono in
  nessuna "riserva": si pagano dal Deposito. Nessun rischio di casella piena: pagare libera caselle, non ne occupa.
- **Offline**: il Villaggio non ha tempo; lo stato non cambia offline. Gli effetti valgono nella simulazione offline (sono modificatori come gli altri).
- **Bilanciamento** (`tools/sim_village.gd`, nessuna ora di farm obbligata): un livello costa al massimo 0,84 h di raccolta dei suoi materiali e dell'oro (livello 8 del
  Magazzino); un edificio al massimo 4,0 h, tutti e cinque circa 17 h su ~295 h di gioco. Tabella nel commit di M19-01 e in `02_FORMULAS.md` F-131.
- **UI**: pagina `village` nella sidebar; un **box** per edificio (livello `n/8`, effetto attuale e del livello successivo, costo con quantità possedute e livello del
  Falegname richiesto, pulsante **Costruisci**/**Migliora**, disabilitato con il motivo). Testi in `*_texts.gd`. La UI non tiene stato.

## 31. Bacheca e Mercato (M20; decisione V7, `M20_BACHECA.md`; formule F-134, F-135, F-136)

**Idea.** I due edifici di M19 rimasti segnaposto diventano **costruibili** (livelli 1…8, costo di F-131, requisito del Falegname come gli altri). La **Bacheca** dà
**incarichi** (quest) con ricompense di oro, XP di un mestiere e cibo; il **Mercato** apre bancarelle con acquisti **esclusivi** di comodità. Come il resto del Villaggio:
nessun potere di combattimento diretto, nessun timer, nessuna risorsa da gestire. Tutti gli effetti passano dal `ModifierService` (`stats.json`).

### 31.1 Bacheca (`noticeboard`, effetto: stat `quest_slots`, +1 per livello)
- **Incarichi attivi** = `floor(T(quest_slots))` = livello della Bacheca (0 se non costruita: nessun incarico, la pagina dice "Costruisci la Bacheca al Villaggio"; massimo 8). Ogni incarico occupa una **casella** (0…7) della pagina Bacheca.
- **Tipi di obiettivo** (tutti misurabili con segnali già esistenti, nessun segnale nuovo da emettere):
  | Tipo | Cosa conta | Segnale |
  |---|---|---|
  | `kill` | ogni mostro sconfitto (qualunque area, anche nei Monoliti e nelle Fratture) | `monster_killed` |
  | `gather` | pezzi **dell'oggetto** indicato prodotti da Boscaiolo, Minatore o Pescatore (cicli del giocatore **e degli aiutanti**) | `action_completed`, `helper_completed` (`outputs[item]`) |
  | `craft` | pezzi **dell'oggetto** indicato prodotti da Fabbro, Cuoco o Falegname | `action_completed` (`outputs[item]`) |
  Il progresso si conta **solo mentre l'incarico è attivo** (nessun conteggio retroattivo), è un intero tra 0 e l'obiettivo e vale anche **offline** (la simulazione offline usa gli stessi segnali, §12): nessun timer, nessuna regola speciale.
- **Quest** (`data/quests/quests.json`, **generato**, 56 voci): una per tipo, per mestiere e per **gradino** 1…8 (stessi gradini del legno di F-131). Un gradino `t` richiede **livello del personaggio** `quest.tier_levels[t−1]` (1, 10, 20, 30, 45, 60, 75, 90) e, per `gather` e `craft`,
  il livello del mestiere dell'azione che produce l'oggetto (stesso numero). Oggetti del gradino: `gather` Boscaiolo `<legno>_log`, Minatore `<metallo>_ore`, Pescatore `<pesce>`; `craft` Fabbro `<metallo>_plate`, Cuoco `seared_<pesce>`, Falegname `<legno>_grip` (liste di F-131).
- **Obiettivo e ricompensa** (F-134): l'obiettivo cresce con il gradino; ogni incarico paga **oro**, i `gather`/`craft` anche **XP del mestiere** dell'incarico (passa da F-02 come ogni XP, quindi ne risente `skill_xp_pct`), i `kill` anche **cibo cotto** del gradino. Niente oggetti di potere, niente pezzi dell'Armeria, niente XP del personaggio.
- **Quali incarichi compaiono** (F-135, **nessun caso e nessun timer**): quando una casella è libera (Bacheca costruita o migliorata, incarico riscosso o abbandonato) si assegna **il successivo** nell'ordine del file a partire da un **cursore** salvato. Un incarico è **candidato** se: ne sono soddisfatti i requisiti (livello del personaggio e del mestiere),
  il suo gradino è tra gli ultimi `quest.tier_window` (3) gradini raggiunti dal personaggio, non è già attivo, e non è tra gli ultimi `quest.recent_memory` (6) riscossi o abbandonati (se così nessuno è candidato, la memoria si ignora). Nessun candidato → la casella resta vuota ("Nessun incarico disponibile") e si riprova a ogni cambio di livello.
- **Comandi**: **Riscuoti** (`claim`, solo se l'obiettivo è raggiunto): paga la ricompensa (oro, XP, cibo nel Deposito), toglie l'incarico, assegna il successivo nella stessa casella. **Abbandona** (`abandon`, gratuito): scarta l'incarico e il suo progresso, assegna il successivo (la memoria recente lo esclude).
- **Casi limite**: casella vuota → `slot_empty`; obiettivo non raggiunto → `quest_incomplete`; ricompensa di cibo senza posto nel Deposito → `bank_full` (nessun cambiamento: l'oro e l'XP non si danno a metà); casella fuori intervallo → `unknown_id`. Il progresso eccedente si ferma all'obiettivo (nessun resto riportato). Il livello della Bacheca non scende: le caselle non si perdono mai.
  Un incarico già assegnato resta anche se il personaggio sale di gradino. Un salvataggio senza `quests` riparte da zero (nessun incarico assegnato finché la Bacheca non è costruita).
- **Offline**: nessun rinnovo a tempo; l'offline fa avanzare i progressi come il gioco normale e può completare incarichi (si riscuotono al ritorno). Non assegna nuovi incarichi se non c'è una casella libera.
- **Ricompensa totale e bilanciamento** (`tools/sim_quests.gd`): ogni incarico richiede al massimo 0,49 h di attività; l'oro pagato per ora d'incarico resta ≤ 0,69 volte l'oro all'ora del combattimento dello stesso gradino (misura sim; l'oro è un bonus, i materiali raccolti restano al giocatore). Tabella in F-134.

### 31.2 Mercato (`market`, nessuna stat: sblocca bancarelle)
- Il Mercato non ha un effetto a modificatore: il suo **livello** sblocca voci dello shop (`data/shop/shop.json`) con la bancarella `mercato` e il requisito `requires.village = {market: n}` (livello `n` del Mercato, 1…8). Livello 0: la bancarella mostra "Costruisci il Mercato al Villaggio".
- **Cosa vende** (solo comodità, tutte voci a **modificatore** con `max_purchases` e prezzo fisso in oro, come le altre voci dello shop): scaffali del mercante (`deposit_slots`), spezie (`food_healing_pct`), manuali di mestiere (`skill_xp_pct`), attrezzi affilati (`skill_interval_pct`), tasca del cacciatore (`loot_bag_slots`). Tabella in F-136. Nessuna voce vende oggetti, pezzi, rune o potere di combattimento (nessun `auto_*`).
- Le voci a catena (Scaffale I-IV, Spezie I-III) usano `requires.entries` come le Razioni da campo. L'acquisto è per slot, come ogni acquisto (sorgente `shop:<id>`); i livelli del Mercato non scendono, quindi nessuna voce già comprata si "perde".
- **Casi limite**: Mercato sotto il livello richiesto → `requirement_not_met` (la UI mostra "Richiede Mercato n"); oro insufficiente → `not_enough_gold`; massimo raggiunto → `max_purchases`.

### 31.3 UI
- Pagina **Bacheca** (`noticeboard`, sidebar dopo Villaggio): una **riga** per casella (nome e descrizione dell'incarico, barra `progresso/obiettivo`, ricompensa, pulsanti **Riscuoti** e **Abbandona**; riga vuota "Nessun incarico disponibile"). Se la Bacheca non è costruita: un solo messaggio.
- Pagina Villaggio: i box del Mercato e della Bacheca diventano costruibili come gli altri (la Bacheca mostra "+1 incarico", il Mercato "Sblocca nuove bancarelle"). Pagina Shop: bancarella **Mercato** con le voci bloccate e il motivo ("Richiede Mercato n").
- La UI non tiene stato; testi in `*_texts.gd`. Notifica quando un incarico raggiunge l'obiettivo (`quest_completed`).

## 32. Mappa del Villaggio (M21; decisione V7 punto 6, `M21_MAPPA.md`; nessuna formula, nessuna stat)

**Idea.** La pagina Villaggio (§30) ha due **viste** dello stesso stato: **Mappa** (predefinita) ed **Elenco** (la griglia di box di M19-M20, invariata). La mappa mostra
i 7 edifici come **nodi cliccabili** posizionati su un campo (come le aree di combattimento, §8.5, ma dentro la pagina, non in una finestra sovrapposta). **Nessuna
nuova meccanica**: costruire, migliorare, costi, requisiti, effetti ed eventi sono quelli di §30-§31; nessuna stat, nessuna formula, **nessun cambio di save**.

**Nodo.** Ogni edificio ha la posizione `map_pos` nei dati (`buildings.json`, §26 dello schema). Il nodo mostra icona, nome e una riga di stato, con il bordo colorato
per stato (derivato, mai salvato, stessi dati di §30):
| Stato del nodo | Condizione | Riga di stato |
|---|---|---|
| `locked` (bloccato) | livello 0 e primo motivo di `can_upgrade` = `level_too_low` | "Richiede Falegname n" |
| `unbuilt` (da costruire) | livello 0, altri motivi (oro, materiali) | "Da costruire" |
| `ready` (pronto) | `can_upgrade` ok (livello 0 o 1…7): si può pagare ora | "Costruibile" / "Migliorabile" |
| `built` (costruito) | livello 1…7, prossimo livello non ancora pagabile | "Livello n/8" |
| `maxed` | livello massimo | "Livello massimo" |
| `placeholder` | `buildable = false` (oggi nessuno) | "In arrivo" |
`ready` ha la precedenza su `built`; per i livelli 1…7 `locked` non esiste (il nodo resta `built`).

**Selezione e dettaglio.** Un clic su un nodo lo **seleziona** (stato di sola presentazione, non salvato; all'apertura è selezionato il primo edificio per `order`). A
destra della mappa un **pannello di dettaglio** mostra il box di §30 dell'edificio selezionato (livello, effetto attuale e successivo, costo con posseduti, requisito
del Falegname, **Costruisci/Migliora** con il motivo): è lo stesso componente della vista Elenco. Costruire dalla mappa non cambia vista né selezione; il nodo si
aggiorna (stato e livello) con gli stessi eventi della pagina.

**Accesso alle pagine.** Gli edifici con pagina propria hanno nei dati il campo `page` (`noticeboard` → pagina Bacheca, `market` → pagina Shop). Nel pannello di dettaglio
compare il pulsante **Apri** (testo "Apri Bacheca" / "Apri Mercato"): **abilitato solo se l'edificio è costruito** (livello ≥ 1), altrimenti disabilitato con "Costruiscilo
per usarlo". Il clic emette `page_requested(page)` e la schermata principale mostra la pagina (stessa via della barra laterale). Gli altri edifici non hanno `page`.

**Vista e persistenza.** La vista scelta (Mappa/Elenco) e la selezione vivono nella pagina e si perdono alla chiusura: non sono stato di gioco, non entrano nel save
né in `settings.cfg`. Nessun caso offline (il Villaggio non ha tempo). Lo stato della mappa si legge dal modulo `village` (livelli, `can_upgrade`) e dal Magazzino/Banca come il box.

**Clean room.** Un campo con nodi fissi e nessuna cosa che si muova, cresca o richieda cura (nessun terreno, strada o abitante da piazzare: il Township di Melvor non è un
modello). Le posizioni sono scelte dal design e non le cambia il giocatore.

**Layout** (1280×720, barra laterale inclusa): campo a sinistra (circa 680×500), pannello di dettaglio a destra (circa 340 px, scorre se il box è alto); nodi 150×72.
**Icone**: quelle già in `assets/icons/ui` (campo `icon` di §24; se manca il file la UI mostra `missing`, nessun asset nuovo). Testi in `village_texts.gd`.

## 33. Dungeon delle scimmie (M22; decisione V12, `M22_DUNGEON.md`; formule F-137…F-144)

**Idea.** Un'istanza a **scelte**, l'unica parte del combattimento che chiede input: si entra con un **Biglietto**, si combatte in automatico (stesso motore, triangolo, tratti, abilità, cibo), e **tra una stanza e l'altra si sceglie una direzione**. Dietro le quinte il gioco
costruisce una mappa a livelli (il giocatore non la vede, §33.2); l'ultima stanza è sempre il **boss**, preceduto da due scagnozzi (braccio destro e stratega) e da un'entrata epica. Primo dungeon: **il Covo delle Scimmie** (`monkey_den`). Idea ispirata ai dungeon
a stanze dei giochi d'azione, solo come meccanica; nomi, testi e numeri originali. Il sistema è **generico** (`data/dungeons/`): altri dungeon sono solo dati nuovi (M23+).

### 33.1 Biglietto, requisiti, miniboss
- **Biglietto del Covo delle Scimmie** (`dungeon_ticket_monkey_den`): oggetto della categoria `misc` con il campo `dungeon` (id del dungeon, `04_DATA_SCHEMA.md` §27); impilabile nella Bank, **non vendibile**, si consuma **all'ingresso** (non si recupera).
- **Fonti** (F-139): i **miniboss** delle aree e i **Monoliti** (tabelle di drop F-32) delle aree 4-10; mai dai mostri comuni, dalle Fratture o dallo shop (Q91). Obiettivo: un Biglietto ogni **1,5-2,5 ore** di combattimento nelle aree giuste.
- **Requisito**: livello del personaggio 35; **consigliato 45** (aree 5-6). Nessun requisito di equipaggiamento.
- **Miniboss (Z8, ora fissato)**: ogni area ha **un miniboss** (10, uno per area, campo `miniboss` di `areas.json`): un mostro dell'area con PV, danno e XP molto maggiori (F-139) che compare in un **incontro a sé** con due mostri dell'area di scorta. Dopo ogni incontro
  normale si tira `miniboss.chance_pct` (1,5%): se riesce, il prossimo incontro (dopo `BETWEEN`) è quello del miniboss; non vale con un Monolito in attesa (il Monolito ha la precedenza) né dentro Fratture o dungeon. Uccisioni, XP, oro e drop come per i mostri (le uccisioni contano per F-87).

### 33.2 La mappa nascosta
- **Generata all'ingresso** da un seme (un solo numero estratto dal generatore dello slot: ricaricando si ottiene la stessa mappa) e **mai mostrata**: la UI vede solo la stanza attuale e le uscite (F-137).
- **Struttura**: stanza d'ingresso (livello 0: un branco di scimmie), poi **5 livelli di bivio** di 2-4 stanze ciascuno, poi la **stanza del boss** (livello 6, una sola). Ogni stanza ha **2-4 uscite** verso il livello successivo (quelle del livello 5 portano
  tutte al boss: corridoio senza scelta, quindi le **scelte vere sono 5**, una per ogni passaggio dal livello 0 al 5). Una stanza può essere raggiunta da più stanze del livello prima; non si torna indietro; non esistono vicoli ciechi.
- **Direzioni**: le stanze di un livello hanno una posizione laterale (`x`, 0..1). Le uscite di una stanza sono le stanze del livello dopo **più vicine** alla sua posizione; la direzione mostrata dipende dallo spostamento laterale (F-137): **sinistra estrema, sinistra, leggermente a sinistra, avanti,
  leggermente a destra, destra, destra estrema**. Chi è all'estrema sinistra non vedrà mai una "sinistra". Due uscite di una stanza hanno sempre direzioni diverse.
- **Indizi (opzionali)**: ogni uscita ha, con probabilità `dungeon.hint_pct` (45%), un **indizio vero** sul tipo di stanza (un suono o un odore, una frase fissa per tipo, F-138); senza indizio la scelta è alla cieca. Gli indizi non mentono mai; non rivelano però il contenuto esatto.
- **Tipi di stanza** (pesi e livello minimo in F-138): **Branco** (3-6 scimmie), **Orda** (12 scimmiette), **Guardiano** (un solo gorilla molto robusto), **Capobranco** (miniboss con due guardie), **Trappola** (evento a scelta), **Riposo** (evento a scelta). Pesi e dimensioni sono dati.

### 33.3 Combattimento: tutto automatico, tranne le scelte
- Una stanza di combattimento è un incontro come gli altri (stesso motore a eventi, triangolo, tratti, abilità, bottino): **nessuna azione del giocatore** (tratti e abilità non si cambiano, `combat_active`; il cibo e l'auto-cibo funzionano; "Mangia" resta). Uccisi tutti i nemici la stanza è
  **superata**: nessun respawn, il gioco **si ferma e aspetta la scelta** (stato `await`, nessun timer, nessun attacco). I PV restano quelli della stanza (non si curano tra le stanze: solo il cibo, il Riposo e la Trappola li cambiano).
- **Eventi** (Trappola, Riposo): all'ingresso la stanza non ha nemici ma **due scelte** (F-140):
  - **Trappola** (dardi, fossa o liane: stesse regole): **"Attraversa di corsa"** toglie `trap.dash_hp_pct` (20%) dei PV massimi (mai sotto 1 PV, mai letale) e si prosegue; **"Aggira"** non costa PV, ma si combatte un'imboscata di 3 scimmie prima di proseguire.
  - **Riposo**: **"Riposa"** cura `rest.heal_pct` (35%) dei PV massimi; **"Fruga tra i rami"** non cura, si combatte un branco di 4 scimmie e poi si trova una scorta (Polvere e a volte un Cristallo).
  Nessun effetto di trappole o riposi dura oltre la stanza né tocca equipaggiamento, Deposito e Bank: **nessun potere permanente**.
- Nel dungeon: nessun Monolito, nessun miniboss di area, nessun conteggio F-87. I mostri contano per le Bacheca (`monster_killed`) e per l'XP del personaggio (F-130 vale come fuori).
- **Nessuna meccanica a fasi** oltre agli stadi del boss; le abilità di scagnozzi e boss sono quelle di F-112 (colpo pesante, evocazione, scudo).

### 33.4 Il boss: entrata epica in tre atti
La stanza finale non è un incontro solo: è una **sequenza di tre stadi**, uno dopo l'altro, senza scelte né pause di recupero (solo il cibo). Prima di ogni stadio c'è una **scena di ingresso** (`intro_ms`, F-139): nessuno attacca, la UI mostra una carta a tutto campo con
nome, titolo e una frase del personaggio (testi nei dati). Gli stadi (`stages` del dungeon, numeri in F-139):
1. **Gorom, il Braccio Destro**: un gorilla armato, con due **guardie**. Abilità: colpo pesante (F-112 `heavy_strike`).
2. **Ziki, la Stratega**: una scimmia sciamana (arcana: il triangolo è dalla parte del giocatore, ma è tenace), con tre **lanciatrici**. Abilità: **evocazione** di altre lanciatrici (F-112 `summon`, mai più di quattro vive).
3. **Uuk-Maar, il Re delle Scimmie**: il boss, **da solo** in campo, con un'entrata più lunga (il ruggito). Abilità: **scudo** a intervalli (F-112 `shield`).
- Gli stadi 1 e 2 danno un premio minore alla morte del loro capo (F-142); il bottino principale è alla vittoria sul **Re** (F-143). Se il giocatore muore in uno stadio la run è persa (§33.5).
- Le guardie e le lanciatrici sono mostri del dungeon con XP e oro; gli **evocati** della Stratega non danno XP, oro né drop (F-112).

### 33.5 Ricompense, morte, uscita
- **Borsa del dungeon**: tutto ciò che cade dentro (oggetti, pezzi, Carte; non l'oro e l'XP, che vanno subito al giocatore) va in una **borsa separata** (stessa classe e regole della borsa della Frattura, nessun limite di caselle); mai nella borsa del bottino normale (che resta com'era).
- **Vittoria** sul Re: la borsa si **consegna** (F-116: oggetti nella Bank, pezzi nell'Armeria con il filtro automatico, Carte nel `CardStore`; ciò che non entra resta **in attesa** finché il giocatore non fa posto e preme "Raccogli"; finché c'è qualcosa in attesa non si entra in un altro dungeon)
  più le ricompense garantite e i **leggendari del dungeon** (F-143).
- **Morte**: si perdono il Biglietto (già consumato) e **tutta la borsa** (`dungeon_loot_lost`); PV al massimo; Deposito ed equipaggiamento non si toccano; oro e XP guadagnati restano (come nelle Fratture, X4).
- **Uscita volontaria**: nei punti di scelta (bivio o evento, mai durante un combattimento) il pulsante **"Esci dal Covo"** (con conferma) chiude la run con esito `left`: la borsa si consegna, ma senza le ricompense del boss. Durante un combattimento esiste solo **"Fuggi"** (con conferma): vale come la **morte** (borsa persa).
  Scelta di design: uscire al bivio è prudente ma costa il boss; fuggire dal combattimento è la scappatoia peggiore.
- Dopo la fine (vittoria, morte, fuga, uscita) il combattimento torna all'**area in cui il giocatore stava combattendo** prima di entrare (se combatteva), con la sua borsa del bottino com'era; altrimenti resta fermo. L'azione del giocatore non riparte; gli **aiutanti continuano** (come nelle Fratture).
- **Una sola istanza alla volta**: non si entra se una Frattura o un altro dungeon è in corso o c'è un bottino in attesa (`dungeon_active`, `fracture_active`, `dungeon_bag_pending`); non si apre una Frattura durante un dungeon (`dungeon_active`).

### 33.6 Salvataggio e offline
- **Stato per slot** (`dungeon`, `05_INTERFACES.md` §5.29 e §6; **additivo**: nessuna migrazione, `format_version` 7 invariata): dungeon, seme, stanza attuale (livello, indice), fase (`fight`, `await`, `event`, `intro`), stadio del boss, percorso fatto, borsa, area di ritorno, contatore di vittorie.
  La mappa non si salva: si rigenera dal seme (test). Nemici e timer li salva il combattimento, come per le Fratture.
- **Caricamento**: la run riprende **in pausa** (F-144, regola 1): i timer non scorrono finché il giocatore non preme **"Riprendi"** (evita di morire mentre non si guarda lo schermo).
- **Offline: la run si congela.** Il simulatore offline non avanza né il combattimento né la run (nessun progresso, nessuna morte, nessuna scelta automatica); gli aiutanti e il resto continuano come sempre; il riepilogo "Mentre eri via…" dice solo "Il Covo delle Scimmie ti aspetta".
  Motivo: la run è attiva per definizione (richiede input) e il bottino non deve sparire senza che il giocatore sia presente. Aperta: Q93.

### 33.7 UI
- Pagina **Dungeon** (sidebar, voce "Dungeon" dopo "Fratture"), tre stati della stessa pagina. **Ingresso** (nessuna run): il dungeon, il livello consigliato, i Biglietti posseduti, pulsante **Entra** (rifiuti con il motivo), il bottino in attesa ("Raccogli"), l'esito dell'ultima run (solo testo, in memoria).
  **Scelta** (fase `await` o `event`): titolo della stanza superata, avanzamento ("Stanza 3 di 7"; il boss è "?"), i **pulsanti delle direzioni** (testo della direzione e, se c'è, l'indizio; sono 2-4), per un evento i due pulsanti dell'evento, "Esci dal Covo", la borsa del dungeon. **Stanza in combattimento**: gli stessi
  componenti della pagina Combattimento (carta del giocatore, nemici, numeri dei colpi, registro), il nome della stanza, "Fuggi", "Mangia" e, per il boss, la **scena di ingresso**. Se la run è in pausa: un solo pulsante **"Riprendi"**.
- La UI non tiene stato di gioco e non conosce la mappa: legge `DungeonSystem.state()` e invia i comandi. Notifica a vittoria, morte, fuga e uscita. **Guida**: pagina "Dungeon" (§27) con struttura, tipi di stanza e fonti dei Biglietti; bottino del boss e leggendari nella Guida a scoperta (§27.1).
