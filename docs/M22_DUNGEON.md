# M22: Dungeon delle scimmie (V12)

Prima istanza **a scelte** del gioco. Design in `01_GDD.md` §33, formule F-137…F-144 in `02_FORMULAS.md` §5j, schema in `04_DATA_SCHEMA.md` §27, contratto in `05_INTERFACES.md` §5.29 (sistema, motore, segnali) e §7.q (UI), task M22-02…08 in `07_TASKS.md`.
Save v7 **invariato** (modulo additivo `dungeon`, nessuna migrazione). Nessuna stat, nessuna sorgente di modificatori.

## Richiesta dell'utente (testo originale, fonte del design: non cambiarne l'intento)
> "Il dungeon sarà l'unica parte veramente attiva che avremo della combat. Richiederà input utente. Il primo dungeon sarà il dungeon delle scimmie. Il dungeon delle scimmie richiede un biglietto di entrata che si potrà droppare dai miniboss o dai metin. Una volta entrati ci sarà 1 stanza con dei mostri scimmia.
> Finiti quei mostri ci sarà un bivio, da 2-3-4 strade... ogni strada porta a un incontro diverso. Può essere un miniboss, 1 mostro solo, tantissimi mostri .. va anche un po' a culo diciamo. Il gioco da dietro le quinte erige una mappa procedurale del dungeon, quindi se tipo siamo sulla sinistra non può farti girare a sinistra perché non c'è una stanza.
> Ovviamente il player non vede questa mappa, sceglie solo la direzione. Possono esserci trappole eccetera ... e poi l'ultima stanza ... è quella del boss, che avrà un bellissimo loot pool. Ricordiamoci che è un boss quindi almeno per questa alpha facciamo un 'entrata epica' del boss. Il boss sicuramente non sarà da solo ...
> magari prima fightiamo il suo braccio destro, una scimmia intendo, e poi un'altra scimmia ... magari il suo stratega. Con dei piccoli sottoposti e poi lui il boss finale. A tua discrezione come fare questa cosa. A parte le scelte però deve essere tutto in autobattle."

## Fissato da M22-01 (2026-11-13), in breve (dettagli in `DECISIONS_LOG.md` M22-01)
- **Sistema generico**: `data/dungeons/<id>.json`; il Covo delle Scimmie (`monkey_den`) è il primo. La seconda classe slitta a M23+.
- **Mappa nascosta** (F-137): ingresso, **5 bivi** di 2-4 stanze, boss; 2-4 uscite per stanza, **7 direzioni** da fasce di spostamento laterale, nessun indizio (tolti in M22-09: la stanza si rivela dopo la scelta); solo il **seme** nel save.
- **Tipi di stanza** (F-138): Branco, Orda (12), Guardiano, Capobranco (miniboss), Trappola, Riposo; le due scelte dei **due eventi** (Trappola, Riposo) sono l'unico altro input (F-140, nessun effetto permanente, mai letali).
- **Boss in tre atti** (F-139, F-141): Gorom (braccio destro) → Ziki (stratega, con sottoposti) → Uuk-Maar (il Re), con scena d'ingresso prima di ogni stadio; abilità = i tre tipi esistenti di F-112.
- **Biglietto** dai **miniboss di area** (nuovi, Z8 fissato: uno per area, 1,5% dopo un incontro) e dai Monoliti, aree 4-10; **uno ogni ~1,7 ore** (F-139).
- **Rischio**: morte e fuga = borsa persa; "Esci dal Covo" ai bivi = si tiene la borsa, non il boss. Borsa separata (stessa classe `FractureBag`).
- **Offline**: la run **si congela**; **dopo il caricamento la run è in pausa** fino a "Riprendi" (F-144).
- **Loot** (F-142, F-143): premi di stanza che crescono con il rischio; boss con 2 pezzi (uno raro), Polvere, 2 Cristalli, Carta e **6 leggendari del dungeon** (19,4% per vittoria).

## Per chi implementa
- **Transitorio del validatore**: M22-02 aggiunge le regole di §27 con una costante `STRICT_REAL_DATA = false` (accetta, sui dati **veri**, l'assenza di `data/dungeons/` e del campo `miniboss`), così `main` resta verde finché M22-03 non porta i dati; M22-03 la porta a `true`. Le **fixture** (`tests/fixtures/data`) sono sempre rigorose.
- **Motore**: `combat_fight.gd` ha 381 righe: nessuna logica nuova lì dentro, solo ganci verso `dungeon_combat.gd`. Riuso del modello di `fracture_combat.gd` (copiare lo schema, nessun refactor di `FractureSystem` né di `FractureCombat`).
- **Orda**: 12 mostri in un incontro: regge il motore dei Monoliti (≥ 30 nemici, vista compatta); un test lo verifica.
- **Tutti i numeri nei dati o nei generatori**: `gen_dungeon.gd` (mostri, stadi, premi), `gen_areas.gd` (miniboss), `balance.json` (`dungeon`, `miniboss`); nessun numero di design nel codice.
- **Clean room**: nomi originali (nessuno da Melvor Idle, nessun personaggio di altri giochi): Gorom, Ziki, Uuk-Maar sono provvisori; M22-03 può cambiarli in `NOMI.md` con il Reviewer.
- **Parallelismo** (max 2 agenti): M22-02 → (M22-03 ∥ M22-04) → (M22-05 ∥ M22-06) → M22-07 (a M22-05 chiuso) → M22-08.
- **Scartati**: la mappa visibile o l'esplorazione libera, scelte a tempo, stanze con enigmi o minigiochi, dungeon cooperativi, rimborso del Biglietto, Biglietti comprabili (Q91), difficoltà variabile (Q92), progresso offline della run (Q93), potere permanente da trappole o riposi.
