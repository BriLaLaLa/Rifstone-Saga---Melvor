# Alpha: equipaggiamento vero, wiki a scoperta, maestria, ritocchi (M14)

Stato: **APPROVATA dall'utente** (2026-11-09), dalla sua prova del gioco. Obiettivo: **alpha giocabile** entro
giovedì. Fonte per il task R-05 (come R-04); dopo R-05 valgono i documenti canonici. Numeri = valori di partenza
(Q66-Q74), da fissare in `02_FORMULAS.md` con esempi e da tarare con la sim. Clean room: da Metin2, World of
Warcraft e Path of Exile si prendono i **criteri**, mai nomi, tabelle o testi.

Criteri presi dalla ricerca:
- **Metin2**: un set nuovo ogni 5-10 livelli; armi con attacco minimo e massimo; valori per tipo d'arma; raffinazione
  +0…+9; più bonus per oggetto.
- **World of Warcraft**: rarità a colori con più bonus quanto più è rara; armi con danno minimo-massimo, velocità e
  danno al secondo; armature di materiali diversi; pezzi artigianali con statistiche fisse; leggendari "un gradino
  sopra" tutto.
- **Path of Exile**: oggetti unici che cambiano le regole del gioco.

## 1. Decisioni dell'utente

| # | Decisione |
|---|---|
| Y1 | L'equipaggiamento è il cuore del gioco e oggi è troppo basico: va reso interessante |
| Y2 | **Armi** con **danno minimo-massimo** e **velocità d'attacco** proprie; **armature** con **Armatura** (riduce in % il danno fisico) e, su alcune, **Barriera** (riduce il danno magico/arcano) |
| Y3 | **Più modelli e più gradi**, come Metin2 |
| Y4 | I **progetti** creano un pezzo **diverso** dai drop, con **statistiche base fisse** più alte e **meno affissi**, a **costo alto** |
| Y5 | **Leggendari**: almeno **3-4 per slot**, attrezzi compresi (accetta, piccone, canna), che **cambiano le regole** |
| Y6 | **Drop di equipaggiamento più frequenti**: abbastanza rari, ma "una quantità discreta ogni mezz'ora" |
| Y7 | **Wiki a scoperta**: gli oggetti non dicono più "dove si droppa"; la Guida sblocca oggetto, fonte e % la prima volta che lo ottieni; la pagina del mostro/attività mostra tutto ciò che dà, bloccato finché non lo trovi |
| Y8 | **Maestria** ripensata per tutte le attività: deve essere chiaro e utile salire di maestria |
| Y9 | Ritocchi UI (§7) |

## 2. Equipaggiamento (Y1-Y6)

### 2.1 Gradi (Y3)
**15 gradi** con requisito di livello del personaggio: 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90
(Q66). Ogni slot ha **un modello per grado** (nomi nuovi in `NOMI.md`, classici in basso ed esotici in alto); i materiali
dei progetti seguono i gradi esistenti (più gradi di pezzo per grado di materiale).

### 2.2 Armi (Y2)
- Ogni modello ha **danno minimo e massimo** propri e **velocità d'attacco** (intervallo) propria; la scheda mostra
  anche il **danno al secondo**.
- Spada: più rapida, danno medio. Spadone: lento, danno alto. Il danno dell'arma sostituisce `power_bonus` come base
  del colpo (F-22 rivista); livello del personaggio e affissi lo modificano.
- Doppia spada: ogni colpo usa il danno dell'arma che colpisce (già così).

### 2.3 Armature (Y2)
- Tre **materiali** per tutte le armature (elmo, corpo, gambe, piedi, mani, scudo):
  - **Piastre**: Armatura alta, niente Barriera;
  - **Cuoio**: Armatura media, Schivata;
  - **Tessuto runico**: Armatura bassa, **Barriera** alta.
- **Armatura** → riduzione % del danno **fisico** (mostri di Lama e Mira) con rendimenti decrescenti:
  `rid = A / (A + k × livello del mostro)` (Q67), al massimo 75%.
- **Barriera** → la stessa formula sul danno **arcano** (mostri di Arcano), stat nuova `barrier`.
- La vecchia "riduzione del danno" piatta diventa l'Armatura (migrazione dei dati, nessuno stato del giocatore da
  migrare: salvataggio incompatibile, `format_version` +1).

### 2.4 Rarità
| Rarità | Colore | Affissi | Fonte |
|---|---|---|---|
| Comune | bianco | 0 | drop |
| Magico | blu | 1-2 | drop |
| Raro | giallo | 3-4 | drop |
| **Capolavoro** | viola | **1-2** (uno scelto dal Fabbro al livello 50) + **statistiche base +25%** fisse | **solo progetti** |
| **Leggendario** | arancione | effetto unico + statistiche fisse | boss delle Fratture, Monoliti, boss rari |

### 2.5 Progetti (Y4)
- Un progetto crea un **Capolavoro**: modello con nome proprio (diverso dai drop), statistiche base fisse più alte,
  1-2 affissi, più un castone.
- **Costo alto** (Q68): circa 3× i materiali di oggi più 2 componenti rari diversi; durata invariata.

### 2.6 Leggendari (Y5)
- **3-4 per slot**: elmo, corpo, gambe, piedi, mani, collo, anello, spada, spadone, scudo, accetta, piccone, canna
  (≈ 45 leggendari; per l'alpha almeno 3 per slot).
- Ognuno ha statistiche fisse e **un effetto che cambia le regole**, costruito sui **tipi di effetto dei tratti** e sui
  modificatori (nessun sistema nuovo). Esempi di **regole** (nomi da `NOMI.md`):
  - spadone: ogni uccisione fa partire subito il prossimo attacco;
  - scudo: una parata riuscita restituisce il 10% dei PV;
  - anello: il bottino dei Monoliti è raddoppiato;
  - canna: il 10% delle catture dà un pesce del grado superiore;
  - piccone: ogni minerale ha il 5% di dare una Scheggia.
- **Fonte di ogni leggendario dichiarata nei dati** (un boss, un Monolito, un grado di Frattura) e mostrata nella wiki a
  scoperta.

### 2.7 Drop (Y6)
- Ogni mostro può far cadere **tutti gli slot** del grado della sua area, non 1-2 modelli fissi.
- Obiettivo (sim, Q69), nell'area del proprio livello: **3-5 pezzi ogni 30 minuti**, circa **1 magico ogni 30 minuti**,
  **1 raro ogni 2-3 ore**; leggendari ~1 ogni 15-30 ore di Fratture del grado giusto.

## 3. Wiki a scoperta (Y7)

- Il tooltip e la scheda dell'oggetto **non** mostrano più "Si ottiene da" (resta "Serve a").
- Nuovo stato per slot: **scoperte** (oggetti ottenuti almeno una volta, fonti viste).
- Nella Guida:
  - un oggetto **non ancora ottenuto** appare come casella bloccata ("???", icona in ombra);
  - ottenuto la prima volta: si sblocca la pagina con **da dove si ottiene** (mostro, area, attività) e la **% base**;
  - la pagina del **mostro** o dell'**attività** mostra **tutto ciò che può dare** come caselle, bloccate finché non le
    trovi; sbloccate mostrano la %.
- Le meccaniche (testi) restano sempre visibili.

## 4. Maestria (Y8)

Vale per raccolta e artigianato. Oggi i bonus esistono ma non si vedono e sono piccoli.
- Ogni **10 livelli** di maestria di un'azione: un bonus **visibile** di quell'azione (raccolta: −2% intervallo e +1%
  prodotto doppio; artigianato: +2% conservazione degli ingredienti e −2% intervallo) (Q70).
- I traguardi 25/50/99 restano (sottoprodotto, bonus della risorsa, bonus del mestiere).
- La carta dell'azione mostra: livello di maestria, **bonus attuali** e **prossimo bonus** ("al livello 40: −2%
  intervallo").
- Artigianato: la maestria della ricetta aumenta anche la probabilità di raro nei progetti (già previsto per il Fabbro).

## 5. Polvere del Rift

Oggi ne cade troppa (≈150/h nelle Pianure) per un solo uso. Drop ridotto (Q71: 8% per uccisione) e **altri usi**:
raffinazione dal +5 in su, borse rinforzate e oltre, Cristalli. Il tooltip dice "Serve a" chiaramente.

## 6. Fratture (dalla verifica di M13)

- Carte rare di grado basso troppo punitive con 3 modificatori: tetto alla somma dei rischi per grado (Q72).
- Le carte della pagina Fratture più basse (modificatori su una riga ciascuno, compatti).

## 7. Ritocchi UI (Y9)

| Dove | Ritocco |
|---|---|
| Combattimento | **barra XP del personaggio**; "In fila" → **"Altri nemici"**; etichetta del triangolo: "**Forte contro di te**" / "**Debole contro di te**" / "**Alla pari**" |
| Shop | descrizioni con i **numeri** dai dati (PV curati, %, effetti) |
| Incisore | **sottoschede**: Lastre, Fondere, Cristalli, Rune |
| Fabbro | **sottoschede**: Lingotti, Piastre, Progetti, Banco del fabbro |
| Deposito | pulsante **Riordina** |
| Equipaggiamento | scheda dell'arma con danno minimo-massimo, velocità e danno al secondo; armature con Armatura/Barriera; colori viola e arancione |

## 8. Domande aperte nuove (vale il default)

| # | Domanda | Default |
|---|---|---|
| Q66 | Gradi e livelli | 15 gradi: 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90 |
| Q67 | Formula di Armatura e Barriera | `A / (A + k × livello)`, `k` da tarare, massimo 75% |
| Q68 | Costo dei progetti | ≈ 3× i materiali attuali + 2 componenti rari |
| Q69 | Obiettivi di drop | §2.7 |
| Q70 | Bonus di maestria ogni 10 livelli | §4 |
| Q71 | Drop di Polvere del Rift | 8% per uccisione, 1 pezzo |
| Q72 | Tetto ai rischi delle Carte | somma dei rischi ≤ 40% al grado 1, +10% per grado |
| Q73 | Numero di leggendari per l'alpha | 3 per slot (39), 4 dove avanza tempo |
| Q74 | Barriera su quali armature | solo Tessuto runico (alta) e Cuoio (bassa) |

## 9. Milestone M14 (R-05 la porta in `07_TASKS.md`; ordine A → C → B → D)

| ID | Titolo | Ruolo |
|---|---|---|
| R-05 | Documenti da questo file; `NOMI.md` (modelli dei 15 gradi, materiali delle armature, Capolavori, leggendari) | REV |
| M14-01 | Armi: danno minimo-massimo e velocità per modello; F-22 rivista | COMBAT |
| M14-02 | Armature: materiali, Armatura e Barriera (stat nuova, formula, registro, test) | COMBAT |
| M14-03 | Rarità Capolavoro e Leggendario; progetti che creano Capolavori; costo alto | CORE |
| M14-04 | Leggendari: effetti sui tipi di effetto dei tratti, fonti dichiarate | CORE |
| M14-05 | Contenuti: 15 gradi × slot, materiali, Capolavori, ≥ 39 leggendari, drop di tutti gli slot, Polvere ridotta | DATA |
| M14-06 | Ritocchi UI §7 e scheda dell'oggetto nuova | UI |
| M14-07 | Wiki a scoperta: stato per slot, Guida con caselle bloccate, tooltip senza "Si ottiene da" | CORE + UI |
| M14-08 | Maestria visibile e bonus ogni 10 livelli | CORE + UI |
| M14-09 | Fratture: tetto ai rischi, carte compatte | DATA + UI |
| M14-10 | Bilanciamento con la sim (drop §2.7, armature, leggendari, progetti) e test | QA |
| M14-11 | Integrazione, tag `m14-alpha` | REV |

## 10. Accettazione

- Armi con danno minimo-massimo, velocità e danno al secondo; armature con materiali, Armatura % e Barriera %.
- 15 gradi per slot; Capolavori solo da progetti; ≥ 3 leggendari per slot (attrezzi compresi), ognuno con un effetto
  che cambia una regola e una fonte dichiarata.
- Sim: 3-5 pezzi ogni 30 minuti nell'area giusta, 1 magico/30 min, 1 raro ogni 2-3 h.
- Guida a scoperta: oggetti e drop bloccati finché non trovati; nessun "Si ottiene da" nei tooltip.
- Maestria: bonus visibili e prossimo bonus su ogni carta.
- Tutti i ritocchi di §7.
