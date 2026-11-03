# Domande aperte

Tutto ciò che non è deciso, con la proposta di default. Finché l'utente non risponde **vale il default** (gli altri
documenti sono già scritti così). Quando una domanda si chiude, il Reviewer aggiorna i documenti e la sposta in fondo
in "Chiuse".

## Più urgenti (prima o durante M0-M1)

| # | Domanda | Default proposto | Dove impatta |
|---|---|---|---|
| Q1 | Posso eliminare la sottocartella `rifstone-saga---melvor/` (progetto vuoto creato dall'editor, Godot 4.5 GL Compatibility) e mettere `project.godot` nella root? | Sì: M0-01 chiede conferma e la elimina | M0-01 |
| Q2 | Restare su Godot 4.5 per tutto l'MVP? | Sì; valutare l'aggiornamento solo dopo M9 | tutti |
| Q3 | Nome definitivo del gioco | resta "RiftStone Saga: Idle" | `project.godot`, menu |
| Q4 | Numero di slot | 4 | `balance.json` `slots.count` |
| Q5 | Salvataggio sincrono o in un thread | sincrono; M1-06 misura, thread solo se > 30 ms | M1-06 |

## Gameplay

| # | Domanda | Default proposto |
|---|---|---|
| Q7 | Penalità di morte: solo la borsa del bottino? | Sì; niente perdita di equipaggiamento o oro |
| Q8 | Togliere un'infusione dall'Altare la distrugge? | Sì (consumo); alternativa futura: recupero con costo in frammenti |
| Q11 | Mostri "boss" o dungeon a ondate? | Dopo l'MVP (M12+) |
| Q12 | Le razioni da campo devono funzionare anche senza acquisto (livello base)? | No: livello 0 = solo pulsante Mangia |
| Q13 | Livelli oltre il 99? | No; l'XP continua fino a `xp_cap` |
| Q14 | Skill da sbloccare (a pagamento) o tutte subito? | Tutte subito |
| Q15 | Valori delle soglie delle razioni da campo, dei prezzi dello shop, dei mostri | quelli di `02_FORMULAS.md` §8-9, da rivedere dopo una prova di gioco a fine M5 (combattimento), con `tools/sim_combat.gd` |
| Q26 | I nodi della maestria di Cavatura e Lenza devono differire da quelli di Selvicoltura (es. Cavatura più `double_item_chance`, Lenza più `rift_shard_chance`)? Le stat di raccolta del registro sono solo cinque e Selvicoltura le usa tutte | No per ora: stessi costi, prerequisiti, stat e valori di §8.8, nomi e testi a tema (M2-02); da rivedere con Q15 dopo una prova di gioco |

## Offline

| # | Domanda | Default proposto |
|---|---|---|
| Q16 | Limite offline aumentabile (es. voce dello shop)? | No: 12 ore fisse |
| Q17 | Si può interrompere la simulazione offline? | No; deve durare < 10 s |
| Q18 | Le Fratture (M10) avanzano anche offline? | Sì, con la stessa simulazione |

## UI, contenuti, piattaforma

| # | Domanda | Default proposto |
|---|---|---|
| Q19 | Schede (tab) multiple nella bank? | No nell'MVP: ordinamento + ricerca |
| Q20 | Icone definitive: chi le produce? | MVP con segnaposto originali; dopo l'MVP icone illustrate (anche con generatore di immagini, con revisione dell'utente e nessuna immagine di altri giochi) |
| Q21 | Audio | M9 solo pochi suoni di interfaccia (clic, livello, frammento) con licenza libera o creati; musica dopo l'MVP |
| Q22 | Lingua inglese | No nell'MVP; i testi restano nei dati, così una traduzione futura tocca solo i JSON |
| Q23 | Piattaforme oltre Windows | Dopo l'MVP (Linux/Mac: export senza cambi di codice) |
| Q24 | Backup del salvataggio | un solo `.bak`; più copie a rotazione solo se richiesto |
| Q25 | Riuso delle icone degli oggetti di RiftStone (`Item_Texture/`, `Icons/`) | No (nomi e temi legati a Metin2, provenienza da verificare); eventualmente il Porting Engineer le valuta una per una su richiesta |

## Riforma da M4 (combattimento al centro, `VISIONE_V2.md` §8)

I documenti sono già scritti con questi default (R-00).

| # | Domanda | Default proposto | Dove impatta |
|---|---|---|---|
| Q27 | La raffinazione può distruggere un pezzo? | No: da +4 il fallimento fa scendere di un livello | F-86, `01_GDD.md` §23 |
| Q28 | Raffinazione massima | +9 | F-86 |
| Q29 | Unici nell'MVP? | No (M12+) | `01_GDD.md` §22 |
| Q30 | Anelli e amuleti forgiabili? | No, solo drop (M7) | §8.4, `01_GDD.md` §22 |
| Q31 | Raffinazione istantanea o azione a tempo? | Istantanea | `01_GDD.md` §23 |
| Q32 | Attrezzi di raccolta con rarità e affissi? | Sì, affissi di raccolta con scope della skill | §8.9, `01_GDD.md` §22 |
| Q33 | Capienza iniziale dell'Armeria | 40 + caselle nello shop (`armory_slot`) | F-82 |
| Q34 | Livello massimo del personaggio | 99, curva `character_curve` | F-71 |
| Q35 | Livelli di apertura degli slot dei tratti | 1, 10, 25, 50 | F-78 |
| Q36 | Slot delle abilità | 2, il 3° al livello 30 | F-78 |
| Q37 | Archi e bastoni restano nei dati (non equipaggiabili) o si tolgono fino alle loro classi? | Si tolgono: oggetti e ricette tornano con le classi future | M4-02 |
| Q38 | Dimensione dei gruppi | 1-6, più grandi nelle aree alte | §8.5, `combat.max_pack_size` |
| Q39 | Doppia spada: moltiplicatore dell'intervallo e penalità di precisione | `combat.dual_wield.interval_mult` 0,75, precisione −10% (modificatore dell'assetto), da rivedere con `tools/sim_combat.gd` | F-73, `04_DATA_SCHEMA.md` §14 |
| Q40 | Parata con lo scudo: cosa blocca? | Tutto il danno di un colpo; `block_chance` dello scudo 5-15% per grado, massimo 50% | F-75 |
| Q41 | XP dei mostri | Da tarare con `tools/sim_combat.gd` a fine M5; default 4 × PV (provvisorio, probabilmente troppo alto) | F-28, `02_FORMULAS.md` §8.5, M5-06 |
| Q42 | Tooltip dei pezzi senza le skill di combattimento: da dove vengono il nome dello stile e il testo del requisito del personaggio? | Testi della UI in costanti di `ItemTooltipLines` (stili `blade`/`marksmanship`/`arcana` → Lama/Mira/Arcano; requisito «Richiede il livello N del personaggio»), come gli altri testi di presentazione | M4-08, `05_INTERFACES.md` §7 |

## Chiuse

| # | Domanda | Decisione | Data |
|---|---|---|---|
| Q6 | Munizioni per Mira e rune/consumabili per Arcano? | Niente munizioni né rune; la classe dell'MVP usa solo spade (D6); archi e bastoni tornano con le loro classi | 2026-11-03 (`VISIONE_V2.md` §8) |
| Q9 | Stance con bonus nascosti? | La stance è tolta: tutta l'XP va al personaggio (D3, F-28) | 2026-11-03 |
| Q10 | Attacchi speciali o abilità delle armi? | Sì: abilità attive automatiche della classe, 2 per assetto (`01_GDD.md` §20.2, M6) | 2026-11-03 |
