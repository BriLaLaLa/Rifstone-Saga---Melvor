# 07. Task, M33: Tutorial forzato

Estensione di `07_TASKS.md`. Fonte: V42 e M33-01 (`DECISIONS_LOG.md`), **`M33_TUTORIAL_FORZATO.md`** (id, chiavi e firme: fonte unica), `01_GDD_M30.md` §41, `04_DATA_SCHEMA_M30.md` §34, `05_INTERFACES_M30.md`,
`M31_RITOCCHI_TUTORIAL.md` (congelamento e ferita), Q204-Q209. Il design **non** si riscrive nei brief: si citano sezioni. Max **2** agenti insieme; `sonnet`. Tre task in fila, nessun parallelismo.

**Ordine**: M33-02 (CORE+DATA, **un solo agente**: modello e dati si toccano a vicenda) → M33-03 (UI, piccolo) → M33-04 (QA).
Lezioni di M30/M31 valide: (a) clic vero con `Viewport.push_input` (GutLayer nascosto, `tests/ui/test_tutorial_real_flow.gd`); (b) `git checkout -B task/<ID> main`; (c) mai `-gtest=`: `-gdir=... -gselect=<nome>`;
(d) screenshot per risoluzione in cartelle separate, guardati (Read); (e) togliere i `*.uid` non tracciati prima del merge; (f) Guida ≤ 160 parole; (g) nessun processo Godot in background;
(h) non regressione: i test esistenti restano verdi **senza cambiare i numeri attesi** (le sessioni di `TestFactory` completano il tutorial: `force_pack`, guardia e congelamento sono spenti, quindi **i golden di combattimento e
`sim_*` non cambiano**; se uno cambia, è un difetto: si ferma e si riporta al REV; nel caso eccezionale che sia voluto, ri-registrare con nota nel messaggio); (i) nessun numero di design nel codice.
**Numeri attesi che cambiano**: nessuno (passi sempre 22, id invariati, Trote iniziali 30). I test del tutorial che assumono «passi 9-13 con il combattimento in marcia» o «ferita una sola volta» si aggiornano (documentato nel report).

| ID | Titolo | Ruolo | Dim. | Dip. | Accettazione |
|---|---|---|---|---|---|
| M33-01 | Design: `M33_TUTORIAL_FORZATO.md`, V42, Q204-Q209, task | REV | S | m32-done | **DONE** (questo commit) |
| M33-02 | CORE+DATA: `force_pack`, guardia, nodo in viaggio, congelamento ai passi 6 e 9-13, ferita ripetuta, validatore, dati veri | CORE | M | 01 | vedi sotto |
| M33-03 | UI: verifica e ritocchi della pausa e dei bersagli, clic vero su Avanti del passo 6, screenshot | UI | S | 02 | vedi sotto |
| M33-04 | QA: flusso a partita nuova con dati veri, ripresa a ogni passo, offline, semi, golden | QA | S | 03 | vedi sotto |

## M33-02: CORE+DATA
- **Leggere**: `M33_TUTORIAL_FORZATO.md` §2-§6; `M31_RITOCCHI_TUTORIAL.md` §2.1, §3 (congelamento, ferita), §4 (`force_node`); `05_INTERFACES_M30.md` §5.41; `04_DATA_SCHEMA_M30.md` §34.1, §34.6;
  `02_FORMULAS.md` F-77, F-139 (solo lettura: **non cambiano**); `02_FORMULAS_M24.md` F-153, F-156; il codice: `systems/combat/combat_cycle.gd` (`_area_encounter`, `_start_travel`, `_arrive`), `combat_engine.gd`
  (`set_frozen`, `set_force_node`, `wound_to_pct`, `advance`), `encounter.gd` (`of_defs`), `systems/encounters/encounter_cycle.gd`, `cycle_state.gd`, `systems/tutorial/*`, `data/combat/areas.json` (solo lettura).
- **Ownership** (codice): `systems/tutorial/**`; `systems/combat/combat_engine.gd` (**solo** `set_force_pack`/`force_pack`/`is_guarded` e il ritocco di `new_game`/`from_save`; ≤ 400 righe: oggi 387, quindi **le tre funzioni vanno in
  `systems/combat/combat_tutorial.gd` nuovo**, che il motore possiede come membro); `systems/combat/combat_cycle.gd` (**solo** `_area_encounter` e `_start_travel`); `systems/encounters/encounter_cycle.gd`
  (**solo** `forced_node`) e `cycle_state.gd` (se serve); `core/data/defs/tutorial_step_def.gd`; `core/data/tutorial_index.gd`, `game_data.gd` (accessori se servono); `core/data/data_validator_tutorial.gd`
  (e un file nuovo `data_validator_tutorial_combat.gd` se supera 400 righe). **Dati**: `data/tutorial/steps.json` (`force_pack` ai passi 5, 7, 14; `freeze_combat` ai passi 6, 9, 10, 11, 12, 13; `force_pack_max_attack_level`;
  `skill_id` negli `args` del passo 14; testi di §5.2; **gli id e il numero dei passi non cambiano**), `data/guide/tutorial.json` (una frase sulla pausa, ≤ 160 parole, **solo se serve**).
  **Test**: `tests/systems/tutorial/**`, `tests/systems/combat/test_combat_force_pack.gd` (nuovo), `tests/systems/encounters/test_force_node.gd` (estensione), `tests/core/data/test_data_validator_tutorial.gd`,
  `tests/data/test_tutorial_data.gd`, `tests/fixtures/data/tutorial/**` e `tests/fixtures/data/m10/tutorial/**` (solo se servono i campi nuovi).
  **Non toccare**: `ui/**`, `core/autoload/event_bus.gd` (nessun segnale), `core/common/reasons.gd` (nessun motivo), `core/save/**` e il formato del save (nessuna chiave nuova: **resta v12**), le formule, `data/combat/**`, `data/config/**`.
- **Accettazione**:
  1. Motore: `set_force_pack/force_pack/is_guarded` come §3.2; un gruppo forzato dell'area di combattimento sostituisce **qualunque** altro incontro d'area (anche con miniboss o Monolito in attesa, che restano in attesa e non
     si perdono); area diversa o Frattura/Dungeon: nessun effetto; **zero tiri su `rng`** per il gruppo; stesso gruppo a ogni incontro finché armato; `new_game`/`from_save` azzerano.
  2. Guardia: con `is_guarded()` un miniboss/Monolito in attesa non fa `forced_fight`; spenta la guardia, riprendono come in F-139/F-87 (esempio di `02_FORMULAS.md` invariati).
  3. Viaggio: `set_force_pack` in viaggio con tipo `node` (senza `force_node`) lo cambia in `fight`; `set_force_node(true)` in viaggio con tipo `fight` o con nodo saltato lo cambia nel nodo forzato (`EncounterCycle.forced_node`),
     **senza tiri**; nessuna disciplina utilizzabile: nessun cambiamento.
  4. `TutorialSystem`: ogni ingresso e `from_save` impostano **tutti** gli effetti (congelamento, nodo, gruppo, ferita) in base al passo; il passo successivo disarma il precedente; `_release_combat` spegne anche il gruppo;
     ferita ripetuta a ogni `encounter_started` finché il passo 7 è corrente (§3.3); nessuna firma pubblica nuova di `TutorialSystem`, `to_save` invariato.
  5. Validatore: i vincoli di §3.1 e §5.2 con **un test per caso rifiutato** (area o mostro sconosciuto, mostro fuori area, miniboss/pietra, `attack_level` sopra soglia, `rock_ram` nel gruppo del passo 5, gruppo più piccolo
     di `count`, `force_node` senza `force_pack`, soglia mancante o fuori 1..20, `skill_id` fuori dalle discipline dell'area, `freeze_combat` con un evento di combattimento, ultimo passo congelato).
  6. Dati veri validi (`validate_data.gd`), testi ≤ limiti (280 caratteri), nessun nome di Melvor, nessun file oltre 400 righe (`check_file_sizes.gd`).
- **Test richiesti (logica)**:
  1. **Composizione forzata**: partita con tutorial al passo 5, `combat.start(redrock_plains)`: `encounter_started` porta **esattamente** i mostri del dato (ordine incluso), **mai** `rock_ram`, per **200 semi**;
     `session.rng.to_save()` identico prima e dopo la scelta del gruppo (nessun tiro in più).
  2. **Vincibile**: gruppo A (passo 5) con il kit iniziale e con ognuno dei tre assetti (spada e scudo, spadone, due spade), **≥ 100 semi**: zero morti, le 3 uccisioni arrivano, `tutorial_progress` 1, 2, 3 (contatore «N su 3»).
  3. **Stop dopo il combattimento**: all'ultima uccisione del passo 5 la sessione è al passo 6 e `combat.is_frozen()` è vero; `advance(60000)` non cambia `to_save()` del combattimento né `rng.to_save()`; `play_time_ms` sale;
     `acknowledge()` scongela e il passo 7 arma il gruppo B (ferita al 30%). **Equivalenza**: stesso seme, tutorial al passo 6, 12 h in un blocco = 100 ms × N = blocchi da 60 s (stato uguale).
  4. **Pasto garantito**: gruppo B con la ferita, ≥ 100 semi × 3 assetti: zero morti, `food_eaten` entro il primo gruppo B; ferita **ripetuta** (si fa morire il personaggio con un colpo di test e si verifica la ferita al gruppo successivo).
  5. **Pausa 8-13**: dopo Ok del passo 8 il combattimento **resta** congelato fino all'ingresso nel passo 14; `skip_step`/`acknowledge` dei passi 9-13 non lo sbloccano; il passo 14 lo scongela.
  6. **Nodo forzato**: al passo 14 con il motore **in viaggio** di tipo `fight` il viaggio diventa il nodo della prima disciplina appresa, **zero tiri**; con un miniboss in attesa vince il nodo (guardia); con il motore fermo il
     giocatore riavvia con `start` e arriva il gruppo C debole, poi il nodo; spento all'uscita (`is_guarded()` falso).
  7. **Nessun effetto fuori dal tutorial**: sessione con tutorial completato: `force_pack()` vuoto, `is_guarded()` falso, F-77/F-139/F-87 e i golden di combattimento **invariati** (suite `tests/systems/combat`, `tests/balance`).
  8. **Ripresa**: `to_save`/`from_save` a ogni passo (anche 6 e 9-13): gli effetti del passo sono riapplicati, il gruppo armato, il tutorial completabile; un salvataggio v12 «vecchio» fermo a un passo 6-13 con il combattimento
     attivo riprende congelato senza avvisi.
- **Filtro test**: `-gdir=res://tests/systems/tutorial -ginclude_subdirs` (e `systems/combat`, `systems/encounters`, `core/data`, `data` per i file toccati); `validate_data.gd`; `check_file_sizes.gd`.

## M33-03: UI
- **Leggere**: `M33_TUTORIAL_FORZATO.md` §5; `M31_RITOCCHI_TUTORIAL.md` §3.3; `05_INTERFACES_M30.md` §7.ab; `ui/screens/tutorial/tutorial_panel.gd`, `tutorial_overlay.gd`, `ui/pages/combat/combat_page.gd`, `combat_texts.gd`.
- **Ownership**: `ui/screens/tutorial/**`; `ui/pages/combat/combat_page.gd` e `combat_texts.gd` (**solo** la riga «In pausa» e la zona nemici vuota); `tools/shot_tutorial.gd`; `tests/ui/**` (smoke e clic veri del tutorial).
  Nessun file di `systems/`, `core/` o `data/`: un difetto del modello va al REV.
- **Accettazione**: (1) «In pausa» compare a `session.combat.is_frozen()` **anche con la zona nemici vuota** (passo 6: il gruppo è morto, il motore è in viaggio) e **non** compare quando non è congelato; (2) la cornice del passo 6 sulla zona
  nemici vuota è visibile e non copre il pannello; (3) **Avanti** del passo 6 riparte: `is_frozen()` falso, passo 7; (4) la riga «In pausa» è solo della pagina Combattimento: le altre pagine dei passi 9-13 non cambiano; (5) nessuno stato di gioco nella UI; file ≤ 400 righe.
- **Test richiesti**: (a) **clic vero** (`Viewport.push_input`, GutLayer nascosto) su **Avanti** del passo `combat_triangle` con la sessione vera e i dati veri: il motore si sblocca e il passo avanza; (b) uno smoke per la pagina
  Combattimento congelata (zona vuota, «In pausa»); (c) nessun test su testi esatti. **Screenshot** 1280×720 e 1600×900 (cartelle separate) di: passo 5 con gruppo forzato, passo 6 (pausa, zona vuota, Avanti), passo 7
  (ferita, Mangia), passo 8, passo 14; guardati con Read e descritti nel report.

## M33-04: QA
- **Ownership**: `tests/integration/**` (aggiornare `test_m31_tutorial_flow.gd`, `test_tutorial_playthrough.gd`, `test_tutorial_resume.gd`, `test_m30_offline_equivalence.gd`; file nuovo `test_m33_forced_tutorial.gd`); nessun file di produzione:
  un difetto → report al REV.
- **Accettazione**: (1) percorso completo su sessione vera con i **dati veri**: 22 passi, dalla Mappa al passo 14 con il combattimento vero (gruppo A, stop, Avanti, gruppo B, pasto, pausa, Ok, pausa 9-13, nodo forzato lavorato),
  fine del tutorial e incarichi come in M31-04; **nessun** `rock_ram` in nessun gruppo di nessun seme provato (≥ 50); (2) ripresa con salvataggio a **ogni** passo, in particolare a metà pausa (6, 8, 11) e a metà nodo; (3) equivalenza
  offline con tutorial ai passi 6, 8 e 14 (12 h = 100 ms = 60 s); (4) un tutorial «vecchio» (slot v12 con combattimento attivo al passo 9) riprende congelato e si completa; (5) giocatore che ferma il combattimento dalla Mappa
  durante il passo 5, 7 o 14 e lo riavvia: trova il gruppo forzato e il tutorial si completa; (6) golden di combattimento invariati (confronto, nessuna ri-registrazione; se cambiano, nota nel report); (7) `run_checks.ps1` **non** si
  lancia: lo fa il REV dopo il merge.
- **Test richiesti**: gli elenchi sopra; uno screenshot a 1280×720 e uno a 1600×900 del passo 6 con la `MainScreen` vera, guardati con Read.

## Rischi
- **Morte nel gruppo B con la ferita** (medio-basso): gruppo debole e test su ≥ 100 semi × 3 assetti; la ferita si ripete; i dati (`monsters`, `wound_hp_pct`) sono ritoccabili senza codice (Q204).
- **Pausa lunga (passi 8-13)** (medio): un giocatore potrebbe aspettarsi che il combattimento giri durante la visita; la riga «In pausa» e i testi lo dicono (Q205). Nessun effetto sull'economia (tutorial breve).
- **Slot v12 già in gioco** (basso): riprendono congelati ai passi 6-13 se il combattimento è attivo (voluto).
- **Miniboss/Monolito dopo la guardia** (basso, ~5%): restano in attesa e arrivano dopo il passo 14 (Q207).
