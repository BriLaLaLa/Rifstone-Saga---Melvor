Sei l'Orchestratore del progetto RiftStone Saga: Idle (cartella: C:\Users\Davide\Desktop\AI\RIFTSTONE SAGA - Melvor).
Leggi CLAUDE.md e docs/STATUS.md (ultima milestone m31-done). Applica le regole operative di CLAUDE.md senza eccezioni: brief con ID e
documento senza parafrasi del design, massimo 2 agenti, sonnet per i ruoli implementativi (il Reviewer resta opus), test mirati con log
minimo, run_checks.ps1 una sola volta dopo i merge, STATUS.md aggiornato, push SOLO dopo aver chiesto all'utente. Mai toccare
../RIFTSTONE SAGA/. Questa è una modifica PICCOLA e URGENTE (ASAP), non una milestone lunga: poco design, una nota in
docs/DECISIONS_LOG.md (V-successivo) e docs/OPEN_QUESTIONS.md (Q-successiva) con i default; un agente alla volta tranne dove i file sono
distinti.

PROBLEMA (trovato provando il tutorial M30)
Il cibo è fondamentale e oggi nasce SOLO dal pesce: tutte le ricette di cottura di `data/actions/hearthcraft.json` (`cook_*`) hanno come
ingrediente un pesce crudo che si ottiene solo con la disciplina di raccolta Pesca (`data/actions/angling.json`). Le discipline di raccolta
sono 2 su 4 e di produzione 2 su 4 (CLAUDE.md, GDD M24 §35; Maestri in `data/disciplines/trainers.json`). Chi sceglie Boscaiolo,
Minatore o Erborista non ha nessuna fonte di cibo (i mostri non lasciano pesce; la Casa d'Aste lo vende ma va prima costruita). Anche
il passo del tutorial `trainers` in `data/tutorial/steps.json` spinge verso il Boscaiolo. Chi non ha la Pesca resta senza cibo.

RICHIESTA DELL'UTENTE (testo suo, non cambiarne l'intento)
"Il cibo è una parte fondamentale del gioco. Noi tecnicamente potremmo cucinare quello che droppano i mostri, no? Aggiungiamo nel
lootTable dei mostri la loro carne (non tutti ma in parte) e facciamo che la cucina si può sempre prendere come mestiere anche se si hanno
già due mestieri, e lì mettiamo tutte le ricette divise per livello ecc., sia pesci che carne. Fixiamo questa cosa ASAP."

Interpretazione dell'Orchestratore (VERIFICALA nel codice e annota i dubbi in OPEN_QUESTIONS con i default):
1) CARNE DAI MOSTRI: nuovi oggetti materiale "carne cruda" (nomi originali in italiano, icone riusate o segnaposto) nelle tabelle di drop
   (`data/combat/loot_tables.json`, schema in `docs/04_DATA_SCHEMA.md`; mostri in `data/combat/monsters.json`) solo per una parte dei mostri
   (quelli plausibilmente "animali/bestie"; non i costrutti, gli spettri ecc.), con probabilità e quantità che rispettino i vincoli di
   F-32/loot e di `tests/balance` (leggi la formula dei drop in `docs/02_FORMULAS.md` e il test `test_drop_balance`; NON rompere le
   bande dei test, se un minimo va ritoccato spiegalo). La carne deve coprire TUTTI i gradi di area (una carne per fascia di livello, come
   i pesci per livello), così che chi non pesca abbia sempre una fonte di cibo adatta al livello.
2) CUCINA SEMPRE DISPONIBILE: la disciplina di produzione `hearthcraft` (Cucina e alchimia) si può SEMPRE imparare dal Maestro, anche se
   si hanno già i 2 mestieri di produzione (non occupa uno slot; verifica come funzionano gli slot di disciplina in `systems/` e nel
   validatore e come si salva: preferisci un campo di dati nel Maestro, es. `free_slot`, a un caso speciale nel codice). Resta gratuita
   o a costo di grado come gli altri? Default: il primo grado resta gratuito. Save: invariato o additivo (dirlo); se si cambia il
   significato di uno slot già salvato serve una migrazione.
3) RICETTE DI CUCINA per livello: pagina Cucina con TUTTE le ricette (pesci e carne) ordinate per livello, come oggi la lista ricette
   (`ui/pages/skill/`). Nuove ricette `cook_*` per le carni (output: nuovi cibi in `data/items/food.json`, cura coerente con la scala di
   F-… §8.3 in `docs/02_FORMULAS.md`: a pari livello la cura è confrontabile con il pesce; costi/reagenti in modo che non sia più
   facile o più difficile del pesce, riusando `reagent_hearthcraft_*` dove già previsti). Le ricette dei tonici (`brew_tonic_*`) NON
   cambiano ma verifica se chiedono pesce: se sì, nota nel report che per i tonici serve ancora la Pesca (Q).
4) TUTORIAL (M30/M31, `data/tutorial/`): il tutorial deve funzionare per chi non pesca: il passo dei Maestri e gli incarichi iniziali non
   devono più rendere il cibo un vicolo cieco (aggiungere un passo o un incarico "Un fuoco da campo: impara la Cucina" che faccia imparare
   la Cucina e cucinare una ricetta di carne; la carne dei primi mostri deve cadere già nel primo combattimento sicuro o nelle prime
   uccisioni; ricontrolla quantità di cibo iniziale e ricompensa "Un pasto sul campo"). Il tutorial esistente resta completabile e i
   test M30/M31 restano verdi (aggiornali solo se il contenuto cambia).

TASK
- M32-01 REV (opus, breve): leggi le sezioni sopra, verifica i punti 1-4 nel codice, scrivi V e Q con i default, definisci i nomi originali
  (carne per fascia, nuovi cibi, nomi delle ricette), l'elenco dei mostri che droppano e le probabilità (come dato, non nei brief
  parafrasato), aggiorna GDD (sezione Cucina/Maestri), schema dati e, se serve, `docs/05_INTERFACES.md` (solo il Reviewer lo cambia).
- M32-02 CORE (sonnet): la Cucina sempre apprendibile (slot libero), validatore e test; migrazione solo se serve.
- M32-03 DATA (sonnet): carni, cibi, ricette per livello, loot tables dei mostri, voci della Guida (Cucina/cibo entro 160 parole),
  ritocchi al tutorial; generare con uno script in `tools/` le parti ripetitive (regola 9 di CLAUDE.md); `validate_data.gd` verde;
  test di validità e di bilanciamento dei drop (verifica che `test_drop_balance` e simili restino nelle bande).
  M32-02 e M32-03 possono girare in parallelo solo se non toccano gli stessi file.
- M32-04 UI (sonnet, solo se serve): pagina Maestri (la Cucina come scelta sempre disponibile con un testo chiaro) e la lista ricette della
  Cucina; OBBLIGATORIO un test con CLICK VERO (`Viewport.push_input` con InputEventMouseButton, GutLayer nascosto, vedi
  tests/ui/test_mail_page_smoke.gd) sull'apprendimento della Cucina quando i 2 slot sono pieni, un solo smoke test per pagina;
  screenshot a 1280x720 e 1600x900 in cartelle separate, guardati con Read.
- M32-05 QA (sonnet): sim di prova (`tools/sim_*` esistenti, cerca `sim_combat`/`sim_encounters`): un personaggio SENZA la Pesca
  (Boscaiolo + Minatore + Cucina) in combattimento per N ore ha cibo sufficiente a ogni fascia di livello (riporta cibo/ora ricavabile dalla
  carne vs cibo consumato); equivalenza offline invariata; i golden di combattimento che cambiano per i nuovi drop si ri-registrano
  (come in M29: i tiri di drop cambiano lo stato dell'RNG condiviso) con la nota nel test.
- Poi REV (opus): integrazione, `run_checks.ps1` una volta, STATUS, aggiornamento documenti, tag locale `m32-done`, CHIEDI all'utente
  prima del push.

VINCOLI
- Clean room: nomi originali, nessun nome da Melvor Idle o da altri giochi.
- Data-driven: tutto in JSON validato, niente valori nel codice; nessuno stato nella UI; nessun file > ~400 righe; testi in italiano.
- Nessuna ritaratura dell'economia oltre quanto serve: annota l'effetto sul bottino e sulle ore al 99.
- Se trovi un conflitto con documenti o codice (es. gli slot delle discipline sono vincolati in modo diverso), fermati e chiedi
  all'utente prima di procedere.

LEZIONI (nei brief): nel worktree `git checkout -B task/<nome> main`; mai `-gtest=` (usare `-gdir=... -gselect=`); prima di unire un
branch rimuovere i `*.uid` non tracciati che bloccano il merge; dopo classi globali nuove `--import`; niente taskkill/pkill generici
sui processi Godot; nessun processo Godot lasciato in background; nessun file > ~400 righe; testi con `Money.text` se mostrano monete.

Prima di iniziare: riassumi in 8 righe il piano; aspetta il mio via solo se trovi un conflitto con i documenti o con il codice.
