# 07. Backlog dei task

Ogni task si esegue leggendo **solo** `CLAUDE.md`, il proprio file agente (`.claude/agents/<ruolo>.md`) e i documenti
in "Leggere". Ruoli: **CORE** Core Systems Dev · **COMBAT** Combat Dev · **DATA** Data/Content Designer · **UI** UI Dev ·
**PORT** Porting Engineer · **QA** QA/Test Engineer · **REV** Reviewer/Integrator (`08_TEAM.md`).

Regole per tutti i task:
- Lavora nel worktree/branch del task (`task/<ID>`), tocca **solo** i file in "Ownership". Un file non elencato che va
  cambiato = fermati e scrivilo nel report.
- Ogni script e scena ≤ 400 righe. Static typing ovunque. Nessun numero di design nel codice (`balance.json`, `stats.json`,
  dati). Nessun percorso verso `../RIFTSTONE SAGA/`.
- Firme e segnali esattamente come in `05_INTERFACES.md`. Se mancano, non inventarli: richiesta al Reviewer.
- "Test richiesti" = file GUT da creare/aggiornare nella stessa cartella speculare di `res://tests/`; tutti verdi con
  `tools/run_tests.ps1`. Il task è finito solo con la Definition of Done di `08_TEAM.md` §5.
- Stima: **S** ≤ mezza giornata-agente, **M** ≈ una, **L** ≈ due (un task L non si divide oltre solo se i file restano ≤ 400 righe).
- `project.godot`: un task può toccarne **solo** la sezione indicata in Ownership.

---

## M0 · Setup

### M0-01 · Root, project.godot, cartelle, git
- **Ruolo** REV · **Stima** S · **Parallelizzabile** no (primo task) · **Dipendenze** nessuna
- **Ownership** `res://project.godot`, `res://.gitignore`, `res://.gitattributes`, `res://.editorconfig`, `res://icon.svg`,
  i file `.gitkeep` di tutte le cartelle di `03_ARCHITECTURE.md` §2, rimozione di `RIFTSTONE SAGA - Melvor/rifstone-saga---melvor/`
- **Leggere** `03_ARCHITECTURE.md` §2-3, `09_CONVENTIONS.md` §7-8
- **Descrizione** Chiedere all'utente conferma prima di eliminare la sottocartella `rifstone-saga---melvor/` (progetto
  vuoto generato dall'editor); se l'utente dice no, fermarsi. Creare `project.godot` nella root con:
  `config/name="RiftStone Saga: Idle"`, `config/features=PackedStringArray("4.5", "GL Compatibility")`, renderer
  `gl_compatibility` (anche mobile), finestra 1600×900 (`display/window/size/viewport_width/height`), dimensione minima
  1280×720 (impostata a runtime da M0-06: qui solo la viewport), `display/window/stretch/mode="canvas_items"`,
  `aspect="expand"`, `application/config/version="0.1.0"`, avvisi GDScript di `09_CONVENTIONS.md` §1
  (`untyped_declaration` = errore). Nessun autoload, nessuna scena principale (le aggiungono M0-03 e
  M0-06). Creare l'albero delle cartelle con `.gitkeep`. `.gitattributes` con `* text=auto eol=lf` e binari marcati;
  `.gitignore` per `.godot/`, `*.tmp`, `/build/`, `export_presets.cfg` escluso dall'ignore (si versiona). `git init`,
  primo commit, branch `main`.
- **Accettazione** la sottocartella non esiste più; `godot --headless --editor --path . --quit` esce con 0 (senza scena
  principale `--quit` da solo non è applicabile: passa a M0-06); `git status` pulito;
  tutte le cartelle di §2 esistono.
- **Test** nessun test GUT (GUT arriva con M0-02); verifica manuale con i comandi sopra, riportata nel report.

### M0-02 · GUT e hook dei test
- **Ruolo** PORT · **Stima** S · **Parallelizzabile** sì (con M0-04, M0-05, M0-07) · **Dipendenze** M0-01
- **Ownership** `res://addons/gut/**`, `res://.gutconfig.json`, `res://tests/helpers/gut_pre_run.gd`, `res://tests/test_smoke.gd`,
  `project.godot` sezione `[editor_plugins]`
- **Leggere** `03_ARCHITECTURE.md` §2 e §13, `09_CONVENTIONS.md` §6
- **Sorgente** `../RIFTSTONE SAGA/addons/gut/` (GUT 9.5.0) → `res://addons/gut/` (copia intera, senza modifiche).
- **Descrizione** Copiare GUT, abilitare il plugin. `.gutconfig.json`: `dirs ["res://tests"]`, `include_subdirs true`,
  `prefix "test_"`, `suffix ".gd"`, `log_level 1`, `should_exit true`, `pre_run_script "res://tests/helpers/gut_pre_run.gd"`.
  L'hook: se esiste l'autoload `SaveService` imposta `base_dir = "user://test_saves"` e svuota la cartella; altrimenti
  non fa nulla. `test_smoke.gd`: un test che passa sempre.
- **Accettazione** `godot --headless --path . -s addons/gut/gut_cmdln.gd` esegue 1 test verde ed esce con 0; nessun file
  fuori da `addons/gut/` copiato da RiftStone.
- **Test** `tests/test_smoke.gd`.

### M0-03 · Autoload e tipi comuni
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** no · **Dipendenze** M0-01, M0-02
- **Ownership** `res://core/autoload/*.gd` (6 file), `res://core/common/command_result.gd`, `res://core/common/reasons.gd`,
  `res://tests/core/autoload/test_event_bus.gd`, `test_game_clock.gd`, `test_log.gd`, `res://tests/core/common/test_command_result.gd`,
  `project.godot` sezione `[autoload]`
- **Leggere** `03_ARCHITECTURE.md` §3, §6; `05_INTERFACES.md` §1-3
- **Descrizione** `Log` completo; `EventBus` (`class_name GameEvents`) con **tutti** i segnali di §3 tranne quelli marcati
  M6/M7; `GameClock` completo (accumulatore, `configure`, pausa, `time_source` sostituibile); `CommandResult` e `Reasons`
  completi. Stub con le firme definitive: `DataRegistry` (`data = null`, `reload()` restituisce false), `SaveService`
  (`class_name SaveStore`, metodi che restituiscono `CommandResult.fail(Reasons.IO_ERROR)`/`{}`), `Game` (`session = null`,
  `state = &"menu"`, `save_now()` restituisce `slot_not_selected`, gli altri `fail(no_session)`). Registrare gli autoload
  nell'ordine di §3 (senza `Tooltips`, che aggiunge M1-16).
- **Accettazione** il progetto si avvia senza errori; ogni segnale ha i parametri tipizzati di §3; `GameClock` con 250 ms
  simulati e `tick_ms` 100 emette 2 volte e conserva 50 ms.
- **Test** `test_event_bus.gd` (elenco dei segnali e numero di argomenti via `get_signal_list`), `test_game_clock.gd`
  (accumulo, catch-up limitato, pausa), `test_log.gd` (livelli), `test_command_result.gd`.

### M0-04 · Tema UI portato da RiftStone
- **Ruolo** PORT · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M0-01
- **Ownership** `res://ui/theme/ui_style.gd`, `res://ui/theme/riftstone_idle_theme.tres`, `res://tools/build_ui_theme.gd`,
  `res://assets/fonts/**`, `res://assets/ui/frames/**`, `res://assets/icons/ui/**`, `res://tests/ui/test_ui_style.gd`,
  `project.godot` chiave `gui/theme/custom`
- **Leggere** `03_ARCHITECTURE.md` §11, §13; `09_CONVENTIONS.md` §2
- **Sorgente** `../RIFTSTONE SAGA/scripts/ui/theme/UiStyle.gd` → `res://ui/theme/ui_style.gd`;
  `../RIFTSTONE SAGA/tools/build_ui_theme.gd` → `res://tools/build_ui_theme.gd`;
  `../RIFTSTONE SAGA/assets/fonts/*` (con `OFL-*.txt`) → `res://assets/fonts/`;
  `../RIFTSTONE SAGA/assets/ui/frame_*.png` → `res://assets/ui/frames/`;
  `../RIFTSTONE SAGA/assets/ui/icons/*` (solo icone elencate nel report + `LICENSE-tabler.txt`) → `res://assets/icons/ui/`.
- **Descrizione** Refactor: nome file `snake_case`; tutti i percorsi verso le nuove cartelle; `THEME_PATH =
  "res://ui/theme/riftstone_idle_theme.tres"`; tipizzazione completa; aggiungere le costanti di presentazione
  (`TOAST_MAX_VISIBLE = 4`, `TOAST_GROUP_MS = 1000`, `BANNER_MS = 2000`, `SIDEBAR_WIDTH = 260`, `TOP_BAR_HEIGHT = 56`,
  `WINDOW_MIN_SIZE = Vector2i(1280, 720)`,
  `MISSING_ICON` = percorso di un'icona segnaposto generata in codice o presente in `assets/icons/ui/`); niente riferimenti a
  stat, inventario o 3D. Rigenerare il tema e impostarlo in `gui/theme/custom`.
- **Accettazione** `godot --headless --path . -s tools/build_ui_theme.gd` rigenera il `.tres` senza errori; `ui_style.gd`
  ≤ 400 righe; nessun percorso `res://scripts/` o `../`; licenze dei font e delle icone presenti.
- **Test** `test_ui_style.gd`: font caricabili, varianti del tema presenti (`TitleLabel`, `HeaderLabel`, `MutedLabel`,
  `IconButton`, `AccentButton`, `ListButton`, `HudPanel`, `WindowPanel`, `SlotPanel`), `icon()` restituisce texture.

### M0-05 · Configurazione di bilanciamento e registro delle stat
- **Ruolo** DATA · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M0-02
- **Ownership** `res://data/config/balance.json`, `res://data/config/stats.json`, `res://tests/data/test_config_files.gd`
- **Leggere** `02_FORMULAS.md` §9, §11; `04_DATA_SCHEMA.md` §2-3
- **Descrizione** Scrivere i due file con esattamente i valori di §9 (senza le chiavi M7/M8) e le 21 stat di §11 (con nome
  italiano, formato, limiti, descrizione, formula, test).
- **Accettazione** JSON valido; tutte le chiavi presenti; nessuna stat di M7/M8.
- **Test** `test_config_files.gd`: parse dei file, presenza di ogni chiave di §9 MVP con il valore atteso, 21 stat con
  campi obbligatori e `min < max`.

### M0-06 · Menu segnaposto e scena principale
- **Ruolo** UI · **Stima** S · **Parallelizzabile** no · **Dipendenze** M0-03, M0-04
- **Ownership** `res://ui/screens/main_menu/main_menu.tscn`, `main_menu.gd`, `res://tests/ui/test_main_menu_smoke.gd`,
  `project.godot` chiavi `run/main_scene` e nessun'altra
- **Leggere** `01_GDD.md` §1; `03_ARCHITECTURE.md` §11; `09_CONVENTIONS.md` §2-3
- **Descrizione** Scena con titolo (Cinzel, `TitleLabel`), pulsanti Nuova partita, Continua, Impostazioni (disabilitati) ed
  Esci (funziona). In `_ready` imposta `get_window().min_size = UiStyle.WINDOW_MIN_SIZE` (costante creata da M0-04).
- **Accettazione** F5 apre il menu nello stile D; Esci chiude; nessun file scritto in `user://`;
  `godot --headless --path . --quit` esce con 0 (criterio spostato da M0-01).
- **Test** `test_main_menu_smoke.gd`: la scena si istanzia, ha i 4 pulsanti, nessun errore.

### M0-07 · Script di test e di controllo
- **Ruolo** QA · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M0-02
- **Ownership** `res://tools/run_tests.ps1`, `res://tools/run_checks.ps1`, `res://tools/check_file_sizes.gd`,
  `res://tools/check_forbidden_refs.gd`, `res://tests/tools/test_checks.gd`
- **Leggere** `09_CONVENTIONS.md` §6, §9; `CLAUDE.md` (comandi)
- **Descrizione** `run_tests.ps1`: lancia GUT headless con l'eseguibile in `$env:GODOT` (default
  `C:\Users\Davide\Desktop\GODOT\Godot_v4.5-stable_win64_console.exe`), esce con il codice di GUT. `check_file_sizes.gd`
  (script `SceneTree`): fallisce se un `.gd` o `.tscn` sotto `core/ systems/ ui/ tools/` supera 400 righe (esclusi
  `addons/`, file generati `*.tres`). `check_forbidden_refs.gd`: fallisce se un file di testo del progetto (esclusi
  `docs/`, `CLAUDE.md`, `.claude/`) contiene `RIFTSTONE SAGA/`, `../RIFTSTONE`, `get_node("/root/` fuori da
  `core/autoload/`, oppure `print(` fuori da `core/autoload/log.gd`. `run_checks.ps1`: test + i due controlli; esce ≠ 0 al
  primo fallimento.
- **Accettazione** `run_checks.ps1` verde sul repository di M0; un file di prova da 401 righe lo fa fallire (provato e poi
  rimosso, scritto nel report).
- **Test** `test_checks.gd`: le funzioni di conteggio e di ricerca dei due script, su stringhe in memoria.

### M0-08 · Integrazione di M0
- **Ruolo** REV · **Stima** S · **Parallelizzabile** no · **Dipendenze** M0-01…M0-07
- **Ownership** merge su `main`, tag `m0-done`
- **Leggere** `08_TEAM.md` §4-6
- **Descrizione** Revisione e merge dei branch nell'ordine delle dipendenze; `run_checks.ps1` verde su `main`.
- **Accettazione** tag `m0-done`; report di milestone con l'elenco dei task chiusi.
- **Test** esecuzione completa della suite.

---

## M1 · Prima skill completa

### M1-01 · Tabella dell'esperienza
- **Ruolo** CORE · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M0-08
- **Ownership** `res://core/progression/xp_table.gd`, `res://tests/core/progression/test_xp_table.gd`
- **Leggere** `02_FORMULAS.md` F-01, F-09; `05_INTERFACES.md` §5.1
- **Descrizione** `XpTable` con tabella precalcolata (array dei totali) e ricerca binaria in `level_for_xp`.
- **Accettazione** tutti i valori delle tabelle F-01 e F-09 riprodotti; `level_for_xp` corretto ai bordi.
- **Test** `test_xp_table.gd`: valori di F-01 e F-09, bordi (69/70/154/155), xp oltre il 99, `progress`.

### M1-02 · Sistema dei modificatori
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M0-08
- **Ownership** `res://core/modifiers/modifier.gd`, `modifier_context.gd`, `modifier_service.gd`, `stat_registry.gd`,
  `res://tests/core/modifiers/test_modifier.gd`, `test_modifier_service.gd`, `test_stat_registry.gd`
- **Leggere** `01_GDD.md` §15; `02_FORMULAS.md` F-05, §11; `03_ARCHITECTURE.md` §9; `05_INTERFACES.md` §5.2
- **Descrizione** Implementare le quattro classi. `set_source` sostituisce; `total` somma e limita; batch; `breakdown`.
- **Accettazione** esempio di F-05 riprodotto; `set_source` due volte con lo stesso id non raddoppia; stat sconosciuta
  → errore e ignorata; `modifiers_changed` una volta per batch.
- **Test** i tre file, incluso `test_modifier_service.gd::test_set_source_replaces` e l'esempio F-05.

### M1-03 · Classi Def e caricatore JSON
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì (con M1-01) · **Dipendenze** M1-02
- **Ownership** `res://core/data/defs/*.gd` (tutte le Def MVP di `05_INTERFACES.md` §4: `item_def`, `equip_info`,
  `weapon_info`, `item_qty`, `drop_entry`, `skill_def`, `mastery_bonus_rule`, `action_def`, `mastery_node_def`,
  `area_def`, `monster_def`, `shop_entry_def`), `res://core/data/json_loader.gd`, `res://tests/core/data/test_defs.gd`,
  `test_json_loader.gd`
- **Leggere** `04_DATA_SCHEMA.md` §1, §4-9; `05_INTERFACES.md` §4
- **Descrizione** `from_dict` di ogni Def con conversione dei tipi (`int()` sui numeri, `StringName` sugli id,
  `Color` da `#rrggbb`, `Vector2i` da `pos`), default dello `scope` (`skill:<skill>` per i nodi, `action:<id>` per i bonus
  della maestria applicato dal MasterySystem). Nessuna validazione semantica (è M1-04).
- **Accettazione** ogni esempio di `04_DATA_SCHEMA.md` diventa una Def con i valori giusti.
- **Test** `test_defs.gd` (un test per ogni esempio dello schema), `test_json_loader.gd` (file mancante, JSON rotto, cartella).

### M1-04 · Validatore, GameData, DataRegistry, fixture
- **Ruolo** CORE · **Stima** L · **Parallelizzabile** no · **Dipendenze** M1-01, M1-03, M0-05
- **Ownership** `res://core/data/data_validator.gd`, `res://core/data/game_data.gd`, `res://core/autoload/data_registry.gd`,
  `res://tools/validate_data.gd` (script `SceneTree` che stampa `errors` ed esce ≠ 0 se non validi), `res://tests/fixtures/data/**`, `res://tests/core/data/test_data_validator.gd`, `test_game_data.gd`
- **Leggere** `03_ARCHITECTURE.md` §10; `04_DATA_SCHEMA.md` tutto; `05_INTERFACES.md` §4
- **Descrizione** Validazione di schema e riferimenti di `04_DATA_SCHEMA.md` (regole comuni + per tipo, campi sconosciuti,
  `REQUIRED_BALANCE_KEYS`, cicli nei `requires` dei nodi, stat dei modificatori nel registro, `rift_shard` presente).
  `GameData.load_from_dirs` e tutte le letture di §4. `DataRegistry.reload()` vero. Fixture minime di `04_DATA_SCHEMA.md` §13.
  Se `data_validator.gd` supera 400 righe, dividerlo in `data_validator.gd` + `data_validator_rules.gd` (stessa ownership).
- **Accettazione** fixture valide; ogni regola ha un caso di errore che produce un messaggio con file e id; nessun
  fallback (id mancante → `null` + errore).
- **Test** `test_data_validator.gd` (un test per regola), `test_game_data.gd` (letture, ordinamenti, `balance_value`).

### M1-05 · Casualità, sessione, snapshot, factory dei test
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** no · **Dipendenze** M1-04
- **Ownership** `res://core/session/rng_service.gd`, `game_session.gd`, `session_snapshot.gd`, `res://tests/helpers/test_factory.gd`,
  `res://tests/core/session/test_rng_service.gd`, `test_game_session.gd`
- **Leggere** `01_GDD.md` §1.1, §2; `03_ARCHITECTURE.md` §4, §6; `05_INTERFACES.md` §5.1, §5.3, §8
- **Descrizione** `RngService` su `RandomNumberGenerator` con stato salvabile. `GameSession` con i campi di §5.3; in questo
  task crea solo `rng` e `modifiers` (gli altri sistemi li aggiungono i loro task, ognuno con una riga di creazione e una
  nella lista dei partecipanti al salvataggio); `advance` chiama i sistemi presenti (non `null`) nell'ordine fisso;
  `to_save/from_save` iterano sui partecipanti. `SessionSnapshot.take` legge ciò che esiste. `TestFactory` di §8.
- **Accettazione** due `RngService` con lo stesso seme danno la stessa sequenza, anche dopo `to_save/from_save`;
  `to_save` produce l'intestazione di §6; `game_session.gd` ≤ 200 righe.
- **Test** `test_rng_service.gd` (determinismo, `roll_pct` 0/100 senza consumo), `test_game_session.gd` (intestazione,
  ordine di `advance` con sistemi finti, round-trip).

### M1-06 · Salvataggio per slot con versioni
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì (con M1-05…M1-09) · **Dipendenze** M0-08
- **Ownership** `res://core/autoload/save_service.gd`, `res://core/save/save_codec.gd`, `save_migrator.gd`, `slot_info.gd`,
  `res://core/save/migrations/.gitkeep`, `res://tests/core/save/test_save_store.gd`, `test_save_migrator.gd`, `test_save_codec.gd`,
  `res://tests/helpers/gut_pre_run.gd` (tipizzare l'accesso a `SaveService` con `as SaveStore` al posto di `set()`)
- **Leggere** `01_GDD.md` §1; `03_ARCHITECTURE.md` §7; `05_INTERFACES.md` §2 (SaveService), §6
- **Descrizione** Scrittura atomica (`.tmp` → `.bak` → rename), lettura con fallback sul `.bak`, `SlotInfo` dall'intestazione,
  migrazioni in catena (con una migrazione finta solo nei test), `version_unsupported`. Misurare il tempo di scrittura di un
  file da 200 KB e riportarlo; se > 30 ms segnalarlo nel report (il passaggio al thread è un task a parte).
- **Accettazione** file principale corrotto → si legge il `.bak`; entrambi corrotti → `SlotInfo.state = corrupted`;
  `format_version` 2 con `CURRENT_VERSION` 1 → `unsupported`; nessuna scrittura se non chiamata.
- **Test** i tre file; i test usano `base_dir = "user://test_saves"`.

### M1-07 · Wallet e Bank
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì (con M1-08, M1-09) · **Dipendenze** M1-05
- **Ownership** `res://systems/wallet/wallet.gd`, `res://systems/bank/bank.gd`, `res://tests/systems/wallet/test_wallet.gd`,
  `res://tests/systems/bank/test_bank.gd`, `res://core/session/game_session.gd` (solo creazione e registrazione dei due sistemi)
- **Leggere** `01_GDD.md` §7-8; `02_FORMULAS.md` F-16; `05_INTERFACES.md` §5.4-5.5, §6
- **Descrizione** Come da interfacce. `start.gold` e `start.items` applicati in `new_game` di Wallet/Bank.
- **Accettazione** un oggetto nuovo con bank piena → `bank_full` + `bank_rejected`; quantità 0 libera la casella; capienza
  segue `bank_slots`; ordine conservato nel salvataggio.
- **Test** `test_wallet.gd`, `test_bank.gd` (incluso `test_capacity_uses_bank_slots`, F-16).

### M1-08 · Skill ed esperienza
- **Ruolo** CORE · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M1-05
- **Ownership** `res://systems/skills/skills_system.gd`, `res://tests/systems/skills/test_skills_system.gd`,
  `res://core/session/game_session.gd` (solo registrazione)
- **Leggere** `01_GDD.md` §3; `02_FORMULAS.md` F-01, F-02; `05_INTERFACES.md` §5.6
- **Descrizione** XP per skill, livelli derivati, un `level_up` per livello, tetto `xp_cap`.
- **Accettazione** esempi di F-02; salto di 3 livelli = 3 segnali.
- **Test** `test_skills_system.gd` (incluso `test_add_xp_applies_skill_xp_pct`).

### M1-09 · Maestria per oggetto e pool
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M1-05
- **Ownership** `res://systems/mastery/mastery_math.gd`, `mastery_system.gd`, `res://tests/systems/mastery/test_mastery_math.gd`,
  `test_mastery_system.gd`, `res://core/session/game_session.gd` (solo registrazione)
- **Leggere** `01_GDD.md` §6.1-6.2; `02_FORMULAS.md` F-09…F-14; `05_INTERFACES.md` §5.7
- **Descrizione** Tutto `MasteryMath`; in `MasterySystem`: guadagno, livelli, pool, bonus per oggetto (`rebuild_modifiers`
  per `mastery_item:*`, aggiornato a ogni salita di livello di maestria), `spend_pool_on_action`. I metodi dei nodi
  (`node_cost`, `owns_node`, `can_buy_node`, `buy_node`) restituiscono `unknown_id` finché M2-01 non li implementa.
- **Accettazione** esempi di F-10…F-14; il pool non supera il tetto.
- **Test** `test_mastery_math.gd` (incluso `test_mastery_xp_pct`), `test_mastery_system.gd` (bonus F-11, spesa F-14).

### M1-10 · ActionRunner e raccolta
- **Ruolo** CORE · **Stima** L · **Parallelizzabile** no · **Dipendenze** M1-07, M1-08, M1-09
- **Ownership** `res://systems/actions/action_runner.gd`, `action_math.gd`, `action_outcome.gd`, `gathering_resolver.gd`,
  `res://tests/systems/actions/test_action_math.gd`, `test_action_runner.gd`, `test_gathering_resolver.gd`,
  `res://core/session/game_session.gd` (solo registrazione)
- **Leggere** `01_GDD.md` §2, §4; `02_FORMULAS.md` F-03, F-04, F-06, F-07; `05_INTERFACES.md` §5.8
- **Descrizione** Corsia `main`; più cicli nello stesso `advance`; intervallo ricalcolato a ogni ciclo; stop con motivo
  (`bank_full`, `stopped_by_user`, `replaced`); `elapsed_ms` salvato; `stop_reasons_log`. Se `session.combat` esiste e
  `start` è sulla corsia main, ferma il combattimento (controllo `null`-safe: `CombatEngine` arriva in M4).
  La parte artigianato (`ArtisanResolver`) è M3-01: `start` di un'azione con `inputs` restituisce `unknown_id` fino ad allora.
- **Accettazione** 600 ms con intervallo 250 → 2 cicli e 100 ms residui; equivalenza 1×1000 ms = 10×100 ms (stesso stato,
  stesso seme); bank piena → nessuna XP, stop `bank_full`.
- **Test** i tre file (inclusi `test_interval_uses_skill_interval_pct`, `test_double_item_chance_100`, `test_rift_shard_chance`).

### M1-11 · Game: menu → slot → partita
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** no · **Dipendenze** M1-06, M1-10
- **Ownership** `res://core/autoload/game.gd`, `res://tests/core/autoload/test_game.gd`,
  `res://tests/core/autoload/test_game_no_save_before_slot.gd`
- **Leggere** `01_GDD.md` §1-2; `03_ARCHITECTURE.md` §6-7, §12; `05_INTERFACES.md` §2 (Game)
- **Descrizione** Implementazione completa senza offline (in `continue_game` il punto in cui M6-01 inserirà l'offline è
  un commento `# Offline: M6-01`). Autosave con un `Timer` figlio creato all'ingresso in partita e distrutto in
  `end_session`. Configura `GameClock` e `SaveService` dai dati. Seme nuovo = `Time.get_ticks_usec()` mescolato con lo slot.
- **Accettazione** nessun file in `user://test_saves` finché non si chiama `new_game`; `new_game` scrive subito; 10 s di
  `GameClock` simulati in partita → 1 salvataggio; `end_session` libera la sessione (`is_instance_valid` falso).
- **Test** `test_game.gd`, `test_game_no_save_before_slot.gd`.

### M1-12 · Contenuto: le 12 skill e Selvicoltura
- **Ruolo** DATA · **Stima** M · **Parallelizzabile** sì (dopo M1-04) · **Dipendenze** M1-04
- **Ownership** `res://data/skills/skills.json`, `res://data/items/materials.json`, `res://data/items/misc.json`,
  `res://data/actions/forestry.json`, `res://assets/icons/skills/**` (segnaposto), `res://assets/icons/items/**` (segnaposto
  di questi oggetti), `res://tests/data/test_data_validity.gd`
- **Leggere** `00_VISION.md`; `01_GDD.md` §3-4, §6.1; `02_FORMULAS.md` §8.1, F-11; `04_DATA_SCHEMA.md` §4-6; `09_CONVENTIONS.md` §5
- **Descrizione** Le 12 skill (id, nomi italiani di `00_VISION.md`, categorie, colori, `mastery_bonuses` di F-11 per raccolta e
  artigianato). Selvicoltura: 8 azioni sui gradini T1-T8 di §8.1 con 8 legni dai nomi originali a tema Roccarossa/Rift;
  `rift_shard` in `misc.json`. Icone segnaposto (64×64, generate o semplici, licenza propria).
- **Accettazione** `GameData.load_from_dirs()` valido; nessun nome preso da Melvor Idle (controllo nel report: elenco dei
  nomi); numeri uguali a §8.1.
- **Test** `test_data_validity.gd`: dati veri validi, 12 skill con gli id di `00_VISION.md`, ogni azione rispetta i gradini.

### M1-13 · Menu principale e scelta dello slot
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì (con M1-14) · **Dipendenze** M1-11, M0-06
- **Ownership** `res://ui/screens/main_menu/**`, `res://ui/screens/slot_select/**`, `res://ui/components/confirm_dialog/**`,
  `res://tests/ui/test_main_menu_smoke.gd`, `test_slot_select_smoke.gd`
- **Leggere** `01_GDD.md` §1; `05_INTERFACES.md` §2 (Game, SlotInfo), §7; `09_CONVENTIONS.md` §2-3
- **Descrizione** Nuova partita (scelta slot, conferma sovrascrittura, nome), Continua (slot con nome, data, tempo di gioco,
  livello totale; danneggiati e non supportati non cliccabili), Elimina con conferma. Dopo `new_game`/`continue_game` ok:
  `change_scene_to_file("res://ui/screens/main/main_screen.tscn")`.
- **Accettazione** nessun file scritto aprendo e chiudendo il menu; i tre stati dello slot visibili; nome non valido rifiutato
  con messaggio.
- **Test** smoke test delle due scene; la scelta di uno slot vuoto non chiama `continue_game`.

### M1-14 · Schermata principale: sidebar, barra in alto, PageHost
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M1-11, M1-17
- **Ownership** `res://ui/screens/main/**` (`main_screen`, `sidebar`, `top_bar`, `page_host`), `res://ui/pages/page.gd`,
  `res://tests/ui/test_main_screen_smoke.gd`
- **Leggere** `01_GDD.md` §13; `03_ARCHITECTURE.md` §11; `05_INTERFACES.md` §3, §7
- **Descrizione** Sidebar dalle skill dei dati (icona, nome, livello aggiornato su `level_up`) + Bank, Shop, Equipaggiamento,
  Combattimento, Altare (voci non ancora implementate disabilitate con "In arrivo"); barra in alto (oro, caselle
  usate/capienza, nome dello slot, pulsante menu → `Game.end_session(true)` e ritorno al menu); `PageHost` con la tabella
  delle rotte; `ToastManager` istanziato nella schermata.
- **Accettazione** nessuna variabile con stato di gioco nella UI (solo letture); cambiare pagina scollega i segnali.
- **Test** smoke: la scena si istanzia con una sessione della `TestFactory`; `show_page` di ogni rotta valida.

### M1-15 · Pagina skill (raccolta) e componenti base
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M1-14, M1-16
- **Ownership** `res://ui/pages/skill/skill_page.gd/.tscn`, `action_card.gd/.tscn`, `res://ui/components/item_slot/**`,
  `res://ui/components/progress/**`, `res://tests/ui/test_skill_page_smoke.gd`
- **Leggere** `01_GDD.md` §4, §6.1; `02_FORMULAS.md` F-03, F-04; `05_INTERFACES.md` §5.6-5.8, §7
- **Descrizione** Pagina generica per qualunque skill di raccolta: intestazione (livello, barra XP), carte delle azioni
  (bloccate sotto il livello, con XP, intervallo attuale, prodotto, livello di maestria), Avvia/Ferma, barra di progresso
  continua (letta ogni frame da `get_progress`), motivo di stop come toast.
- **Accettazione** la barra non tiene stato (solo lettura); l'intervallo mostrato coincide con `current_interval_ms`.
- **Test** smoke della pagina con la fixture `test_gather`.

### M1-16 · Tooltip e GameWindow portati
- **Ruolo** PORT · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M1-04, M0-04
- **Ownership** `res://ui/components/tooltip/**`, `res://ui/components/game_window/**`, `res://tests/ui/test_tooltip.gd`,
  `project.godot` sezione `[autoload]` (solo la riga `Tooltips`, in fondo)
- **Leggere** `03_ARCHITECTURE.md` §13; `05_INTERFACES.md` §2 (Tooltips), §4 (ItemDef), §5.2 (StatRegistry)
- **Sorgente** `../RIFTSTONE SAGA/scripts/ui/TooltipManager.gd`, `scripts/ui/CustomTooltip.gd`, `scenes/ui/CustomTooltip.tscn`
  → `res://ui/components/tooltip/tooltip_manager.gd`, `custom_tooltip.gd`, `custom_tooltip.tscn`;
  `../RIFTSTONE SAGA/scripts/ui/hud/GameWindow.gd` → `res://ui/components/game_window/game_window.gd`.
- **Descrizione** Togliere ogni accesso a `GameState`/`/root/`; input `ItemDef` + quantità; righe dei modificatori
  dell'oggetto con l'etichetta e il formato di `StatRegistry.info()`; nessuna stat inventata. `GameWindow` invariata salvo
  `snake_case`, tipizzazione e testi.
- **Accettazione** nessun riferimento a dizionari "oggetto" di RiftStone; file ≤ 400 righe.
- **Test** `test_tooltip.gd`: `show_item` con un oggetto delle fixture produce le righe attese; `hide_tooltip`.

### M1-17 · Toast portati
- **Ruolo** PORT · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M0-03, M0-04
- **Ownership** `res://ui/components/toast/**`, `res://tests/ui/test_toast_manager.gd`
- **Leggere** `01_GDD.md` §13; `05_INTERFACES.md` §3, §7 (ToastManager)
- **Sorgente** `../RIFTSTONE SAGA/scripts/ui/LootNotificationManager.gd`, `LootNotification.gd`, `scenes/ui/LootNotification.tscn`
  → `res://ui/components/toast/toast_manager.gd`, `toast.gd`, `toast.tscn`.
- **Descrizione** Da `CanvasLayer` globale a `Control` dentro la schermata; ascolta `notification_requested`,
  `bank_changed` (solo aumenti, raggruppati per `TOAST_GROUP_MS`), `level_up`, `action_stopped`; massimo `TOAST_MAX_VISIBLE`.
- **Accettazione** 10 `bank_changed` dello stesso oggetto in 1 s → un toast con la somma.
- **Test** `test_toast_manager.gd` con un `GameEvents` nuovo.

### M1-18 · Bank minima
- **Ruolo** UI · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M1-14, M1-15, M1-16
- **Ownership** `res://ui/pages/bank/bank_page.gd/.tscn`, `res://tests/ui/test_bank_page_smoke.gd`
- **Leggere** `01_GDD.md` §7; `05_INTERFACES.md` §5.5, §7
- **Descrizione** Griglia di `ItemSlotView` dalle `stacks()` nell'ordine della bank, contatore caselle, tooltip al passaggio.
- **Accettazione** si aggiorna su `bank_changed` rileggendo; nessuna copia delle quantità.
- **Test** smoke con oggetti dati dalla `TestFactory`.

### M1-19 · Test di integrazione di M1
- **Ruolo** QA · **Stima** M · **Parallelizzabile** no · **Dipendenze** M1-10, M1-11, M1-12
- **Ownership** `res://tests/integration/test_gathering_loop.gd`, `test_save_roundtrip.gd`, `test_slot_isolation.gd`,
  `test_item_conservation.gd`, `res://tests/data/test_stat_registry_coverage.gd`
- **Leggere** `03_ARCHITECTURE.md` §7, §12; `02_FORMULAS.md` §11; `05_INTERFACES.md` §6, §8
- **Descrizione** Flusso: partita nuova → 60 s di Selvicoltura via `advance` → XP, oggetti, maestria attesi (seme fisso);
  salva/ricarica identico (anche `elapsed_ms` e RNG); slot A e B non si influenzano; conservazione degli oggetti
  (prodotti = bank finale). Copertura delle stat: per ogni stat di `stats.json` il test indicato deve esistere;
  finché la milestone di quella formula non è chiusa il caso è `pending()` (diventa errore in M6-07).
- **Accettazione** tutti verdi o `pending` motivati.
- **Test** i cinque file.

### M1-20 · Integrazione di M1
- **Ruolo** REV · **Stima** M · **Parallelizzabile** no · **Dipendenze** M1-01…M1-19
- **Ownership** merge, tag `m1-done`, `docs/` solo per correzioni concordate
- **Leggere** `08_TEAM.md` §4-6; `06_ROADMAP.md` M1
- **Descrizione** Revisione con la checklist di `09_CONVENTIONS.md` §9, merge, partita di prova manuale con le voci del
  "Giocabile" di M1.
- **Accettazione** tag `m1-done`; report di milestone con l'esito della prova.
- **Test** suite completa e `run_checks.ps1`.

---

## M2 · Maestria a nodi e raccolta completa

### M2-01 · Nodi della maestria
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì (con M2-02) · **Dipendenze** M1-20
- **Ownership** `res://systems/mastery/mastery_system.gd`, `res://tests/systems/mastery/test_mastery_nodes.gd`
- **Leggere** `01_GDD.md` §6.3; `02_FORMULAS.md` F-15, §8.8; `05_INTERFACES.md` §5.7
- **Descrizione** `node_cost`, `owns_node`, `can_buy_node`, `buy_node`, sorgenti `mastery_node:*`; nodi nel salvataggio.
  Se `mastery_system.gd` supera 400 righe, estrarre `mastery_nodes.gd` (classe interna di supporto, stessa cartella, ownership di questo task).
- **Accettazione** esempi di F-15; prerequisiti; nodi permanenti dopo la spesa del pool.
- **Test** `test_mastery_nodes.gd`.

### M2-02 · Contenuto: Cavatura, Lenza, nodi della raccolta
- **Ruolo** DATA · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M1-20
- **Ownership** `res://data/actions/quarrying.json`, `angling.json`, `res://data/items/materials.json` (aggiunte),
  `res://data/mastery/forestry.json`, `quarrying.json`, `angling.json`, icone segnaposto relative, `res://tests/data/test_data_validity.gd` (casi nuovi)
- **Leggere** `02_FORMULAS.md` §8.1, §8.8; `04_DATA_SCHEMA.md` §5-7; `09_CONVENTIONS.md` §5
- **Descrizione** 8 azioni per skill sui gradini T1-T8; minerali (servono poi alla Forgiatura: 8 gradi) e pesci crudi
  (8 gradi); nodi di Selvicoltura come §8.8, nodi di Cavatura e Lenza con lo stesso schema e modificatori a tema.
- **Accettazione** dati validi; costi totali dei nodi 55-65%; nomi originali.
- **Test** casi nuovi in `test_data_validity.gd`.

### M2-03 · Pannello della maestria
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M2-01, M1-15
- **Ownership** `res://ui/pages/mastery/**`, `res://ui/pages/skill/skill_page.gd` (solo il pulsante che apre il pannello),
  `res://tests/ui/test_mastery_panel_smoke.gd`
- **Leggere** `01_GDD.md` §6; `05_INTERFACES.md` §5.7, §7
- **Descrizione** Finestra (`GameWindow`) con: barra del pool (avviso al 95%), elenco delle azioni con livello e barra di
  maestria, spesa del pool (importo con cursore), albero dei nodi disposto per `pos` con stato (comprato, comprabile, bloccato).
- **Accettazione** ogni comando passa da `MasterySystem` e mostra il `reason` in caso di errore.
- **Test** smoke con la fixture.

### M2-04 · Bank completa
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M1-18
- **Ownership** `res://ui/pages/bank/**`, `res://tests/ui/test_bank_page_smoke.gd`
- **Leggere** `01_GDD.md` §7; `05_INTERFACES.md` §5.5, §7
- **Descrizione** Pannello dell'oggetto (`bank_item_panel.gd/.tscn`) con blocca/sblocca, trascinamento per riordinare
  (`move_stack`), pulsante Ordina (`sort_stacks`), ricerca per nome. (Vendita, equipaggia, cibo: M3-06/M3-07.)
- **Accettazione** l'ordine sopravvive al salvataggio; il trascinamento non sposta nulla se `move_stack` fallisce.
- **Test** smoke aggiornato.

### M2-05 · Test di M2
- **Ruolo** QA · **Stima** S · **Parallelizzabile** no · **Dipendenze** M2-01…M2-04
- **Ownership** `res://tests/integration/test_mastery_flow.gd`
- **Leggere** `02_FORMULAS.md` F-10…F-15
- **Descrizione** Flusso: raccolta lunga → pool → acquisto nodi → l'intervallo cambia di quanto previsto; spesa del pool su
  un'azione → nuovo livello e bonus F-11.
- **Accettazione / Test** il file verde con seme fisso.

### M2-06 · Integrazione di M2
- **Ruolo** REV · **Stima** S · **Parallelizzabile** no · **Dipendenze** M2-01…M2-05
- **Ownership** merge, tag `m2-done` · **Leggere** `08_TEAM.md` §4-6 · **Descrizione** come M1-20 · **Accettazione** tag `m2-done` · **Test** suite.

---

## M3 · Artigianato, shop, equipaggiamento

### M3-01 · Ricette dell'artigianato
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì (con M3-02, M3-03, M3-04) · **Dipendenze** M2-06
- **Ownership** `res://systems/actions/artisan_resolver.gd`, `res://systems/actions/action_runner.gd` (avvio e ciclo delle
  azioni con `inputs`), `res://tests/systems/actions/test_artisan_resolver.gd`, `test_action_runner.gd` (casi nuovi)
- **Leggere** `01_GDD.md` §5; `02_FORMULAS.md` F-06, F-08; `05_INTERFACES.md` §5.8
- **Descrizione** Controllo degli ingredienti all'inizio del ciclo, consumo alla fine, conservazione, doppio prodotto,
  nessun frammento; stop `missing_inputs`.
- **Accettazione** con `preservation_chance` 100 (limitata a 80) circa l'80% dei cicli non consuma (10.000 cicli, seme fisso,
  tolleranza ±2%); ingredienti venduti a metà ciclo → ciclo fallito senza XP.
- **Test** `test_artisan_resolver.gd` (incluso `test_preservation_cap`).

### M3-02 · Shop (porting)
- **Ruolo** PORT · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M2-06
- **Ownership** `res://systems/shop/shop.gd`, `res://tests/systems/shop/test_shop.gd`, `res://core/session/game_session.gd` (solo registrazione)
- **Leggere** `01_GDD.md` §8; `02_FORMULAS.md` F-17…F-19, §8.6; `05_INTERFACES.md` §5.11
- **Sorgente** `../RIFTSTONE SAGA/scripts/systems/Shop.gd` → `res://systems/shop/shop.gd`.
- **Descrizione** Riscrivere come sistema della sessione: voci da `GameData.shop_entries()`, prezzo fisso o F-17, requisiti,
  massimo acquisti, effetti a modificatore (sorgenti `shop:<id>`) o a oggetto, vendita F-18; eliminate la lettura diretta del
  JSON, `DEFAULT_SELL_RATIO` e la regola "60 × livello".
- **Accettazione** tabella F-17 riprodotta; vendita di un oggetto bloccato rifiutata; acquisto di un oggetto con bank piena
  rifiutato senza spendere oro.
- **Test** `test_shop.gd` (F-17, F-18, F-19, requisiti).

### M3-03 · Equipaggiamento e attrezzi
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M2-06
- **Ownership** `res://systems/equipment/equipment.gd`, `res://tests/systems/equipment/test_equipment.gd`,
  `res://core/session/game_session.gd` (solo registrazione)
- **Leggere** `01_GDD.md` §9; `05_INTERFACES.md` §5.9
- **Descrizione** Slot, cibo, stance, regola delle due mani, requisiti, sorgenti `equipment:<slot>`; blocco del cambio arma
  in combattimento con controllo `null`-safe su `session.combat`.
- **Accettazione** un pezzo è sempre in un solo posto (bank o slot); scambio con bank piena rifiutato senza cambi;
  l'attrezzo cambia l'intervallo di F-03 della sua skill.
- **Test** `test_equipment.gd`.

### M3-04 · Contenuto: Forgiatura, Focolare, Intaglio, shop
- **Ruolo** DATA · **Stima** L · **Parallelizzabile** sì · **Dipendenze** M2-06
- **Ownership** `res://data/actions/forging.json`, `hearthcraft.json`, `woodwright.json`, `res://data/items/equipment.json`,
  `tools.json`, `food.json`, `materials.json` (lingotti, intermedi), `res://data/shop/shop.json`, icone segnaposto relative,
  `res://tests/data/test_data_validity.gd` (casi nuovi)
- **Leggere** `02_FORMULAS.md` §8.2-8.4, §8.6; `04_DATA_SCHEMA.md` §5-6, §9
- **Descrizione** Ricette e oggetti come le tabelle (8 gradi); equipaggiamento con i modificatori di §8.4 (le armi servono in
  M4); attrezzi T1-T8 e gli attrezzi del novizio; shop dell'MVP senza `second_thought`.
- **Accettazione** dati validi; XP e valori calcolati con le formule delle tabelle (il test le ricalcola).
- **Test** casi nuovi: ogni ricetta rispetta §8.2, ogni pezzo §8.4.

### M3-05 · Pagina skill: variante artigianato
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M3-01, M1-15
- **Ownership** `res://ui/pages/skill/recipe_card.gd/.tscn`, `res://ui/pages/skill/skill_page.gd` (scelta tra carta azione e
  carta ricetta), `res://tests/ui/test_skill_page_smoke.gd` (casi nuovi)
- **Leggere** `01_GDD.md` §5; `05_INTERFACES.md` §5.8
- **Descrizione** Carta ricetta con ingredienti (posseduti/richiesti, evidenziati se mancano) e prodotti; probabilità di
  conservazione e di doppio prodotto lette da `modifiers.total`.
- **Accettazione / Test** smoke con la fixture `test_craft`.

### M3-06 · Shop e vendita
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M3-02, M2-04
- **Ownership** `res://ui/pages/shop/**`, `res://ui/pages/bank/bank_item_panel.gd` (sezione vendita), `res://tests/ui/test_shop_page_smoke.gd`
- **Leggere** `01_GDD.md` §8; `05_INTERFACES.md` §5.11
- **Descrizione** Voci per categoria con prezzo, acquisti, requisiti mancanti; vendita con cursore, "tutti tranne 1", "tutti".
- **Accettazione / Test** smoke; il pulsante Compra è disabilitato quando `can_buy` fallisce e mostra il motivo.

### M3-07 · Pagina equipaggiamento
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M3-03, M2-04
- **Ownership** `res://ui/pages/equipment/**`, `res://ui/pages/bank/bank_item_panel.gd` (pulsanti Equipaggia e Usa come cibo),
  `res://tests/ui/test_equipment_page_smoke.gd`
- **Leggere** `01_GDD.md` §9; `05_INTERFACES.md` §5.2 (`breakdown`), §5.9
- **Descrizione** Slot (anche attrezzi), cibo, stance, riepilogo delle stat con il dettaglio delle sorgenti (`breakdown`).
  Ownership condivisa di `bank_item_panel.gd` con M3-06: sezioni diverse; il secondo a chiudere fa rebase.
- **Accettazione / Test** smoke; nessuna stat mostrata che non sia nel registro.

### M3-08 · Test di M3
- **Ruolo** QA · **Stima** S · **Parallelizzabile** no · **Dipendenze** M3-01…M3-07
- **Ownership** `res://tests/integration/test_crafting_chain.gd`, `res://tests/integration/test_item_conservation.gd` (casi nuovi)
- **Descrizione** Catena minerale → lingotto → attrezzo → equipaggiato → raccolta più veloce; conservazione degli oggetti con
  artigianato, vendita, equipaggiamento. **Leggere** `01_GDD.md` §5, §9 · **Accettazione / Test** i file verdi.

### M3-09 · Integrazione di M3
- **Ruolo** REV · **Stima** S · **Dipendenze** M3-01…M3-08 · **Ownership** merge, tag `m3-done` · **Parallelizzabile** no ·
  **Leggere** `08_TEAM.md` §4-6 · **Descrizione / Accettazione / Test** come M1-20.

---

## M4 · Combattimento

### M4-01 · Formule di combattimento
- **Ruolo** COMBAT · **Stima** M · **Parallelizzabile** sì (anticipabile dopo M1-04) · **Dipendenze** M1-04
- **Ownership** `res://systems/combat/combat_math.gd`, `res://tests/systems/combat/test_combat_math.gd`
- **Leggere** `01_GDD.md` §10; `02_FORMULAS.md` F-20…F-28; `05_INTERFACES.md` §5.10
- **Descrizione** Funzioni statiche pure, tutti i parametri da `balance.json`.
- **Accettazione** tutti gli esempi di F-20…F-28 riprodotti.
- **Test** `test_combat_math.gd` (incluse le funzioni elencate in `02_FORMULAS.md` §11 per le stat di combattimento).

### M4-02 · Statistiche, razioni da campo, borsa del bottino
- **Ruolo** COMBAT · **Stima** M · **Parallelizzabile** no · **Dipendenze** M4-01, M3-09
- **Ownership** `res://systems/combat/combatant_stats.gd`, `auto_eat.gd`, `loot_bag.gd`,
  `res://tests/systems/combat/test_combatant_stats.gd`, `test_auto_eat.gd`, `test_loot_bag.gd`
- **Leggere** `01_GDD.md` §10.5-10.6; `02_FORMULAS.md` F-27, F-29, F-30, F-33; `05_INTERFACES.md` §5.10
- **Descrizione** `for_player` da livelli, equipaggiamento e `modifiers.total`; `for_monster` dai dati; razioni da campo
  (livello dallo shop); borsa con `auto_loot`.
- **Accettazione** esempio di F-30 (2 pezzi); borsa piena → `loot_lost`.
- **Test** i tre file (inclusi `test_food_healing_pct`, `test_tier_thresholds`, `test_capacity_uses_loot_bag_slots`, `test_auto_loot_to_bank`).

### M4-03 · Motore del combattimento
- **Ruolo** COMBAT · **Stima** L · **Parallelizzabile** no · **Dipendenze** M4-02
- **Ownership** `res://systems/combat/combat_engine.gd`, `res://tests/systems/combat/test_combat_engine.gd`,
  `res://core/session/game_session.gd` (solo registrazione)
- **Leggere** `01_GDD.md` §10; `02_FORMULAS.md` F-07, F-23…F-34; `05_INTERFACES.md` §5.10, §6
- **Descrizione** Timer, ordine (prima il giocatore), più eventi per `advance`, respawn, uccisione (oro, drop, frammento),
  XP per danno con stance, morte (borsa persa, PV al massimo), stato salvato e ripreso, contatori, mutua esclusione con la
  corsia main.
- **Accettazione** stato identico dopo salvataggio/caricamento a metà duello; equivalenza 1×1000 ms = 10×100 ms.
- **Test** `test_combat_engine.gd` (inclusi `test_gold_drop_pct`, drop F-32, morte).

### M4-04 · Contenuto del combattimento
- **Ruolo** DATA · **Stima** M · **Parallelizzabile** sì (con M4-01…M4-03) · **Dipendenze** M3-09
- **Ownership** `res://data/combat/areas.json`, `monsters.json`, `res://data/items/materials.json` (drop dei mostri),
  `res://assets/icons/monsters/**`, `res://tests/data/test_data_validity.gd` (casi nuovi)
- **Leggere** `02_FORMULAS.md` §8.5; `04_DATA_SCHEMA.md` §8
- **Descrizione** 4 aree e 12 mostri della tabella, con nomi e descrizioni originali; drop (max 4 per mostro).
- **Accettazione / Test** valori uguali a §8.5 (il test li confronta).

### M4-05 · Pagina del combattimento
- **Ruolo** UI · **Stima** L · **Parallelizzabile** sì · **Dipendenze** M4-03
- **Ownership** `res://ui/pages/combat/**` (`combat_page`, `combat_hud`, `loot_bag_view`, `area_list`), `res://tests/ui/test_combat_page_smoke.gd`
- **Leggere** `01_GDD.md` §10, §13; `05_INTERFACES.md` §3, §5.10
- **Descrizione** Scelta di area e mostro (requisiti), barre PV e timer di entrambi, probabilità di colpire e danno massimo
  (da `player_stats`/`monster_stats` e `CombatMath.hit_chance`), cibo e Mangia, stance, borsa con Raccogli tutto, numeri del
  danno sui `combat_hit`.
- **Accettazione / Test** smoke con la fixture; nessuno stato del duello nella UI.

### M4-06 · Test di M4
- **Ruolo** QA · **Stima** M · **Parallelizzabile** no · **Dipendenze** M4-01…M4-05
- **Ownership** `res://tests/integration/test_reference_duel.gd`, `test_combat_flow.gd`
- **Leggere** `02_FORMULAS.md` F-34; `01_GDD.md` §10.7
- **Descrizione** Duello di riferimento F-34 (1.000 duelli, intervallo 15-21 s); flusso con morte (borsa persa, bank intatta),
  razioni da campo, cambio di stile e triangolo.
- **Accettazione / Test** i file verdi.

### M4-07 · Integrazione di M4
- **Ruolo** REV · **Stima** S · **Dipendenze** M4-01…M4-06 · **Ownership** merge, tag `m4-done` · **Parallelizzabile** no ·
  **Leggere** `08_TEAM.md` §4-6 · **Descrizione / Accettazione / Test** come M1-20.

---

## M5 · Legatura del Rift

### M5-01 · Altare del Rift
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì (con M5-02) · **Dipendenze** M4-07
- **Ownership** `res://systems/rift/rift_altar.gd`, `res://tests/systems/rift/test_rift_altar.gd`, `res://core/session/game_session.gd` (solo registrazione)
- **Leggere** `01_GDD.md` §11; `02_FORMULAS.md` §8.7; `05_INTERFACES.md` §5.12
- **Descrizione** Prese sbloccate per livello, incastona, togli (distrugge), `unique`, sorgenti `rift_socket:<i>`.
- **Accettazione** l'infusione esce dalla bank; i modificatori cambiano `total`; togliere la distrugge.
- **Test** `test_rift_altar.gd`.

### M5-02 · Contenuto della Legatura del Rift e nodi dell'artigianato
- **Ruolo** DATA · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M4-07
- **Ownership** `res://data/actions/riftbinding.json`, `res://data/items/infusions.json`, `res://data/mastery/forging.json`,
  `hearthcraft.json`, `woodwright.json`, `riftbinding.json`, icone segnaposto, `res://tests/data/test_data_validity.gd` (casi nuovi)
- **Leggere** `02_FORMULAS.md` §8.7-8.8; `04_DATA_SCHEMA.md` §5-7
- **Descrizione** 9 ricette e 9 infusioni della tabella §8.7; nodi della maestria delle 4 skill di artigianato.
- **Accettazione / Test** dati validi, numeri uguali alla tabella.

### M5-03 · Pagina dell'Altare
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M5-01, M3-05
- **Ownership** `res://ui/pages/rift/**`, `res://ui/pages/bank/bank_item_panel.gd` (pulsante Incastona), `res://tests/ui/test_rift_page_smoke.gd`
- **Leggere** `01_GDD.md` §11; `05_INTERFACES.md` §5.12
- **Descrizione** 5 prese (bloccate con livello richiesto), scelta dell'infusione dalla bank, conferma prima di togliere,
  totale dei modificatori dell'Altare. Le ricette si fanno dalla pagina skill della Legatura (già generica).
- **Accettazione / Test** smoke.

### M5-04 · Test di M5
- **Ruolo** QA · **Stima** S · **Parallelizzabile** no · **Dipendenze** M5-01…M5-03
- **Ownership** `res://tests/integration/test_rift_flow.gd` · **Leggere** `01_GDD.md` §11
- **Descrizione** frammenti → infusione → presa → effetto misurabile (intervallo o precisione) → salvataggio/caricamento identico.
- **Accettazione / Test** verde.

### M5-05 · Integrazione di M5
- **Ruolo** REV · **Stima** S · **Dipendenze** M5-01…M5-04 · **Ownership** merge, tag `m5-done` · **Parallelizzabile** no ·
  **Leggere** `08_TEAM.md` §4-6 · **Descrizione / Accettazione / Test** come M1-20.

---

## M6 · Offline e polish (fine dell'MVP)

### M6-01 · Simulazione offline
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì (con M6-03, M6-04) · **Dipendenze** M5-05
- **Ownership** `res://core/offline/offline_simulator.gd`, `offline_summary.gd`, `res://core/autoload/game.gd` (punto
  `# Offline: M6-01` in `continue_game` e stato `offline`), `res://core/autoload/event_bus.gd` (solo la firma di
  `offline_completed`, tipizzata con `OfflineSummary`), la riga `offline_completed` di
  `res://tests/core/autoload/test_event_bus.gd`, `res://tests/core/offline/test_offline_simulator.gd`
- **Leggere** `01_GDD.md` §12; `02_FORMULAS.md` F-40, F-41; `03_ARCHITECTURE.md` §8; `05_INTERFACES.md` §5.13
- **Descrizione** Come da documenti; usa solo `session.advance`; riepilogo da snapshot e `stop_reasons_log`.
- **Accettazione** esempi F-40/F-41; equivalenza dei blocchi; 12 h di raccolta e 12 h di combattimento simulate in < 10 s
  ciascuna (misura nel report).
- **Test** `test_offline_simulator.gd` (con `yield_frames = false`).

### M6-02 · Schermate dell'offline
- **Ruolo** UI · **Stima** M · **Parallelizzabile** no · **Dipendenze** M6-01
- **Ownership** `res://ui/screens/offline/**`, `res://ui/screens/main/main_screen.gd` (apertura del riepilogo), `res://tests/ui/test_offline_dialog_smoke.gd`
- **Leggere** `01_GDD.md` §12; `05_INTERFACES.md` §3, §5.13
- **Descrizione** Overlay con barra (`offline_progress`), poi finestra del riepilogo (tempo, limite, XP e livelli, oggetti
  +/−, oro, uccisioni, morti, cibo, motivi di stop).
- **Accettazione / Test** smoke con un `OfflineSummary` finto.

### M6-03 · Impostazioni (porting)
- **Ruolo** PORT · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M1-20
- **Ownership** `res://core/settings/game_settings.gd`, `res://ui/settings/**`, `res://ui/screens/main_menu/main_menu.gd`
  (abilitare Impostazioni), `res://tests/core/settings/test_game_settings.gd`
- **Leggere** `01_GDD.md` §16; `03_ARCHITECTURE.md` §13; `05_INTERFACES.md` §5.14
- **Sorgente** `../RIFTSTONE SAGA/scripts/systems/GameSettings.gd` → `res://core/settings/game_settings.gd`;
  `../RIFTSTONE SAGA/scripts/ui/SettingsPanel.gd` → `res://ui/settings/settings_panel.gd`.
- **Descrizione** Togliere qualità 3D/supersampling e `GameState`; aggiungere `log_level`; "Salva ed esci" → `Game.end_session(true)`.
- **Accettazione** impostazioni salvate solo in `user://settings.cfg`; nessuno stato di gioco lì.
- **Test** `test_game_settings.gd` (default, salvataggio su file di prova).

### M6-04 · Sistema dei suggerimenti
- **Ruolo** CORE · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M5-05
- **Ownership** `res://systems/hints/hints_system.gd`, `res://core/data/defs/hint_def.gd`, `res://core/data/game_data.gd`
  (`hints()`), `res://core/data/data_validator.gd` (regole di `hints.json`), `res://core/autoload/event_bus.gd`
  (segnale `hint_triggered`), `res://core/session/game_session.gd` (registrazione), `res://tests/systems/hints/test_hints_system.gd`
- **Leggere** `01_GDD.md` §14; `04_DATA_SCHEMA.md` §10; `05_INTERFACES.md` §3, §5.15
- **Descrizione** Trigger di §10 collegati agli eventi della sessione; una volta per slot.
- **Accettazione / Test** un suggerimento visto in uno slot non è visto nell'altro.

### M6-05 · Contenuto dei suggerimenti
- **Ruolo** DATA · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M6-04
- **Ownership** `res://data/hints/hints.json`, `res://tests/data/test_data_validity.gd` (casi nuovi)
- **Leggere** `04_DATA_SCHEMA.md` §10 · **Descrizione** un suggerimento per trigger, testi originali brevi ·
  **Accettazione / Test** dati validi.

### M6-06 · Feedback visivo e carta dei suggerimenti
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M6-04, M4-05
- **Ownership** `res://ui/feedback/**`, `res://ui/components/hint_card/**`, `res://ui/screens/main/main_screen.tscn` (istanze
  di banner e carta), `res://tests/ui/test_feedback_smoke.gd`
- **Leggere** `01_GDD.md` §13-14; `05_INTERFACES.md` §3
- **Descrizione** Banner del livello, particelle del frammento, carta del suggerimento; solo ascolto di segnali.
- **Accettazione / Test** smoke; nessuna modifica dello stato.

### M6-07 · Regressione, prestazioni, foto della UI
- **Ruolo** QA · **Stima** M · **Parallelizzabile** no · **Dipendenze** M6-01…M6-06
- **Ownership** `res://tests/data/test_stat_registry_coverage.gd` (modalità rigida: niente più `pending`),
  `res://tests/integration/test_offline_performance.gd`, `res://tools/ui_shots/**`
- **Leggere** `01_GDD.md` §12; `02_FORMULAS.md` §11; `09_CONVENTIONS.md` §6
- **Descrizione** Ogni stat ha il suo test reale; prestazioni dell'offline; `tools/ui_shots/ui_shots.tscn` che fotografa ogni
  pagina su una sessione della `TestFactory` (mai su uno slot vero).
- **Accettazione** suite completa verde; foto generate in una cartella passata da riga di comando.
- **Test** i file elencati.

### M6-08 · Rilascio dell'MVP
- **Ruolo** REV · **Stima** S · **Parallelizzabile** no · **Dipendenze** M6-01…M6-07
- **Ownership** `res://export_presets.cfg`, merge, tag `m6-mvp` e `m6-done`, `docs/` (stato finale)
- **Leggere** `08_TEAM.md` §4-6; `06_ROADMAP.md` M6
- **Descrizione** Preset "Windows Desktop" (pck incorporato, esclusi `tests/*`, `tools/*`, `addons/gut/*`, `docs/*`, `*.md`),
  esportazione di prova, checklist delle Lezioni (`03_ARCHITECTURE.md` §12) spuntata nel report.
- **Accettazione** l'eseguibile parte, crea uno slot, gioca, chiude, riapre con l'offline. **Test** suite completa.

---

## M7 · Fratture del Rift (dopo l'MVP)

### M7-01 · Sistema delle Fratture
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì (con M7-02) · **Dipendenze** M6-08
- **Ownership** `res://systems/fractures/fracture_system.gd`, `res://core/data/defs/fracture_def.gd`, `res://core/data/game_data.gd`
  (`fractures()`), `res://core/data/data_validator.gd` (regole nuove e chiavi `fractures.*`), `res://core/autoload/event_bus.gd`
  (`fracture_opened`, `fracture_closed`), `res://core/session/game_session.gd` (registrazione e `advance`),
  `res://systems/combat/combat_engine.gd` (solo uso di `bonus_monster_for_area` nella scelta del mostro),
  `res://tests/systems/fractures/test_fracture_system.gd`
- **Leggere** `01_GDD.md` §17; `02_FORMULAS.md` F-50; `04_DATA_SCHEMA.md` §11; `05_INTERFACES.md` §5.15
- **Descrizione / Accettazione** F-50 riprodotta; stato salvato; funziona anche durante l'offline. **Test** il file (incluso `test_duration_pct`).

### M7-02 · Dati delle Fratture
- **Ruolo** DATA · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M6-08
- **Ownership** `res://data/fractures/fractures.json`, `res://data/config/balance.json` (`fractures`), `res://data/config/stats.json`
  (`fracture_duration_pct`), `res://tests/data/test_config_files.gd`, `test_data_validity.gd` (casi nuovi)
- **Leggere** `02_FORMULAS.md` §9, §11; `04_DATA_SCHEMA.md` §11 · **Descrizione** 8 Fratture originali · **Accettazione / Test** dati validi.

### M7-03 · Indicatore delle Fratture
- **Ruolo** UI · **Stima** S · **Dipendenze** M7-01 · **Parallelizzabile** sì · **Ownership** `res://ui/components/fracture_badge/**`,
  `res://ui/screens/main/top_bar.gd` (istanza), `res://tests/ui/test_fracture_badge_smoke.gd` · **Leggere** `01_GDD.md` §17 ·
  **Descrizione** badge con nome, tempo rimasto, tooltip dei modificatori · **Accettazione / Test** smoke.

### M7-04 · Test di M7 — **Ruolo** QA · **Stima** S · **Dipendenze** M7-01…M7-03 · **Parallelizzabile** no ·
**Ownership** `res://tests/integration/test_fracture_flow.gd` · **Leggere** `01_GDD.md` §17 · **Descrizione** apertura, effetto,
chiusura, salvataggio, offline · **Accettazione / Test** verde.

### M7-05 · Integrazione di M7 — **Ruolo** REV · **Stima** S · **Dipendenze** M7-01…M7-04 · **Parallelizzabile** no ·
**Ownership** merge, tag `m7-done`, aggiornamento di `05_INTERFACES.md` se servito · **Leggere** `08_TEAM.md` · **Test** suite.

## M8 · Azioni in parallelo (dopo l'MVP)

### M8-01 · Corsia secondaria
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì (con M8-02) · **Dipendenze** M6-08
- **Ownership** `res://systems/actions/action_runner.gd` (se supera 400 righe: estrarre `action_lane.gd` nella stessa cartella),
  `res://core/data/data_validator.gd` (chiave `parallel.interval_penalty_pct` e categoria dello shop `lanes`),
  `res://tests/systems/actions/test_action_runner.gd` (casi nuovi)
- **Leggere** `01_GDD.md` §18; `02_FORMULAS.md` F-51; `05_INTERFACES.md` §5.8
- **Descrizione** `lanes_available`, corsia `secondary` solo per azioni non di combattimento, skill diverse, penalità F-51,
  ordine di risoluzione main → secondary.
- **Accettazione** F-51 riprodotta; `skill_in_other_lane`; ingredienti contesi risolti nell'ordine.
- **Test** casi nuovi (incluso `test_secondary_lane_unlock`).

### M8-02 · Dati di M8 — **Ruolo** DATA · **Stima** S · **Dipendenze** M6-08 · **Parallelizzabile** sì ·
**Ownership** `res://data/shop/shop.json` (`second_thought`), `res://data/config/balance.json` (`parallel`), `res://data/config/stats.json`
(`parallel_lanes`), `res://tests/data/test_config_files.gd` · deve essere mergiato **dopo** M8-01 (il validatore accetta le chiavi nuove) · **Leggere** `02_FORMULAS.md` §8.6, §9, §11 · **Accettazione / Test** dati validi.

### M8-03 · UI a due corsie — **Ruolo** UI · **Stima** M · **Dipendenze** M8-01 · **Parallelizzabile** sì ·
**Ownership** `res://ui/pages/skill/**`, `res://ui/screens/main/top_bar.gd` (indicatore delle corsie), `res://tests/ui/test_skill_page_smoke.gd` ·
**Leggere** `01_GDD.md` §18 · **Descrizione** scelta della corsia all'avvio, due barre di progresso · **Accettazione / Test** smoke.

### M8-04 · Test di M8 — **Ruolo** QA · **Stima** S · **Dipendenze** M8-01…M8-03 · **Parallelizzabile** no ·
**Ownership** `res://tests/integration/test_parallel_lanes.gd` · **Descrizione** combattimento + raccolta, offline con due corsie ·
**Accettazione / Test** verde.

### M8-05 · Integrazione di M8 — **Ruolo** REV · **Stima** S · **Dipendenze** M8-01…M8-04 · **Parallelizzabile** no ·
**Ownership** merge, tag `m8-done` · **Test** suite.
