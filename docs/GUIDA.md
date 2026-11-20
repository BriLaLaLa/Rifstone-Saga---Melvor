# Guida in gioco (M11)

> Superato da R-02: valgono i documenti canonici (`01_GDD.md` §27, `04_DATA_SCHEMA.md` §19, `05_INTERFACES.md` §5.19/§7.y, `06_ROADMAP.md`, `07_TASKS.md`).
>
> **M24 (Incontri e Mestieri, allineato da M24-08)**: i mestieri sono **discipline** da imparare dai Maestri; pagine a mano nuove "Mestieri e Maestri"
> (`guide_disciplines`, tabella `trainer_grades`, aiuto della rotta `trainers`) e "Viaggio e nodi" (`guide_travel`) in `data/guide/mestieri.json`
> e `primi_passi.json`; pagina dell'Erborista e delle Ricette come per gli altri mestieri e oggetti. Le pagine e le tabelle degli aiutanti e dei Contratti sono
> eliminate. La regola "nessun numero scritto a mano" vale anche qui: "cinque gradi" è stato tolto dal testo (la tabella dai dati li elenca).
>
> **M26 (Alpha 2, allineato da M26-12)**: pagine a mano nuove "Professioni" (`guide_professions`: colori delle ricette e avanzamento) e "Mercanti"
> (`guide_merchants`: schemi, reagenti, botteghe) in `data/guide/professioni.json`. **Da fare** (dati, non in M26): la pagina "Casa d'Aste" (`guide_auction`, `casa_aste.json`) non parla
> ancora di compratori, venditori e domanda (§38.8 la chiede aggiornata); il testo attuale resta corretto ma incompleto. Le ricette non si conoscono più solo per livello (`01_GDD_M26.md` §38.1-§38.3). Nomi di schemi e reagenti in `NOMI.md`; nessun numero copiato.
>
> **M27 (Casa d'Aste v2, allineato da M27-10)**: pagine a mano nuove "Monete" (`guide_coins`, `data/guide/monete.json`: rame, argento, oro) e "Posta"
> (`guide_mail`, `posta.json`); "Casa d'Aste" (`guide_auction`) aggiornata da M27-08 (libro delle inserzioni, Metti in vendita, Vendi subito per Posta, Le mie inserzioni). Il denaro
> nei testi si scrive "monete" e gli importi arrivano da `Money.text`; ogni pagina ≤ 160 parole (`test_guide_texts`). Altre pagine di meccanica: `data/guide/*.json` (17 file).

Stato: **APPROVATA dall'utente** (2026-11-08). Nasce dalla prova dell'utente: "tante cose non si capiscono cosa
facciano". Ispirazione: la **struttura** delle wiki dei giochi idle (pagina per mestiere, oggetto, mostro, meccanica),
mai i testi. Fonte per il task di riforma dei documenti R-02; dopo R-02 valgono i documenti canonici.

## 1. Decisioni dell'utente

| # | Decisione |
|---|---|
| G1 | La wiki è **dentro il gioco** (pagina "Guida"), non un sito esterno |
| G2 | Viene **prima delle mappe**: M11 = Guida, M12 = mappe, M13 = corsie parallele, M14+ il resto |

## 2. Principi

- **Generata dai dati**: tabelle, drop, ricette, statistiche e numeri si leggono da `data/` (e da `balance.json`,
  `stats.json`) a ogni apertura. Nessun numero ricopiato nei testi: un testo cita un valore con un segnaposto
  (es. `{balance:offline.cap_ms|ore}`) che la Guida sostituisce.
- **A mano** si scrivono solo i testi delle meccaniche e dei primi passi (`data/guide/*.json`, in italiano).
- **Logica separata dalla UI**: l'indice "da dove viene / a cosa serve" è una classe in `core/` o `systems/`, testata.
- Ogni oggetto, mostro, area, mestiere, stat, tratto e abilità ha **la sua pagina**: un test lo verifica.

## 3. Struttura

Pagina **Guida** nella sidebar (sezione Partita), con indice a sinistra, contenuto a destra, **ricerca** in alto e
cronologia (indietro).

| Sezione | Pagine | Origine |
|---|---|---|
| Primi passi | la prima ora: combattere, mangiare, raccogliere il bottino, equipaggiare, i mestieri | testo a mano |
| Personaggio e combattimento | livello, assetti, triangolo, tratti, abilità, cibo e Razioni, morte e borsa del bottino, gruppi e bersaglio | testo a mano + tabelle dai dati (tratti, abilità con sblocco e ricarica) |
| Bottino | rarità, affissi (tabella dei gradi), raffinazione (tabella dei costi e delle probabilità), castoni e pietre, valute, smantellamento e filtro, Pietre del Rift, progetti | testo a mano + tabelle dai dati |
| Mestieri | una pagina per mestiere: cosa fa, tabella delle azioni (livello, XP, durata, ingredienti, prodotto), maestria e nodi, attrezzo e sua raffinazione | testo breve a mano + tabelle dai dati |
| Oggetti | una pagina per oggetto: descrizione, valore, **Si ottiene da** (mostri con area e %, ricette, shop, Pietre, smantellamento, kit iniziale), **Serve a** (ricette, progetti, raffinazione, castoni, Altare, cibo) | tutto dai dati |
| Mostri e aree | area: livello richiesto, gruppi, mostri; mostro: statistiche, stile, intervallo, drop con % | tutto dai dati |
| Altare del Rift | prese, livelli di sblocco, infusioni con effetto | dai dati + testo breve |
| Statistiche | glossario: nome, descrizione, limiti (da `stats.json`) | dai dati |
| Offline | come funziona, limite di ore, cosa prosegue e cosa no | testo a mano con segnaposto |

Elenco minimo dei testi a mano (≈ 20 pagine brevi): Primi passi; Livello del personaggio; Assetti; Triangolo; Tratti;
Abilità; Cibo e Razioni; Morte; Gruppi e bersaglio; Rarità e affissi; Raffinazione; Castoni e pietre; Valute;
Smantellamento e filtro; Pietre del Rift; Progetti; Maestria; Attrezzi; Altare del Rift; Offline.

## 4. Collegamenti, "?" e tooltip

- **Collegamenti**: ogni nome di oggetto, mostro, area, mestiere, stat, tratto o abilità nella Guida è cliccabile e
  apre la sua pagina.
- **Pulsante "?"** nell'intestazione di ogni pagina del gioco (Combattimento, Equipaggiamento, Personaggio, Altare,
  Deposito, Shop, pagine dei mestieri): apre la pagina di Guida pertinente.
- **Tooltip degli oggetti**: due righe in fondo, "Si ottiene da: …" e "Serve a: …" (al massimo 3 voci ciascuna,
  poi "e altro"), dallo stesso indice della Guida.
- **Tooltip delle stat** (statistiche del personaggio e dell'equipaggiamento): la descrizione da `stats.json`.

## 5. Proposta di task (R-02 li porta in `07_TASKS.md`)

| ID | Titolo | Ruolo |
|---|---|---|
| R-02 | Riforma dei documenti da questo file; roadmap M11 Guida, M12 mappe, M13 corsie, M14+ | REV |
| M11-01 | Indice "da dove viene / a cosa serve" per ogni oggetto (drop, ricette, progetti, shop, Pietre, smantellamento, kit, raffinazione, castoni, Altare, cibo) | CORE |
| M11-02 | Schema e validatore di `data/guide/*.json` (pagine, sezioni, segnaposto verso `balance.json`/`stats.json`, collegamenti verso id esistenti) | CORE |
| M11-03 | Testi delle ≈ 20 pagine a mano e dei primi passi | DATA |
| M11-04 | Pagina Guida: indice, contenuto generato, ricerca, collegamenti, indietro | UI (L) |
| M11-05 | Pulsanti "?" nelle pagine e righe "Si ottiene da / Serve a" nei tooltip; tooltip delle stat | UI |
| M11-06 | Test: ogni entità ha una pagina, nessun collegamento rotto, nessun segnaposto non risolto, nessun numero scritto a mano nei testi | QA |
| M11-07 | Integrazione, tag `m11-done` | REV |

## 6. Accettazione

- La Guida si apre dalla sidebar; ricerca per nome; ogni nome è un collegamento; "indietro" funziona.
- Ogni oggetto, mostro, area, mestiere, stat, tratto e abilità ha la sua pagina (test).
- Ogni oggetto mostra "Si ottiene da" e "Serve a"; un oggetto senza fonte o senza uso è segnalato dal test (salvo
  eccezioni dichiarate nei dati).
- Nessun numero scritto a mano nei testi: i valori arrivano dai segnaposto (test).
- Ogni pagina del gioco ha il suo "?".
- Testi in italiano, chiari, al massimo ~150 parole per pagina di meccanica; nomi da `docs/NOMI.md`.
- Layout a 1600×900 e 1280×720.

> **M28 (Abilità e tratti v2, allineato da M28-10)**: pagina a mano nuova "Condizioni" (`data/guide/condizioni.json`, sezione `character`: Sanguinamento, Fiacchezza, Breccia, Sbilanciamento, Riparo),
> collegata dalle pagine Tratti e Abilità; i testi dei 31 tratti e delle 19 abilità vengono da `LoadoutDescribe` (nessun numero scritto a mano). Ogni pagina ≤ 160 parole.
