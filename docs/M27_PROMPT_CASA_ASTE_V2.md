Sei l'Orchestratore del progetto RiftStone Saga: Idle (cartella: C:\Users\Davide\Desktop\AI\RIFTSTONE SAGA - Melvor).
Leggi CLAUDE.md, docs/STATUS.md (ultima milestone m26-done, poi il fix `db8da0a` sulla Casa d'Aste) e la richiesta qui sotto.
Applica le regole operative di CLAUDE.md senza eccezioni: brief con ID e documento senza parafrasi del design, massimo 2 agenti,
sonnet per i ruoli implementativi (il Reviewer resta opus), test mirati con log minimo, run_checks.ps1 una sola volta dopo i merge,
STATUS.md aggiornato, push di main e del tag solo a fine milestone e SOLO dopo aver chiesto all'utente. Mai toccare ../RIFTSTONE SAGA/.

OBIETTIVO: milestone M27 "Casa d'Aste v2": inserzioni simulate, posta, valute (rame, argento, oro).
Oggi la Casa d'Aste (M23 + M26: docs/01_GDD.md §34, docs/01_GDD_M26.md §38.5-§38.8, F-145..F-152 e F-172..F-176, interfaccia
AuctionHouse/AuctionPricing in docs/05_INTERFACES.md §5.30 e docs/05_INTERFACES_M26.md §5.37, UI in ui/pages/auction/) vende
SUBITO a un prezzo calcolato dalla popolazione, senza inserzioni, senza attesa, solo in oro. L'utente vuole un mercato che
somigli a quello di World of Warcraft (solo idee di meccanica e di UI, clean room: nessun testo, nome o asset copiato).

RICHIESTA DELL'UTENTE (testo suo, fonte del design: non cambiarne l'intento)
1) "Quando seleziono un oggetto vedo le inserzioni di quell'oggetto, dalla meno cara alla più cara (simulato ovviamente) e la
   popolazione totale di quell'oggetto."
2) "Quando metto un'inserzione possono succedere 2 cose: o lo vendo, oppure il mercato va al ribasso e il mio oggetto rimane lì
   invenduto. A una certa magari si rialza e viene comprato, ma deve essere una cosa organica simulata."
3) "Quando vendo un oggetto alla casa d'aste (vendita effettiva) avrò poi una sezione 'mail' dove mi troverò un piccolo messaggio
   e i soldi della vendita da ritirare. Una cosa carina alla WOW."
4) "C'è da aggiungere più valute, non solo oro: rame, argento e oro, per avere differenze eccetera. È importante per un mercato sano."

VINCOLI DA NON ROMPERE (lezioni di M23-M26)
- Deterministico e senza tiri del generatore dello slot: l'organico (inserzioni dei PNG, vendite, ribassi, rialzi) nasce da un
  seme dello slot e dal tempo di gioco, come le onde di F-172..F-176 (vettori di hash in F-146).
- Offline: 12 ore in un colpo = tick da 100 ms = blocchi da 60 s DANNO LO STESSO STATO (inserzioni vendute, posta ricevuta,
  prezzi), con salva e ricarica a metà (equivalenza Q124). Posta e inserzioni sono stato dello slot (save), mai fuori dallo slot.
- Nessun guadagno senza rischio: comprare e rivendere non deve mai rendere (la sim di tools/sim_market.gd lo verifica: aggiornala).
- Nessuna ritaratura dell'economia complessiva (Q122): valori di partenza ragionevoli nei dati; commissioni e depositi sono
  parametri nei dati, mai nel codice. Q151 (costo dei reagenti) è aperta: non toccarla.
- Valute: il portafoglio oggi è in oro (modulo wallet). Il Reviewer propone la rappresentazione (consigliato: unità base intera
  in rame, 100 rame = 1 argento, 100 argento = 1 oro, fattori in balance.json) e una migrazione del salvataggio v10 -> v11
  (additiva se possibile) che converta oro, prezzi di dati, Maestri, edifici, Bacheca, Shop e Casa d'Aste SENZA cambiare il
  potere d'acquisto. Mostra "1g 25s 40c" con icone/colori distinti. Nessuna stat decorativa: le valute non sono stat.
- Un solo sistema di modificatori, nessun file > ~400 righe, dati in JSON validati, codice in inglese, testi in italiano, test
  GUT per ogni formula/regola (ogni esempio di docs/02_FORMULAS*.md è un test), un solo smoke test per pagina di UI.
- Moduli separati dalla UI (core/ e systems/): mercato a inserzioni (libro degli ordini simulato), posta (nuovo modulo `mail`),
  valute (wallet). GameSession solo composizione.
- Lezioni di oggi (applicale nei brief): (a) ogni nuova UI interattiva deve avere un test che usa un CLICK VERO
  (`Viewport.push_input` con InputEventMouseButton), non solo `emit`/`select` programmatici: un bug del clic su un Tree
  sfuggiva ai test; (b) gli agenti lavorano in worktree: dentro il worktree fare `git checkout -B task/<nome> main` se parte da un
  commit vecchio; (c) NON usare `-gtest=` con GUT (lancia la suite intera): usare `-gdir=... -gselect=<nome>`; (d) gli screenshot
  vanno in cartelle separate per risoluzione e si guardano davvero (Read), poi si prova il flusso con clic;
  (e) prima di unire un branch rimuovere i `*.uid` non tracciati che bloccano il merge; (f) le pagine della Guida hanno un limite
  di 160 parole (test_guide_texts); (g) a fine task un agente non deve lasciare processi Godot in background.

DESIGN DA FARE (M27-01, Reviewer opus, solo documenti: GDD §39 in un nuovo docs/01_GDD_M27.md con puntatori, formule F-xx nuove
in docs/02_FORMULAS_M27.md con esempi = test, schema dati docs/04_DATA_SCHEMA_M27.md, contratto docs/05_INTERFACES_M27.md con save
v11 e migrazione, DECISIONS_LOG V33+, OPEN_QUESTIONS Q159+, ROADMAP M27, docs/07_TASKS_M27.md). Deve decidere, con default
prudenti e annotando i dubbi:
 a) Libro delle inserzioni per oggetto: inserzioni dei PNG generate in modo deterministico da seme+tempo, ordinate dalla meno
    cara alla più cara, quantità e prezzo per inserzione, popolazione totale (compratori, venditori, domanda: riusa F-172..F-176).
 b) Inserzione del giocatore: oggetto, quantità, prezzo unitario scelto dal giocatore (con suggerimento di mercato), durata
    (es. 12/24/48 h di gioco, dati), deposito/commissione (sink di valuta, dati). Esiti organici: venduta (tutta o a pezzi),
    invenduta perché il mercato scende (la sua inserzione resta nel libro e può essere battuta da PNG più economici), rialzo che
    la fa comprare dopo, scaduta (oggetti restituiti per posta). Annullare: regole e costo.
 c) Posta: nuovo modulo `mail` per slot, messaggi con mittente (la Casa d'Aste), testo breve generato da dati, valuta e/o oggetti
    allegati da RITIRARE (non accreditati in automatico), capienza, scadenza (decidi: default nessuna perdita), pulsante "Ritira
    tutto", indicatore non letti nella barra laterale, comportamento a Deposito pieno. Estendibile (Bacheca, ecc.) ma FUORI SCOPE.
 d) Valute rame/argento/oro: rappresentazione, conversione, formattazione, migrazione di TUTTI i valori in oro dei dati e del
    save senza alterare l'economia (Q122), impatto su Shop, Maestri, edifici, Bacheca, Mercante, Guida, test esistenti.
 e) Rapporto con il modello a popolazione di M26: come il libro e le vendite ne derivano senza stato nuovo non necessario.
 f) Equivalenza offline e rischio per i test esistenti (AuctionPricing, AuctionHouse, save, sim_market, test di integrazione).
 g) Filoni e ordine consigliato, dimensionati S/M/L, max 2 agenti insieme: A valute (tocca tutto: PRIMO, da solo), B libro e
    inserzioni (core + dati), C posta (core), poi UI di ciascuno, QA (sim_market e sim del libro) e integrazione.

PROPOSTA DI TASK (adattala a docs/07_TASKS.md; accorpa i task S dello stesso ruolo)
- M27-01 REV  Design (sopra).
- M27-02 CORE Valute e migrazione v11 (filone A), con aggiornamento dei test esistenti.
- M27-03 DATA Conversione dei valori di dati con generatore in tools/ (non a mano), Guida.
- M27-04 CORE Libro delle inserzioni e inserzioni del giocatore, offline in forma chiusa/equivalente (filone B).
- M27-05 CORE Posta (filone C).
- M27-06 UI   Casa d'Aste: elenco delle inserzioni dell'oggetto selezionato (dalla meno cara), popolazione, flusso di vendita
              (prezzo, durata, deposito), "Le mie inserzioni" con stato, formato delle valute ovunque.
- M27-07 UI   Pagina Posta (voce nella barra laterale con indicatore), ritiro, messaggi.
- M27-08 QA   tools/sim_market.gd e sim del libro (nessun guadagno senza rischio, offline = online), test con clic veri.
- M27-09 REV  Integrazione, documenti allineati, run_checks.ps1 una volta, STATUS, tag m27-done; prima di pushare CHIEDI all'utente.

CRITERI DI ACCETTAZIONE
- Selezionando un oggetto si vedono le inserzioni ordinate dalla meno cara e la popolazione totale.
- Un'inserzione del giocatore si vende, resta invenduta quando il mercato scende, o si vende dopo un rialzo; tutto simulato,
  deterministico e uguale tra offline in un colpo, a tick e a blocchi (con salva/ricarica a metà).
- La vendita effettiva manda un messaggio in Posta con i soldi da ritirare; ritirare accredita il portafoglio.
- Il portafoglio e tutti i prezzi usano rame/argento/oro; uno slot v10 reale migra a v11 senza perdite e senza cambiare il
  potere d'acquisto; la build Windows parte con una partita nuova e con uno slot migrato.
- run_checks.ps1 verde; nessun file oltre ~400 righe; nessuna stat decorativa; test con clic veri sulle nuove UI.

NON FARE: ritaratura dell'economia, nuove discipline, asta tra giocatori reali, eventi di mercato, cambiare Q151.
Annota ogni dubbio in OPEN_QUESTIONS.md e prosegui con il default più prudente.

Prima di iniziare: riassumi in 10 righe il piano e i task; aspetta il mio via solo se trovi un conflitto con i documenti o con il
codice; altrimenti parti con M27-01.
