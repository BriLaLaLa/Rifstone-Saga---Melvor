# 01. Game Design Document

Ogni sistema ha: **regole**, **stati**, **casi limite** e **interazioni**. I numeri stanno in `02_FORMULAS.md` (citati
come `F-xx`); i parametri hanno un'unica definizione in `res://data/config/balance.json`; le stat dei modificatori
sono elencate in `res://data/config/stats.json` (sezione 15). Le firme dei metodi sono in `05_INTERFACES.md`.

Indice: 1 Slot e sessione · 2 Tempo di gioco · 3 Skill ed esperienza · 4 Azioni di raccolta · 5 Azioni di
artigianato · 6 Maestria · 7 Bank · 8 Oro e shop · 9 Equipaggiamento e attrezzi · 10 Combattimento ·
11 Legatura del Rift e Altare · 12 Progressione offline · 13 Feedback e notifiche · 14 Suggerimenti ·
15 Modificatori e stat · 16 Impostazioni · 17 Fratture del Rift (M7) · 18 Azioni in parallelo (M8)

---

## 1. Slot di salvataggio e sessione

**Regole**
- Ci sono 4 slot (`slots.count`). Ogni slot è una partita indipendente: **tutto** lo stato del giocatore (skill,
  maestria, bank, oro, equipaggiamento, stance, cibo scelto, azione in corso, combattimento in corso, acquisti dello
  shop, prese dell'Altare, suggerimenti visti, fratture) sta nel file dello slot. Nessuno stato di gioco è fuori.
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
Tutte le skill al livello 1 (0 XP), maestria a 0, pool vuoti, 0 nodi; bank vuota con capienza base; oro
`start.gold`; oggetti iniziali `start.items` (definiti in `balance.json`); nessun equipaggiamento; stance
`offensive`; nessuna azione in corso; nessun acquisto; prese dell'Altare vuote; seme casuale nuovo.

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
- L'ordine di aggiornamento in un passo è fisso: fratture (M7) → corsie delle azioni → combattimento → tempo di gioco.
- Il tempo di gioco (`play_time_ms`) cresce solo durante `PLAYING` (non durante l'offline, che ha il suo totale).

**Casi limite**: finestra ridotta a icona o gioco bloccato per alcuni secondi: il tempo accumulato si recupera nei
passi successivi fino a `max_catchup_ms` (5 s) per frame; oltre, il resto si scarta (evita la "spirale"). Pause lunghe
reali (computer in sospensione con il gioco aperto) sono trattate come offline al ritorno se superano
`offline_min_ms` (vedi sezione 12).

## 3. Skill ed esperienza

**Regole**
- 12 skill (tabella in `00_VISION.md`), tutte disponibili dall'inizio.
- L'esperienza è un intero cumulativo per skill. Il livello si ricava dall'XP con la tabella `F-01` (livelli 1-99).
  L'XP continua a crescere oltre il 99 fino a `xp_curve.xp_cap`, ma il livello resta 99.
- L'XP guadagnata passa sempre da `skill_xp_pct` (F-02).
- Salire di livello sblocca azioni, ricette, aree, prese dell'Altare, equipaggiamento (requisiti nei dati).
- Ogni salita di livello emette `level_up` (anche più livelli in un colpo: un evento per livello).

**Stati**: per skill solo `xp`. Livello e progresso sono derivati, mai salvati.

**Casi limite**: XP negativa non ammessa (assert, ignorata); XP oltre il tetto troncata; salto di più livelli.

**Interazioni**: azioni, combattimento (XP per danno), maestria (le skill di combattimento non hanno maestria),
requisiti di equipaggiamento, Altare del Rift.

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
- Una sola azione alla volta nella corsia principale (fino a M8): avviarne un'altra ferma la precedente; avviare il
  combattimento ferma l'azione; avviare un'azione ferma il combattimento.
- L'attrezzo della skill (slot `tool_<skill>`) dà modificatori alla skill (di solito `skill_interval_pct` negativo).

**Stati**: corsia `IDLE` / `RUNNING(skill, action, elapsed_ms)`. `elapsed_ms` è salvato: ricaricando, la barra riprende.

**Casi limite**: livello insufficiente (non si avvia: `level_too_low`); dati mancanti (`unknown_id`); intervallo
ridotto sotto il minimo (`action.min_interval_ms`); cambio di attrezzo durante l'azione (vale dal ciclo successivo:
l'intervallo si ricalcola a ogni avvio di ciclo).

## 5. Azioni di artigianato (Forgiatura, Focolare, Intaglio, Legatura del Rift)

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
- Le skill di combattimento non hanno maestria.

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
- La bank è l'**unico** contenitore degli oggetti posseduti (esclusi equipaggiamento indossato, borsa del bottino e
  prese dell'Altare). Ogni tipo di oggetto occupa **una** casella, con quantità illimitata (intero a 64 bit).
- Capienza = `bank.base_slots` (24) + somma della stat `bank_slots` (caselle comprate nello shop, F-17).
- Aggiungere un oggetto già presente non occupa caselle; aggiungerne uno nuovo richiede una casella libera, altrimenti
  l'aggiunta fallisce (`bank_full`) e il chiamante decide cosa fare (le azioni si fermano, la borsa del bottino tiene
  l'oggetto, l'acquisto non avviene).
- Quando la quantità arriva a 0 la casella si libera.
- Ogni casella può essere **bloccata**: un oggetto bloccato non si vende (né singolo né "vendi tutto").
- Ordine: quello di inserimento; il giocatore può spostare le caselle (trascinamento) o usare "Ordina" (per categoria,
  poi per `sort_order` dell'oggetto).
- Dal pannello dell'oggetto: vendi (quantità con cursore, "tutti tranne 1", "tutti"), blocca, equipaggia, scegli
  come cibo, incastona (infusioni).

**Casi limite**: capienza che scende sotto le caselle usate (non può succedere nell'MVP: le caselle comprate non si
perdono); oggetto sconosciuto in un salvataggio (scartato al caricamento, con avviso nel log); quantità ≤ 0 (rifiutata).

## 8. Oro e shop

**Regole**
- Unica valuta: **Oro** (`gold`, intero ≥ 0).
- Vendere: oro = `item.value × quantità` (F-18). Oggetti con `value = 0` non si vendono.
- Lo shop ha voci (`data/shop/shop.json`), per categoria:
  - **Bank**: "Casella della bank" (+1 `bank_slots`), prezzo crescente F-17, massimo `bank.max_purchasable`;
  - **Combattimento**: "Razioni da campo I/II/III" (stat `auto_eat_tier`, una alla volta, in ordine),
    "Raccolta automatica del bottino" (`auto_loot`), "Tasca della borsa" (+4 `loot_bag_slots`, max 3);
  - **Materiali**: oggetti base comprabili (es. sale, spago) a prezzo fisso;
  - **Corsie** (M8): "Secondo pensiero" (`parallel_lanes` +1).
- Ogni voce ha: costo (oro fisso o formula), massimo di acquisti, requisiti (skill/livello, altra voce), effetto
  (modificatori o oggetto).
- Gli effetti a modificatore valgono `valore × numero di acquisti` (sorgente `shop:<id>`).

**Casi limite**: oro insufficiente (`not_enough_gold`); massimo raggiunto (`max_purchases`); requisito mancante
(`requirement_not_met`); acquisto di un oggetto con bank piena (`bank_full`, oro non speso).

## 9. Equipaggiamento e attrezzi

**Regole**
- Slot: `head`, `body`, `legs`, `feet`, `hands`, `neck`, `ring`, `weapon`, `offhand`, `tool_forestry`,
  `tool_quarrying`, `tool_angling`. Più due scelte che non sono slot: **cibo** (riferimento a un oggetto della bank)
  e **stance** (`offensive`, `balanced`, `defensive`).
- Equipaggiare toglie **1** pezzo dalla bank e lo mette nello slot; se lo slot era occupato, il pezzo precedente torna
  nella bank (se non c'è posto l'operazione fallisce, `bank_full`, e nulla cambia).
- Requisiti: livelli di skill (`equip.requirements`). Senza requisiti: `requirement_not_met`.
- Arma a due mani: per equipaggiarla l'`offhand` deve tornare nella bank; equipaggiare un `offhand` con un'arma a due
  mani rimuove l'arma.
- I modificatori dell'oggetto valgono finché è indossato (sorgente `equipment:<slot>`).
- L'arma decide lo **stile** di combattimento (`blade`, `marksmanship`, `arcana`) e l'intervallo d'attacco; senza arma
  si combatte a mani nude (stile `blade`, valori `combat.unarmed`).
- Il cibo scelto si mangia **direttamente dalla bank**: nessuna copia separata.
- Gli attrezzi danno modificatori con ambito della loro skill; si forgiano (Forgiatura) o si comprano.
- Durante il combattimento si può cambiare tutto tranne l'arma (`combat_active`); il cambio di armatura vale subito
  (le statistiche si ricalcolano).

## 10. Combattimento

### 10.1 Struttura
- **Aree** (4 nell'MVP) con una lista di mostri. Il giocatore sceglie area e mostro e avvia; il combattimento è un
  duello ripetuto: ucciso un mostro, dopo `combat.respawn_ms` ne compare uno uguale.
- Il combattimento occupa la corsia principale (ferma l'azione in corso e viceversa).

### 10.2 Stili e triangolo
- Tre stili: **Lama** (`blade`), **Mira** (`marksmanship`), **Arcano** (`arcana`). Il livello della skill dello stile
  dà precisione e danno massimo (F-20, F-22); **Guardia** dà evasione (F-21); **Vitalità** dà punti vita (F-27).
- Triangolo: **Lama batte Arcano, Arcano batte Mira, Mira batte Lama** (F-24). Chi ha il vantaggio fa più danni;
  chi è in svantaggio fa meno danni e la sua riduzione del danno vale meno.

### 10.3 Turni a timer
- Giocatore e mostro hanno ciascuno un timer d'attacco (F-26). Allo scadere, l'attaccante tira la precisione (F-23):
  se colpisce, tira il danno tra minimo e massimo (F-22), applica triangolo e riduzione del danno del bersaglio
  (F-25), toglie i punti vita. Il timer riparte.
- Se nello stesso passo scadono entrambi, attacca prima il giocatore.

### 10.4 Stance ed esperienza
- L'XP si guadagna **per danno inflitto** (danno effettivo, non oltre i PV rimasti del mostro) (F-28):
  `offensive` → skill dello stile; `balanced` → metà stile, metà Guardia; `defensive` → Guardia. Vitalità guadagna
  sempre una quota. Tutto passa da `skill_xp_pct`.
- La stance cambia solo l'XP (nessun bonus nascosto).

### 10.5 Cibo e razioni da campo
- Pulsante "Mangia": consuma 1 cibo scelto e cura `heal × (1 + food_healing_pct/100)` (F-29), senza superare il massimo.
- Razioni da campo (livelli 1-3 dallo shop, stat `auto_eat_tier`): dopo ogni colpo subito, se i PV sono ≤ soglia
  del livello, mangia un pezzo alla volta finché i PV non superano la soglia obiettivo o il cibo finisce (F-30).
- Senza cibo il combattimento continua (rischio di morte).

### 10.6 Bottino
- Alla morte del mostro: oro (F-31) direttamente nel portafoglio; oggetti dalla sua tabella dei drop (ogni voce tira la
  sua probabilità) e frammento del Rift (F-07, probabilità del mostro) nella **borsa del bottino**.
- La borsa ha `combat.loot_bag_base_slots` (12) + `loot_bag_slots` caselle (una per tipo, quantità illimitata). Se è
  piena, gli oggetti nuovi si perdono (notifica).
- "Raccogli tutto" sposta tutto nella bank (ciò che non entra resta nella borsa). Con `auto_loot` ≥ 1 ogni drop va
  direttamente nella bank; se la bank è piena va nella borsa.

### 10.7 Morte
- Se i PV del giocatore arrivano a 0: il combattimento si ferma (`player_died`), **il contenuto della borsa del bottino
  si perde**, i PV tornano al massimo. Equipaggiamento e bank non si toccano.

### 10.8 Stati
`IDLE` → `FIGHTING(area, monster, player_hp, monster_hp, timers)` ⇄ `RESPAWNING(respawn_ms)` → `IDLE`.
I PV del giocatore fuori dal combattimento sono sempre al massimo. Tutto lo stato del combattimento è salvato
(ricaricando, il duello riprende dallo stesso punto).

### 10.9 Casi limite
Cambio di Vitalità o equipaggiamento durante il duello (PV massimi ricalcolati; i PV attuali non superano il nuovo
massimo); mostro con 0 di evasione (vale la formula, con i limiti del 5-95%); danno minimo sempre ≥ 1 dopo la
riduzione; cibo finito; bank piena con raccolta automatica.

## 11. Legatura del Rift e Altare del Rift

**Regole**
- **Frammenti del Rift** (`rift_shard`): cadono con piccola probabilità dalle azioni di raccolta e dai mostri (F-07).
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
- Alla fine: riepilogo con tempo simulato (e se è stato limitato), XP e livelli per skill, oggetti ottenuti e
  consumati, oro, mostri uccisi, morti, cibo mangiato, motivo dell'eventuale stop (es. "Ingredienti finiti alle 3h 12m").
  Poi salvataggio.
- Se `elapsed < offline_min_ms` si simula senza schermata.
- La simulazione si può **non** interrompere nell'MVP (vedi `OPEN_QUESTIONS.md`).

**Casi limite**: orologio indietro (`elapsed = 0`, avviso nel log); azione ferma (si simula comunque il tempo: nulla
succede, il riepilogo lo dice); morte durante l'offline (il combattimento si ferma e il resto del tempo passa a vuoto).

**Requisito di prestazioni**: 12 ore di raccolta o combattimento simulate in meno di 10 s su un PC di sviluppo.

## 13. Feedback e notifiche ("anima visiva")

- Toast in basso a destra (max 4 visibili) per: oggetti ottenuti (raggruppati per 1 s), livello, maestria 99,
  nodo comprato, bank piena, azione fermata, morte, salvataggio fallito.
- Banner centrale al passaggio di livello (Cinzel oro, 2 s).
- Barra di progresso dell'azione con riempimento continuo; piccola esplosione di particelle all'ottenimento di un
  frammento del Rift.
- Numeri del danno sopra le barre dei PV nel combattimento.
- Nessuna emoji nella UI (i font non le hanno).
- Tutto il feedback è puramente visivo: ascolta i segnali dell'EventBus e non cambia lo stato.

## 14. Suggerimenti (M6)

- Carte di suggerimento contestuali (prima azione, bank piena, primo nodo comprabile, primo frammento, prima morte).
  Ogni suggerimento si vede una sola volta **per slot** (`hints.seen` nel salvataggio).

## 15. Modificatori e stat

**Regole**
- Esiste **un solo** sistema di modificatori. Un modificatore è `{stat, value, scope}`; lo scope è `global`,
  `skill:<id>` o `action:<id>`. Le sorgenti sono: equipaggiamento, maestria per oggetto, nodi della maestria, shop,
  prese dell'Altare, fratture (M7).
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
`loot_bag_slots`, `auto_loot`, `auto_eat_tier`. Dopo l'MVP: `parallel_lanes` (M8), `fracture_duration_pct` (M7).

## 16. Impostazioni

Globali (non per slot, perché non sono stato di gioco): modalità finestra, dimensione, scala UI, VSync, limite FPS,
volume, livello dei log. File `user://settings.cfg`. Pannello dal menu e in partita (Esc).

## 17. Fratture del Rift (M7, dopo l'MVP)

- Ogni `fractures.interval_min_ms`-`interval_max_ms` (2-4 ore) di tempo di sessione (online + offline) si apre una
  Frattura casuale da `data/fractures/fractures.json`, per `fractures.duration_ms` (30 min) ×
  `(1 + fracture_duration_pct/100)`.
- Una Frattura applica modificatori globali (sorgente `fracture:<id>`) e/o rende disponibile un mostro speciale
  in un'area. Alla chiusura tutto torna normale. Stato salvato (prossima apertura, frattura attiva, tempo rimasto).

## 18. Azioni in parallelo (M8, dopo l'MVP)

- La stat `parallel_lanes` (base 1) apre una seconda corsia `secondary` per un'azione **non di combattimento**.
- L'azione della corsia secondaria ha intervallo × `(1 + parallel.interval_penalty_pct/100)` (+40%).
- Le due corsie non possono usare la stessa skill; ingredienti presi dalla stessa bank (ordine di risoluzione: corsia
  principale, poi secondaria).
- Il combattimento resta solo nella corsia principale.
