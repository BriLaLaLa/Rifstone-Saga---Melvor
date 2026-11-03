# Stato dei task

Aggiornato dall'Orchestratore (unico che modifica questo file). Stati: TODO / IN_PROGRESS / REVIEW / DONE / BLOCKED.
Se la sessione si interrompe, si riparte da qui.

## Ripartenza (aggiornata il 2026-11-03)
- **Stato**: M3 avviata (OK utente 2026-11-03). M2 completata, tag `m2-done` su `c4e12c0`; `main` e i tag `m0-done`, `m1-done`, `m2-done` pushati su `origin`.
  Suite su main: 740 test, 739 passati, 1 pending (stat di M3/M4, diventa errore in M6-07).
- **Prossimo passo**: M3 in corso, task in parallelo a coppie (M3-01+M3-04, poi M3-02, M3-03, M3-05..M3-09); vedere la tabella.
  consumi di `CLAUDE.md` (massimo 2 agenti, test mirati, suite completa solo dopo il merge, review sul diff, sezioni nei brief).
- **Decisioni aperte per l'utente**: Q26 (nodi di Cavatura e Lenza con i valori di Selvicoltura; default: così, rivedere con Q15).
- **Follow-up già registrati** (note in `07_TASKS.md`): divisione di `ui_style.gd` (390/400) in M3-05 o nel primo task M3
  che aggiunge costanti `UiStyle`; sfondo del pannello della maestria trasparente e toast dei livelli accumulati sopra le
  finestre (UI, M3-05 o polish); `skill_page.gd` 223 righe, ricontare in M3-05.
- **Pulizia a mano**: worktree finiti in `C:/Users/Davide/Desktop/AI/RSI-worktrees/` (branch tutti mergiati) e cartella
  vuota `rifstone-saga---melvor/` nella root.

| ID | Milestone | Titolo | Ruolo | Stato | Branch | Note |
|---|---|---|---|---|---|---|
| M0-01 | M0 | Root, project.godot, cartelle, git | REV | DONE | task/M0-01 | merge 5e82b06, docs ad92606; c6b5573; sottocartella svuotata, cartella vuota bloccata da processo (da rimuovere a mano); criterio --quit sostituito con --editor --quit |
| M0-02 | M0 | GUT e hook dei test | PORT | DONE | task/M0-02 | merge cbd80dd, docs CLAUDE.md 93cf74c; 916b7e4, 65c8eb2; 1/1 verde |
| M0-03 | M0 | Autoload e tipi comuni | CORE | DONE | task/M0-03 | merge 8d61aee; 27 test propri, suite main 38/38; tipi provvisori RefCounted/Node per GameData, SlotInfo, GameSession, OfflineSummary |
| M0-04 | M0 | Tema UI portato da RiftStone | PORT | DONE | task/M0-04 | merge d58075f; 10 test propri; primo import di checkout nuova va in crash (gestito in M0-07) |
| M0-05 | M0 | Configurazione di bilanciamento e registro delle stat | DATA | DONE | task/M0-05 | merge a3dc8ac; run_checks su main 75/75; b3991fb, 86d3dfc; 19/19 GUT; 21 stat, 66 chiavi balance |
| M0-06 | M0 | Menu segnaposto e scena principale | UI | DONE | task/M0-06 | merge 407e0ca; 2eac300, d9b2bfd; 7 test propri, 45/45 nel worktree |
| M0-07 | M0 | Script di test e di controllo | QA | DONE | task/M0-07 | merge 06a4c02; 90754d7..50dd655; run_checks verde (40 test); retry import provato con Godot finto |
| M0-08 | M0 | Integrazione di M0 | REV | DONE | main | docs 26a96ee; tag m0-done; run_checks main 82/82 |
| M1-01 | M1 | Tabella dell'esperienza | CORE | DONE | task/M1-01 | merge b206b51; eb31970, 011ccdd; 15 test, run_checks 97/97 |
| M1-02 | M1 | Sistema dei modificatori | CORE | DONE | task/M1-02 | merge 7db4a0a, docs a6b0b09; 856fc17, f1b1098, ec23a7b; 44 test, run_checks 123/123 |
| M1-03 | M1 | Classi Def e caricatore JSON | CORE | DONE | task/M1-03 | merge c1e1845, docs d9a8418; d3e60a0, 58a768b, 61e5d6a, adcdfe2; 52 test, run_checks 190/190 |
| M1-04 | M1 | Validatore, GameData, DataRegistry, fixture | CORE | DONE | task/M1-04 | merge 76941ce, docs 559d00a; 6017c56..b59a435; run_checks 368/368; validatore in 3 file (283/354/169) |
| M1-05 | M1 | Casualità, sessione, snapshot, factory dei test | CORE | DONE | task/M1-05 | merge 6dab967; _join/_tick/_PHASE_* punti di estensione protetti (05 §5.3) |
| M1-06 | M1 | Salvataggio per slot con versioni | CORE | DONE | task/M1-06 | merge 7f84ef2, docs fb30c65; 8cf567f..9f66f2c; 44 test, run_checks 126/126; scrittura 200 KB ~10-12 ms |
| M1-07 | M1 | Wallet e Bank | CORE | DONE | task/M1-07 | merge 7d91052; la Bank emette bank_changed(item_id, new_count, delta) con delta con segno; ownership estesa: TestFactory.give, SessionSnapshot.take (bank, oro); campo tipizzato + _join in game_session.gd; sposta _Participant in core/session/session_participants.gd |
| M1-08 | M1 | Skill ed esperienza | CORE | DONE | task/M1-08 | merge 718a32d; ownership estesa: GameSession.total_level(), TestFactory.set_level, SessionSnapshot.take (xp, livelli) |
| M1-09 | M1 | Maestria per oggetto e pool | CORE | DONE | task/M1-09 | merge a65ac29 |
| M1-10 | M1 | ActionRunner e raccolta | CORE | DONE | task/M1-10 | merge 9278936; stop del combattimento in start rimandato al task M4 che registra CombatEngine (annotato su M4-03) |
| M1-11 | M1 | Game: menu → slot → partita | CORE | DONE | task/M1-11 | merge e137972, docs 2a32cea; tipizzare Game.session (GameSession) e list_slots (Array[SlotInfo]); chiamare GameClock.configure da balance.json; autosave sul tempo di GameClock invece del Timer (DECISIONS_LOG); proposta aperta: limite 1-24 del nome in balance.json |
| M1-12 | M1 | Contenuto: le 12 skill e Selvicoltura | DATA | DONE | task/M1-12 | merge 9201158; Ownership estesa a areas/monsters/shop.json vuoti (DECISIONS_LOG) |
| M1-13 | M1 | Menu principale e scelta dello slot | UI | DONE | task/M1-13 | merge 8e125be; SlotTexts usa ItemTooltipLines.format_int: da passare a NumberFormat al merge di M1-14 (annotato su M1-14) |
| M1-14 | M1 | Schermata principale: sidebar, barra in alto, PageHost | UI | DONE | task/M1-14 | merge d2d316e; follow-up di M1-16 (ownership estesa, 07_TASKS): NumberFormat, costanti TOOLTIP_/WINDOW_ in UiStyle, test_game_window.gd, Modifier.SCOPE_* |
| M1-15 | M1 | Pagina skill (raccolta) e componenti base | UI | DONE | task/M1-15 | merge c634e35; follow-up di M1-13: costanti MENU_/SLOT_/DIALOG_ in UiStyle (ownership estesa, 07_TASKS) |
| M1-16 | M1 | Tooltip e GameWindow portati | PORT | DONE | task/M1-16 | merge 1981acd; Tooltips.data iniettabile (05 §2) |
| M1-17 | M1 | Toast portati | PORT | DONE | task/M1-17 | merge ecbf36b, docs aae6438; 386ea12..a6d6f0a; 18 test, run_checks 200/200; bank_changed con delta |
| M1-18 | M1 | Bank minima | UI | DONE | task/M1-18 | merge 74e3ca7; follow-up di M1-15: NumberFormat.format_seconds, eliminare il segnaposto |
| M1-19 | M1 | Test di integrazione di M1 | QA | DONE | task/M1-19 | merge dc3500e; ownership estesa: tools/run_checks.ps1 (validate_data.gd su fixture e dati veri); 621 test, 1 pending (stat M3/M4, errore in M6-07) |
| M1-20 | M1 | Integrazione di M1 | REV | DONE | main | tag m1-done su c0529c8; 676 test, 675 passati, 1 pending; prova del Giocabile 38/38 |
| M2-00 | M2 | Limite del nome in balance.json | CORE | DONE | task/M2-00 | merge 27b65a3, docs bba9872; 680 test, 679 passati, 1 pending; richiesta utente dopo M1 (DECISIONS_LOG); i worktree condividono user:// (test in parallelo instabili): nota sotto M2-05 |
| M2-01 | M2 | Nodi della maestria | CORE | DONE | task/M2-01 | merge 09ab93f, docs 92f4885; 700 test, 698 passati, 2 pending; ownership estesa a test_mastery_system.gd (rimosso il test dei segnaposto) |
| M2-02 | M2 | Contenuto: Cavatura, Lenza, nodi della raccolta | DATA | DONE | task/M2-02 | merge d72ffe9, docs 2451b40; 704 test, 703 passati, 1 pending; ownership estesa a test_main_screen_smoke.gd; nodi di Cavatura e Lenza = valori di Selvicoltura, Q26 in OPEN_QUESTIONS (default: così, rivedere con Q15) |
| M2-03 | M2 | Pannello della maestria | UI | DONE | task/M2-03 | merge ff61a7d, docs cd1bdc5; 732 test, 731 passati, 1 pending; soglia del pool in balance.json, UiStyle.MASTERY_*, MasteryButton nella scena (DECISIONS_LOG); ui_style.gd a 390 righe: divisione prevista in M3-05 |
| M2-04 | M2 | Bank completa | UI | DONE | task/M2-04 | merge 6815fd2, docs 35b03c7; 717 test, 716 passati, 1 pending; rilascio fuori dalle caselle = in fondo; caselle vuote non disegnate (facoltativo) |
| M2-05 | M2 | Test di M2 | QA | DONE | task/M2-05 | merge cd8693b, docs e77cf4d; 740 test, 739 passati, 1 pending; cartelle dei test uniche per checkout (PreRun.test_dir); ownership estesa a test_gathering_resolver.gd e test_bank.gd |
| M2-06 | M2 | Integrazione di M2 | REV | DONE | main | tag m2-done su c4e12c0; 740 test, 739 passati, 1 pending; prova del Giocabile 50/50; follow-up M3: sfondo del pannello della maestria trasparente, toast dei livelli accumulati sopra le finestre |
| M3-01 | M3 | Ricette dell'artigianato | CORE | DONE | task/M3-01 | merge d94b5f2, fix b8d95b2 (smoke skill page: missing_inputs), docs be66510, 7375220, 2feac0d; 762 test, 761 passati, 1 pending; ownership estesa (da M1-09): mastery_bonuses di test_craft nelle fixture + caso F-11 artigianato in test_mastery_system.gd |
| M3-02 | M3 | Shop (porting) | PORT | DONE | task/M3-02 | merge c16af12, docs ee819ae; a5c4a37 rimandato (test condizionale, F-17 non dallo shop, save senza limite), corretto in 6ce2020; 772 test, 771 passati, 1 pending |
| M3-10 | M3 | Togliere bank.max_purchasable (doppione di max_purchases di bank_slot) | CORE | TODO | | proposta Reviewer accettata dall'Orchestratore: unica definizione in shop.json; task da scrivere in 07_TASKS (balance.json, data_validator.gd, test_config_files.gd; docs 01 §8, 04) |
| M3-03 | M3 | Equipaggiamento e attrezzi | CORE | IN_PROGRESS | task/M3-03 | |
| M3-04 | M3 | Contenuto: Forgiatura, Focolare, Intaglio, shop | DATA | DONE | task/M3-04 | merge 0af98c4, fix eb72044 (smoke sidebar), docs ff02bc6, 2f67367; 746 test, 745 passati, 1 pending; ownership estesa a test_crafting_data.gd; impugnature restano (DECISIONS_LOG) |
| M3-05 | M3 | Pagina skill: variante artigianato | UI | IN_PROGRESS | task/M3-05 | |
| M3-06 | M3 | Shop e vendita | UI | TODO | | |
| M3-07 | M3 | Pagina equipaggiamento | UI | TODO | | |
| M3-08 | M3 | Test di M3 | QA | TODO | | |
| M3-09 | M3 | Integrazione di M3 | REV | TODO | | |
| M4-01 | M4 | Formule di combattimento | COMBAT | TODO | | |
| M4-02 | M4 | Statistiche, razioni da campo, borsa del bottino | COMBAT | TODO | | |
| M4-03 | M4 | Motore del combattimento | COMBAT | TODO | | ownership estesa (da M1-10): riga stop del combattimento in action_runner.gd start; chiave finta combat in test_game_session.gd |
| M4-04 | M4 | Contenuto del combattimento | DATA | TODO | | |
| M4-05 | M4 | Pagina del combattimento | UI | TODO | | |
| M4-06 | M4 | Test di M4 | QA | TODO | | |
| M4-07 | M4 | Integrazione di M4 | REV | TODO | | |
| M5-01 | M5 | Altare del Rift | CORE | TODO | | |
| M5-02 | M5 | Contenuto della Legatura del Rift e nodi dell'artigianato | DATA | TODO | | |
| M5-03 | M5 | Pagina dell'Altare | UI | TODO | | |
| M5-04 | M5 | Test di M5 | QA | TODO | | |
| M5-05 | M5 | Integrazione di M5 | REV | TODO | | |
| M6-01 | M6 | Simulazione offline | CORE | TODO | | ownership aggiunta: event_bus.gd (solo firma offline_completed: OfflineSummary) e riga offline_completed di test_event_bus.gd; tipizzare Game.last_offline_summary; GameSession.advance aumenta play_time_ms: decidere se l offline lo conta (GDD) |
| M6-02 | M6 | Schermate dell'offline | UI | TODO | | |
| M6-03 | M6 | Impostazioni (porting) | PORT | TODO | | |
| M6-04 | M6 | Sistema dei suggerimenti | CORE | TODO | | da review M1-04: GameData._clear() non azzera _balance/stats; validatore: hp_skill/defence_skill di categoria combat, struttura di auto_eat_tiers e rift.sockets |
| M6-05 | M6 | Contenuto dei suggerimenti | DATA | TODO | | |
| M6-06 | M6 | Feedback visivo e carta dei suggerimenti | UI | TODO | | |
| M6-07 | M6 | Regressione, prestazioni, foto della UI | QA | TODO | | |
| M6-08 | M6 | Rilascio dell'MVP | REV | TODO | | |
| M7-01 | M7 | Sistema delle Fratture | CORE | TODO | | |
| M7-02 | M7 | Dati delle Fratture | DATA | TODO | | |
| M7-03 | M7 | Indicatore delle Fratture | UI | TODO | | |
| M7-04 | M7 | Test di M7 | QA | TODO | | |
| M7-05 | M7 | Integrazione di M7 | REV | TODO | | |
| M8-01 | M8 | Corsia secondaria | CORE | TODO | | |
| M8-02 | M8 | Dati di M8 | DATA | TODO | | |
| M8-03 | M8 | UI a due corsie | UI | TODO | | |
| M8-04 | M8 | Test di M8 | QA | TODO | | |
| M8-05 | M8 | Integrazione di M8 | REV | TODO | | |
