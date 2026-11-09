# Fratture come mappe (M13)

Stato: **APPROVATA dall'utente** (2026-11-09). Sostituisce `01_GDD.md` §17 (Frattura casuale ogni 2-4 ore: **eliminata**).
Fonte per il task R-04; dopo R-04 valgono i documenti canonici. Idea delle mappe di Path of Exile adattata a un idle;
nomi e numeri originali. Numeri = valori di partenza, da fissare in `02_FORMULAS.md` con esempi e da tarare con la sim.

## 1. Decisioni dell'utente

| # | Decisione |
|---|---|
| X1 | La Frattura si apre **quando vuole il giocatore**, usando una **Carta della Frattura**; nessun timer, nessuna apertura casuale |
| X2 | Carte di **grado 1-10**; le Carte di grado più alto cadono soprattutto **dalle Fratture stesse** |
| X3 | **Boss** alla fine di ogni Frattura, già in M13 |
| X4 | **Se muori perdi tutto quello della Frattura**: la Carta e tutto il bottino raccolto dentro (Deposito ed equipaggiamento non si toccano) |

## 2. La Carta della Frattura

- Oggetto (`category: map`) con **grado** (1-10) e **rarità** come i pezzi: comune (0 modificatori), magica (1-2),
  rara (3-4). Ogni Carta è un'istanza (come i pezzi), con i suoi modificatori.
- **Fonti**: drop dei mostri delle aree (gradi 1-3, dipende dall'area), Monoliti (gradi 1-4), **Fratture** (stesso grado
  o +1, raramente +2; il boss ha una probabilità alta).
- **Modificatori** (tabella in `data/maps/map_mods.json`, solo stat del registro o regole del motore): ognuno ha un
  **rischio** e un **premio**. Esempi: "Mostri robusti" (+40% PV dei mostri; +10% quantità del bottino), "Assalto"
  (attacchi dei mostri più rapidi; +rarità), "Fame" (il cibo cura meno; +progetti), "Orde" (gruppi più numerosi;
  +XP), "Impulsi" (danno periodico come i Monoliti; +Polvere del Rift).
- I **Cristalli** funzionano anche sulle Carte: risveglio (comune → magica), ascesa (magica → rara), mutamento
  (rifà i modificatori). Lo **smantellamento** di una Carta dà Polvere del Rift.

## 3. La Frattura

- Si apre dalla pagina **Fratture** ("Apri") consumando la Carta. Occupa la corsia del combattimento (ferma il
  combattimento normale e l'azione del giocatore; gli aiutanti continuano).
- Contenuto: **N gruppi** (default 30, Q63) di mostri del grado della Carta (mostri delle aree scalati per grado),
  poi il **boss**. Il motore a gruppi è lo stesso; i modificatori si applicano a mostri e ricompense.
- **Bottino della Frattura**: va in una **borsa della Frattura** separata (non nel Deposito) fino alla fine.
  - Vittoria sul boss: tutto passa nel Deposito (ciò che non entra resta in attesa, come la borsa del bottino).
  - **Morte: si perde la Carta e tutta la borsa della Frattura** (X4). Si torna fuori con i PV pieni.
  - "Abbandona" (comando del giocatore): come la morte, con conferma.
- Funziona **anche offline**, con il motore a eventi; il riepilogo dice com'è finita.
- Una sola Frattura alla volta.

## 4. Il boss

- Un mostro grande per grado (o per gruppi di gradi), con PV e danni alti e **una abilità propria** semplice
  (es. colpo ad area ogni N s, scudo temporaneo, evocazione di un piccolo gruppo). Nessuna meccanica a fasi in M13.
- Ricompense garantite: un pezzo almeno magico del grado, Polvere del Rift, e un'alta probabilità di Carta di grado +1.

## 5. Scala dei gradi

- Grado 1 ≈ difficoltà delle Miniere; grado 10 ≈ ben oltre la Soglia (fine gioco).
- Il livello degli oggetti caduti (`ilvl`) cresce con il grado: le Fratture diventano la fonte dei pezzi migliori.
- Obiettivo di bilanciamento (sim): un personaggio ben equipaggiato del livello giusto completa una Frattura in
  15-30 minuti e ottiene in media ~1 Carta dello stesso grado o superiore per Frattura (la scala non si interrompe, ma
  i gradi alti si raggiungono solo migliorando il personaggio).

## 6. UI

Pagina **Fratture** nella sidebar (Partita): elenco delle Carte nel Deposito (grado, rarità, modificatori con rischio
e premio), "Apri"; durante la Frattura: avanzamento (gruppo N/30, boss), borsa della Frattura, "Abbandona". La
pagina Combattimento mostra la Frattura in corso come un'area speciale. Guida: pagina "Fratture" nuova.

## 7. Domande aperte nuove (vale il default)

| # | Domanda | Default |
|---|---|---|
| Q63 | Gruppi per Frattura | 30 più il boss |
| Q64 | Probabilità di Carte da mostri, Monoliti, Fratture, boss | tarate per l'obiettivo di §5 |
| Q65 | Modificatori per rarità e tabella iniziale | comune 0, magica 1-2, rara 3-4; ~12 modificatori |

## 8. Proposta di milestone (R-04 la porta in `07_TASKS.md`)

| ID | Titolo | Ruolo |
|---|---|---|
| R-04 | Documenti da questo file (GDD §17 riscritto, formule, schema, contratto, Q63-Q65, X1-X4, roadmap) | REV |
| M13-01 | Carte: oggetto a istanza, gradi, rarità, modificatori, cristalli, smantellamento | CORE |
| M13-02 | Motore della Frattura: N gruppi + boss, modificatori, borsa della Frattura, morte/abbandono, offline | COMBAT |
| M13-03 | Boss con abilità propria | COMBAT |
| M13-04 | Contenuti: modificatori, boss, drop delle Carte, scala dei mostri per grado | DATA |
| M13-05 | UI: pagina Fratture, Frattura in corso in Combattimento, Guida | UI |
| M13-06 | Bilanciamento con la sim (§5) e test | QA |
| M13-07 | Integrazione, tag `m13-done` | REV |

## 9. Accettazione

- Nessuna apertura automatica: una Frattura si apre solo usando una Carta.
- Carte 1-10 con rarità e modificatori; i Cristalli funzionano sulle Carte.
- Ogni Frattura ha N gruppi e un boss; vittoria = bottino nel Deposito; morte o abbandono = Carta e borsa della
  Frattura perse.
- Funziona offline; il riepilogo lo racconta.
- Sim: 15-30 minuti per Frattura nel grado giusto; la scala dei gradi non si interrompe.
