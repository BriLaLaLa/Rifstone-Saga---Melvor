# Stato dei task

Aggiornato dall'Orchestratore (unico che modifica questo file). Stati: TODO / IN_PROGRESS / REVIEW / DONE / BLOCKED.
Se la sessione si interrompe, si riparte da qui.

## Ripartenza (aggiornata il 2026-11-03)
- **Stato**: M4 in corso. **M4-01 + M4-02 DONE**, merge congiunto `16e6306` su `main` (correzioni del Reviewer sul
  branch in `df9bc0d`). **M4-04 DONE**, merge `ef00713`. Suite (run_checks dopo M4-04): 939 test, 917 passati,
  22 pending, 0 falliti; validate_data verde su fixture e dati veri. M4-03 in corso. M3 completata, tag `m3-done` su `ca18ee6`; `main` e i tag `m0-done`…`m3-done` pushati su `origin`
  (il push di M4 si fa a fine milestone). Visione v2 approvata (D1-D6), R-00 fatto.
- **Prossimo passo**: chiudere **M4-03** (Personaggio e salvataggio v2), poi M4-05 (note "da M4-04"), M4-06,
  M4-07 ∥ M4-09, M4-08, M4-10, M4-11, con le regole dei consumi di `CLAUDE.md` (massimo 2 agenti, test mirati, suite
  completa solo dopo il merge, review sul diff, sezioni nei brief). I worktree `RSI-worktrees/M4-01` e `M4-02` si
  possono rimuovere.
- **Pending aperti** (21 nuovi + 1 vecchio; ognuno lo chiude il task indicato, note in `07_TASKS.md`):
  M4-06 `test_equipment.gd` (15) e `test_item_conservation.gd` (2); M4-08 `test_bank_item_panel_smoke.gd` (1) e
  `test_tooltip.gd::test_show_item_weapon_lines` (1); M4-09 `test_main_screen_smoke.gd` (2); vecchio:
  `test_stat_registry_coverage.gd` (stat del combattimento, errore da M6-07).
- **Follow-up di M4-04** (note "da M4-04" in `07_TASKS.md`): M4-05 `from_dict` non controlla `uid`/unicità/castoni;
  M4-07 rarità tirata dal chiamante e scope `skill:forestry` degli attrezzi nelle fixture; M7-01 caso `+N` di
  `instance_modifiers`; M7-03 stub `drop_chances`.
- **Follow-up di M4-02** (note "da M4-02" in `07_TASKS.md`): M4-03 `total_level` in `test_skills_system.gd` e requisiti
  misti con `character`; M4-05 requisito `character` in `test_shop.gd`; M4-06 pending e costante `BOW`; M4-07
  `test_crafting_chain.gd` con gli attrezzi nell'Armeria; M4-08 pending, ownership di `item_tooltip_lines.gd` (Q42);
  M4-09 pending della sidebar; M4-10 riga lunga in `test_config_files.gd`.
- **Da aggiornare fuori da `docs/`** (non nell'ownership di R-00): `.claude/agents/reviewer.md` cita M6-08 per il rilascio
  (ora M9-08); eventuali altri file agente che citano le vecchie M4-M8.
- **Decisioni aperte per l'utente**: Q26 (nodi di Cavatura e Lenza); Q27-Q40 (valgono i default); Q41 (XP dei mostri, da
  tarare in M5-06); **Q42 nuova** (testi del tooltip dei pezzi senza skill di combattimento, default in OPEN_QUESTIONS).
  Confermati come provvisori: affissi (`02_FORMULAS.md` §8.9), F-83, F-86.
- **Decisioni prese in M4-01/M4-02** (DECISIONS_LOG): `dual_swords` `accuracy_pct −10` (Q39); `formula` di una stat con
  più formule = la prima; `block_chance` nei dati da M4, effetto in M5; ponte `m4_config_bridge.gd` eliminato; test fuori
  ownership adeguati dal Reviewer e pending dei task successivi.
- **Follow-up già registrati** (note in `07_TASKS.md`): su M4-08 spostamento di `build_theme` da `ui_style.gd` (390/400)
  e pulizia del test `tool_forestry`; su M4-09 sfondo trasparente del pannello della maestria; su M5-03
  `_combat_active()` tipizzato in `equipment.gd` (N2); su M9-06 toast dei livelli sopra le finestre (N9). Il debito di
  stile di `test_crafting_data.gd` è chiuso (M4-02).
- **Prova manuale consigliata** (non verificabile in headless): aspetto delle pagine Shop ed Equipaggiamento, vendita e
  trascinamento con clic reali.
- **Pulizia a mano**: cartella `C:/Users/Davide/Desktop/AI/RSI-worktrees/M3-03` (worktree già staccato da git, file
  bloccati da un processo Godot rimasto aperto) e cartella vuota `rifstone-saga---melvor/` nella root.

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
| M4-03 | M4 | Personaggio e salvataggio v2 | CORE | TODO | | parallelo con M4-04 |
| M4-04 | M4 | ItemRoller e istanze | CORE | DONE | task/M4-04 | merge ef00713; 78d3e1a; 14 test propri; run_checks 939 test, 917 passati, 22 pending, 0 falliti; worktree non rimosso |
| M4-05 | M4 | Armeria, bank e shop | CORE | TODO | | |
| M4-06 | M4 | Equipaggiamento con uid e assetti | CORE | TODO | | |
| M4-07 | M4 | Artigianato verso l'Armeria | CORE | TODO | | |
| M4-08 | M4 | Pagina dell'Armeria ed equipaggiamento | UI | TODO | | dopo M4-09 (page_host.gd); spostamento build_theme |
| M4-09 | M4 | Pagina del personaggio, sidebar e shop | UI | TODO | | sfondo del pannello della maestria |
| M4-10 | M4 | Test di M4 | QA | TODO | | |
| M4-11 | M4 | Integrazione di M4 | REV | TODO | | tag m4-done |
| M5-01 | M5 | Formule di combattimento | COMBAT | TODO | | |
| M5-02 | M5 | Statistiche per mano, razioni da campo, borsa del bottino | COMBAT | TODO | | |
| M5-03 | M5 | Motore a eventi, incontri e gruppi | COMBAT | TODO | | note ereditate N1-N2 (07_TASKS) |
| M5-04 | M5 | Contenuto: 4 aree, 12 mostri, gruppi | DATA | TODO | | |
| M5-05 | M5 | Pagina del combattimento | UI | TODO | | |
| M5-06 | M5 | Strumento di bilanciamento sim_combat | COMBAT | TODO | | |
| M5-07 | M5 | Test di M5 | QA | TODO | | |
| M5-08 | M5 | Integrazione di M5 | REV | TODO | | tag m5-done |
| M6-01 | M6 | Def, validatore e Loadout | CORE | TODO | | |
| M6-02 | M6 | Agganci del motore e 8 tipi di effetto | COMBAT | TODO | | |
| M6-03 | M6 | Abilità attive | COMBAT | TODO | | |
| M6-04 | M6 | Contenuto: 12 tratti e 6 abilità | DATA | TODO | | |
| M6-05 | M6 | Scelta di tratti e abilità nella UI | UI | TODO | | |
| M6-06 | M6 | Test di M6 | QA | TODO | | |
| M6-07 | M6 | Integrazione di M6 | REV | TODO | | tag m6-done |
| M7-01 | M7 | Raffinazione | CORE | TODO | | |
| M7-02 | M7 | Smantellamento e filtro automatico | CORE | TODO | | |
| M7-03 | M7 | Drop di equipaggiamento con rarità | COMBAT | TODO | | |
| M7-04 | M7 | Pietre del Rift | COMBAT | TODO | | |
| M7-05 | M7 | Contenuto: gioielli, drop, Pietre, Sigillo | DATA | TODO | | |
| M7-06 | M7 | Armeria completa e Pietra nella UI | UI | TODO | | |
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
