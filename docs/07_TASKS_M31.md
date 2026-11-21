# 07. Task, M31: Ritocchi al tutorial e ai «Primi passi»

Estensione di `07_TASKS.md`. Fonte: V40 e M31-01 (`DECISIONS_LOG.md`), **`M31_RITOCCHI_TUTORIAL.md`** (id, chiavi e firme: fonte unica), `01_GDD_M30.md` §41, `04_DATA_SCHEMA_M30.md` §34, `05_INTERFACES_M30.md`,
Q193-Q198. Il design **non** si riscrive nei brief: si citano sezioni. Max **2** agenti insieme; `sonnet`. Non è una milestone lunga: tre task in fila.

**Ordine**: M31-02 (CORE+DATA, **un solo agente**: modello e dati si toccano a vicenda) → M31-03 (UI) → M31-04 (QA). Nessun parallelismo: 03 legge l'API di 02, 04 prova tutto.
Lezioni di M30 valide: (a) clic vero con `Viewport.push_input` (GutLayer nascosto, `tests/ui/test_tutorial_real_flow.gd`); (b) `git checkout -B task/<ID> main`; (c) mai `-gtest=`: `-gdir=... -gselect=<nome>`;
(d) screenshot per risoluzione in cartelle separate, guardati (Read); (e) togliere i `*.uid` non tracciati prima del merge; (f) Guida ≤ 160 parole; (g) nessun processo Godot in background;
(h) non regressione: i test esistenti restano verdi **senza cambiare i numeri attesi**, tranne i due documentati qui sotto; (i) nessun numero di design nel codice.
**Numeri attesi che cambiano (documentati)**: `start.items[0].qty` 20 → 30 (i test che contano le Trote iniziali); numero di passi 21 → 22 (`tests/data/test_tutorial_data.gd`, `test_tutorial_playthrough.gd`, `test_tutorial_resume.gd`, fixture non toccate).

| ID | Titolo | Ruolo | Dim. | Dip. | Accettazione |
|---|---|---|---|---|---|
| M31-01 | Design: `M31_RITOCCHI_TUTORIAL.md`, V40, Q193-Q198, task | REV | S | m30-done | **DONE** (questo commit) |
| M31-02 | CORE+DATA: congelamento e ferita del motore, `force_node`, campi di passo, `StarterQuests` bonus finale, validatore, dati veri | CORE | M | 01 | vedi sotto |
| M31-03 | UI: etichette del pannello, «In pausa», pallino del widget, riga del bonus nella pagina | UI | S | 02 | vedi sotto |
| M31-04 | QA: percorso con dati veri, pausa e RNG, bonus, clic veri, screenshot | QA | S | 03 | vedi sotto |

## M31-02: CORE+DATA
- **Leggere**: `M31_RITOCCHI_TUTORIAL.md` §2-§5; `05_INTERFACES_M30.md` §5.41, §5.42, §6g; `04_DATA_SCHEMA_M30.md` §34.1, §34.3, §34.6; `02_FORMULAS_M24.md` F-155/F-156 (solo lettura: **non cambiano**);
  `05_INTERFACES.md` §5.10 (motore di combattimento, ciclo `advance`); il codice: `systems/combat/combat_engine.gd`, `combat_cycle.gd`, `systems/encounters/encounter_cycle.gd`, `cycle_state.gd`, `systems/tutorial/*`.
- **Ownership** (codice): `systems/tutorial/**`; `systems/combat/combat_engine.gd` (**solo** le API di §3.1; ≤ 400 righe, altrimenti `systems/combat/combat_tutorial.gd` nuovo); `systems/encounters/encounter_cycle.gd`, `cycle_state.gd`
  (solo `force_node`); `core/data/defs/tutorial_step_def.gd`, `starter_quest_def.gd` (se serve), `starter_final_def.gd` (nuovo); `core/data/tutorial_index.gd`, `game_data.gd` (accessore `starter_final`);
  `core/data/data_validator_tutorial.gd`. **Dati**: `data/tutorial/steps.json` (22 passi: §2.2), `data/tutorial/starter_quests.json` (`final_reward`: §2.3), `data/items/misc.json` (solo `pioneer_emblem`),
  `assets/icons/items/pioneer_emblem.svg`, `data/config/balance.json` (**solo** `start.items[0].qty` = 30), `data/guide/tutorial.json` (cita il bonus e il cibo senza numeri).
  **Test**: `tests/systems/tutorial/**`, `tests/systems/combat/test_combat_freeze.gd` (nuovo), `tests/systems/encounters/test_force_node.gd` (nuovo), `tests/core/data/test_data_validator_tutorial.gd`,
  `tests/data/test_tutorial_data.gd`, `tests/fixtures/data/tutorial/**` e `tests/fixtures/data/m10/tutorial/**` (solo se servono i campi nuovi o `final_reward`, che il validatore richiede), i test del cibo iniziale.
  **Non toccare**: `ui/**`, `core/autoload/event_bus.gd` (nessun segnale nuovo), `core/common/reasons.gd` (nessun motivo nuovo), `core/save/**` (nessuna versione nuova), le formule.
- **Accettazione**:
  1. Contatore: il passo 5 ha `progress_text` e `step_progress_text()` lo restituisce; il conteggio sale **a ogni uccisione** (non per scontro: un gruppo di 3 nemici = +3).
  2. Motore: `set_frozen/is_frozen`, `set_force_node/is_force_node`, `wound_to_pct` come §3.1; `advance` congelato non consuma timer e **non tira l'RNG**; il ciclo esce alla fine dell'istante del pasto.
  3. `TutorialSystem`: ingresso/uscita/caricamento come §3.2 (passi `combat_eat`, `combat_food`, `nodes`); `acknowledge` su `combat_food` sblocca; `to_save` non cambia forma.
  4. `force_node` come §4 (nessuna disciplina appresa → regola normale; Monolito/miniboss in attesa prevalgono).
  5. Bonus: API di §5, salvataggio additivo `final_claimed` **senza** nuova versione, tolleranza di §5.
  6. Validatore: i vincoli di §2.1 e §2.3 con un test per caso rifiutato (campo fuori regola: `%d` mancanti o in più, `ack_text` senza `ack`, `freeze_combat` senza `ack`, `force_node` senza `node_started`, `wound_hp_pct` fuori 1..99 o senza
     `food_eaten`, `final_reward` mancante, ricompensa con categoria vietata, denaro e oggetti insieme); il bersaglio e la raggiungibilità dei passi come §34.6.
  7. Dati veri validi (`validate_data.gd`), testi ≤ limiti, nessun nome di Melvor, nessun file oltre 400 righe (`check_file_sizes.gd`).
- **Test richiesti (logica)**:
  1. **Pausa e RNG**: dopo il pasto del passo 7 la sessione è congelata; `advance(60000)` non cambia `to_save()` del combattimento né `rng.to_save()`; `play_time_ms` sale; Ok sblocca e il combattimento riprende.
  2. **Equivalenza**: stesso seme, tutorial al passo 7: 12 h in un blocco = 100 ms × N = blocchi da 60 s (stato uguale, incluso il punto di arresto, §3.1); salva e ricarica **a metà pausa** → ancora congelato, Ok funziona.
  3. **Garanzia del pasto**: area 1, kit iniziale, ferita al 30%: su **almeno 50 semi** il personaggio **non muore** prima di mangiare e `food_eaten` arriva entro il primo scontro (se un seme fallisce: si riporta al REV, si cambia `wound_hp_pct` solo nei dati).
  4. **Contatore per uccisione**: un gruppo di 3 nemici uccisi nello stesso istante porta il passo 5 a 3 e lo chiude; `tutorial_progress` emesso a ogni uccisione.
  5. **Nodo forzato**: al passo `nodes` il primo viaggio dopo l'ingresso è un nodo lavorato della disciplina appresa (con Boscaiolo appreso, area 1) con **zero tiri RNG** nella scelta; spento all'uscita; senza discipline: regola normale.
  6. **Bonus**: disponibile solo a 20/20; `claim_final` consegna per Posta gli oggetti + XP e imposta `final_claimed`; ordine dei rifiuti (`tutorial_inactive`, `already_claimed`, `quest_incomplete`, `mailbox_full`); round trip del save; `final_claimed` assente = `false`; save v12 vecchio senza chiave carica senza avvisi.
  7. **Cibo iniziale**: `start.items` dà 30 Trote in una partita nuova.
- **Filtro test**: `-gdir=res://tests/systems/tutorial -ginclude_subdirs` (e `combat`, `encounters`, `core/data`, `data` per i file toccati); `validate_data.gd`; `check_file_sizes.gd`.

## M31-03: UI
- **Leggere**: `M31_RITOCCHI_TUTORIAL.md` §3.3, §6, §7; `05_INTERFACES_M30.md` §7.ab; `ui/screens/tutorial/tutorial_panel.gd`, `tutorial_overlay.gd`, `ui/screens/main/starter_widget.gd`, `ui/pages/starter/*`, `ui/pages/combat/combat_page.gd`.
- **Ownership**: `ui/screens/tutorial/**` (`tutorial_panel.gd`: `progress_text` e `ack_text` dal modello; `tutorial_texts.gd`); `ui/screens/main/starter_widget.gd`; `ui/pages/starter/**` (riga `FinalRow`, `StarterTexts`);
  `ui/pages/combat/combat_page.gd` e `combat_texts.gd` (solo la riga «In pausa»); `ui/theme/ui_style.gd` (solo costanti: `STARTER_DOT_SIDE` 12 e quelle della pulsazione); `tools/shot_tutorial.gd`; `tests/ui/**` (smoke del tutorial e dei Primi passi).
  Nessun file di `systems/`, `core/` o `data/`.
- **Accettazione**: (1) il pannello mostra «Nemici sconfitti: n su 3» (dato), «Ok» sul passo 8, la cornice sul pulsante Mangia; (2) la pagina Combattimento mostra «In pausa» solo a `session.combat.is_frozen()`; (3) il pallino
  del riquadro si accende su `starter_quest_completed` (misura vera), su `starter_quests_changed`, per il bonus finale, e si spegne quando non c'è più nulla da riscuotere; pulsa; (4) il riquadro resta a 20/20 finché il bonus non è riscosso;
  (5) la pagina `starter` ha la riga del bonus (disattivata prima di 20/20, Riscuoti dopo, avviso e `mailbox_full` come gli altri); (6) nessuno stato di gioco nella UI; file ≤ 400 righe.
- **Test richiesti**: (a) **clic vero** (`Viewport.push_input`, GutLayer nascosto) su **Ok** del passo `combat_food` con la sessione vera: il motore si sblocca (`is_frozen()` falso) e il passo avanza; (b) **clic vero** su **Riscuoti** (un incarico a misura già vera e il bonus a 20/20):
  Posta con il messaggio, pallino spento; (c) il pallino compare quando una misura diventa vera (si alza il livello del personaggio nel modello) senza altro evento; (d) uno smoke per pagina, nessun test su testi esatti.
  **Screenshot** 1280×720 e 1600×900 (cartelle separate) di: passo 5 con «n su 3», passo 7, passo 8 (pausa, Ok, cornice), riquadro con pallino acceso, pagina `starter` con bonus disponibile; guardati con Read e descritti nel report.

## M31-04: QA
- **Ownership**: `tests/integration/**` (nuovi `test_m31_tutorial_flow.gd`, aggiornamento di `test_tutorial_playthrough.gd`, `test_tutorial_resume.gd`, `test_m30_offline_equivalence.gd` ai 22 passi); nessun file di produzione: un difetto → report al REV.
- **Accettazione**: (1) percorso completo su sessione vera con i **dati veri**: 22 passi, dal passo 5 al passo 14 con il combattimento vero (seed fissati), pasto, pausa, Ok, Boscaiolo, nodo forzato lavorato, fine tutorial,
  20 incarichi riscossi (helper permessi **solo** per quelli irraggiungibili: Frattura, Dungeon, edifici) e bonus finale per Posta; (2) ripresa con salvataggio a **ogni** passo, in particolare a metà pausa e a metà nodo forzato;
  (3) equivalenza offline con tutorial al passo 7 e al passo 14 (12 h = 100 ms = 60 s); (4) la sessione di un salvataggio v12 pre-M31 a 20/20 mostra il bonus disponibile; (5) `run_checks.ps1` **non** si lancia: lo fa il REV dopo il merge.
- **Test richiesti**: gli elenchi sopra; flusso della UI con clic veri già in M31-03 (qui solo un passaggio completo dei passi 7-8 e 14 con la `MainScreen` vera a 1280×720 e uno screenshot a 1600×900 del passo 8, guardato).

## Rischi
- **Ferita letale** (medio): 30% di PV e un colpo nel «primo combattimento sicuro». Mitigazioni: test su ≥ 50 semi (M31-02, test 3), il valore è un dato ritoccabile, `wound_to_pct` mai sotto 1.
- **Congelamento a metà istante** (medio): l'arresto è alla fine dell'istante, non nel mezzo; il test di equivalenza (test 2) lo prova. Il motore non ha stato nuovo da salvare.
- **Slot v12 già in gioco** (basso): su `combat_food` del vecchio ordine riprendono congelati con Ok; un 20/20 vede il bonus disponibile (voluto).
- **Numeri attesi** (basso): Trote iniziali 20 → 30 e passi 21 → 22 sono gli unici cambi ai test esistenti.
