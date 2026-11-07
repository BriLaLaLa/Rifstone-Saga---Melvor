# RiftStone Saga: Idle

Idle/incremental nell'universo di RiftStone con il **combattimento al centro** (visione v2, decisioni D1-D6 in
`docs/DECISIONS_LOG.md`): idee da Melvor Idle, Metin2 e Path of Exile studiate in clean room, contenuti originali.
Godot **4.5 stable**, GDScript tipizzato, renderer GL Compatibility, PC desktop, **solo UI**.
MVP: una classe (Lama del Rift, solo spade in tre assetti) con livello del personaggio, tratti e abilità; combattimento
automatico a gruppi con triangolo; Armeria di pezzi unici con rarità, affissi, raffinazione e castoni; Pietre del Rift;
7 skill di supporto (3 raccolta, 3 artigianato, Legatura del Rift) con maestria a nodi; bank, shop, Altare del Rift,
offline fino a 12 ore.

## Le due cartelle
| Cartella | Ruolo |
|---|---|
| `C:\Users\Davide\Desktop\AI\RIFTSTONE SAGA - Melvor\` (questa) | **il nuovo progetto**: tutto il gioco nasce qui, `res://` = questa cartella |
| `C:\Users\Davide\Desktop\AI\RIFTSTONE SAGA\` (`../RIFTSTONE SAGA/`) | gioco precedente, **solo riferimento, SOLA LETTURA**. Mai modificare, spostare o creare file lì. La legge solo il Porting Engineer. Il nuovo progetto non la referenzia mai (niente `preload`, percorsi o dipendenze): il codice riusato si **copia** con i task di porting |

**`../RIFTSTONE SAGA/`: solo lettura di file.** È vietato eseguire qualsiasi comando al suo interno o su di essa (git,
anche `git -C`/`git status`; Godot; script; shell). Si usano solo strumenti di lettura dei file (Read, Glob, Grep). La regola
va nel brief di ogni task di porting.

## Documenti (`docs/`)
- [00_VISION.md](docs/00_VISION.md): pitch, pilastri, differenze da Melvor, fuori scope
- [01_GDD.md](docs/01_GDD.md): regole di ogni sistema, stati, casi limite
- [02_FORMULAS.md](docs/02_FORMULAS.md): formule `F-xx` con esempi (= test), tabelle di bilanciamento, registro delle stat
- [03_ARCHITECTURE.md](docs/03_ARCHITECTURE.md): cartelle, autoload, classi, tick, save, offline, modificatori, Lezioni, porting
- [04_DATA_SCHEMA.md](docs/04_DATA_SCHEMA.md): schema di ogni JSON in `data/`
- [05_INTERFACES.md](docs/05_INTERFACES.md): **contratto** tra moduli (firme, segnali, formato del save). Lo cambia solo il Reviewer
- [06_ROADMAP.md](docs/06_ROADMAP.md): milestone M0-M12 (MVP M0-M9)
- [07_TASKS.md](docs/07_TASKS.md): backlog con ownership, accettazione, test
- [08_TEAM.md](docs/08_TEAM.md): ruoli, regole, Definition of Done, formato del report
- [09_CONVENTIONS.md](docs/09_CONVENTIONS.md): stile, nomi, test, commit
- [OPEN_QUESTIONS.md](docs/OPEN_QUESTIONS.md): decisioni aperte con default

Agenti: `.claude/agents/` (un file per ruolo di `08_TEAM.md`).

## Regole non negoziabili
1. **Clean room**: nessun codice, asset, testo, nome (skill, oggetti, mostri, luoghi) o tabella copiati da Melvor Idle.
2. **Logica separata dalla UI**: stato in classi testabili (`core/`, `systems/`); la UI legge e invia comandi, reagisce ai
   segnali dell'`EventBus`.
3. **Data-driven**: contenuti e parametri in JSON sotto `data/`; validati; nessun fallback silenzioso.
4. **Static typing ovunque**; codice, identificatori e commenti in inglese; documenti e testi di gioco in italiano.
5. **Test GUT** per tutta la logica; ogni esempio di `02_FORMULAS.md` è un test.
6. Firme e segnali solo quelli di `05_INTERFACES.md`.
7. Lavoro per task: un branch/worktree per task, solo i file in Ownership, report di fine task (`08_TEAM.md` §6).

## Lezioni da RiftStone (vincoli di progetto)
- **Niente god object**: un modulo per dominio (wallet, bank, skill, maestria, azioni, equip, combattimento, shop,
  Altare, save); `GameSession` solo composizione.
- **Unica fonte di verità**: gli oggetti esistono solo nel modello (bank, slot indossati, borsa, prese); la UI non tiene dati.
- **Nessuna stat decorativa**: ogni stat è in `data/config/stats.json` con effetto, formula e test; senza effetto non esiste.
- **Tutto lo stato del giocatore è per slot** (anche stance, cibo, azione in corso, suggerimenti). Fuori dallo slot solo
  le impostazioni (`user://settings.cfg`).
- **Nessun salvataggio prima che il giocatore scelga o crei uno slot.**
- **Un solo sistema di modificatori** (`ModifierService`), usato da tutte le formule.
- **Ogni parametro di design ha un'unica definizione** in un file di dati (`balance.json`, `stats.json`, `data/`).
- **Nessun file di scena o script oltre ~400 righe.**

## Regole operative dell'Orchestratore
- **Brief senza parafrasi del design**: mai riscrivere formule, valori o regole di design nei brief. Si cita l'ID e il
  documento (es. "F-10 in `02_FORMULAS.md`", "`01_GDD.md` §6.3") e l'agente li legge dalla fonte.
- **Repository remoto** `origin` = `https://github.com/BriLaLaLa/Rifstone-Saga---Melvor.git`.
  - Push di `main` e del tag `mN-done` solo a fine milestone, dopo il tag; mai durante la milestone (niente push dei branch `task/*`).
  - Mai force push. Se il remote ha commit che `main` non contiene: fermarsi e chiedere all'utente.
  - Se il push fallisce per autenticazione: fermarsi e dirlo all'utente, che lo fa a mano.
  - `.gitignore` esclude `.godot/`, `export/`, i file temporanei, i salvataggi e gli slot di test.

## Consumi (regole dell'utente)
1. **Modelli**: i ruoli implementativi (Core, Data/Content, UI, Combat, Porting, QA) usano `model: sonnet` nei file di
   `.claude/agents/`; il Reviewer/Integrator resta com'è.
2. **Output dei test**: GUT sempre con il log minimo (`-glog=0`) e l'output filtrato con `grep`/`tail` (solo riepilogo e
   test falliti). Mai leggere l'output completo della suite.
3. **Test mirati**: durante un task l'agente lancia solo i test della sua cartella
   (`-s addons/gut/gut_cmdln.gd -gdir=res://tests/<cartella> -ginclude_subdirs -glog=0`). La suite completa
   (`run_checks.ps1`) gira **una volta sola**, dopo il merge su main.
4. **Review sul diff**: il Reviewer legge il diff del branch e i criteri del task, non i file interi.
5. **Letture mirate**: i brief indicano le **sezioni** dei documenti da leggere, non i documenti interi.
6. **Task piccoli accorpati**: due o più task S consecutivi dello stesso ruolo vanno allo stesso agente in un'unica sessione.
7. **Parallelismo**: massimo **2** agenti insieme.
8. **Sessioni per milestone**: dopo lo stop di fine milestone l'utente apre una sessione nuova che riparte da
   `docs/STATUS.md`. STATUS.md va tenuto sempre aggiornato (stato di ogni task, hash, prossimo passo).

## Comandi
Godot: `C:\Users\Davide\Desktop\GODOT\Godot_v4.5-stable_win64_console.exe` (variabile `$env:GODOT`).

Comandi standard (dalla root del progetto o del worktree):
```bash
# import headless con un nuovo tentativo + suite GUT (exit 0 = tutti verdi)
powershell -File tools/run_tests.ps1
```
```bash
# run_tests.ps1 + validate_data.gd (fixture e dati veri) + controlli di progetto (righe per file, riferimenti vietati)
powershell -File tools/run_checks.ps1
```
```bash
"C:/Users/Davide/Desktop/GODOT/Godot_v4.5-stable_win64_console.exe" --headless --path . -s tools/validate_data.gd
```
(senza argomenti valida `res://data`; per le fixture: `... -s tools/validate_data.gd -- res://tests/fixtures/data`; `run_checks.ps1` li esegue entrambi).

Alternativa manuale ai test, due passi:
```bash
# 1. import headless delle risorse: obbligatorio in ogni worktree nuovo (senza .godot/ le classi GUT non si risolvono)
"C:/Users/Davide/Desktop/GODOT/Godot_v4.5-stable_win64_console.exe" --headless --path . --import
# 2. suite GUT da riga di comando (legge .gutconfig.json; exit 0 = tutti verdi)
"C:/Users/Davide/Desktop/GODOT/Godot_v4.5-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd
```
Il **primo import di una checkout nuova può andare in crash sui font** (segfault): si risolve cancellando i `*.tmp` in
`.godot/imported` e ripetendo l'import; `run_tests.ps1` lo fa da solo. L'avviso `ObjectDB instances leaked at exit` dopo
l'import è innocuo.

## Stato
M0 (Setup) completata, tag `m0-done`. M1 (Prima skill completa, Selvicoltura) completata, tag `m1-done`. M2 (Maestria a nodi e raccolta completa)
completata, tag `m2-done`. M3 (Artigianato, shop, equipaggiamento) completata, tag `m3-done`. Visione v2 approvata e
riportata nei documenti (R-00, fonte `docs/VISIONE_V2.md`). M4 (Riforma: personaggio e Armeria) completata, tag
`m4-done`. M5 (Combattimento a gruppi) completata, tag `m5-done`. M6 (Abilità e tratti) completata, tag `m6-done`. M7 (Bottino) completata, tag `m7-done`. M8 (Legatura del Rift) completata, tag `m8-done`.
Prossima milestone: **M9 Offline e polish** (ultima dell'MVP; sessione nuova da `docs/STATUS.md`).
Avanzamento dei task in `docs/STATUS.md`.
