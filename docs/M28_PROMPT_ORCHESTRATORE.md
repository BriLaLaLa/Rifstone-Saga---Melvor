Sei l'Orchestratore del progetto RiftStone Saga: Idle (cartella: C:\Users\Davide\Desktop\AI\RIFTSTONE SAGA - Melvor).
Leggi CLAUDE.md, docs/STATUS.md (ultima milestone m27-done, poi il design M28-01 nel commit `a2994bf`) e docs/07_TASKS_M28.md.
Applica le regole operative di CLAUDE.md senza eccezioni: brief con ID e documento senza parafrasi del design, massimo 2 agenti insieme,
sonnet per i ruoli implementativi (il Reviewer resta opus), test mirati con log minimo, run_checks.ps1 una sola volta dopo i merge,
STATUS.md aggiornato, push di main e del tag SOLO a fine milestone e SOLO dopo aver chiesto all'utente. Mai toccare ../RIFTSTONE SAGA/.

OBIETTIVO: milestone M28 "Abilità e tratti v2" (design già fatto e approvato dall'utente: docs/01_GDD_M28.md §40, F-185..F-194 in
docs/02_FORMULAS_M28.md, schema docs/04_DATA_SCHEMA_M28.md, contratto docs/05_INTERFACES_M28.md, task docs/07_TASKS_M28.md).
Oggi: 12 tratti e 6 abilità, nessuno sblocco dopo il livello 30. Il design porta 19 abilità (13 nuove) e 31 tratti (19 nuovi) sbloccati
lungo 1-99, 5 condizioni (Sanguinamento, Fiacchezza, Breccia, Sbilanciamento, Riparo), 1 tipo di abilità nuovo (`ward`) e 12 tipi di
effetto nuovi per i tratti. Slot invariati.

DECISIONI DELL'UTENTE (chiudono le domande del design; riportale in OPEN_QUESTIONS.md e DECISIONS_LOG.md)
- Le tabelle di docs/01_GDD_M28.md §40.6 (abilità) e §40.7 (tratti) sono APPROVATE così come sono: Q182 chiusa. Valori "di partenza":
  il bilanciamento lo verifica F-194 con tools/sim_combat.gd; se un contenuto nuovo domina o fallisce, si ritoccano solo i valori
  nuovi (M28-09), mai i 18 contenuti esistenti.
- Q174: l'abilità "Raffica di lame" (id `blade_volley`) si rinomina nel nome visibile in "Sciame di tagli" (id invariato).
  Fallo nei documenti subito (M28-02 o un commit REV iniziale) e nei dati a M28-06.
- Q171 (slot invariati), Q172 (critico rimandato), Q173 (albero delle passive rimandato), Q175-Q181 (regole delle condizioni, soglie
  F-194, filtro "Solo assetto attuale", `setup=sword` in sim_combat, niente tipi nuovi nei leggendari): default del design CONFERMATI.
- FUORI SCOPE: albero delle passive, critico, nuove classi, ritaratura dell'economia, Q151 (non toccarla), nuove stat nel registro.

ORDINE (da docs/07_TASKS_M28.md): M28-02 -> M28-03 (da solo) -> (M28-04 || M28-05) -> M28-06 -> (M28-07 || M28-08) -> [M28-09 solo se
F-194 fallisce] -> M28-10 (REV: integrazione, run_checks.ps1 una volta, STATUS, tag locale m28-done; prima di pushare CHIEDI all'utente).
Accorpa i task S dello stesso ruolo. M28-04 e M28-05 condividono la fixture tests/fixtures/data/classes/test_class.json: 04 tocca solo le
abilità, 05 solo i tratti, chi chiude per secondo fa rebase.

VINCOLI DA NON ROMPERE
- Combattimento deterministico: nessun nuovo tiro del generatore dello slot fuori dalle regole del design (F-23/F-22 per i colpi nuovi).
  Con i contenuti di M27 equipaggiati la sequenza dei tiri e i numeri restano identici (test di non regressione in M28-03).
- Offline: 12 ore in un colpo = tick da 100 ms = blocchi da 60 s, con salva e ricarica a metà, DANNO LO STESSO STATO anche con le
  condizioni attive. Il Sanguinamento aggiunge un evento al secondo: tempo offline non oltre 1,5x quello senza.
- Save: resta v11, aggiunte additive (`enemies[i].cond`, `cond_clock_ms`, `ward`), nessuna migrazione.
- Un solo sistema di modificatori; nessuna stat decorativa; nessun file > ~400 righe (combat_fight.gd è a 397, player_column.gd a 400,
  tools/sim_combat.gd a 400: M28-02 è un refactor senza cambi di comportamento che libera spazio); dati in JSON validati; codice in
  inglese, testi in italiano; test GUT per ogni formula (ogni esempio di docs/02_FORMULAS_M28.md è un test); un solo smoke test per
  pagina di UI; clean room (nomi e testi originali).
- Lezioni di M27 (da mettere nei brief): (a) ogni UI interattiva ha un test con CLICK VERO (`Viewport.push_input` con
  InputEventMouseButton; nascondere il GutLayer nei test, vedi tests/ui/test_mail_page_smoke.gd); (b) nel worktree: `git checkout -B
  task/<nome> main` se parte da un commit vecchio; (c) NON usare `-gtest=` con GUT: usare `-gdir=... -gselect=<nome>`;
  (d) screenshot in cartelle separate per risoluzione e guardati davvero (Read); (e) prima di unire un branch rimuovere i `*.uid`
  non tracciati che bloccano il merge; (f) pagine della Guida max 160 parole (test_guide_texts); (g) gli agenti non lasciano processi
  Godot in background e NON usano taskkill/pkill generici sui processi Godot (altri agenti ne usano); (h) dopo l'aggiunta di classi
  globali serve `--import` nel worktree; (i) la suite completa gira una volta sola, dopo il merge su main.
- Valute: i testi usano g/s/c ("1g 25s 40c") con `Money.text`; i valori in dati sono in rame.

STATO DEL REPOSITORY ALL'AVVIO: main ha commit locali non ancora pushati (icone dei mostri già pushate fino a 364b3f4; poi `eb1fe1d`
prompt degli oggetti e `a2994bf` design M28-01). Il lavoro sulle icone degli oggetti (docs/PROMPT_OGGETTI.md, tools/gen_item_sheets.gd
e il futuro script di ritaglio) è un filone SEPARATO dell'utente: non toccarlo e non bloccarlo. Se `git status` mostra file modificati
in tools/ o assets/icons/, non fanno parte di M28.

Prima di iniziare: riassumi in 10 righe il piano e i task; aspetta il mio via solo se trovi un conflitto con i documenti o con il
codice; altrimenti parti con M28-02.
