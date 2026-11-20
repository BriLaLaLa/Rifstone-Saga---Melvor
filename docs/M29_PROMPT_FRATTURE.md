Sei l'Orchestratore del progetto RiftStone Saga: Idle (cartella: C:\Users\Davide\Desktop\AI\RIFTSTONE SAGA - Melvor).
Leggi CLAUDE.md e docs/STATUS.md (ultima milestone m28-done; dopo: icone, drop vendibili V37). Applica le regole operative di CLAUDE.md
senza eccezioni: brief con ID e documento senza parafrasi del design, massimo 2 agenti, sonnet per i ruoli implementativi (il Reviewer
resta opus), test mirati con log minimo, run_checks.ps1 una sola volta dopo i merge, STATUS.md aggiornato, push SOLO dopo aver chiesto
all'utente. Mai toccare ../RIFTSTONE SAGA/. Questa è una modifica PICCOLA, non una milestone: due task, un solo agente alla volta,
niente nuovo design lungo (solo una nota in docs/DECISIONS_LOG.md V38+ e OPEN_QUESTIONS.md Q184+ con i default).

RICHIESTA DELL'UTENTE (testo suo, non cambiarne l'intento)
1) "Fai si che i bonus sulle pietre per aprire i rift siano 1-2 se uncommon e raro da 3 a 6. Quando rollo gli affissi sulle rune non
   possono sparire ma solo cambiare."
   Interpretazione dell'Orchestratore (VERIFICALA nel codice e annota il dubbio in OPEN_QUESTIONS): le "pietre per aprire i rift" sono le
   CARTE DELLA FRATTURA (docs/01_GDD.md §17.1, F-109 in docs/02_FORMULAS.md, data/maps/map_mods.json); i "bonus" sono i modificatori della
   Carta; "uncommon" = rarità magica; "rune" = i Cristalli che agiscono sulle Carte (risveglio, ascesa, mutamento, GDD §26, F-104).
   Regola voluta: Carta magica = 1-2 modificatori, Carta rara = da 3 a 6 (oggi 3-4); un RIROLL (Cristallo di mutamento, "reroll")
   non deve mai cambiare il NUMERO dei modificatori: quelli esistenti si sostituiscono con altri, non spariscono. Controlla che valga per
   tutti i punti in cui si tirano i modificatori (nascita della Carta F-109, ascesa, mutamento) e anche per i pezzi se il reroll dei
   pezzi ha lo stesso difetto (in tal caso segnalalo nel report, correggilo solo se è lo stesso codice).
   Vincoli: il tetto ai rischi (F-123, Q72: somma dei punti di rischio entro il limite per grado; se sfora l'intensità si riduce) resta;
   servono almeno 6 modificatori distinti e compatibili in data/maps/map_mods.json (se non bastano, aggiungine con i dati/test, nomi
   originali in italiano); nessuna ritaratura del bilanciamento delle ricompense oltre a quanto il design F-109/F-111 già prevede per
   più modificatori (annota l'effetto sul bottino e fai girare la sim delle Fratture di tools/ se esiste, riporta il numero).
2) "Quando droppo qualcosa nel rift deve comparire nella borsa, senno' è brutto. Magari non lo posso ritirare ma deve comparire."
   Oggi il bottino di una Frattura va nella borsa della Frattura (FractureBag, systems/fractures/, docs/05_INTERFACES.md §5.23) e
   passa al Deposito solo alla vittoria sul boss (GDD §17.2); la UI mostra al massimo dei contatori (segnale `fracture_bag_changed`).
   Voluto: la pagina Fratture (e/o la pagina Combattimento durante la Frattura) mostra l'ELENCO di ciò che è nella borsa della Frattura
   (oggetti con icona e quantità, pezzi con nome e rarità, Carte) che si aggiorna a ogni drop, con la scritta chiara che si ritira alla
   vittoria e si perde se muori o abbandoni. NON si può ritirare prima del boss (regola X4 invariata). Vale anche per la borsa del
   Dungeon se usa lo stesso componente (non cambiare il suo comportamento). La UI legge dal modello (nessuno stato nella UI): se il
   modello non espone l'elenco, aggiungi una funzione di sola lettura (firma nel contratto, solo il Reviewer cambia 05_INTERFACES).

TASK
- M29-01 CORE (sonnet): punto 1 (modificatori 1-2 / 3-6, reroll che conserva il numero, validatore e dati, test di ogni regola; gli esempi
  di F-109 che cambiano si ricalcolano e restano test; save invariato o additivo: dire quale; offline/determinismo: nessun nuovo tiro
  fuori dal RngService con le regole di oggi).
- M29-02 UI (sonnet): punto 2 (elenco della borsa della Frattura, aggiornamento live su `fracture_bag_changed`/segnali esistenti, testi in
  italiano, Guida "Fratture" aggiornata entro 160 parole). OBBLIGATORIO un test con CLICK VERO (`Viewport.push_input` con
  InputEventMouseButton, GutLayer nascosto, vedi tests/ui/test_mail_page_smoke.gd) e un solo smoke test per pagina; screenshot a 1280x720
  e 1600x900 in cartelle separate, guardati con Read. Dipende da 01 solo se cambia l'API del modello; altrimenti può girare in parallelo.
- Poi un task REV (opus): integrazione, run_checks.ps1 una volta, STATUS, aggiornamento documenti (GDD §17.1 e §26, F-109, schema),
  tag locale `m29-done` (o `fratture-1`), CHIEDI all'utente prima del push.

LEZIONI (nei brief): nel worktree `git checkout -B task/<nome> main`; mai `-gtest=` (usare `-gdir=... -gselect=`); prima di unire un
branch rimuovere i `*.uid` non tracciati che bloccano il merge; dopo classi globali nuove `--import`; niente taskkill/pkill generici sui
processi Godot; nessun processo Godot lasciato in background; nessun file > ~400 righe; testi con `Money.text` se mostrano monete.

Prima di iniziare: riassumi in 8 righe il piano; aspetta il mio via solo se trovi un conflitto con i documenti o con il codice.
