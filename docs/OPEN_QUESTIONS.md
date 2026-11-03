# Domande aperte

Tutto ciò che non è deciso, con la proposta di default. Finché l'utente non risponde **vale il default** (gli altri
documenti sono già scritti così). Quando una domanda si chiude, il Reviewer aggiorna i documenti e la sposta in fondo
in "Chiuse".

## Più urgenti (prima o durante M0-M1)

| # | Domanda | Default proposto | Dove impatta |
|---|---|---|---|
| Q1 | Posso eliminare la sottocartella `rifstone-saga---melvor/` (progetto vuoto creato dall'editor, Godot 4.5 GL Compatibility) e mettere `project.godot` nella root? | Sì: M0-01 chiede conferma e la elimina | M0-01 |
| Q2 | Restare su Godot 4.5 per tutto l'MVP? | Sì; valutare l'aggiornamento solo dopo M6 | tutti |
| Q3 | Nome definitivo del gioco | resta "RiftStone Saga: Idle" | `project.godot`, menu |
| Q4 | Numero di slot | 4 | `balance.json` `slots.count` |
| Q5 | Salvataggio sincrono o in un thread | sincrono; M1-06 misura, thread solo se > 30 ms | M1-06 |

## Gameplay

| # | Domanda | Default proposto |
|---|---|---|
| Q6 | Munizioni per Mira e rune/consumabili per Arcano? | No nell'MVP: i tre stili usano solo l'arma |
| Q7 | Penalità di morte: solo la borsa del bottino? | Sì; niente perdita di equipaggiamento o oro |
| Q8 | Togliere un'infusione dall'Altare la distrugge? | Sì (consumo); alternativa futura: recupero con costo in frammenti |
| Q9 | Stance con bonus nascosti (precisione, difesa)? | No: la stance cambia solo l'XP |
| Q10 | Attacchi speciali o abilità delle armi? | No nell'MVP |
| Q11 | Mostri "boss" o dungeon a ondate? | Dopo l'MVP (eventuale M9) |
| Q12 | Le razioni da campo devono funzionare anche senza acquisto (livello base)? | No: livello 0 = solo pulsante Mangia |
| Q13 | Livelli oltre il 99? | No; l'XP continua fino a `xp_cap` |
| Q14 | Skill da sbloccare (a pagamento) o tutte subito? | Tutte subito |
| Q15 | Valori delle soglie delle razioni da campo, dei prezzi dello shop, dei mostri | quelli di `02_FORMULAS.md` §8-9, da rivedere dopo una prova di gioco a fine M4 |
| Q26 | I nodi della maestria di Cavatura e Lenza devono differire da quelli di Selvicoltura (es. Cavatura più `double_item_chance`, Lenza più `rift_shard_chance`)? Le stat di raccolta del registro sono solo cinque e Selvicoltura le usa tutte | No per ora: stessi costi, prerequisiti, stat e valori di §8.8, nomi e testi a tema (M2-02); da rivedere con Q15 dopo una prova di gioco |

## Offline

| # | Domanda | Default proposto |
|---|---|---|
| Q16 | Limite offline aumentabile (es. voce dello shop)? | No: 12 ore fisse |
| Q17 | Si può interrompere la simulazione offline? | No; deve durare < 10 s |
| Q18 | Le Fratture (M7) avanzano anche offline? | Sì, con la stessa simulazione |

## UI, contenuti, piattaforma

| # | Domanda | Default proposto |
|---|---|---|
| Q19 | Schede (tab) multiple nella bank? | No nell'MVP: ordinamento + ricerca |
| Q20 | Icone definitive: chi le produce? | MVP con segnaposto originali; dopo l'MVP icone illustrate (anche con generatore di immagini, con revisione dell'utente e nessuna immagine di altri giochi) |
| Q21 | Audio | M6 solo pochi suoni di interfaccia (clic, livello, frammento) con licenza libera o creati; musica dopo l'MVP |
| Q22 | Lingua inglese | No nell'MVP; i testi restano nei dati, così una traduzione futura tocca solo i JSON |
| Q23 | Piattaforme oltre Windows | Dopo l'MVP (Linux/Mac: export senza cambi di codice) |
| Q24 | Backup del salvataggio | un solo `.bak`; più copie a rotazione solo se richiesto |
| Q25 | Riuso delle icone degli oggetti di RiftStone (`Item_Texture/`, `Icons/`) | No (nomi e temi legati a Metin2, provenienza da verificare); eventualmente il Porting Engineer le valuta una per una su richiesta |

## Chiuse
(vuoto)
