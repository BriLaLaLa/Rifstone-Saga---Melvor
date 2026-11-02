# 09. Convenzioni

Base: la guida di stile ufficiale di GDScript (Godot 4). Qui sotto ciò che teniamo da RiftStone, ciò che correggiamo
(le incoerenze di `../RIFTSTONE SAGA/docs/handover/07_CONVENTIONS.md`) e le regole nuove.

| Teniamo da RiftStone | Correggiamo |
|---|---|
| `snake_case` per variabili e funzioni, `UPPER_SNAKE_CASE` per costanti, `PascalCase` per classi | file `PascalCase.gd` → **file `snake_case.gd`** con `class_name` `PascalCase` |
| commenti di testa `##` (doc di Godot) | niente docstring in stile Python `"""..."""`; niente `# File: res://...` |
| commenti che spiegano il **perché** | commenti in **inglese** (prima misti) |
| servizi senza stato come classi con `static func` | niente `var` scritte come costanti (`SAVE_PATH`), niente `const LOG := true` per file |
| tipo di ritorno sempre dichiarato | **tutte** le variabili tipizzate (prima ~1.700 senza tipo) |
| tema generato da codice (`UiStyle`) | niente `StyleBoxFlat.new()` sparsi: solo varianti del tema o helper di `UiStyle` |
| commit "conventional" (`feat(ui): …`) | — |
| segnali al passato (`died`, `quest_completed`) | niente prefisso `on_` per i segnali |
| JSON con 2 spazi, chiavi inglesi | id dei dati **solo in inglese** (prima misti italiano/inglese); un solo nome per l'id (`id`, mai `item_id` e `id` per la stessa cosa nei dati) |
| — | fine riga **LF** ovunque (prima miste) |
| — | niente `print` con emoji: solo `Log`, senza emoji |
| — | niente duck typing (`has_method`, `obj.get("campo")`): tipi espliciti |
| — | niente `const X = preload(...)` come alias di una classe che ha già `class_name` |

## 1. GDScript

- Godot 4.5, tab per l'indentazione, righe ≤ 120 caratteri.
- Ordine nel file: `class_name`, `extends`, commento `##`, `signal`, `enum`, `const`, `@export`, `var` pubbliche,
  `var` private (`_`), `_init`/`_ready`, metodi pubblici, metodi privati.
- Tipizzazione: `var x: int = 0` o `var x := 0` (inferenza solo quando il tipo è ovvio dal lato destro); parametri e ritorni
  sempre tipizzati; array e dizionari tipizzati (`Array[ItemDef]`, `Dictionary[StringName, int]`).
- Impostazioni del progetto (M0-01 le attiva): `debug/gdscript/warnings/untyped_declaration = 2` (errore),
  `inferred_declaration = 0`, `unsafe_*` = 1 (avviso).
- `StringName` per gli id (`&"forestry"`); `String` per i testi.
- Niente numeri di design nel codice: si leggono da `GameData`. Ammessi `0`, `1`, `-1`, `100` (percentuali), `1000` (ms→s)
  e le costanti di presentazione in `ui_style.gd`.
- Errori di programmazione: `assert` + `push_error`; errori di gioco: `CommandResult.fail(Reasons.X)`.
- Nessun `await`, `Timer` o `_process` nella logica (`core/`, `systems/`), tranne `GameClock`, `Game` (autosave) e
  `OfflineSimulator.run`.
- Massimo ~400 righe per file (`tools/check_file_sizes.gd`), ~40 righe per funzione come obiettivo.

## 2. Nomi

| Cosa | Regola | Esempio |
|---|---|---|
| File | `snake_case.gd`, scena accanto allo script con lo stesso nome | `skill_page.gd`, `skill_page.tscn` |
| Classi | `PascalCase`, uguale al nome del file | `class_name SkillPage` |
| Autoload | `PascalCase`, `class_name` diverso se serve istanziarlo | `EventBus` / `GameEvents` |
| Privati | prefisso `_`, mai usati da fuori (neanche nei test: si testa l'API pubblica) | `_advance_lane` |
| Segnali | passato o evento, `snake_case`, senza `on_` | `bank_changed`, `level_up` |
| Gestori | `_on_<emettitore>_<segnale>` | `_on_bank_changed` |
| Booleani | `is_`, `has_`, `can_` | `is_running()` |
| Id dei dati | inglese `snake_case` | `cut_redbirch`, `plains_boar` |
| Nodi nelle scene | `PascalCase` | `ActionList`, `ProgressBar` |

## 3. Scene e UI

- Una scena = una responsabilità; scene ≤ 400 righe (`.tscn`), altrimenti si dividono in sotto-scene.
- La UI si costruisce nelle scene `.tscn` per la struttura; il codice crea solo elementi ripetuti (carte, caselle).
- Nessuna `var` con stato di gioco nella UI: ogni dato si legge dalla sessione. Ammessi solo riferimenti a nodi, alla
  sessione e stato di presentazione (scheda aperta, testo di ricerca).
- Le pagine estendono `Page` e si collegano/scollegano agli eventi in `bind`/`unbind`.
- Accesso ai nodi con `%NomeUnico` (nomi unici nella scena) o `@onready var x: Tipo = $Percorso` interno alla scena.
  Vietati `get_node("/root/...")` e percorsi che escono dalla propria scena; vietato `reparent` a runtime.
- Testi visibili in italiano, senza emoji; numeri con separatore delle migliaia (`1.250`).
- Stile: varianti del tema (`theme_type_variation`) di `UiStyle`; colori solo dalle costanti di `UiStyle`.

## 4. Segnali

- I segnali di gioco stanno solo nell'`EventBus` e sono quelli di `05_INTERFACES.md` §3, con parametri tipizzati.
- Si emettono **dopo** aver cambiato lo stato (chi ascolta legge lo stato nuovo).
- Segnali locali di una scena (es. `pressed` di un componente) sono ammessi dentro `ui/`.
- Ogni `connect` in una pagina ha il suo `disconnect` in `unbind`.

## 5. Dati e contenuti

- JSON UTF-8, 2 spazi, chiavi inglesi, campi come `04_DATA_SCHEMA.md`; `_doc` per i commenti.
- Nomi e descrizioni originali in italiano, a tema RiftStone (Roccarossa, Rift, frammenti, brace…). Vietati nomi di
  skill, oggetti, mostri, luoghi o testi di Melvor Idle e copie di sue tabelle. In caso di dubbio su un nome, scegliere
  un altro nome e segnalarlo nel report.
- Icone segnaposto: generate (forme e colori semplici) o disegnate per il progetto; niente immagini prese da altri giochi.
- I numeri seguono le tabelle di `02_FORMULAS.md` §8; uno scostamento si propone nel report, non si fa.

## 6. Test

- GUT 9.5.0. File `test_<cosa>.gd` in `res://tests/` con la stessa struttura della cartella sorgente.
- Comandi:
  ```bash
  powershell -File tools/run_tests.ps1
  ```
  ```bash
  powershell -File tools/run_checks.ps1
  ```
  (eseguibile di Godot da `$env:GODOT`, default `C:\Users\Davide\Desktop\GODOT\Godot_v4.5-stable_win64_console.exe`).
- Unit test su classi isolate con la `TestFactory`; mai l'autoload `Game` con slot veri. Ogni sessione creata si libera.
- Ogni esempio numerico di `02_FORMULAS.md` è un test con gli stessi numeri; i test casuali usano semi fissi.
- Nome del test: `test_<comportamento>` (`test_bank_full_rejects_new_item`).
- Un test che non può ancora girare (dipende da una milestone futura) usa `pending("motivo, task <ID>")`.

## 7. Git e commit

- Branch `main` + un branch `task/<ID>` per task (vedi `08_TEAM.md` §3).
- Messaggi: `tipo(ambito): descrizione in italiano [<ID>]`; tipi `feat`, `fix`, `refactor`, `test`, `docs`, `data`,
  `port`, `tools`, `chore`. Esempio: `feat(bank): capienza dalla stat bank_slots [M1-07]`.
- Corpo facoltativo con il perché. Nessun file generato o di cache (`.godot/`) nei commit.

## 8. Formato dei file

- UTF-8 senza BOM, fine riga LF (`.gitattributes`: `* text=auto eol=lf`), newline finale.
- `.editorconfig`: tab per `.gd`/`.tscn`/`.tres`/`.cfg`, 2 spazi per `.json`/`.md`.

## 9. Checklist di revisione (Reviewer/Integrator)

- [ ] DoD di `08_TEAM.md` §5 completa; report nel formato giusto.
- [ ] Diff solo nei file di Ownership.
- [ ] API e segnali = `05_INTERFACES.md`.
- [ ] Numeri di design nel codice: nessuno (cercare letterali numerici nei file di `core/` e `systems/`).
- [ ] Nessuna `var` con stato di gioco in `ui/`.
- [ ] Nessun accesso diretto ai campi privati di un altro sistema.
- [ ] Stat nuove: registrate in `stats.json` con formula e test.
- [ ] `tools/run_checks.ps1` verde su `main` dopo il merge.
