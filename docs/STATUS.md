# Stato dei task

Aggiornato dall'Orchestratore (unico che modifica questo file). Stati: TODO / IN_PROGRESS / REVIEW / DONE / BLOCKED.
Se la sessione si interrompe, si riparte da qui.

## Ripartenza (aggiornata il 2026-11-06, fine M6)
- **Stato**: **M6 completata**, tag `m6-done` sul commit docs di M6-07 (`main`). Merge di M6: M6-00a `03160e3`, M6-01
  `9d85382`, M6-00b `44ddcdb`, M6-00c `be942ee`, M6-02 `8c4690d`, M6-03 `d84476a`, M6-04 `58edace`, M6-05 `86bc4e1`,
  M6-06 (task/M6-06, c2220a1). Suite e Prova del Giocabile: vedi riga M6-07. M5 era chiusa col tag `m5-done`.
- **Sessione M7 iniziata (OK dell'utente dato)**. Q44 decisa: valgono i valori attuali di `rift_blade.json`, da ritarare con `tools/sim_combat.gd` a fine M7 (nota su M7-07).
- **Prove manuali consigliate (M7-00)**: impilamento dei testi volanti con piu colpi ravvicinati (danno, Mancato, Parato); piu carte nemici in fila che riempiono la zona senza tagli; etichette degli attrezzi con le skill reali nella bambola; tratti e abilita come carte con un solo avviso durante l'incontro; statistiche finali nell'Equipaggiamento; layout a 1600x900 e 1280x720.
- **Pulizia a mano**: rimuovere `C:\Users\Davide\Desktop\AI\wt-M7-03-04` (Permission denied, probabile Godot headless orfano; poi `git worktree prune`).
- **Prossimo passo**: M7-01..M7-06 DONE (M7-06 merge `2782b9d`). Ora **M7-07** (QA; include ritaratura Q44+Q45 con sim_combat), poi **M7-08** (REV, fine milestone). Ogni task che aggiunge una stat chiude la sua formula in `CLOSED_FORMULAS` di `tests/data/test_stat_registry_coverage.gd`.
- **Prove manuali consigliate (M6-05)**: pagina Personaggio, pannello Tratti e Abilità: scegliere o svuotare uno slot, voci bloccate per livello o già in uso, slot chiusi, selettori disabilitati durante un incontro; in combattimento lampo della carta o del tratto, righe nel registro, stato "attiva N s" dei buff; layout a 1600x900 e 1280x720. Regole dei consumi di `CLAUDE.md`.
- **Prove manuali consigliate (M6-00c)**: avviare un combattimento e verificare colonne giocatore/nemici, bersaglio e fila, numeri di danno (colpo forte), bottino e rendimento "ultima ora", registro, equipaggiamento con tooltip, sezioni Abilità/Tratti vuote; layout a 1600x900 e 1280x720.
- **Decisioni aperte per l'utente** (`OPEN_QUESTIONS.md`, finché non risponde valgono i default): Q26 (nodi di Cavatura
  e Lenza); Q27-Q40 (default); Q41 (XP dei mostri 4 × PV, confermato da M5-06; tempi stimati fino al 99: Pianure circa
  10-12 min, Bosco 25-45 min, Miniere 2,5-3,5 h, Soglia 36-52 h; decide l'utente); Q42 (testi del tooltip dei pezzi
  senza skill di combattimento, default applicato in M4-08); Q43 (livello del criterio di §8.5: default livello medio
  dei mostri, criterio soddisfatto; al livello d'ingresso Miniere e Soglia restano sotto 60 uccisioni/ora). Confermati
  come provvisori: affissi (`02_FORMULAS.md` §8.9), F-83, F-86.
- **Decisioni prese in M5** (DECISIONS_LOG e 05 §5.10): comportamenti del motore fissati da M5-03; decisioni (a)-(d) di
  M5-04 sul contenuto; M5-07: in `idle` `area` è `""` (`area_id()`, `get_state()`, save), le 9 stat di F-20…F-22 e
  F-25…F-27 hanno come test `test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats` (effetto
  stat → modificatori → `CombatantStats`, anche nella tabella del registro di 02).
- **Prove manuali consigliate (M6-00b)**: trascinare un pezzo sui 12 slot e verificare che si illuminino solo i compatibili (spada a una mano anche sulla seconda mano); tasto destro (equipaggia, seconda mano, Rimuovi); errore con combattimento in corso (motivo mostrato, nessun cambio); tooltip di confronto; layout a 1600x900 e 1280x720; riga cibo.
- **Follow-up M6-00b**: `neck`/`ring` senza pezzi nei dati (slot vuoti); riga cibo "Togli" provvisoria fino a M6-00c; etichette slot "In mano"/"Seconda mano" da rivedere; `EquipTargets` rilegge le regole di `Equipment` solo per illuminare (l'autorita resta `equip`): `can_equip` su `Equipment` non serve ora, rivalutare a M7.
- **Follow-up registrati** (note in `07_TASKS.md`): M6-01 `GameData.has_area`/`has_monster`; **M6-02** save/load del
  motore in un file a parte **prima** degli agganci (`combat_engine.gd` a **399** righe) e normalizzazione del save in
  `idle` (`player_hp`, `player_timer_ms`, `hand`, `between_ms` a 0: oggi save → load → save di un motore fermo dopo
  stop/morte non è identico; nota "da M5-07"); M7-01 caso `+N` di `ItemRoller.instance_modifiers` ed `Equipment` che
  ascolta `armory_changed(uid, &"updated")`; M7-03 stub `ItemRoller.drop_chances`; M7-06 smoke con `upgrade > 0`; M9-06
  toast dei livelli sopra le finestre (N9); inoltro `UiStyle.build_theme()` → `UiThemeBuilder.build()` (nota "da
  M4-08"); filtro automatico dell'Armeria per slot in M7-02.
- **Pending aperti**: nessuno.
- **Prova manuale consigliata** (non verificabile in headless): (1) aspetto della griglia dell'Armeria e colori di
  rarità; (2) layout a 1600×900 e 1280×720; (3) tooltip sulle celle dell'Armeria; (4) sfondo opaco di `WindowPanel`
  (maestria, menu, selezione slot); (5) sezione Assetto della pagina Equipaggiamento; (6) flusso forgia → Armeria →
  equip "In mano" / "Seconda mano" → assetto "Due spade"; (7) aspetto delle pagine Shop ed Equipaggiamento, vendita e
  trascinamento con clic reali; (8) lo slot 1 vero dell'utente (save v1 di M3) appare "versione non supportata" nel
  menu e "Nuova partita" lo sovrascrive solo su richiesta; (9) pagina del Combattimento: aspetto e layout a 1280×720 e
  1600×900 con 4 o più nemici, numeri dei colpi e loro dissolvenza, passaggio tra i gruppi (`between`), messaggio di
  sconfitta (e sua scomparsa al nuovo avvio), valori F-70 nella pagina Personaggio; (10) combattimento giocato a mano:
  avvio da un pulsante d'area, "Ferma", "Mangia" col cibo scelto, "Raccogli tutto" del bottino, parata visibile con lo
  scudo (colpo a 0), cambio di area durante un incontro, avvio di un'azione di raccolta che ferma il combattimento;
  (11) un salvataggio durante un incontro e il ricaricamento dal menu (stesso incontro, stessi PV).
- **Pulizia a mano**: cartella `C:/Users/Davide/Desktop/AI/RSI-worktrees/M3-03` (worktree già staccato da git, file
  bloccati da un processo Godot); cartella vuota `rifstone-saga---melvor/` nella root; cartella di prova rimasta da M4
  `%APPDATA%/Godot/app_userdata/RiftStone Saga- Idle/m4_config_tmp/`. I worktree di M5 sono rimossi.
- **Fuori da `docs/`**: FATTO (2026-11-06, OK diretto dell'utente): `CLAUDE.md` § Stato aggiornato a "M5 e M6 completate,
  prossima milestone M7 Bottino".

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
| M3-10 | M3 | Togliere bank.max_purchasable (doppione di max_purchases di bank_slot) | CORE | DONE | task/M3-10 | merge 6a79296, docs 2e28f3d, 7f05e70; 825 test, 824 passati, 1 pending; ownership estesa al conteggio di test_data_validator.gd (58 chiavi) |
| M3-03 | M3 | Equipaggiamento e attrezzi | CORE | DONE | task/M3-03 | merge 01ee4fc, docs e457b88, f262cb7; 796 test, 795 passati, 1 pending; ownership estesa a fixture equipment.json e test_game_data.gd (conteggio); worktree non rimosso (file bloccati, forse da un GUT appeso) |
| M3-04 | M3 | Contenuto: Forgiatura, Focolare, Intaglio, shop | DATA | DONE | task/M3-04 | merge 0af98c4, fix eb72044 (smoke sidebar), docs ff02bc6, 2f67367; 746 test, 745 passati, 1 pending; ownership estesa a test_crafting_data.gd; impugnature restano (DECISIONS_LOG) |
| M3-05 | M3 | Pagina skill: variante artigianato | UI | DONE | task/M3-05 | merge 52835f5, docs 9e448b0, 2e7494e; b023268 rimandato (assert sempre vero, numero nudo), corretto in ff75f6b; 800 test, 799 passati, 1 pending; build_theme non spostato (nessuna costante UiStyle nuova) |
| M3-06 | M3 | Shop e vendita | UI | DONE | task/M3-06 | merge 444d051, docs c4cc394, 5d08b00; 1a56aa5 rimandato (rotta shop, oro scritto a mano), corretto in a267a0a; 813 test, 812 passati, 1 pending; ownership estesa a ROUTES di page_host.gd e test_main_screen_smoke.gd |
| M3-07 | M3 | Pagina equipaggiamento | UI | DONE | task/M3-07 | merge 0063967, docs b7c972d, 273bd24; ba9cd4d rimandato (nomi di skill scritti a mano, riepilogo senza attrezzi), corretto in 04a8f07; 825 test, 824 passati, 1 pending; ownership estesa a ROUTES e test_main_screen_smoke.gd |
| M3-08 | M3 | Test di M3 | QA | DONE | task/M3-08 | merge b29e214, docs 245cbd3; 836 test, 834 passati, 2 pending (stat M4; bug from_save due mani + offhand, chiuso da M3-11) |
| M3-11 | M3 | from_save: arma a due mani e offhand insieme | CORE | DONE | task/M3-11 | merge 0159747; 3538bb7; bug trovato da M3-08; regola in 05 §5.9 (245cbd3): offhand scartato con Log.warn |
| M3-09 | M3 | Integrazione di M3 | REV | DONE | main | docs 5eb8222, ca18ee6; tag m3-done su ca18ee6; 837 test, 836 passati, 1 pending; prova del Giocabile 10/10 |
| R-00 | M4 | Riforma dei documenti (visione v2) | REV | DONE | main | solo docs; commit dell'Orchestratore; stop per l'OK dell'utente prima di M4-01 |
| M4-01 | M4 | Schema e validatore della riforma | CORE | DONE | task/M4-01 | merge congiunto 16e6306 (con M4-02); 83f36fc, 4c1626c, df909ac, 3da8494, b6d4e51, e2a2ba3 |
| M4-02 | M4 | Contenuto della riforma | DATA | DONE | task/M4-02 | merge 16e6306; 31cbcbf, 8855c5a, e3c1afa; correzioni del Reviewer df9bc0d; run_checks 925 test, 903 passati, 22 pending |
| M4-03 | M4 | Personaggio e salvataggio v2 | CORE | DONE | task/M4-03 | merge f6ed43c; 765664e, merge di main ef4bb5d; 20 test nuovi; ownership estesa: 2 righe di `test_skills_system.gd` (snapshot e `total_level`); run_checks 959 test, 937 passati, 22 pending, 0 falliti; worktree non rimosso |
| M4-04 | M4 | ItemRoller e istanze | CORE | DONE | task/M4-04 | merge ef00713; 78d3e1a; 14 test propri; run_checks 939 test, 917 passati, 22 pending, 0 falliti; worktree non rimosso |
| M4-05 | M4 | Armeria, bank e shop | CORE | DONE | task/M4-05 | merge a85cb8c; 789ff61, correzioni del Reviewer bb59448 (`set_worn` con `quiet`, una sola costante delle categorie, pending doppio); ownership estesa: solo righe `pending` + `return` in 5 file di test (regola comune di M4); run_checks 982 test, 946 passati, 36 pending, 0 falliti; worktree non rimosso |
| M4-06 | M4 | Equipaggiamento con uid e assetti | CORE | DONE | task/M4-06 | merge 558447b; 437037c; casi non fissati da §5.9 accettati e documentati in 05 §5.9; ownership estesa (regola comune di M4): `bank_page.gd`/`equipment_page.gd` solo chiamanti e connessioni `food_changed`/`equipment_changed(int)`, `test_equipment_save.gd` nuovo (divisione del test), `test_crafting_chain.gd` segnaposto `equip(0)`; run_checks 990 test, 976 passati, 14 pending, 0 falliti; note per M4-07, M4-08, M4-10, M7-01; worktree non rimosso |
| M4-07 | M4 | Artigianato verso l'Armeria | CORE | DONE | task/M4-07 | merge 13c65e2; c60cb6c, test aggiunti dal Reviewer e22c705 (maestria alta → più rari a seme fisso, ricetta mista con Armeria piena); maestria letta prima di `add_for_action` (05 §5.8); pending di `test_crafting_chain.gd` chiusi; run_checks 1005 test, 997 passati, 8 pending, 0 falliti; note per M4-08 e M4-10; worktree non rimosso |
| M4-08 | M4 | Pagina dell'Armeria ed equipaggiamento | UI | DONE | task/M4-08 | merge 1464d72; e14561d, 90cc24e, ec9215b, 0052fb5, 68e8dd5, correzione del Reviewer 9a129e0 (tolti `ArmoryTexts.kind_name`/`KIND_NAMES` inutilizzati); API UI nuove registrate in 05 §7 (ArmoryItemPanel, ArmoryCell, ArmoryTexts, UiStyle.rarity_color/build_theme, UiThemeBuilder, ItemTooltipLines Q42); 7 pending chiusi; tooltip deterministico (frame di processo); run_checks 1026 test, 1025 passati, 1 pending, 0 falliti; note per M4-10 e M7-06; worktree non rimosso |
| M4-09 | M4 | Pagina del personaggio, sidebar e shop | UI | DONE | task/M4-09 | merge 71fafa6; 0755b3d, main riunito nel branch 1a81dbd, correzione del Reviewer ce4430f (`Equipment.setup()` tipizzato al posto di `has_method`, `equipment_changed(slot, uid)`, test dell'assetto evidenziato); sfondo della maestria con override locale accettato in via provvisoria (spostamento nel tema su M4-08); categoria `combat` della fixture dello shop su M4-10; run_checks 997 test, 986 passati, 11 pending, 0 falliti; worktree non rimosso |
| M4-10 | M4 | Test di M4 | QA | DONE | task/M4-10 | merge 213678a; 46c4c50, eb2a3e2, 082d1c8, 02b14b1, bd182bc; test nuovi `test_reform_flow` (7), `test_save_v2` (11), divisi `test_item_conservation_equipment`, `test_equipment_setups`; `test_buy_log` e bank piena nello shop; voci `combat` della fixture spostate in `bank`; `FORMULA_MILESTONES` del combattimento → M5; decisioni (a)-(d) in DECISIONS_LOG (scope di `item_rarity_pct` e maestria 1 scritti in F-83, `.uid` committati, inoltro `build_theme` lasciato); run_checks 1046 test, 1045 passati, 1 pending, 0 falliti |
| M4-11 | M4 | Integrazione di M4 | REV | DONE | main | tag m4-done sul commit docs di M4-11; run_checks 1046 test, 1045 passati, 1 pending, 0 falliti; prova del Giocabile 8/8 (test + avvio headless); Lezioni checklist ok; worktree M4-10 rimosso; main e m4-done pushati |
| M5-00 | M5 | Correzioni della prova visiva di M4 (UI) | UI | DONE | task/M5-00 | merge 09364ba; fdfb49a, 7e0f186 (correzione del Reviewer: `ItemTooltipLines.COMBAT_TEXT` unica, riusata da ShopPage e Sidebar); richiesta dell'utente dopo M4: sorgente "Assetto: <nome>", lista degli assetti con quello in uso evidenziato, categoria "Combattimento" e Casella dell'Armeria nella categoria bank, modificatori della stessa stat sommati, nome nel colore della rarità, contatore "(+N indossati)"; firme in 05 §7; decisioni in DECISIONS_LOG; run_checks 1061 test, 1060 passati, 1 pending, 0 falliti |
| M5-01 | M5 | Formule di combattimento | COMBAT | DONE | task/M5-01 | merge 447224b; f1da183; `CombatMath` (F-20…F-27, F-73, limite di F-75, parte pura di F-70), `test_combat_math.gd` (14 test, tutti gli esempi); caso `AR + ER ≤ 0` scritto in F-23; note "da M5-01" per M5-02/M5-03 in 07; decisioni in DECISIONS_LOG; run_checks 1075 test, 1074 passati, 1 pending, 0 falliti |
| M5-02 | M5 | Statistiche per mano, razioni da campo, borsa del bottino | COMBAT | DONE | task/M5-02 | merge 6c11beb; a94638f, 6c156ef, f04d7cf (correzione del Reviewer: bonus esatti dell'esempio F-74 nel test); `total_without`, `CombatantStats`, `AutoEat`, `LootBag` con i test; esempio di F-29 riscritto (20 e +80% → 36), F-74 con AR dell'assetto; comportamenti e ordine dei tiri in 05 §5.10; note "da M5-02" per M5-03; run_checks 1103 test, 1102 passati, 1 pending, 0 falliti |
| M5-03 | M5 | Motore a eventi, incontri e gruppi | COMBAT | DONE | task/M5-03 | merge a3b01b1; c9cdf0b, eae2cc8 (correzione del Reviewer: stop del combattimento solo dalla corsia main (N1), test dell'esempio di F-31 "tiro 10, +25% → 12"); `CombatEngine`, `Encounter`, segnali di M5, registrazione nella sessione, contatori dello snapshot, N1-N2; comportamenti in 05 §5.10; note "da M5-03" per M5-05/06/07 e M6-01/02; run_checks 1131 test, 1130 passati, 1 pending, 0 falliti |
| M5-04 | M5 | Contenuto: 4 aree, 12 mostri, gruppi | DATA | DONE | task/M5-04 | merge 8f40e08; be30f80; 4 aree e 12 mostri (tabella §8.5), gruppi, 16 materiali di bottino, icone `.svg` segnaposto, `test_combat_data.gd` (9 test); decisioni (a)-(d) in DECISIONS_LOG; note per M5-03/M5-06 in `07_TASKS.md` §M5; run_checks 1055 test, 1054 passati, 1 pending, 0 falliti |
| M5-05 | M5 | Pagina del combattimento | UI | DONE | task/M5-05 | merge 2ff18ec; 3b20cce, 6e365fc, 7c344a4 (merge di main), 1fbf299 (correzione del Reviewer: nomi dei valori F-70 da `stats.json` con `CombatTexts.stat_line`, messaggio di sconfitta tolto a ogni `combat_started`, test); `CombatPage`, `CombatantCard`, `CombatTexts`, rotta `combat`, valori F-70 nella CharacterPage; firme in 05 §7; run_checks 1153 test, 1152 passati, 1 pending, 0 falliti |
| M5-06 | M5 | Strumento di bilanciamento sim_combat | COMBAT | DONE | task/M5-06 | merge ece8639; 3fc0471, e6d8530 (correzione del Reviewer: sessione liberata in `measure`, niente orfani), 766e66e (correzione del Reviewer dopo il merge: `print_rich` al posto di `print`, regola di `check_forbidden_refs`); `tools/sim_combat.gd` sul `CombatEngine` vero, nessun save, scenario dai dati; criterio di §8.5 soddisfatto al livello medio dei mostri (0 morti, 213/115/80/62 uccisioni/ora), sotto 60 in Miniere e Soglia al livello d'ingresso (Q43); XP 4 × PV invariata (Q41); run_checks 1142 test, 1141 passati, 1 pending, 0 falliti (prima esecuzione rossa solo su `check_forbidden_refs`, corretta e ricontrollata) |
| M5-07 | M5 | Test di M5 | QA | DONE | task/M5-07 | merge 60326bc; d8b43a2, 49d05a2, 98e44b6, 25e9b77, 72ab086 (correzione del Reviewer BUG-M5-07-1: i 9 campi `test` delle stat di F-20…F-22/F-25…F-27 in `stats.json` puntano a `test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats`, `BROKEN_REFS` e pending tolti), 0564d90 (correzione del Reviewer: `stop` azzera l'area, contratto `idle` → `area` `""` in 05 §5.10; normalizzazione del save in `idle` a M6-02, nota "da M5-07"); F-34 18,58 s per uccisione (seme 34), `test_combat_flow.gd` 10 test, `CLOSED_FORMULAS` di M5 e `"10.6"`; run_checks 1168 test, 1168 passati, 0 pending, 0 falliti |
| M5-08 | M5 | Integrazione di M5 | REV | DONE | main | tag m5-done sul commit docs di M5-08; run_checks 1168 test, 1168 passati, 0 pending, 0 falliti; prova del Giocabile 6/6 (test + prova headless dei tre assetti × quattro aree + avvio headless del menu); Lezioni checklist ok; worktree M5-07 rimosso; main e m5-done pushati |
| M6-00a | M6 | Icone di mostri, slot e classe | DATA | DONE | task/M6-00a | merge 03160e3 (37c1920); 12 icone slot, 1 classe, `icon` della classe e `sprite` riservato nel validatore; `class_def.gd` esteso (solo `icon`) |
| M6-01 | M6 | Def, validatore e Loadout | CORE | DONE | task/M6-01 | merge 9d85382; commit 2480863; TraitDef/TraitEffectDef/AbilityDef, DataValidatorTraits, Loadout, GameData.has_area/has_monster, traits_changed; intervalli F-81 in 04 §14 |
| M6-02 | M6 | Agganci del motore e 8 tipi di effetto | COMBAT | DONE | task/M6-02 | merge 8c4690d; 06f1b4b; CombatSave, KillRewards, EffectSet + 8 effetti, save idle normalizzato; decisioni in DECISIONS_LOG |
| M6-03 | M6 | Abilità attive | COMBAT | DONE | task/M6-03 | merge d84476a; commit 9f9b960; AbilityRunner, CombatView, `ability_used`, save `abilities`/`buffs` in idle {}; precisazioni in F-79/F-80 |
| M6-04 | M6 | Contenuto: 12 tratti e 6 abilità | DATA | DONE | 58edace | valori provvisori in Q44 |
| M6-05 | M6 | Scelta di tratti e abilità nella UI | UI | DONE | task/M6-05 | merge 86bc4e1; commit 8a80908; LoadoutPanel nella pagina Personaggio (solo comandi di Loadout), lampo e registro su ability_used/trait_triggered; follow-up: FEEDBACK_FLASH_SEC in CombatTexts (valutare UiStyle); "Gruppo n." e regola del bersaglio non in get_state(), accettato |
| M6-06 | M6 | Test di M6 | QA | DONE | task/M6-06 | merge di c2220a1; `test_build_flow.gd` (13 test), copertura stat: dati della classe con stat registrate, 8 tipi di effetto con il loro file di test |
| M6-07 | M6 | Integrazione di M6 | REV | DONE | main | tag m6-done sul commit docs di M6-07; copertura stat: pending diventa errore per le formule MVP (solo F-50/F-51 post-MVP restano pending); Prova del Giocabile 2/2 (test); run_checks 1317 test, 1317 passati, 0 pending, 0 falliti; validate_data verde; file <= 400 righe; riferimenti vietati assenti (1033 file); push di main e m6-done a fine milestone |
| M7-00 | M7 | Correzioni dalla prova visiva di M6 | UI | DONE | 560c4ac | testi volanti impilati, carte nemici a larghezza piena, carte tratti/abilità, plurali, statistiche finali |
| M7-01 | M7 | Raffinazione | CORE | DONE | task/M7-01-02 | merge ae5abb1 (e3b24ef); F-86 provvisoria; fixture materials.json estesa (lingotti di prova) |
| M7-02 | M7 | Smantellamento e filtro automatico | CORE | DONE | task/M7-01-02 | merge ae5abb1 (504c097); F-88 provvisoria; filtro nel save armory (additivo), senza segnale; note M7-05 (`warding_seal`) e M9-01 (bank_rejected); run_checks 1373/1373 |
| M7-03 | M7 | Drop di equipaggiamento con rarità | COMBAT | DONE | task/M7-03-04 | merge 09ddd00 (2c21f6d); F-84, `ilvl` = max dei tre livelli (F-85), drop di pezzi ammessi dal validatore |
| M7-04 | M7 | Pietre del Rift | COMBAT | DONE | task/M7-03-04 | merge 09ddd00 (2b15a76); `RiftStone`, `RiftStoneDef`, `DataValidatorStones`, `combat.stone` nel save, segnale `rift_stone_appeared`; `rift_stones.json` ancora vuoto (M7-05) |
| M7-05 | M7 | Contenuto: gioielli, drop, Pietre, Sigillo | DATA | DONE | task/M7-05 | merge bf21966 (3d34b8a); 8 anelli + 8 amuleti, `warding_seal`, 4 Pietre, drop nei mostri; `validate_refs` controlla `seal_item`; valori provvisori in Q45 (ritaratura in M7-07) |
| M7-06 | M7 | Armeria completa e Pietra nella UI | UI | DONE | task/M7-06 | merge 2782b9d (cf67057); riquadro Raffina (RefineBox/RefineTexts, costi e probabilità da Upgrade), Smantella con conferma (SalvageBox), filtro per slot (FilterPanel), carta Pietra (EnemyView, GameData.rift_stone); equipment_page.gd a 400 righe: nessun margine, spostare codice prima di aggiungerne; item_upgraded senza livello precedente (UI: "è ora a +N"), `previous_level` in 05 non necessario per MVP; prove manuali: riquadro Raffina con/senza Sigillo, Smantella con conferma, filtro per slot, carta Pietra viola con barra impulso, layout 1600x900 e 1280x720 del filtro; run_checks 1419/1419 |
| M7-07 | M7 | Test di M7 | QA | TODO | | |
| M7-08 | M7 | Integrazione di M7 | REV | TODO | | tag m7-done |
| M8-01 | M8 | Altare del Rift | CORE | TODO | | nota N3 |
| M8-02 | M8 | Contenuto: Legatura e nodi dell'artigianato | DATA | TODO | | nota N4 |
| M8-03 | M8 | Castoni, pietre e valute del Rift | CORE | TODO | | |
| M8-04 | M8 | Contenuto: pietre e valute | DATA | TODO | | |
| M8-05 | M8 | Pagine dell'Altare e dei castoni | UI | TODO | | |
| M8-06 | M8 | Test di M8 | QA | TODO | | |
| M8-07 | M8 | Integrazione di M8 | REV | TODO | | tag m8-done |
| M9-01 | M9 | Simulazione offline | CORE | TODO | | note N5-N6 |
| M9-02 | M9 | Schermate dell'offline | UI | TODO | | |
| M9-03 | M9 | Impostazioni (porting) | PORT | TODO | | nota N7 |
| M9-04 | M9 | Sistema dei suggerimenti | CORE | TODO | | nota N8 |
| M9-05 | M9 | Contenuto dei suggerimenti | DATA | TODO | | |
| M9-06 | M9 | Feedback visivo e carta dei suggerimenti | UI | TODO | | nota N9 |
| M9-07 | M9 | Regressione, prestazioni, foto della UI | QA | TODO | | nota N10 |
| M9-08 | M9 | Rilascio dell'MVP | REV | TODO | | tag m9-mvp, m9-done |
