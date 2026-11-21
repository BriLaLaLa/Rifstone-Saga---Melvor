# 07. Task, M30: Tutorial obbligatorio e incarichi «Primi passi»

Estensione di `07_TASKS.md`. Fonte: V39 e M30-01 (`DECISIONS_LOG.md`), `01_GDD_M30.md` §41, `04_DATA_SCHEMA_M30.md` §34, `05_INTERFACES_M30.md`, Q186-Q192. Il design **non** si riscrive nei brief:
si citano ID e sezioni. Max **2** agenti insieme; `sonnet` per i ruoli implementativi.

**Ordine**: M30-02 (CORE, da solo: tocca dati, sessione, save, segnali, Posta, hint, helper dei test) → (**M30-03 DATA ∥ M30-04 UI**) → M30-05 (QA) → M30-06 (REV).
Perché: 02 posa tutto il contratto (tipi, segnali, API, validatore, migrazione) con dati **segnaposto** minimi (valgono per far girare `main`); 03 sostituisce i JSON con il contenuto vero e scrive i
test dei dati; 04 costruisce l'interfaccia contro l'API e i dati segnaposto (4 passi: `welcome`, `character`, `combat_start`, `finish`, abbastanza per ogni forma di passo), quindi 03 e 04 non
condividono nessun file e non si aspettano a vicenda; 05 prova tutto insieme con i dati veri.

**Lezioni da applicare in ogni brief** (da M27-M28): (a) ogni UI interattiva nuova ha un test con **clic vero** (`Viewport.push_input` con `InputEventMouseButton`, GutLayer nascosto, come
`tests/ui/test_mail_page_smoke.gd`); (b) nel worktree, se parte da un commit vecchio: `git checkout -B task/<ID> main`; (c) mai `-gtest=` con GUT: `-gdir=... -gselect=<nome>`; (d) screenshot in
cartelle separate per risoluzione, guardati davvero (Read), poi il flusso provato con clic; (e) prima del merge si tolgono i `*.uid` non tracciati che lo bloccano; (f) pagine della Guida ≤ 160 parole;
(g) a fine task nessun processo Godot in background; (h) **non regressione**: tutti i test esistenti restano verdi **senza cambiare i numeri attesi** (un conteggio di costanti, come `MAX_SESSION_LINES`
o il numero di segnali, si aggiorna con il valore nuovo documentato qui); (i) nessun numero di design nel codice (`stuck_ms`, ricompense, regalo: tutto nei dati).

| ID | Titolo | Ruolo | Dim. | Dip. | Accettazione |
|---|---|---|---|---|---|
| M30-01 | Design: GDD §41, schema §34, contratto, task, V39, Q186-Q192 | REV | M | m29-done | **DONE** (questo commit) |
| M30-02 | CORE: `TutorialSystem`, `StarterQuests`, condizioni e metriche, defs e `GameData`, `DataValidatorTutorial`, segnali, motivi, Posta (kind e `collected_total`), gate dei Suggerimenti, save **v12** con `migration_11_to_12`, composizione in sessione, `TestFactory`, dati segnaposto | CORE | L | 01 | vedi sotto |
| M30-03 | DATA: i 21 passi, i 20 incarichi, i modelli di Posta, la pagina Guida «Tutorial»; test dei dati | DATA | M | 02 | vedi sotto |
| M30-04 | UI: `TutorialOverlay`, pannello, bersagli, blocchi, barra laterale (pagine chiuse, `StarterWidget`), `StarterPage`, notifica della pagina, `HintCard` | UI | L | 02 | vedi sotto |
| M30-05 | QA: percorso completo su sessione vera, ripresa a ogni passo, incarichi, equivalenza offline, flusso della UI con clic veri e screenshot | QA | M | 03, 04 | vedi sotto |
| M30-06 | Integrazione: merge, `run_checks.ps1` una volta, `03_ARCHITECTURE.md` (cartella `systems/tutorial/`, save v12), `GUIDA.md`, STATUS, Q186-Q192 riviste, build Windows (partita nuova con tutorial, slot di M29 migrato), tag `m30-done`; push **solo** dopo aver chiesto all'utente (Orchestratore) | REV | S | tutti | `run_checks.ps1` verde su main; nessun file oltre 400 righe; nessun riferimento vietato; la build parte in entrambi i casi |

## M30-02 — CORE
- **Leggere**: `01_GDD_M30.md` §41.2, §41.3, §41.5, §41.9; `04_DATA_SCHEMA_M30.md` §34.1-§34.3, §34.5, §34.6; `05_INTERFACES_M30.md` §3g, §4f, §5.41, §5.42, §6g, §8b; `05_INTERFACES.md` §5.3 (sessione), §5.15 (Hint), §6 (save);
  `05_INTERFACES_M27.md` §5.40 (Posta); per i modelli: `systems/hints/hints_system.gd`, `core/save/migrations/migration_10_to_11.gd`, `core/data/mail_index.gd` e `data_validator_mail.gd` (precedente della Posta, M27-05).
- **Ownership**:
  - Codice: `systems/tutorial/**` (nuovo: `tutorial_system.gd`, `tutorial_conditions.gd`, `tutorial_metrics.gd`, `starter_quests.gd`); `core/data/defs/tutorial_condition.gd`, `tutorial_step_def.gd`, `starter_quest_def.gd` (nuovi);
    `core/data/tutorial_index.gd` (nuovo), `core/data/game_data.gd` (accessori), `core/data/data_validator.gd` (aggancio), `core/data/data_validator_tutorial.gd` (nuovo), `core/data/data_validator_mail.gd` (solo `KINDS`);
    `core/session/game_session.gd`; `core/autoload/event_bus.gd`; `core/common/reasons.gd`; `core/save/save_migrator.gd`; `core/save/migrations/migration_11_to_12.gd`; `systems/mail/mail_box.gd` (kind, `collected_total`, save);
    `systems/hints/hints_system.gd` (solo il gate di `_fire`).
  - Dati **segnaposto** (3 passi `welcome`, `combat_start`, `finish` + 1 `character`; 2 incarichi; un modello per ognuno dei due kind di Posta; `stuck_ms`, `always_open` veri): `data/tutorial/steps.json`, `data/tutorial/starter_quests.json`,
    `data/mail/templates.json` (solo in coda). **M30-03 li sostituisce** (non girano insieme).
  - Test: `tests/systems/tutorial/**`; `tests/core/data/test_data_validator_tutorial.gd`; `tests/core/save/**` (`test_migration_11_to_12.gd`, `test_save_migrator.gd`); `tests/core/session/test_game_session.gd` (solo `MAX_SESSION_LINES` = 249 e i moduli attesi);
    `tests/core/autoload/test_event_bus.gd`; `tests/core/common/test_reasons.gd`; `tests/systems/mail/**`; `tests/systems/hints/test_hints_system.gd` (completano il tutorial in `before_each` o usano `TestFactory`);
    `tests/helpers/test_factory.gd` (§8b); `tests/fixtures/data/tutorial/**` e `tests/fixtures/data/m10/tutorial/**`; `tests/fixtures/data/mail/templates.json`, `tests/fixtures/data/m10/mail/templates.json` (i due kind);
    `tests/fixtures/saves/slot_v11.json` (scritto **prima** di toccare `CURRENT_VERSION`).
- **Accettazione**:
  1. Contratto di §3g-§6g implementato alla lettera; nessun file oltre 400 righe (`tutorial_system.gd` ≤ ~330: eventi e filtri stanno in `TutorialConditions`, misure in `TutorialMetrics`); `game_session.gd` con 3 righe in più.
  2. Nuova partita (`TestFactory.session(..., with_tutorial = true)`): `is_active()`, passo 0, nulla visitato, incarichi non attivi; `from_save` di un v12 con `tutorial` completato: incarichi attivi.
  3. Ogni tipo di condizione avanza il passo con i dati di fixture: `ack`, `event` (scalare, array, `{gte}`, `count` > 1 con `tutorial_progress`), `metric` (già vera all'ingresso → finisce subito; ricontrollata dal segnale giusto).
  4. `on_enter`: il regalo arriva per Posta una sola volta; con la Posta piena arriva comunque (`post` non rifiuta).
  5. Valvola: `can_skip_step()` falso prima di `stuck_ms` di tempo di gioco e vero dopo; `skip_step` rifiuta con `not_stuck`, passa al passo dopo; `acknowledge` rifiuta con `wrong_step` su un passo non-Avanti.
  6. `is_page_open`: casi di §5.41 (completato, `always_open`, passo con `page` vuota, pagine già scoperte, pagina futura chiusa); `needs_navigation` dipende da `notify_page_opened`, `skill:forestry` → `skill`.
  7. Incarichi: misura già vera = riscuotibile; evento contato solo dopo l'attivazione e salvato; `claim` paga XP, consegna **un** messaggio `starter_reward` (denaro **o** oggetti) senza fusioni, una volta sola (`already_claimed`);
     `mailbox_full` non cambia nulla; `starter_quest_completed` una volta e mai al load; `next_open` e `claimable` in ordine di file; niente ricalcolo delle misure a ogni segnale dopo la notifica (test con un contatore di letture).
  8. Save: salva → carica → salva identico (passo a metà con `progress`, visite, incarichi); `from_save` tollerante (§5.41, §6g: passo sconosciuto → completato; `since_ms` > `play_time_ms` → `play_time_ms`).
     **Migrazione**: esempi di `migration_11_to_12` come test; **slot v11 reale** (`slot_v11.json`) caricato senza perdite con il tutorial completato e gli incarichi attivi; chiave `tutorial` mancante in un v12 = partita nuova (documentato).
  9. `HintsSystem`: con il tutorial attivo `bank_full`/`first_shard`/`player_died`/`first_level_10` non scattano e non si segnano visti; completato, scattano; i test esistenti degli hint restano verdi (sessioni con tutorial completato).
  10. `DataValidatorTutorial`: tutti i casi rifiutati di §34.6; `validate_data` verde su dati veri (segnaposto) e su tutte le fixture; `MailBox`: kind nuovi accettati, `collected_total` salvato e azzerato.
  11. Equivalenza: `tests/systems/tutorial/test_tutorial_offline.gd`: 2 h di combattimento in un colpo = passi da 100 ms, con il tutorial a metà (passo `event`) e con gli incarichi attivi: stesso stato di `to_save()`.
  12. `run_tests` mirati verdi: `tests/systems/tutorial`, `tests/systems/mail`, `tests/systems/hints`, `tests/core` (save, data, session, autoload, common), `tests/integration` (non regressione, senza cambiare i numeri).
- **Test richiesti (elenco)**: `test_tutorial_system.gd` (stato, avanzamento, `on_enter`, pagine, valvola), `test_tutorial_conditions.gd` (filtri, nomi degli argomenti dallo script, segnale sconosciuto), `test_tutorial_metrics.gd`,
  `test_starter_quests.gd`, `test_tutorial_save.gd`, `test_tutorial_offline.gd`, `test_migration_11_to_12.gd`, `test_data_validator_tutorial.gd`, estensioni di mail/hints/event_bus/reasons/session.

## M30-03 — DATA (parte dopo 02; può girare con M30-04)
- **Leggere**: `01_GDD_M30.md` §41.4 e §41.7 (i testi e i valori **si trascrivono, non si riscrivono**), §41.6; `04_DATA_SCHEMA_M30.md` §34.1-§34.7; `04_DATA_SCHEMA.md` §19 (Guida) e `data/guide/primi_passi.json` come forma.
- **Ownership**: `data/tutorial/steps.json`, `data/tutorial/starter_quests.json` (sostituiscono i segnaposto), `data/mail/templates.json` (i modelli veri dei due kind, ≥ 2 ciascuno, originali; **in coda**, gli esistenti invariati),
  `data/guide/tutorial.json` (nuovo), `tests/data/test_tutorial_data.gd` (nuovo), `tests/data/test_guide_texts*.gd` e `test_guide_tables` **solo** se contano le pagine/parole della Guida (si riallineano al numero nuovo),
  `tests/data/test_config_files.gd` (solo se elenca i file di `data/`), `docs/NOMI.md` (solo se servono nomi nuovi: non dovrebbero).
- **Accettazione**: `validate_data` verde su dati veri e fixture; 21 passi e 20 incarichi **con gli id, l'ordine e i testi di §41.4/§41.7** (test: conteggio, ordine degli id, `title`/`text`/`name`/`description` dentro i limiti, ultimo passo `ack`);
  ogni passo con `done_when` non-`ack` supera i controlli di raggiungibilità di §34.6 (**test sui dati veri**: Armeria iniziale con un'arma non indossata; area con livello 1; `trainer.learn_gold` = 0 e Maestri per le quattro raccolte; regalo prima di `mail_collected`;
  `ember_rat` esiste e compare nei pacchetti di un'area; `seared_brookfin` e `rift_dust` vendibili; nessun oggetto di ricompensa nelle categorie vietate); totale del denaro degli incarichi = **40.800 rame** (test, con il messaggio che rimanda a Q188);
  i modelli di Posta ≥ 2 per kind, senza segnaposto; la pagina Guida ≤ 160 parole e raggiungibile (`test_guide_texts`); nessun nome di Melvor; nessun file > 400 righe; nessuna modifica a `hints.json` (Q190).
- **Test richiesti**: `tests/data/test_tutorial_data.gd` (sopra) più i test esistenti dei dati verdi.

## M30-04 — UI (può girare con M30-03)
- **Leggere**: `01_GDD_M30.md` §41.2, §41.8; `05_INTERFACES_M30.md` §5.41 (solo le firme di lettura e i comandi), §7.ab, §8b; `04_DATA_SCHEMA_M30.md` §34.4; `05_INTERFACES.md` §5.15b (`HintCard`, `OfflineOverlay`) e §7 (pagine);
  `docs/UI_GDR.md` per lo stile; `tests/ui/test_mail_page_smoke.gd` come modello del clic vero.
- **Ownership**: `ui/screens/tutorial/**` (nuovo: `tutorial_overlay.gd/.tscn`, `tutorial_panel.gd`, `tutorial_targets.gd`, `tutorial_blockers.gd`, `tutorial_texts.gd`); `ui/pages/starter/**` (nuovo: `starter_page.gd/.tscn`, `starter_row.gd`, `starter_texts.gd`);
  `ui/screens/main/starter_widget.gd` (+ `.tscn` se serve); `ui/screens/main/main_screen.gd`, `page_host.gd`, `sidebar.gd`, `sidebar.tscn`; `ui/theme/ui_style.gd` (solo costanti `TUTORIAL_*`/`STARTER_*`);
  l'assegnazione dei **nomi univoci o `unique_name_in_owner`** ai controlli bersaglio di §34.4 nelle scene e negli script delle pagine esistenti **solo** quando serve (`combat_page.tscn` ha già `%MapButton`, `%EnemyZone`, `%EatButton`; per
  Armeria, Maestri, Mestiere, Posta: il nome più piccolo possibile, nessun'altra modifica alle pagine; `combat_page.gd` è a 399 righe: non si tocca il codice, solo la scena); i test `tests/ui/test_tutorial_*.gd`, `tests/ui/test_starter_*.gd` e
  gli esistenti `tests/ui/test_main_screen*.gd`, `test_sidebar*.gd`, `test_page_host*.gd` **solo** per le aspettative nuove (le sessioni dei test hanno il tutorial completato: non devono cambiare).
- **Accettazione**:
  1. Nessuno stato di gioco nella UI: l'overlay e il widget leggono `session.tutorial` / `session.tutorial.starter` e inviano `acknowledge`, `skip_step`, `claim`, `notify_page_opened` (grep nel report).
  2. **Clic veri** (`Viewport.push_input`, GutLayer nascosto): (a) Avanti sul passo `welcome` fa avanzare al passo 2 (modello, non solo UI); (b) con `needs_navigation()` solo la voce `nav.<route>` è premibile: un clic su un'altra voce e sulla barra
     in alto (salvo menu) non cambia pagina; il clic sulla voce giusta mostra la pagina e il passo; (c) il tasto menu apre le Impostazioni sopra l'overlay; Esc idem; (d) `StarterWidget` apre la pagina; **Riscuoti** consegna il messaggio per Posta
     (`mail.count()` + 1) e aggiorna la riga; (e) un clic nell'area della pagina durante un passo funziona (es. «Mappa» in `combat_start` avvia il flusso e il passo `event` finisce).
  3. Ridimensionamento: overlay e blocchi corretti a **1280×720 e 1600×900** (screenshot in cartelle separate, guardati con Read: passo `welcome` al centro; passo con bersaglio evidenziato e pannello fuori dal bersaglio; stato "Vai a <pagina>" con la voce illuminata;
     barra laterale con pagine attenuate e `StarterWidget`; `StarterPage` con almeno 4 gruppi, un incarico riscuotibile e uno no).
  4. Pagine chiuse: righe attenuate con suggerimento; `PageHost.show_page` rifiuta una pagina chiusa (test) e non rompe `_first_page`; i collegamenti interni verso pagine chiuse non fanno nulla; completato: tutto come prima.
  5. `HintCard`: con il tutorial attivo non appare; a `tutorial_completed` mostra gli hint in coda (test).
  6. Offline: con `is_blocked` vero l'overlay non è visibile; il riepilogo offline sta sopra (ordine dei figli). L'overlay si libera da solo a `tutorial_completed` e a `session_ended` (nessun riferimento alla sessione liberata).
  7. File ≤ 400 righe; un solo smoke test per pagina nuova (`StarterPage`) e uno per l'overlay (oltre ai clic veri); nessun test su testi esatti.
- **Test richiesti**: `test_tutorial_overlay_smoke.gd` (stati: passo, navigazione, valvola, completato), `test_tutorial_clicks.gd` (clic veri, punto 2), `test_starter_page_smoke.gd`, `test_starter_widget.gd`, ritocchi a sidebar e page_host (punto 4);
  screenshot con `tools/shot_ui.gd`-style (script in `tools/` solo se serve, nuovo file `tools/shot_tutorial.gd`).

## M30-05 — QA (dopo 03 e 04)
- **Leggere**: `01_GDD_M30.md` §41.4, §41.7, §41.10; `05_INTERFACES_M30.md` §5.41-§5.42; `tests/integration/test_m28_conditions_flow.gd` e `tests/helpers/test_factory.gd` come modello.
- **Ownership**: `tests/integration/test_tutorial_playthrough.gd`, `test_tutorial_resume.gd`, `test_starter_quests_flow.gd`, `test_m30_offline_equivalence.gd` (nuovi); `tests/ui/test_tutorial_real_flow.gd` (nuovo); `tools/shot_tutorial.gd` (se non già scritto da 04: si estende, non si
  riscrive); nessun codice di produzione (un difetto trovato si riporta al REV).
- **Accettazione**:
  1. **Percorso completo su sessione vera** (dati veri, `with_tutorial = true`): per **ognuno dei 21 passi** si esegue dal modello l'azione del giocatore (`equipment.equip`, `combat.start(redrock_plains)` + avanzare il tempo fino a 3 uccisioni, `disciplines.learn(forestry)`,
     `advance` fino a `node_started`, `mail.collect`, `acknowledge`, `notify_page_opened` per ogni pagina) e si verifica che il passo finisca e il successivo cominci; alla fine `tutorial_completed`. Nessun passo richiede un'azione fuori dallo stato iniziale (per `mail`: il regalo è arrivato).
  2. **Ripresa**: salva e ricarica **a ogni passo** (anche a metà di un `count`): stesso passo, stesso avanzamento, il tutorial prosegue fino alla fine; un v11 reale migrato: completato, Primi passi attivi, nessun overlay.
  3. **Incarichi**: per ognuno dei 20, un percorso con l'aiuto dei **soli helper di test** (`TestFactory.give`, `set_character_level`, `learn_all`, edifici impostati dal modello) che porta l'obiettivo a vero **con eventi veri**, poi `claim` → messaggio in Posta → `collect`;
     quelli raggiungibili con lo stato iniziale (1-7, 9-10, 19-20) senza helper; il totale riscosso = 40.800 rame + oggetti + XP di §41.6.
  4. **Equivalenza offline** con tutorial e incarichi attivi: 12 h in un colpo = passi da 100 ms = blocchi da 60 s con salva e ricarica a metà (stato `to_save()` uguale, `tutorial_completed` emesso allo stesso istante di gioco).
  5. **Flusso di UI su sessione vera con clic veri** (`MainScreen` + dati veri, 1280×720): welcome → character → equipment (selezione e Equipaggia con clic) → `combat_start` (Mappa e area con clic) fino al passo 5; riavvio della scena a metà (salva ed esci, ricarica) riprende dal passo.
  6. Screenshot 1280×720 e 1600×900 dei passi 1, 3, 4, 11, 17 e del widget a metà catena, guardati e descritti nel report; nessun file oltre 400 righe; nessun processo Godot in background.
- **Test richiesti**: gli elenchi sopra; **non** si aggiustano test di altri task: un difetto → report al REV.

## Rischi
- **Un passo che intrappola** (alto): una condizione irraggiungibile bloccherebbe una partita nuova. Mitigazioni: tutti i passi non-Avanti hanno un controllo di raggiungibilità sui dati veri (M30-03), il test di percorso completo
  (M30-05), la valvola `skip_step` (§41.2) e la regola «stato illeggibile → completato». I passi 5 e 13 dipendono dal caso (morte, nodo): l'area della pagina resta usabile per riavviare.
- **Test esistenti che si aprono su un tutorial attivo** (alto): ogni test di pagina, hint e flusso crea una sessione con `TestFactory`. Mitigazione: `TestFactory` completa il tutorial (§8b); gli unici test con tutorial attivo sono quelli di M30.
- **`game_session.gd`** (medio): 245 righe, tetto 246 → 249. Se serve di più, si estrae in `SessionParticipants` (file nuovo), non si alza il tetto oltre.
- **Save** (basso): modulo additivo + migrazione banale; un v11 si carica con il tutorial completato. Un v12 con `tutorial` mancante vale partita nuova (non si produce).
- **Suggerimenti** (basso): `first_action` resta inerte (Q190); i Suggerimenti ritornano a scattare solo a tutorial finito, quindi `first_shard` può perdersi (accettato).
- **Eventi** (medio): collegamento generico per nome di segnale con argomenti variabili: il test di `tutorial_conditions` copre ogni segnale usato dai dati e il validatore rifiuta nomi di argomenti inesistenti.
- **Offline** (basso): nessun `advance`; i listener degli incarichi sono pochi e le misure si rileggono solo finché serve (§5.42).
- **Parallelismo 03 ∥ 04** (basso): file disgiunti (`data/**`, `tests/data/**` contro `ui/**`, `tests/ui/**`, `tools/shot_tutorial.gd`); l'unico punto di contatto sono i **id dei bersagli** di §34.4 e i passi segnaposto, fissati qui.

**M31 (V40)**: ritocchi al tutorial, task in `07_TASKS_M31.md`; il numero dei passi diventa 22 (`M31_RITOCCHI_TUTORIAL.md` §2.2).
