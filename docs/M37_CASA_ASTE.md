# M37: Casa d'Aste più bella e comoda, proposta (DESIGN, in attesa delle scelte dell'utente)

> **Esito (2026-11-24)**: l'utente ha scelto: ambito must + should (A, C, idea 4, 5a, storico; 3a/3b, 6, B, D, E, F, G); sottogruppi dei materiali in M38; avvisi dopo; ordini fuori; storico 50 voci con scadute e annullate; nessuna conferma d'acquisto; niente filtro rarità. Design in `01_GDD_M37.md` §45, V47, Q237-Q245, `07_TASKS_M37.md`.
Richiesta dell'utente: «secondo te, come potremmo migliorare la casa d'aste per renderla più bella da usare?». Documento di proposta: nessuna regola è ancora in
GDD/formule. Dopo le scelte: V in `DECISIONS_LOG.md`, Q in `OPEN_QUESTIONS.md`, GDD, F-xx con esempi (= test), schema, `05_INTERFACES_M37.md`, `07_TASKS_M37.md`.

## 1. Stato attuale (letto dal codice, non dallo STATUS)
Pagina `ui/pages/auction/` (`auction_page.gd` 266 righe + 8 file): tre schede in alto (**Compra / Vendi / Le mie inserzioni**), corpo a tre colonne (albero categorie con
ricerca per nome, `AuctionList` con 5 colonne ordinabili, `AuctionDetail` a colonna unica con scroll). Modello: `AuctionHouse` (facciata), `AuctionPricing` (prezzi, scorte,
tendenza, popolazione), `AuctionListings` (inserzioni del giocatore), `AuctionView`, `MailBox` (ricavi per Posta). 130 oggetti trattati; 13 categorie.

**Correzione al contesto**: «Le mie vendite» non è del tutto assente. Dopo M27 esiste la scheda **«Le mie inserzioni»** (`auction_mine.gd`: oggetto, venduti/totale, prezzo,
tempo, stato in vendita/superata/venduta in parte, Annulla). Manca solo lo **storico** (cosa si è venduto e per quanto): le vendite finite vivono solo come messaggi in Posta
(`auction_sold`/`auction_sale`, uniti per oggetto) e spariscono quando si ritirano.

Già presenti, da non rifare: ricerca per nome, ordinamento a clic su 5 colonne (Oggetto, Posseduti/Disponibili, Prezzo, Tendenza, Al Deposito) con ▲▼, scorciatoie quantità
1/10/100/Tutti, totale previsto, motivo del rifiuto sul pulsante, libro delle inserzioni (NPC + tue), compratori/venditori/domanda, prezzo consigliato, durata, deposito e netto.

## 2. Difetti visibili (letti dal codice; da confermare a schermo)
1. **Detail panel troppo lungo**: nella scheda Vendi una sola colonna impila icona, prezzo, libro, quantità, scorciatoie, totale, «Vendi subito», nota, form di inserzione e
   blocco mercato. Il pulsante e l'esito (`MessageLabel`, in fondo allo `stack`, fuori dallo scroll) stanno lontani. Due azioni diverse (Vendi subito / Metti in vendita) si
   contendono la stessa quantità senza separazione chiara.
2. **Colonna Prezzo da 70 px** (`AuctionRow.PRICE_WIDTH`) per testi tipo «12g 34s 56c»: rischio di taglio o allargamento a 1280x720; tendenza da 92 px solo testo + freccia.
3. **Prezzo della riga ambiguo**: in Vendi è il prezzo di 1 pezzo con la saturazione attuale, non il ricavo medio per `qty`; nessun confronto con il valore base.
4. **Tendenza**: «Stabile» in `GOLD` su fondo scuro (contrasto basso, già annotato); `ScrollbarGap` di 14 px è un cerotto per il pulsante/colonna attaccato alla scrollbar.
5. **Bordi da 1 px persi a 1280x720** (scala 0,8 di tutta la UI): la riga selezionata (bordo 1 px) quasi non si vede; serve riempimento + barra laterale da 3 px, non solo bordo.
6. **Selezione persa** al cambio scheda (`_selected = &""`); nessun ricordo dell'ultima categoria/ordinamento tra Compra e Vendi.
7. **Nessun colore di rarità/fascia**: tutte le righe sono uguali; «fascia di valore» (`AuctionPopulationBand`, F-172) non mostrata nel dettaglio.
8. **Scheda «Le mie inserzioni»** a righe di testo con colonne fisse (170+90+190+100+150): nessuna icona, nessuna selezione, nessun totale («in vendita per X», «incasso atteso»).
9. Categorie in ordine **alfabetico** invece che d'uso; «Materiali» (grezzi, lingotti, pesci, erbe… tutti insieme) è un elenco unico.

## 3. Le idee, una per una
Legenda: **S**olo UI · **C**ORE (calcolo nuovo nel modello, testabile con F-xx) · **D**ati (JSON/generatore) · **già** = già disponibile. Taglia del task: S/M/L.

| # | Idea | Dato / calcolo | Save | Economia | Priorità | Taglia |
|---|---|---|---|---|---|---|
| 1 | **Storico vendite** («Le mie vendite» = inserzioni attive + vendute + ritirate) | Attive: **già** (`my_listings`). Vendute/scadute: **C**: `AuctionHistory` (ultimi N=50 eventi `{item, qty, unit, block, kind}`), scritto da `AuctionListings.process_block` / `sell` / `cancel_listing` | **additivo**: chiave `auction.history`, v12→v13 con default vuoto | nessuna fonte di oro nuova (registra soltanto) | **must** (colma il buco annotato) | M |
| 2 | **Sottogruppi dei materiali** | **D**: campo `group` opzionale in `auction_items.json` (generato da `tools/gen_auction.gd` dalla disciplina che produce l'oggetto: Legni, Minerali, Lingotti, Pesci, Erbe, Carni, Pelli…); `ItemDef` **non** cambia; validatore | nessuno | nessuna | should | M |
| 3a | **Filtri**: «solo ciò che posso usare», livello, rarità | **S** per «Posseduti > 0» e «Comprabili ora» (oro ≥ prezzo): **già**. «Posso usare»/livello: solo per equipaggiamento via `EquipInfo.requirements` (**già**, ma pochi oggetti); **rarità non esiste** su `ItemDef` (solo i pezzi unici dell'Armeria, non scambiati) → **proposta: niente filtro rarità**, al suo posto filtro per gruppo (idea 2) | nessuno | nessuna | should | S |
| 3b | **Ordinamento con un clic** | **già** (5 colonne). Mancano: ordina per «% sotto la media» e per «ricavo totale» (Vendi) → **S** con il calcolo di (4) | nessuno | nessuna | should | S |
| 4 | **Prezzo unitario evidenziato + % rispetto alla media + freccia** | Media = `value_of(item)` (**già**, valore base); `pct = quote × 100 / value − 100`: **C** minimo in `AuctionView.price_gap(item, mode)` (formula nuova F-2xx, esempi = test) o calcolo UI con numeri già esposti (`sell_quote`, `buy_quote`, `market_price`, `value_of` non è nella facciata → +1 passante) | nessuno | nessuna | **must** | S (UI + 1 passante) |
| 5a | **Compra max** | `min(stock, oro / unit)`: `buy_quote` è lineare (`qty × unit`) e `stock` già esposto → **S** | nessuno | nessuna | **must** | S |
| 5b | **Acquisto in due clic** (conferma) | **S**. Oggi è un clic: già comodo. Una conferma ovunque peggiora l'uso: **solo se totale ≥ 50% dell'oro** (soglia in `balance.json`, **D**) | nessuno | nessuna | should (opzionale) | S |
| 5c | **«Compra quanto serve» per la ricetta** | **C**: `shortfall(recipe, qty)` = reagenti − Deposito, solo per i comprabili (componenti/cibo, Q99); la logica della coda/Bacheca di M36 («Cosa ti serve») è la fonte; richiede un punto d'ingresso dalla pagina professione (**S**) | nessuno | nessuna | later | M |
| 6 | **Vendita dal Deposito con prezzo consigliato** | Pulsante «Vendi alla Casa d'Aste» nel pannello di dettaglio del Deposito (M34) → apre la pagina `auction` in Vendi con l'oggetto selezionato; prezzo consigliato **già** (`suggested_price`). **S** (+ parametro di navigazione pagina, come «Vai» di M36) | nessuno | nessuna | should | S |
| 7 | **Storico prezzo, grafico 7 giorni** | Il prezzo è funzione del seme e del blocco: l'equilibrio `_equilibrium(item, block−k)` è ricostruibile senza stato (**C**: `AuctionPricing.history(item, days)` e `forecast`); la saturazione passata non è nota → il grafico mostra l'**equilibrio** (prezzo senza il tuo effetto), indicato come tale | **nessuno** (derivato dal seme) | nessuna | later (bello, ma serve spiegare «equilibrio») | M |
| 8a | **Avvisi di prezzo** (notifica in Posta quando X scende sotto Y) | **C**: nuovo stato `auction.alerts` + controllo a ogni blocco (`process_block`) + messaggio Posta nuovo (`KINDS` + `auction_alert`) | **additivo** `auction.alerts`, v13 | nessuna | later | M |
| 8b | **Ordini di acquisto** (compra da solo a ≤ Y) | **C** + riserva d'oro; **cambia il bilancio** (oro bloccato) e apre casi limite (offline, Posta piena, scorte) | additivo | **tocca l'economia**: nessun oro creato, ma l'acquisto automatico offline è un nuovo percorso (va in `sim_market`) | **later, sconsigliato per ora** | L |

### Cose che il codice suggerisce e mancano (aggiunte)
- **A. Dettaglio a due colonne/sezioni**: parte alta fissa (icona, nome, prezzo unitario, % e freccia, fascia), sotto **sotto-schede «Subito» / «Inserzione» / «Mercato»** invece
  di un'unica colonna lunga; pulsante principale e messaggio di esito **fissi in fondo** (fuori dallo scroll). **S, must** (risolve il difetto 1).
- **B. Riepilogo in testata** per la scheda Le mie inserzioni: «N inserzioni, X in vendita, incasso atteso Y (netto)»; icone nelle righe; Annulla con conferma se vendute in parte. **S, should**.
- **C. Riga della lista rifatta**: colonne a larghezza fissa più larghe, prezzo con `MoneyLabel` compatto, freccia di tendenza colorata + % (idea 4), colore «Stabile» leggibile,
  riga selezionata con riempimento e barra a sinistra (difetto 5). **S, must**.
- **D. Ricordare le scelte** (categoria, ordinamento, ultimo oggetto) per scheda durante la sessione; **S, should**.
- **E. Avviso «Posta piena»** nella testata, perché blocca Vendi subito e le inserzioni (`mailbox_full`); badge «N da ritirare» come in Posta. **S, should**.
- **F. Guida «Casa d'Aste»** aggiornata (resta da fare da M26/M27). Solo dati di testo, **S, should**.
- **G. Categorie in ordine d'uso** (ordine fisso da dati) e conteggi «(n)» già presenti. **S, should**.

## 4. Raccomandazione
**M37 (prima milestone) = quasi solo UI, un solo punto di CORE piccolo**, nessun cambio di formula di prezzo e nessuna fonte di oro:
- **Must**: A (dettaglio a sezioni con azione fissa), C (riga e contrasti), 4 (prezzo unitario, % sulla media, freccia), 5a (Compra max), 1 (storico vendite, **l'unico CORE**: save additivo v12→v13).
- **Should (se il budget lo permette)**: 3a/3b (filtri «comprabili ora/posseduti» e ordine per %), 6 (Vendi dal Deposito), B, D, E, F, G.
- **M38 / later**: 2 (sottogruppi: dati + generatore), 5c (compra quanto serve), 7 (grafico), 8a (avvisi).
- **Fuori**: 8b ordini automatici; filtro rarità (non esiste il dato).

Dimensione stimata di M37: ~1 CORE (S/M), 1 DATA (S: testo Guida), 2 UI (M ciascuno) in file disgiunti (`auction_detail*`, `auction_row/list`, `auction_mine`), 1 QA (smoke + test di
`AuctionHistory`), integrazione. Massimo 2 agenti insieme.

## 5. Impatto riassunto
- **Save**: solo l'idea 1 (e 8a, later) aggiungono chiavi; migrazione con default vuoto; nessun slot esistente cambia comportamento.
- **Economia**: nessuna idea di M37 crea oro né cambia prezzi/commissioni/depositi; lo storico registra soltanto. 8b sì (rimandata).
- **Contratto `05_INTERFACES`**: +1 metodo (`AuctionHouse.history()`), +1 passante (`value_of`), +1 evento opzionale; tutto in `05_INTERFACES_M37.md`.
- **Test**: F-xx nuove solo per lo storico (limite N, ordine, unione) e per `price_gap`; UI un solo smoke test per pagina (CLAUDE.md §10).

## 6. Domande per l'utente (con default)
1. **Ambito M37**: (a) *Must* soltanto, (b) **Must + Should (consigliato)**, (c) tutto fino al grafico e agli avvisi.
2. **Storico vendite**: tieni le ultime **50** voci (default) o più? E vuoi che includa anche scadute/ritirate (default sì)?
3. **Conferma d'acquisto**: nessuna (default, già un clic), oppure solo sopra il 50% dell'oro?
4. **Sottogruppi dei materiali**: in M37 (aggiunge un task DATA) o in M38 (default)?
5. **Rarità**: ok togliere il filtro rarità (il dato non c'è) e usare i gruppi?
6. **Ordini/avvisi**: rimandati (default). Gli avvisi (non gli ordini) ti servono già in M37?
