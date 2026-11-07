# Riforma del bottino, degli attrezzi e dei nomi (M10)

Stato: **APPROVATA dall'utente** (2026-11-07). Da fare **prima** di far provare il gioco agli amici. Fonte per il task di
riforma dei documenti R-01 (come R-00 per `VISIONE_V2.md`): dopo R-01 valgono i documenti canonici. I nomi nuovi sono
in `docs/NOMI.md`. I numeri qui sono valori di partenza, da fissare in `02_FORMULAS.md` con esempi e da tarare con
`tools/sim_combat.gd`.

## 1. Perché

Oggi Forgiatura funziona come in Melvor: si forgiano centinaia di pezzi per l'XP, se ne indossa uno e il resto si
smantella. Il pezzo non vale niente. L'utente vuole che **l'equipaggiamento sia fondamentale**: arriva dai mostri o da
**un singolo craft fatto come si deve**. In più i nomi sono ripetitivi e poco chiari.

## 2. Decisioni dell'utente

| # | Decisione |
|---|---|
| R1 | L'equipaggiamento arriva **dai mostri** (fonte principale) o da **un singolo craft**: un **progetto** + molti materiali + un **componente raro**; un progetto = un pezzo; risultato **almeno magico** |
| R2 | Le skill artigiane **non producono più equipaggiamento in serie**: il Fabbro produce **componenti** (lingotti, piastre…) che servono a progetti, raffinazione, attrezzi |
| R3 | **Un attrezzo per mestiere** (accetta, piccone, canna) per tutta la partita, potenziato con la raffinazione **+0…+9**, che **riesce sempre** (il costo basta a frenarla) |
| R4 | Nomi: **classici e diretti** per le cose comuni, **più esotici** per le rare (`docs/NOMI.md`) |

## 3. Il nuovo modello

### 3.1 Fonti dei pezzi
- **Drop dei mostri** (F-84, già in M7): restano la fonte principale; vanno ritarati perché ora devono vestire il
  giocatore da soli (obiettivo: un pezzo utile del proprio grado ogni 20-40 minuti nell'area del proprio livello).
- **Kit iniziale**: una partita nuova parte con spada, spadone e scudo comuni di grado 1 e i 3 attrezzi a +0
  (`start` in `balance.json`). Spariscono gli "attrezzi del novizio" dello shop.
- **Progetti** (craft singolo, §3.2).

### 3.2 Progetti (craft singolo)
- Nuova categoria di oggetto `blueprint`: un progetto indica **base** (modello del pezzo) e **grado**. Cade dai mostri
  (raro) e dalle Pietre del Rift (più spesso), pesato sul grado dell'area.
- Il craft si avvia dalla pagina del Fabbro (sezione "Progetti"): consuma il progetto, i materiali (componenti del
  Fabbro e del Falegname del grado) e **un componente raro** (i drop dei mostri dell'area, es. Nucleo di golem).
- È **un'azione a ciclo unico**: dura a lungo (default Q48: 10 min al grado 1 → 60 min al grado 8), dà molta XP al
  Fabbro, si ferma da sola alla fine. Si può fare offline.
- Risultato: rarità **almeno magica**; probabilità di raro che cresce con il livello del Fabbro; dal livello Q50 il
  giocatore **sceglie un affisso** garantito (grado fisso) prima di avviare il craft.
- Sostituisce F-83 (rarità nell'artigianato).

### 3.3 Il Fabbro e il Falegname
- **Fabbro** (azioni ripetibili, per l'XP): minerale → **lingotto**; lingotti → **piastra** (componente di grado).
  Restano la maestria e i suoi nodi.
- **Falegname**: legno → **impugnatura**, **telaio dello scudo**, **manico** (componenti).
- **Spariscono** le ricette ripetibili di spade, spadoni, armature e scudi (e le loro maestrie per azione).
- Il livello del Fabbro dà un bonus alla **riuscita della raffinazione** delle armi e armature (stat
  `upgrade_success_pct` da una sorgente nuova della skill, con formula e test).
- Lo **smantellamento** (F-88) restituisce componenti (piastre, impugnature) e frammenti, non solo lingotti.

### 3.4 Attrezzi unici
- Tre oggetti unici, uno per mestiere; stanno sempre nello slot del loro mestiere (non si smantellano, non si vendono).
- Raffinazione **+0…+9 sempre riuscita**: costo in componenti del grado del livello, oro e un **livello minimo del
  mestiere** per ogni passo (es. +4 richiede il mestiere al livello 25).
- Ogni + dà `skill_interval_pct` con scope del mestiere e, ai passi alti, un piccolo bonus (`double_item_chance`,
  `rift_shard_chance`). Valori in una tabella di `02_FORMULAS.md`.
- Spariscono i 27 attrezzi a gradi e le loro ricette.

## 4. Correzioni di bilanciamento dalla prova dell'MVP (B1-B5)

| # | Correzione |
|---|---|
| B1 | **Livello del personaggio troppo veloce**: oggi una notte offline porta dal 50 al 95. Obiettivo: livello 99 in circa **300 ore** di combattimento nell'area giusta (offline compreso); 50 → 60 in una notte. Si interviene su XP per uccisione (Q41) e/o `character_curve`, tarando con `sim_combat` |
| B2 | **Razioni da campo I gratuite** dall'inizio (cambia Q12); avviso se si avvia un combattimento senza cibo scelto |
| B3 | Riepilogo offline: "morto (dopo 0 s)" mostra il tempo vero della morte |
| B4 | Il **primo suggerimento** porta al combattimento (con il kit iniziale), non alla raccolta |
| B5 | Più livelli in un colpo: **un solo toast** ("Boscaiolo: livello 2 → 5"), non uno per livello |

## 5. Domande aperte nuove (vale il default)

| # | Domanda | Default |
|---|---|---|
| Q48 | Durata del craft di un progetto | 10 min al grado 1, +7 min per grado (60 min al grado 8) |
| Q49 | Frequenza dei progetti | circa 1 progetto all'ora nell'area del proprio livello; 1 su 3 Pietre del Rift |
| Q50 | Livello del Fabbro per scegliere un affisso | 50 |
| Q51 | Kit iniziale | spada, spadone, scudo comuni di grado 1 + 3 attrezzi a +0 + 20 pesci cotti di grado 1 |
| Q52 | Gli id interni cambiano con i nomi? | No: cambiano solo i nomi visibili (`name`, `description`); gli id restano |

## 6. Proposta di milestone (da R-01 in `07_TASKS.md`)

M10 diventa **"Riforma del bottino e dei nomi"**; le mappe passano a M11, le corsie parallele a M12, il resto a M13+.

| ID | Titolo | Ruolo |
|---|---|---|
| R-01 | Riforma dei documenti da questo file e da `NOMI.md` | REV |
| M10-01 | Schema e validatore: `blueprint`, attrezzi unici, componenti, `start` nuovo | CORE |
| M10-02 | Progetti: craft a ciclo unico, rarità minima, affisso scelto | CORE |
| M10-03 | Attrezzi unici con raffinazione sempre riuscita; bonus del Fabbro alla raffinazione | CORE |
| M10-04 | Contenuti: ricette di Fabbro e Falegname a componenti, progetti, tabella degli attrezzi, drop ritarati, kit iniziale | DATA |
| M10-05 | Nomi nuovi in tutti i dati e i testi UI (`NOMI.md`), "Bank" → "Deposito" | DATA |
| M10-06 | UI: sezione Progetti nella pagina del Fabbro, raffinazione degli attrezzi | UI |
| M10-07 | Bilanciamento B1-B5 con `sim_combat` (anche offline) | COMBAT/QA |
| M10-08 | Test di M10 | QA |
| M10-09 | Integrazione, tag `m10-done` | REV |

## 7. Accettazione della milestone
- Nessuna ricetta produce equipaggiamento in serie; i pezzi arrivano da drop, kit iniziale e progetti.
- Un progetto produce un solo pezzo, almeno magico; con il Fabbro al livello Q50 si sceglie un affisso.
- Tre attrezzi unici, raffinazione +0…+9 sempre riuscita, requisiti di livello rispettati.
- Tutti i nomi visibili seguono `NOMI.md`; nessun "Bank" nella UI.
- `sim_combat`: livello 99 in 250-350 h; una notte offline nell'area giusta non supera +12 livelli dopo il 50.
- Salvataggi dell'MVP: `format_version` aumenta; un salvataggio v-precedente è "versione non supportata" (nessun
  giocatore reale ancora).
