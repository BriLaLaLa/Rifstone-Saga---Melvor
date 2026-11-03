# RiftStone Saga: Idle

Idle/incremental "skiller" in stile Melvor Idle (meccaniche studiate in clean room, contenuti originali) nell'universo
di RiftStone. Godot **4.5 stable**, GDScript tipizzato, renderer GL Compatibility, PC desktop, **solo UI**.
12 skill nell'MVP (3 raccolta, 3 artigianato, 5 combattimento, Legatura del Rift), maestria a nodi, bank, shop,
equipaggiamento, combattimento a timer con triangolo, Altare del Rift, offline fino a 12 ore.

## Le due cartelle
| Cartella | Ruolo |
|---|---|
| `C:\Users\Davide\Desktop\AI\RIFTSTONE SAGA - Melvor\` (questa) | **il nuovo progetto**: tutto il gioco nasce qui, `res://` = questa cartella |
| `C:\Users\Davide\Desktop\AI\RIFTSTONE SAGA\` (`../RIFTSTONE SAGA/`) | gioco precedente, **solo riferimento, SOLA LETTURA**. Mai modificare, spostare o creare file lì. La legge solo il Porting Engineer. Il nuovo progetto non la referenzia mai (niente `preload`, percorsi o dipendenze): il codice riusato si **copia** con i task di porting |

## Documenti (`docs/`)
- [00_VISION.md](docs/00_VISION.md): pitch, pilastri, differenze da Melvor, fuori scope
- [01_GDD.md](docs/01_GDD.md): regole di ogni sistema, stati, casi limite
- [02_FORMULAS.md](docs/02_FORMULAS.md): formule `F-xx` con esempi (= test), tabelle di bilanciamento, registro delle stat
- [03_ARCHITECTURE.md](docs/03_ARCHITECTURE.md): cartelle, autoload, classi, tick, save, offline, modificatori, Lezioni, porting
- [04_DATA_SCHEMA.md](docs/04_DATA_SCHEMA.md): schema di ogni JSON in `data/`
- [05_INTERFACES.md](docs/05_INTERFACES.md): **contratto** tra moduli (firme, segnali, formato del save). Lo cambia solo il Reviewer
- [06_ROADMAP.md](docs/06_ROADMAP.md): milestone M0-M8
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
M0 (Setup) completata, tag `m0-done`. M1 (Prima skill completa, Selvicoltura) completata, tag `m1-done`. Prossima milestone: **M2**. Avanzamento dei task in `docs/STATUS.md`.
