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
  `area_def`, `monster_def`, `shop_entry_def`; helper interno `def_reader`), `res://core/data/json_loader.gd`,
  `res://tests/core/data/test_defs.gd`, `test_item_defs.gd`, `test_json_loader.gd`
- **Leggere** `04_DATA_SCHEMA.md` §1, §4-9; `05_INTERFACES.md` §4
- **Descrizione** `from_dict` di ogni Def con conversione dei tipi (`int()` sui numeri, `StringName` sugli id,
  `Color` da `#rrggbb`, `Vector2i` da `pos`), default dello `scope` (`skill:<skill>` per i nodi, `action:<id>` per i bonus
  della maestria applicato dal MasterySystem). Nessuna validazione semantica (è M1-04).
- **Accettazione** ogni esempio di `04_DATA_SCHEMA.md` diventa una Def con i valori giusti.
- **Test** `test_defs.gd` (un test per ogni esempio dello schema), `test_json_loader.gd` (file mancante, JSON rotto, cartella).

### M1-04 · Validatore, GameData, DataRegistry, fixture
- **Ruolo** CORE · **Stima** L · **Parallelizzabile** no · **Dipendenze** M1-01, M1-03, M0-05
- **Ownership** `res://core/data/data_validator.gd`, `res://core/data/game_data.gd`, `res://core/autoload/data_registry.gd`,
  `res://tools/validate_data.gd` (script `SceneTree` che stampa `errors` ed esce ≠ 0 se non validi), `res://tests/fixtures/data/**`, `res://tests/core/data/test_data_validator.gd`, `test_game_data.gd`;
  estesa: `res://core/data/data_validator_rules.gd`, `data_validator_items.gd`, `res://tests/core/data/test_data_validator_items.gd`,
  `test_data_validator_combat.gd`, `res://core/data/defs/def_reader.gd` (solo `level_map`: salto di `_doc`)
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
  Nota (review): la registrazione dei sistemi (`_join`/`_tick`) è in `05_INTERFACES.md` §5.3. `game_session.gd` resta
  ≤ 200 righe per tutti i task successivi (test): chi lo supererebbe sposta `_Participant` in
  `core/session/session_participants.gd`, aggiunto alla propria Ownership.
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
  `res://tests/systems/bank/test_bank.gd`, `res://core/session/game_session.gd` (solo campi tipizzati, creazione e
  registrazione dei due sistemi), `res://core/session/session_snapshot.gd` (solo `bank` e `gold` in `take`),
  `res://tests/helpers/test_factory.gd` (solo `give`), `res://core/session/session_participants.gd` (estrazione di
  `_Participant` per il limite di 200 righe), `res://tests/core/session/test_game_session.gd` (solo le asserzioni rese
  false dalla registrazione di Wallet/Bank; estensione concessa a posteriori dal Reviewer)
- **Leggere** `01_GDD.md` §7-8; `02_FORMULAS.md` F-16; `05_INTERFACES.md` §5.4-5.5, §6
- **Descrizione** Come da interfacce. `start.gold` e `start.items` applicati in `new_game` di Wallet/Bank.
- **Accettazione** un oggetto nuovo con bank piena → `bank_full` + `bank_rejected`; quantità 0 libera la casella; capienza
  segue `bank_slots`; ordine conservato nel salvataggio; ogni variazione emette `bank_changed(item_id, new_count, delta)`
  con il `delta` con segno di quella operazione.
- **Test** `test_wallet.gd`, `test_bank.gd` (incluso `test_capacity_uses_bank_slots`, F-16).
- **Nota (da M1-08)** In `tests/core/session/test_game_session.gd` le asserzioni di `to_save` sui moduli sono per chiave
  (non confronti dell'intero `modules`): aggiungere quelle di `wallet`/`bank` allo stesso modo.
  `test_snapshot_of_session_without_systems_is_empty` va rinominato (es. `test_snapshot_reads_registered_systems`) e
  aggiornato quando anche `bank` e `gold` lo riempiono. `SkillsSystem` è già registrato in `_create_systems`.

### M1-08 · Skill ed esperienza
- **Ruolo** CORE · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M1-05
- **Ownership** `res://systems/skills/skills_system.gd`, `res://tests/systems/skills/test_skills_system.gd`,
  `res://core/session/game_session.gd` (solo campo tipizzato, registrazione e `total_level()`),
  `res://core/session/session_snapshot.gd` (solo `xp` e `levels` in `take`), `res://tests/helpers/test_factory.gd`
  (solo `set_level`), `res://tests/core/session/test_game_session.gd` (solo le asserzioni rese false dalla
  registrazione di SkillsSystem; estensione concessa a posteriori dal Reviewer)
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
- **Nota (da M1-07)** `_create_systems()` registra già `wallet`, `bank`, `skills` in quest'ordine: `mastery` va in coda
  (dopo `skills`), con `rebuild_fn = mastery.rebuild_modifiers`. I partecipanti stanno in `SessionParticipants`
  (`core/session/session_participants.gd`, helper interno: non va toccato). In `test_game_session.gd` le asserzioni sui
  `modules` sono per chiave: aggiungere quella di `mastery` allo stesso modo (estensione di ownership come M1-07/M1-08).

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
- **Nota (da M1-07)** Prima di consumare o produrre usare `bank.can_add` per ogni output nuovo: `bank.add` con bank piena
  emette già `bank_rejected` + `bank_full` (non duplicarli); lo stop `bank_full` dell'azione è del runner. `add`/`remove`
  restituiscono `CommandResult` (§5.5); `TestFactory.give` è disponibile per i test. `actions` va registrato dopo
  `mastery` e con `_tick(_PHASE_ACTIONS, actions.advance)`.
- **Nota (da M1-09)** `session.mastery.add_for_action(action)` si chiama a ogni ciclo riuscito con l'`ActionDef`, senza
  controllare `action.mastery`: per le azioni senza maestria restituisce 0 senza effetti; al 99 la xp resta ferma ma il pool
  riceve la quota (`05_INTERFACES.md` §5.7). I bonus F-11 (`double_item_chance` ecc.) sono già in `ModifierService` con
  scope `action:<id>`: leggerli con `ModifierContext.for_action(skill, action)`.
- **Nota (review M1-10)** Ownership estesa (accettata) a `res://tests/core/session/test_game_session.gd`: asserzioni di
  `actions` e `ProbeSession._tick` che registra solo le fasi dei `FakeSystem`; chiave finta `actions` → `lanes`.

### M1-11 · Game: menu → slot → partita
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** no · **Dipendenze** M1-06, M1-10
- **Ownership** `res://core/autoload/game.gd`, `res://tests/core/autoload/test_game.gd`,
  `res://tests/core/autoload/test_game_no_save_before_slot.gd`
- **Leggere** `01_GDD.md` §1-2; `03_ARCHITECTURE.md` §6-7, §12; `05_INTERFACES.md` §2 (Game)
- **Descrizione** Implementazione completa senza offline (in `continue_game` il punto in cui M6-01 inserirà l'offline è
  un commento `# Offline: M6-01`). Autosave sul tempo di `GameClock` (contatore su `GameClock.ticked`, collegato
  all'ingresso in partita e scollegato in `end_session`; nessun `Timer`). Configura `GameClock` e `SaveService` dai dati. Seme nuovo = `Time.get_ticks_usec()` mescolato con lo slot.
- **Accettazione** nessun file in `user://test_saves` finché non si chiama `new_game`; `new_game` scrive subito; 10 s di
  `GameClock` simulati in partita → 1 salvataggio; `end_session` libera la sessione (`is_instance_valid` falso).
- **Test** `test_game.gd`, `test_game_no_save_before_slot.gd`.
- **Nota (da M1-10)** La sessione ha 5 sistemi (`wallet`, `bank`, `skills`, `mastery`, `actions`) e la fase azioni
  registrata: `GameClock` → `session.advance` basta a far girare la corsia (il runner non usa `_process`/`Timer`).
  `stop_reasons_log()` svuota il log a ogni lettura: M1-11 non lo legge (lo legge l'offline, M6-01, dopo la simulazione;
  in `continue_game` resta il commento). Dopo `from_save` l'intervallo del ciclo si fissa al primo `advance`
  (`05_INTERFACES.md` §5.8).
- **Nota (review M1-11)** Fatto. Comportamenti in `05_INTERFACES.md` §2 (Game). Proposta aperta, non applicata: il limite
  1-24 caratteri del nome è oggi una costante di `game.gd` fissata dal contratto e da `01_GDD.md` §1; spostarlo in
  `balance.json` sarebbe un parametro di design nuovo e richiede l'ok dell'utente.

### M1-12 · Contenuto: le 12 skill e Selvicoltura
- **Ruolo** DATA · **Stima** M · **Parallelizzabile** sì (dopo M1-04) · **Dipendenze** M1-04
- **Ownership** `res://data/skills/skills.json`, `res://data/items/materials.json`, `res://data/items/misc.json`,
  `res://data/actions/forestry.json`, `res://assets/icons/skills/**` (segnaposto), `res://assets/icons/items/**` (segnaposto
  di questi oggetti), `res://tests/data/test_data_validity.gd`, `res://data/combat/areas.json`, `monsters.json`,
  `res://data/shop/shop.json` (vuoti con `_doc`, così il caricamento dei dati veri è valido; li sostituiscono M4-04 e M3-04)
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
- **Nota (da M1-11)** Prima di offrire Nuova partita/Continua controllare `DataRegistry.data.is_valid()` (non esiste un
  motivo `data_invalid`: con dati non validi `Game` non configura gli slot e ogni comando dà `io_error`). Errori da
  mostrare: `invalid_name`, `slot_active`, `io_error`, `corrupted`, `version_unsupported` (`05_INTERFACES.md` §2).
  `new_game` sovrascrive senza chiedere: la conferma è del menu. Cambiare scena solo con `CommandResult.ok`; in caso di
  errore `Game` è già in `menu`, senza sessione e con il clock in pausa.
- **Nota (review M1-13)** Fatto. Contratti in `05_INTERFACES.md` §7 (`SlotSelect`, `SlotRow`, `SlotTexts`, variabili
  iniettabili del menu, `ConfirmDialog`). Due test di `test_main_menu_smoke.gd` usano l'autoload `Game` vero (accettato:
  provano il menu reale; chiamano solo `list_slots` e un `new_game` rifiutato per `invalid_name`, quindi nessuna sessione
  né clock avviati): dipendono da `user://test_saves` senza uno slot 1 danneggiato lasciato da altri test; se un giorno
  diventano instabili, svuotare la cartella in `before_each`. Follow-up delle costanti di presentazione su M1-15.

### M1-14 · Schermata principale: sidebar, barra in alto, PageHost
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M1-11, M1-17
- **Ownership** `res://ui/screens/main/**` (`main_screen`, `sidebar`, `top_bar`, `page_host`), `res://ui/pages/page.gd`,
  `res://tests/ui/test_main_screen_smoke.gd`; per il follow-up di M1-16: `res://ui/theme/number_format.gd` (nuovo),
  `res://ui/theme/ui_style.gd` (solo costanti `TOOLTIP_*`/`WINDOW_*`), `res://ui/components/tooltip/**`,
  `res://ui/components/game_window/**`, `res://ui/components/toast/toast_manager.gd` (solo `_format_count`),
  `res://tests/ui/test_tooltip.gd`, `res://tests/ui/test_game_window.gd` (nuovo), `res://tests/ui/test_number_format.gd` (nuovo)
- **Follow-up di M1-16** (prima della barra in alto, che mostra oro e caselle): (1) `class_name NumberFormat` statica con
  `format_int` ("1.250") e `format_number` ("1.250,5"), spostate da `ItemTooltipLines`; `ItemTooltipLines` e
  `ToastManager._format_count` la usano (nessuna copia; `ui_style.gd` è già a 350 righe, per questo un file a parte);
  (2) le costanti di presentazione del tooltip (`TOOLTIP_LAYER`, offset dal mouse, margine dallo schermo, larghezza
  minima, dimensioni dei font, oggi `const`/`@export` in `tooltip_manager.gd`/`custom_tooltip.gd`) e di layout di
  `GameWindow` (`PLACE_MARGIN`, `PLACE_TOP`, `DRAG_KEEP_VISIBLE`, `HEADER_SEPARATION`, `CLOSE_BUTTON_SIDE`) diventano
  `UiStyle.TOOLTIP_*`/`UiStyle.WINDOW_*` (`09_CONVENTIONS.md` §2: costanti di presentazione solo in `ui_style.gd`);
  restano `@export` solo i testi e `GameWindow.default_size`; (3) `ItemTooltipLines._scope_name` usa
  `Modifier.SCOPE_SKILL`/`SCOPE_ACTION` invece dei letterali; (4) la classe interna `TestGameWindow` di
  `test_tooltip.gd` passa in `tests/ui/test_game_window.gd`. Firme pubbliche invariate, tranne `format_int`/`format_number`
  che escono da `ItemTooltipLines` (`05_INTERFACES.md` §7 da aggiornare nel report).
- **Leggere** `01_GDD.md` §13; `03_ARCHITECTURE.md` §11; `05_INTERFACES.md` §3, §7
- **Descrizione** Sidebar dalle skill dei dati (icona, nome, livello aggiornato su `level_up`) + Bank, Shop, Equipaggiamento,
  Combattimento, Altare (voci non ancora implementate disabilitate con "In arrivo"); barra in alto (oro, caselle
  usate/capienza, nome dello slot, pulsante menu → `Game.end_session(true)` e ritorno al menu); `PageHost` con la tabella
  delle rotte; `ToastManager` istanziato nella schermata.
- **Accettazione** nessuna variabile con stato di gioco nella UI (solo letture); cambiare pagina scollega i segnali.
  Test aggiornati del follow-up di M1-16 verdi; `format_int` e `format_number` esistono in un solo file.
- **Test** smoke: la scena si istanzia con una sessione della `TestFactory`; `show_page` di ogni rotta valida.
- **Nota (da M1-11)** Il pulsante menu chiama `Game.end_session(true)` e poi cambia scena: dopo la chiamata `Game.session`
  è `null` (liberata), `state = menu`, clock in pausa; i nodi della schermata si scollegano su `session_ended` (emesso
  prima di liberare la sessione) e non toccano più la sessione. `session_started` arriva a sessione pronta e già salvata,
  prima del cambio scena: la schermata legge `Game.session` in `_ready`, non aspetta il segnale.
- **Nota (da M1-13)** (1) `SlotTexts` (`res://ui/screens/slot_select/slot_texts.gd`, ownership estesa alle sole chiamate
  `ItemTooltipLines.format_int` in `slot_details` e `play_time`, e al commento in testa) passa a `NumberFormat.format_int`
  quando `format_int` esce da `ItemTooltipLines`; M1-14 si mergia dopo M1-13 e il Reviewer di M1-14 verifica che non resti
  nessuna chiamata a `ItemTooltipLines.format_int`. (2) Ritorno al menu dal pulsante della barra in alto:
  `Game.end_session(true)` e poi `get_tree().change_scene_to_file("res://ui/screens/main_menu/main_menu.tscn")`; il menu
  rilegge gli slot in `_ready`. (3) Il menu, se `change_scene_to_file` verso `main_screen.tscn` fallisce, chiude la
  sessione: la schermata deve quindi caricarsi senza errori anche con la sessione appena creata.
- **Nota (review M1-14)** Fatto. Contratti in `05_INTERFACES.md` §7 (`PageHost` esteso, `MainScreen`, `Sidebar`,
  `TopBar`, `NumberFormat`; `format_int`/`format_number` tolte da `ItemTooltipLines`). Integrazione con M1-13 nel commit di
  merge: `SlotTexts` usa `NumberFormat.format_int`. Il ritorno al menu usa `application/run/main_scene`
  (= `main_menu.tscn`). `placeholder_page.gd/.tscn` è temporanea (rotte `skill` e `bank`) e si elimina con M1-18.

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
- **Follow-up di M1-13** (ownership estesa: `res://ui/theme/ui_style.gd` solo costanti `MENU_*`/`SLOT_*`/`DIALOG_*`,
  `res://ui/components/confirm_dialog/confirm_dialog.gd`, `res://ui/screens/main_menu/main_menu.gd/.tscn`,
  `res://ui/screens/slot_select/slot_select.gd/.tscn`, `slot_row.gd/.tscn`; da fare dopo il merge di M1-14, che tocca
  `ui_style.gd`): le costanti di presentazione oggi locali diventano `UiStyle` (`09_CONVENTIONS.md` §2):
  `ConfirmDialog.DIALOG_SIZE` → `UiStyle.DIALOG_SIZE`; larghezza del pannello del menu (520) → `MENU_PANEL_WIDTH`, del
  pannello degli slot (820) → `SLOT_PANEL_WIDTH`, altezza dei pulsanti del menu e degli slot (44) → `MENU_BUTTON_HEIGHT`
  (impostate in `_ready` dagli script, i `.tscn` tengono solo la struttura); la dimensione 36 del titolo del menu
  (`theme_override_font_sizes` in `main_menu.tscn`) diventa una costante o una variante del tema. Se `ui_style.gd`
  supererebbe 400 righe, fermarsi e chiedere al Reviewer come dividerlo. Test esistenti verdi, nessun cambio di firme.
- **Nota (da M1-14)** (1) Ownership estesa alla sola riga `ROUTE_SKILL` di `PageHost.ROUTES`
  (`res://ui/screens/main/page_host.gd`): `&"skill": "res://ui/pages/skill/skill_page.tscn"`. `SkillPage` estende `Page`,
  legge la skill da `PageHost.argument_of(page_id)` in `bind`, si collega a `session.events` e scollega tutto in `unbind`.
  (2) `tests/ui/test_main_screen_smoke.gd` (ownership estesa al solo `test_changing_page_disconnects_the_old_page`): oggi
  conta le connessioni del segnaposto (`level_up` sulla skill, `bank_capacity_changed` sulla bank); va aggiornato con i
  segnali collegati dalla `SkillPage` vera (il test deve continuare a provare che cambiare pagina torna alla base).
  (3) `ui_style.gd` è a 368 righe dopo M1-14: le costanti `MENU_*`/`SLOT_*`/`DIALOG_*` ci stanno, ma ricontare prima
  del merge (limite 400).
- **Nota (review M1-15)** Fatto. Contratti in `05_INTERFACES.md` §7 (`SkillPage`, `ActionCard`, estensioni di
  `ItemSlotView` e `XpBar`, costanti `UiStyle.MENU_*`/`SLOT_*`/`DIALOG_*`). Accettati: la quantità tenuta da
  `ItemSlotView` solo per il proprio tooltip (copia di presentazione, documentata in §7); l'indicatore "bloccato" come
  quadratino d'oro (`LockMarker`) finché non c'è un'icona a lucchetto. Restano nei `.tscn` le altezze 40 dei pulsanti di
  `slot_row.tscn` e le larghezze fisse non elencate nel follow-up (accettato). Follow-up `format_seconds` su M1-18.

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
- **Nota (da M1-14)** Ownership estesa a `res://ui/screens/main/page_host.gd` (solo la riga `&"bank"` di `ROUTES` →
  `"res://ui/pages/bank/bank_page.tscn"` ed eventualmente `PLACEHOLDER_SCENE`), a `res://ui/screens/main/placeholder_page.gd/.tscn`
  (da eliminare, con i `.uid`, quando nessuna rotta la usa più, cioè dopo M1-15) e a `tests/ui/test_main_screen_smoke.gd`
  (conteggi di `test_changing_page_disconnects_the_old_page`). `BankPage` estende `Page`, si collega a `session.events`
  in `bind` e scollega tutto in `unbind`.
- **Nota (da M1-15)** (1) Con la rotta `bank` su `bank_page.tscn` nessuna rotta usa più il segnaposto: eliminare
  `placeholder_page.gd/.tscn` (con i `.uid`) e `PLACEHOLDER_SCENE`; in `test_changing_page_disconnects_the_old_page` la
  SkillPage collega 6 segnali (già contati), il conteggio di `bank_capacity_changed` va adattato ai segnali della
  `BankPage`. (2) Le caselle sono `ItemSlotView` (`set_item`/`clear`/`item_id`, tooltip già incluso): su `bank_changed`
  rileggere `stacks()` e richiamare `set_item` (la quantità del tooltip è quella dell'ultimo `set_item`). (3) Follow-up
  (ownership estesa a `res://ui/theme/number_format.gd`, `res://tests/ui/test_number_format.gd` e alla sola
  `ActionCard.seconds_text` con la costante `DECIMAL_SEPARATOR` in `res://ui/pages/skill/action_card.gd`):
  `NumberFormat.format_seconds(ms: int) -> String` ("3,0 s", "2,7 s", sempre almeno un decimale) diventa l'unica
  definizione; `ActionCard.seconds_text` la chiama (o sparisce, aggiornando `05_INTERFACES.md` §7 e `test_seconds_text`).
- **Nota (review M1-18)** Fatto. Contratti in `05_INTERFACES.md` §7 (`BankPage`, `NumberFormat.format_seconds`,
  `ActionCard.seconds_text` = `format_seconds`, rotte di `PageHost` senza segnaposto). `placeholder_page.gd/.tscn` e
  `PLACEHOLDER_SCENE` eliminati. Follow-up per M2-04 annotati lì.

### M1-19 · Test di integrazione di M1
- **Ruolo** QA · **Stima** M · **Parallelizzabile** no · **Dipendenze** M1-10, M1-11, M1-12
- **Ownership** `res://tests/integration/test_gathering_loop.gd`, `test_save_roundtrip.gd`, `test_slot_isolation.gd`,
  `test_item_conservation.gd`, `res://tests/data/test_stat_registry_coverage.gd`, `res://tools/run_checks.ps1` (esegue
  `tools/validate_data.gd -- res://tests/fixtures/data` e, dopo M1-12, `tools/validate_data.gd` sui dati veri; exit ≠ 0 se non validi)
- **Leggere** `03_ARCHITECTURE.md` §7, §12; `02_FORMULAS.md` §11; `05_INTERFACES.md` §6, §8
- **Descrizione** Flusso: partita nuova → 60 s di Selvicoltura via `advance` → XP, oggetti, maestria attesi (seme fisso);
  salva/ricarica identico (anche `elapsed_ms` e RNG); slot A e B non si influenzano; conservazione degli oggetti
  (prodotti = bank finale). Copertura delle stat: per ogni stat di `stats.json` il test indicato deve esistere;
  finché la milestone di quella formula non è chiusa il caso è `pending()` (diventa errore in M6-07).
- **Accettazione** tutti verdi o `pending` motivati.
- **Test** i cinque file.
- **Nota (da M1-09)** La proposta di aggiungere `mastery_bonuses` di artigianato a `test_craft` nelle fixture non è di
  questo task (le fixture sono del CORE, M1-04): è assegnata a M3-01.
- **Nota (da M1-11)** Per i flussi che passano da `Game` usare un'istanza privata di `game.gd` (mai l'autoload), come
  `test_game.gd`: `SaveService.base_dir` è già `user://test_saves`, `GameClock.time_source` sostituito e ripristinato,
  tempo simulato con `GameClock._process(delta)` (frazioni binarie esatte) oppure direttamente con `session.advance`.
  Dopo ogni test `end_session(false)` e clock in pausa.

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

### M2-00 · Limite del nome del giocatore in balance.json
- **Ruolo** CORE · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M1-20
- **Ownership** `res://data/config/balance.json`, `res://core/autoload/game.gd`, `res://core/data/data_validator.gd`,
  `res://ui/screens/slot_select/slot_texts.gd`, `slot_select.gd` (solo commento), `res://tests/data/test_config_files.gd`,
  `res://tests/core/autoload/test_game.gd`, `test_game_no_save_before_slot.gd`,
  `res://tests/core/data/test_data_validator.gd`, `res://tests/ui/test_slot_select_smoke.gd`
- **Leggere** `01_GDD.md` §1; `DECISIONS_LOG.md` (riga M2-00); `05_INTERFACES.md` §2 (`Game`) e `SlotTexts`
- **Descrizione** Le costanti `Game.PLAYER_NAME_MIN/MAX_LENGTH` diventano `player_name.min_length` (1) e
  `player_name.max_length` (24) di `balance.json`; `Game` le legge in `_ready` (chiavi `Game.NAME_MIN_LENGTH_KEY` /
  `NAME_MAX_LENGTH_KEY`), `SlotTexts` le legge con le stesse chiavi per il messaggio di `invalid_name`. Valori invariati.
- **Accettazione** chiavi in `REQUIRED_BALANCE_KEYS`; il validatore rifiuta valori mancanti, non interi, < 1 o
  min > max; nessun numero del limite nel codice.
- **Test** `test_config_files.gd`, `test_game.gd` (nomi ai limiti e fuori), `test_game_no_save_before_slot.gd`,
  `test_data_validator.gd` (chiavi mancanti, interi ≥ 1, min ≤ max), `test_slot_select_smoke.gd` (messaggio con i limiti dei dati).

### M2-01 · Nodi della maestria
- **Ruolo** CORE · **Stima** M · **Parallelizzabile** sì (con M2-02) · **Dipendenze** M1-20
- **Ownership** `res://systems/mastery/mastery_system.gd`, `res://tests/systems/mastery/test_mastery_nodes.gd`
- **Leggere** `01_GDD.md` §6.3; `02_FORMULAS.md` F-15, §8.8; `05_INTERFACES.md` §5.7
- **Descrizione** `node_cost`, `owns_node`, `can_buy_node`, `buy_node`, sorgenti `mastery_node:*`; nodi nel salvataggio.
  Se `mastery_system.gd` supera 400 righe, estrarre `mastery_nodes.gd` (classe interna di supporto, stessa cartella, ownership di questo task).
- **Accettazione** esempi di F-15; prerequisiti; nodi permanenti dopo la spesa del pool.
- **Test** `test_mastery_nodes.gd`.
- **Nota (da M1-09)** `rebuild_modifiers` registra oggi solo `mastery_item:*` (dentro un batch): aggiungere le sorgenti
  `mastery_node:<node_id>` dei nodi posseduti nello stesso batch. `to_save` scrive già `"nodes": []` per ogni skill con
  maestria e `from_save` lo ignora: leggere la lista (id sconosciuti o di un'altra skill → `Log.warn` e scartati). I
  quattro metodi dei nodi sono segnaposto (`node_cost` 0, `owns_node` false, gli altri `unknown_id`); il costo usa
  `get_pool_cap` e `MasteryMath.node_cost` (F-15). `mastery_system.gd` è a 284 righe.

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
  `res://tests/ui/test_mastery_panel_smoke.gd`; estesa (`DECISIONS_LOG.md`, M2-03) a `res://data/config/balance.json`,
  `res://core/data/data_validator.gd` (solo `mastery.pool_warning_pct`), `res://tests/data/test_config_files.gd`,
  `res://tests/core/data/test_data_validator.gd`, `res://ui/theme/ui_style.gd` (solo `MASTERY_*`),
  `res://ui/pages/skill/skill_page.tscn` (solo `MasteryButton`)
- **Leggere** `01_GDD.md` §6; `05_INTERFACES.md` §5.7, §7
- **Descrizione** Finestra (`GameWindow`) con: barra del pool (avviso al 95%), elenco delle azioni con livello e barra di
  maestria, spesa del pool (importo con cursore), albero dei nodi disposto per `pos` con stato (comprato, comprabile, bloccato).
- **Accettazione** ogni comando passa da `MasterySystem` e mostra il `reason` in caso di errore.
- **Test** smoke con la fixture.
- **Nota (da M2-01/M2-02)** Errori di `can_buy_node`/`buy_node` nell'ordine `unknown_id` → `node_owned` →
  `node_prereq_missing` → `pool_insufficient` (`05_INTERFACES.md` §5.7): lo stato del nodo si ricava da `owns_node` e
  `can_buy_node(id).reason` (comprato / comprabile / bloccato da prerequisiti / pool insufficiente), senza copie nella UI.
  Aggiornarsi su `mastery_node_purchased` e `mastery_pool_changed`. I tre alberi veri usano `pos` su 3 colonne × 4 righe
  (`02_FORMULAS.md` §8.8), la fixture `test_gather` ha 3 nodi; lo schema ammette `pos` 0..5.

### M2-04 · Bank completa
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M1-18
- **Ownership** `res://ui/pages/bank/**`, `res://tests/ui/test_bank_page_smoke.gd`
- **Leggere** `01_GDD.md` §7; `05_INTERFACES.md` §5.5, §7
- **Descrizione** Pannello dell'oggetto (`bank_item_panel.gd/.tscn`) con blocca/sblocca, trascinamento per riordinare
  (`move_stack`), pulsante Ordina (`sort_stacks`), ricerca per nome. (Vendita, equipaggia, cibo: M3-06/M3-07.)
- **Accettazione** l'ordine sopravvive al salvataggio; il trascinamento non sposta nulla se `move_stack` fallisce.
- **Test** smoke aggiornato.
- **Nota (da M1-18)** (1) Oggi la griglia non disegna caselle vuote (il GDD non le chiede): facoltativo mostrare le
  caselle libere fino alla capienza. (2) Click sulle caselle: `ItemSlotView.pressed(item_id)` apre il pannello
  dell'oggetto. (3) `CountLabel` di `item_slot.tscn` allarga la casella con numeri lunghi: clip o formato abbreviato
  (ownership estesa a `res://ui/components/item_slot/item_slot.gd/.tscn` per questo solo punto; un formato abbreviato va
  in `NumberFormat`, ownership estesa a `res://ui/theme/number_format.gd` e `tests/ui/test_number_format.gd`).
  (4) Margini, spaziatura della griglia (8) e dimensione della casella di `bank_page.tscn` diventano costanti
  `UiStyle.BANK_*` (es. `BANK_CELL_SIZE`, `BANK_GRID_SEPARATION`; ownership estesa a `res://ui/theme/ui_style.gd`, solo
  costanti `BANK_*`; oggi 375 righe, ricontare il limite di 400). (5) Il tooltip già aperto su una casella non si
  aggiorna se la quantità cambia mentre è visibile: rileggerla o richiudere/riaprire il tooltip su `bank_changed`.

### M2-05 · Test di M2
- **Ruolo** QA · **Stima** S · **Parallelizzabile** no · **Dipendenze** M2-01…M2-04
- **Ownership** `res://tests/integration/test_mastery_flow.gd`
- **Leggere** `02_FORMULAS.md` F-10…F-15
- **Descrizione** Flusso: raccolta lunga → pool → acquisto nodi → l'intervallo cambia di quanto previsto; spesa del pool su
  un'azione → nuovo livello e bonus F-11.
- **Accettazione / Test** il file verde con seme fisso.
- **Nota (da M1-19)** `tests/data/test_stat_registry_coverage.gd` tiene in `CLOSED_FORMULAS` le formule delle milestone
  chiuse che hanno stat. F-11…F-15 non hanno stat proprie in `stats.json`: nessuna modifica a quel file in M2 (se M2
  aggiunge una stat, la formula va in `CLOSED_FORMULAS` con il test dell'effetto e il file entra nell'Ownership).
- **Nota (da M2-00)** Tutti i worktree condividono la stessa cartella `user://` (stesso `config/name`, nessuna
  `use_custom_user_dir`): `user://test_saves` e le cartelle temporanee dei test (`test_game_data`, `test_json_loader`,
  `test_action_runner`, `test_item_conservation`) si sovrascrivono se due suite girano in parallelo (24 fallimenti
  transitori in M2-00, verdi alla ripetizione). Rendere le cartelle dei test uniche per checkout (es. un sottopercorso
  derivato da `ProjectSettings.globalize_path("res://")`, deciso in `tests/helpers/gut_pre_run.gd` e usato dai test)
  oppure, in alternativa, vietare in `CLAUDE.md` le suite in parallelo. Ownership estesa a `gut_pre_run.gd` e ai test
  elencati; nessun codice di produzione.
- **Nota (da M2-03)** Il pannello della maestria (`05_INTERFACES.md` §7, "Pannello della maestria") è coperto dallo
  smoke `tests/ui/test_mastery_panel_smoke.gd`; il flusso di M2-05 resta nel modello (`session.mastery`, nessuna UI).
  Lo smoke porta il pool a un valore preciso con `mastery.to_save()`/`from_save()` (nessun segnale): va bene per
  preparare lo stato, ma la parte "raccolta lunga → pool" deve passare dal runner con il seme fisso. Lo stato di un nodo
  nella UI è `MasteryNodeView.state_of` (`owns_node`, poi `can_buy_node(id).reason`); nel flusso si verifica
  direttamente su `owns_node`/`can_buy_node`. `balance.json` ha ora 59 chiavi obbligatorie (`mastery.pool_warning_pct`
  = 95, solo presentazione: nessuna formula F-xx la usa).

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
- **Nota (da M1-09)** F-11 artigianato è testato solo a livello di regola (`test_mastery_math.gd`, regole vere di
  `forging`). Aggiungere a `test_craft` delle fixture le regole `mastery_bonuses` di artigianato e un caso F-11 di sistema
  (L 50 → +7,5 `preservation_chance`; L 99 → +13,5 e −5 `skill_interval_pct`). Ownership estesa a
  `res://tests/fixtures/data/**` (solo `mastery_bonuses` di `test_craft`) e `res://tests/systems/mastery/test_mastery_system.gd`
  (solo il caso nuovo).
- **Nota (da M1-10)** In `action_runner.gd` l'artigianato entra in due punti: `_start_check` (oggi `is_artisan()` →
  `unknown_id`: diventa `ArtisanResolver.can_start`, `missing_inputs`; lo usa anche `_load_lane`) e `_complete_cycle`
  (oggi sempre `GatheringResolver.resolve`: scegliere il resolver dal tipo di azione; un esito `ok = false` ferma già la
  corsia con `outcome.reason`). Facoltativo (fixture = CORE, ownership estesa a `res://tests/fixtures/data/actions/test_gather.json`,
  solo `interval_ms` di `gather_bundle`): `gather_bundle` a 1000 ms per il caso letterale di F-03 (1000, −80 → 250) e
  rimozione della copia `fast` sotto `user://` in `test_action_runner.gd`; prima verificare che nessun test dipenda dai
  3000 ms di `gather_bundle`.

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
  `tools.json`, `food.json`, `materials.json` (lingotti, intermedi), `res://data/shop/shop.json` (sostituisce il file vuoto di
  M1-12), icone segnaposto relative,
  `res://tests/data/test_data_validity.gd` (casi nuovi)
- **Leggere** `02_FORMULAS.md` §8.2-8.4, §8.6; `04_DATA_SCHEMA.md` §5-6, §9
- **Descrizione** Ricette e oggetti come le tabelle (8 gradi); equipaggiamento con i modificatori di §8.4 (le armi servono in
  M4); attrezzi T1-T8 e gli attrezzi del novizio; shop dell'MVP senza `second_thought`.
- **Accettazione** dati validi; XP e valori calcolati con le formule delle tabelle (il test le ricalcola).
- **Test** casi nuovi: ogni ricetta rispetta §8.2, ogni pezzo §8.4.
- **Nota (da M2-02)** Minerali di Cavatura T1-T8 (ingredienti della Forgiatura): `emberbronze_ore`, `ashlead_ore`,
  `stormzinc_ore`, `duskcobalt_ore`, `glimmerite_ore`, `palecinnabar_ore`, `emberheart_ore`, `riftite_ore`; pesci crudi
  di Lenza T1-T8 (Focolare): `brookfin`, `ashgill`, `redscale`, `dusk_eel`, `shard_gar`, `mist_barbel`, `ember_sturgeon`,
  `riftmaw`. `sort_order` di `materials.json` già usati: legni 10-80, minerali 110-180, pesci 210-280.
- **Nota (review)** Ownership estesa a `res://tests/data/test_crafting_data.gd` (nuovo): i casi nuovi non entravano in
  `test_data_validity.gd` sotto le 400 righe. Fatto: 88 ricette di Forgiatura (lingotti, lame, 6 armature, 3 attrezzi con
  2 lingotti + 1 legno dello stesso grado), 8 di Focolare (`seared_<pesce>`), 24 di Intaglio (arco, bastone arcano,
  impugnatura `<legno>_grip`, tenuta: §8.2 la elenca); `sort_order` di `materials.json` usati in più: lingotti 310-380,
  impugnature 410-480.

### M3-05 · Pagina skill: variante artigianato
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M3-01, M1-15
- **Ownership** `res://ui/pages/skill/recipe_card.gd/.tscn`, `res://ui/pages/skill/skill_page.gd` (scelta tra carta azione e
  carta ricetta), `res://tests/ui/test_skill_page_smoke.gd` (casi nuovi)
- **Leggere** `01_GDD.md` §5; `05_INTERFACES.md` §5.8
- **Descrizione** Carta ricetta con ingredienti (posseduti/richiesti, evidenziati se mancano) e prodotti; probabilità di
  conservazione e di doppio prodotto lette da `modifiers.total`.
- **Accettazione / Test** smoke con la fixture `test_craft`.
- **Nota (da M3-04)** Con i dati veri la Forgiatura ha 88 ricette in una pagina (la lista deve scorrere) e gli attrezzi
  hanno 2 ingredienti (lingotto e legno): la carta ricetta mostra un numero variabile di ingredienti.
- **Nota (da M1-15)** Oggi la `SkillPage` crea una `ActionCard` anche per le ricette e il runner rifiuta lo `start`
  con `unknown_id` (testo "Questa azione non è ancora disponibile."): `test_artisan_skill_refuses_start_until_recipes`
  va sostituito dai casi della carta ricetta. I motivi `missing_inputs` e `bank_full` hanno già un testo in
  `SkillPage.REFUSED_TEXTS`.
- **Nota (da M3-01)** Ora `start` di una ricetta risponde `missing_inputs` quando mancano ingredienti (dopo
  `level_too_low`) e la corsia si ferma con `missing_inputs` quando finiscono a metà serie (05 §5.8): nel merge di M3-01
  `test_artisan_skill_refuses_start_until_recipes` è stato adattato (attende il testo di `missing_inputs`); va comunque
  sostituito dai casi della carta ricetta. Per lo stato
  "avviabile" della carta usare `ArtisanResolver.can_start(session, action)` (sola lettura); le probabilità con
  `ModifierContext.for_action(skill_id, action_id)` (le regole di maestria di artigianato hanno scope di azione). La
  fixture `test_craft` ha ora `mastery_bonuses` (uguali a `forging`).
- **Nota (da M2-03)** `res://ui/theme/ui_style.gd` è a 390 righe su 400: prima di aggiungere costanti `UiStyle.*`
  (qui o in M3-06/M3-07, chi arriva prima) spostare `build_theme()` con i suoi `_add_*` e `_button_styles` (circa 185
  righe) in `res://ui/theme/ui_theme_builder.gd` (`class_name UiThemeBuilder`, solo statiche), lasciando
  `UiStyle.build_theme()` come delega di una riga (nessun chiamante cambia). Ownership estesa a `ui_style.gd` e al file
  nuovo per questo solo spostamento; i test del tema esistenti restano verdi. La `SkillPage` ha ora anche
  `%MasteryButton` e `_mastery_panel` (M2-03): la scelta tra carta azione e carta ricetta non li tocca.

### M3-06 · Shop e vendita
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M3-02, M2-04
- **Ownership** `res://ui/pages/shop/**`, `res://ui/pages/bank/bank_item_panel.gd` (sezione vendita), `res://tests/ui/test_shop_page_smoke.gd`
- **Leggere** `01_GDD.md` §8; `05_INTERFACES.md` §5.11
- **Descrizione** Voci per categoria con prezzo, acquisti, requisiti mancanti; vendita con cursore, "tutti tranne 1", "tutti".
- **Accettazione / Test** smoke; il pulsante Compra è disabilitato quando `can_buy` fallisce e mostra il motivo.
- **Nota (da M2-04)** Il `BankItemPanel` non manda comandi: emette segnali (oggi `lock_requested`, `close_requested`) e
  `BankPage` chiama il modello e mostra il motivo con `REFUSED_TEXTS`. La sezione vendita aggiunge un segnale (da
  dichiarare in `05_INTERFACES.md` §7) e nodi in `bank_item_panel.tscn`; collegamento in `bank_page.gd` (`_ready` e un
  handler) e testi dei motivi nuovi in `REFUSED_TEXTS`: ownership estesa a `bank_item_panel.tscn` e `bank_page.gd`
  (solo questi punti). `tests/ui/test_bank_page_smoke.gd` ha 396 righe: i casi del pannello vanno in un file nuovo
  `tests/ui/test_bank_item_panel_smoke.gd` (ownership estesa). Un oggetto bloccato non si vende (`01_GDD.md` §7).
  Oggi il pulsante Blocca deduce il valore da inviare dal proprio testo: se la sezione cambia il pannello, leggere
  `bank.is_locked` dall'ultimo `show_item`.
- **Nota (da M3-04)** `shop.json` ha 9 voci nelle categorie `bank`, `combat`, `tools`; gli attrezzi del novizio hanno
  `max_purchases` 0 (illimitato, `04_DATA_SCHEMA.md` §9): nessun contatore "x/max" per loro.
- **Nota (da M2-03)** `ui_style.gd` è a 390 righe: costanti `UiStyle.*` nuove solo dopo lo spostamento di `build_theme`
  descritto nella nota di M3-05 (lo fa il primo dei tre task UI di M3 che ne ha bisogno).

### M3-07 · Pagina equipaggiamento
- **Ruolo** UI · **Stima** M · **Parallelizzabile** sì · **Dipendenze** M3-03, M2-04
- **Ownership** `res://ui/pages/equipment/**`, `res://ui/pages/bank/bank_item_panel.gd` (pulsanti Equipaggia e Usa come cibo),
  `res://tests/ui/test_equipment_page_smoke.gd`
- **Leggere** `01_GDD.md` §9; `05_INTERFACES.md` §5.2 (`breakdown`), §5.9
- **Descrizione** Slot (anche attrezzi), cibo, stance, riepilogo delle stat con il dettaglio delle sorgenti (`breakdown`).
  Ownership condivisa di `bank_item_panel.gd` con M3-06: sezioni diverse; il secondo a chiudere fa rebase.
- **Nota (da M2-04)** Come per M3-06: pulsanti del pannello → segnali nuovi (in `05_INTERFACES.md` §7), comandi (`equip`,
  scelta del cibo) mandati da `BankPage`; ownership estesa a `bank_item_panel.tscn`, `bank_page.gd` (solo collegamento e
  testi dei motivi) e `tests/ui/test_bank_item_panel_smoke.gd` (condivisi con M3-06, il secondo fa rebase).
  `bank_item_panel.gd` 95 righe, `bank_page.gd` 280: ricontare il limite di 400.
- **Nota (da M3-04)** Dati veri: archi e bastoni arcani sono `two_handed` (liberano l'`offhand`), lo scudo va in
  `offhand`; le descrizioni dei cibi ripetono la cura ("Cura 20 punti vita."): la pagina mostri `food.heal` letto dai
  dati, non la descrizione, come valore.
- **Nota (da M2-03)** `ui_style.gd` è a 390 righe: costanti `UiStyle.*` nuove solo dopo lo spostamento di `build_theme`
  descritto nella nota di M3-05 (lo fa il primo dei tre task UI di M3 che ne ha bisogno).
- **Accettazione / Test** smoke; nessuna stat mostrata che non sia nel registro.

### M3-08 · Test di M3
- **Ruolo** QA · **Stima** S · **Parallelizzabile** no · **Dipendenze** M3-01…M3-07
- **Ownership** `res://tests/integration/test_crafting_chain.gd`, `res://tests/integration/test_item_conservation.gd` (casi nuovi)
- **Descrizione** Catena minerale → lingotto → attrezzo → equipaggiato → raccolta più veloce; conservazione degli oggetti con
  artigianato, vendita, equipaggiamento. **Leggere** `01_GDD.md` §5, §9 · **Accettazione / Test** i file verdi.
- **Nota (da M1-19)** Ownership estesa a `res://tests/data/test_stat_registry_coverage.gd`: aggiungere `"F-08"` a
  `CLOSED_FORMULAS` (`preservation_chance`; il test `test_artisan_resolver.gd::test_preservation_cap` deve esistere).
- **Nota (da M3-01)** `test_preservation_cap` esiste (somma 95 → 80, 10.000 cicli, seme fisso). Il controllo dello spazio
  dell'artigianato conta le caselle liberate dagli ingredienti consumati del tutto (05 §5.8): un caso di conservazione
  degli oggetti con l'ultimo lotto di ingredienti e la bank piena è utile. Facoltativo di M3-01 non fatto: `gather_bundle`
  a 1000 ms per il caso letterale di F-03 (resta la copia `fast` sotto `user://` in `test_action_runner.gd`).
- **Nota (da M3-04)** Catena con i dati veri: `smelt_<metallo>` (2 minerali → lingotto), `forge_<metallo>_hatchet|pick|rod`
  (2 lingotti + 1 `<legno>_log` dello stesso grado) → slot `tool_forestry|tool_quarrying|tool_angling`, modificatore
  `skill_interval_pct` con scope `skill:<skill>`.

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
  `res://core/session/game_session.gd` (solo campo tipizzato e registrazione), `res://core/session/session_snapshot.gd`
  (solo `kills`, `deaths`, `food_eaten` in `take`)
- **Leggere** `01_GDD.md` §10; `02_FORMULAS.md` F-07, F-23…F-34; `05_INTERFACES.md` §5.10, §6
- **Descrizione** Timer, ordine (prima il giocatore), più eventi per `advance`, respawn, uccisione (oro, drop, frammento),
  XP per danno con stance, morte (borsa persa, PV al massimo), stato salvato e ripreso, contatori, mutua esclusione con la
  corsia main.
- **Accettazione** stato identico dopo salvataggio/caricamento a metà duello; equivalenza 1×1000 ms = 10×100 ms.
- **Test** `test_combat_engine.gd` (inclusi `test_gold_drop_pct`, drop F-32, morte).
- **Nota (da M1-10)** Ownership estesa a `res://systems/actions/action_runner.gd`, solo la riga dello stop del
  combattimento in `start` (oggi un commento segnaposto prima di `stop(lane, Reasons.REPLACED)`, già solo corsia main):
  `if _session.combat != null: _session.combat.stop(Reasons.REPLACED)`. E a `res://tests/core/session/test_game_session.gd`:
  la chiave finta `combat` di `ProbeSession` va in conflitto con `CombatEngine.SAVE_KEY` (assert di `_join`): rinominarla
  (es. `duels`) e aggiungere le asserzioni di `combat`. Avviare il combattimento chiama
  `session.actions.stop(ActionRunner.MAIN, Reasons.REPLACED)` (no-op se la corsia è ferma).

### M4-04 · Contenuto del combattimento
- **Ruolo** DATA · **Stima** M · **Parallelizzabile** sì (con M4-01…M4-03) · **Dipendenze** M3-09
- **Ownership** `res://data/combat/areas.json`, `monsters.json` (sostituiscono i file vuoti di M1-12),
  `res://data/items/materials.json` (drop dei mostri),
  `res://assets/icons/monsters/**`, `res://tests/data/test_data_validity.gd` (casi nuovi)
- **Leggere** `02_FORMULAS.md` §8.5; `04_DATA_SCHEMA.md` §8
- **Descrizione** 4 aree e 12 mostri della tabella, con nomi e descrizioni originali; drop (max 4 per mostro).
- **Accettazione / Test** valori uguali a §8.5 (il test li confronta).
- **Nota (da M3-04)** `sort_order` di `materials.json` già usati: legni 10-80, minerali 110-180, pesci 210-280, lingotti
  310-380, impugnature 410-480: i drop partono da 510. `test_data_validity.gd` è a 275 righe; i casi artigianato sono in
  `tests/data/test_crafting_data.gd`.

### M4-05 · Pagina del combattimento
- **Ruolo** UI · **Stima** L · **Parallelizzabile** sì · **Dipendenze** M4-03
- **Ownership** `res://ui/pages/combat/**` (`combat_page`, `combat_hud`, `loot_bag_view`, `area_list`), `res://tests/ui/test_combat_page_smoke.gd`
- **Leggere** `01_GDD.md` §10, §13; `05_INTERFACES.md` §3, §5.10
- **Descrizione** Scelta di area e mostro (requisiti), barre PV e timer di entrambi, probabilità di colpire e danno massimo
  (da `player_stats`/`monster_stats` e `CombatMath.hit_chance`), cibo e Mangia, stance, borsa con Raccogli tutto, numeri del
  danno sui `combat_hit`.
- **Accettazione / Test** smoke con la fixture; nessuno stato del duello nella UI.
- **Nota (da M1-14)** La rotta `&"combat"` si aggiunge a `PageHost.ROUTES` (`res://ui/screens/main/page_host.gd`,
  ownership estesa alla sola riga della rotta). Le 5 skill di combattimento oggi sono nella Sidebar disabilitate con
  "In arrivo" (`PageHost.has_page` le esclude: `SKILL_PAGE_CATEGORIES` = raccolta, artigianato): decidere se la loro voce
  apre la pagina del combattimento (es. `has_page` vero e `show_page` che porta a `combat`) o resta solo informativa
  (livello), aggiornando `05_INTERFACES.md` §7 e `test_main_screen_smoke.gd`.

### M4-06 · Test di M4
- **Ruolo** QA · **Stima** M · **Parallelizzabile** no · **Dipendenze** M4-01…M4-05
- **Ownership** `res://tests/integration/test_reference_duel.gd`, `test_combat_flow.gd`
- **Leggere** `02_FORMULAS.md` F-34; `01_GDD.md` §10.7
- **Descrizione** Duello di riferimento F-34 (1.000 duelli, intervallo 15-21 s); flusso con morte (borsa persa, bank intatta),
  razioni da campo, cambio di stile e triangolo.
- **Accettazione / Test** i file verdi.
- **Nota (da M1-19)** Ownership estesa a `res://tests/data/test_stat_registry_coverage.gd`: aggiungere a `CLOSED_FORMULAS`
  F-20, F-21, F-22, F-25, F-26, F-27, F-29, F-30, F-31, F-33 e `"10.6"` (`auto_loot`: in `stats.json` il campo `formula`
  è la sezione del GDD, come ammette `04_DATA_SCHEMA.md` §2); dopo M4 nessuna stat dell'MVP resta in `pending`.

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
- **Nota (da M2-02)** `test_data_validity.gd` ha già `FORESTRY_NODES`, `_nodes_by_skill`, `_assert_node_like` e il
  controllo del totale 55-65% su ogni file di `data/mastery/`; i nodi della raccolta ricopiano §8.8 (`OPEN_QUESTIONS.md` Q26).
- **Nota (da M3-04)** Id delle azioni di artigianato per i nodi: `smelt_<metallo>`, `forge_<metallo>_<pezzo>`,
  `cook_<pesce>` (prodotto `seared_<pesce>`), `carve_<legno>_bow|staff|grip` (gli id esatti sono nei file di
  `data/actions/`). Ownership estesa a `res://tests/data/test_crafting_data.gd` per un debito di stile di M3-04: 8 righe
  oltre i 120 caratteri e le costanti `METALS`…`WEAPONS` dichiarate dopo le prime funzioni (vanno in testa).

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
- **Nota (da M1-11)** In `continue_game` l'offline va nel punto `# Offline: M6-01` (dopo `_attach`, prima del
  salvataggio e di `_start_playing`); la costante `STATE_OFFLINE` esiste già. Durante l'offline il clock resta in pausa
  (si avvia in `_start_playing`); `last_offline_summary` va tipizzato `OfflineSummary`; `session_started` resta l'ultimo
  passo. Aggiungere a `test_game.gd` (ownership da estendere) i casi con offline.
- **Nota (da M1-13)** Se `continue_game` diventa una coroutine, `SlotSelect._continue_game`
  (`res://ui/screens/slot_select/slot_select.gd`, ownership estesa a quel metodo) deve fare `await` e impedire un secondo
  click durante lo stato `offline`; aggiornare i `FakeGame` di `tests/ui/test_slot_select_smoke.gd` e
  `test_main_menu_smoke.gd` (stesse firme di `game.gd`).

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
- **Nota (da M1-13)** Nel menu il pulsante è `%SettingsButton` di `main_menu.tscn` (oggi `disabled` con tooltip "Disponibili
  in un prossimo aggiornamento"): attivarlo, togliere il tooltip e collegarlo in `main_menu.gd` (ownership estesa a
  `main_menu.tscn` per quelle proprietà e a `tests/ui/test_main_menu_smoke.gd` per l'asserzione `SettingsButton.disabled`,
  che oggi ha il messaggio sbagliato "settings arrive with M1-12"); correggere anche il commento in testa a
  `main_menu.gd` ("Settings (M1-12)" → M6-03).

### M6-04 · Sistema dei suggerimenti
- **Ruolo** CORE · **Stima** S · **Parallelizzabile** sì · **Dipendenze** M5-05
- **Ownership** `res://systems/hints/hints_system.gd`, `res://core/data/defs/hint_def.gd`, `res://core/data/game_data.gd`
  (`hints()`), `res://core/data/data_validator.gd` (regole di `hints.json`), `res://core/autoload/event_bus.gd`
  (segnale `hint_triggered`), `res://core/session/game_session.gd` (registrazione), `res://tests/systems/hints/test_hints_system.gd`
- **Leggere** `01_GDD.md` §14; `04_DATA_SCHEMA.md` §10; `05_INTERFACES.md` §3, §5.15
- **Descrizione** Trigger di §10 collegati agli eventi della sessione; una volta per slot. Il validatore è in 3 file
  (`data_validator.gd`, `data_validator_rules.gd`, `data_validator_items.gd`): le regole nuove vanno nel file del dominio o,
  se un file supera ~360 righe, in un file proprio (`data_validator_hints.gd`, stessa ownership).
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
- **Nota (da M1-19)** Modalità rigida: `test_stats_of_open_milestones` fallisce (non più `pending`) se una stat di
  `stats.json` non ha il suo test; `CLOSED_FORMULAS` e `FORMULA_MILESTONES` restano la mappa formula → milestone. Le stat
  di M7/M8 (`fracture_duration_pct` F-50, `parallel_lanes` F-51) entrano in `CLOSED_FORMULAS` con i loro task.

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
  Il validatore è in 3 file (`data_validator.gd`, `data_validator_rules.gd`, `data_validator_items.gd`): le regole nuove
  vanno nel file del dominio o, se un file supera ~360 righe, in un file proprio (`data_validator_fractures.gd`, stessa ownership).
- **Nota (da M1-10)** Se `FractureSystem.SAVE_KEY` è `fractures`, rinominare la chiave finta `fractures` di `ProbeSession`
  in `res://tests/core/session/test_game_session.gd` (ownership estesa, solo quella chiave).

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
- **Nota (da M1-10)** Il runner ha già `LANE_ORDER` (main → secondary) e le corsie in `_lanes` (classe interna `_Lane`);
  vanno sbloccati: `start` (oggi `lane_unavailable` per ogni corsia ≠ main), `from_save` (scarta le corsie ≠ main con
  `Log.warn`), `current_interval_ms` (ignora la corsia), `lanes_available` (1); `ActionMath.secondary_interval_ms` (F-51)
  è già testato. Aggiungere `skill_in_other_lane`. Lo stop del combattimento resta solo per la corsia main.

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
