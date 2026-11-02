# Stato dei task

Aggiornato dall'Orchestratore (unico che modifica questo file). Stati: TODO / IN_PROGRESS / REVIEW / DONE / BLOCKED.
Se la sessione si interrompe, si riparte da qui.

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
| M1-03 | M1 | Classi Def e caricatore JSON | CORE | IN_PROGRESS | task/M1-03 | |
| M1-04 | M1 | Validatore, GameData, DataRegistry, fixture | CORE | TODO | | tipizzare DataRegistry.data come GameData (oggi RefCounted) |
| M1-05 | M1 | Casualità, sessione, snapshot, factory dei test | CORE | TODO | | |
| M1-06 | M1 | Salvataggio per slot con versioni | CORE | REVIEW | task/M1-06 | 8cf567f..9f66f2c; 44 test, run_checks 126/126; scrittura 200 KB ~10-12 ms |
| M1-07 | M1 | Wallet e Bank | CORE | TODO | | |
| M1-08 | M1 | Skill ed esperienza | CORE | TODO | | |
| M1-09 | M1 | Maestria per oggetto e pool | CORE | TODO | | |
| M1-10 | M1 | ActionRunner e raccolta | CORE | TODO | | |
| M1-11 | M1 | Game: menu → slot → partita | CORE | TODO | | tipizzare Game.session (GameSession) e list_slots (Array[SlotInfo]); chiamare GameClock.configure da balance.json |
| M1-12 | M1 | Contenuto: le 12 skill e Selvicoltura | DATA | TODO | | |
| M1-13 | M1 | Menu principale e scelta dello slot | UI | TODO | | |
| M1-14 | M1 | Schermata principale: sidebar, barra in alto, PageHost | UI | TODO | | |
| M1-15 | M1 | Pagina skill (raccolta) e componenti base | UI | TODO | | |
| M1-16 | M1 | Tooltip e GameWindow portati | PORT | TODO | | |
| M1-17 | M1 | Toast portati | PORT | IN_PROGRESS | task/M1-17 | |
| M1-18 | M1 | Bank minima | UI | TODO | | |
| M1-19 | M1 | Test di integrazione di M1 | QA | TODO | | |
| M1-20 | M1 | Integrazione di M1 | REV | TODO | | |
| M2-01 | M2 | Nodi della maestria | CORE | TODO | | |
| M2-02 | M2 | Contenuto: Cavatura, Lenza, nodi della raccolta | DATA | TODO | | |
| M2-03 | M2 | Pannello della maestria | UI | TODO | | |
| M2-04 | M2 | Bank completa | UI | TODO | | |
| M2-05 | M2 | Test di M2 | QA | TODO | | |
| M2-06 | M2 | Integrazione di M2 | REV | TODO | | |
| M3-01 | M3 | Ricette dell'artigianato | CORE | TODO | | |
| M3-02 | M3 | Shop (porting) | PORT | TODO | | |
| M3-03 | M3 | Equipaggiamento e attrezzi | CORE | TODO | | |
| M3-04 | M3 | Contenuto: Forgiatura, Focolare, Intaglio, shop | DATA | TODO | | |
| M3-05 | M3 | Pagina skill: variante artigianato | UI | TODO | | |
| M3-06 | M3 | Shop e vendita | UI | TODO | | |
| M3-07 | M3 | Pagina equipaggiamento | UI | TODO | | |
| M3-08 | M3 | Test di M3 | QA | TODO | | |
| M3-09 | M3 | Integrazione di M3 | REV | TODO | | |
| M4-01 | M4 | Formule di combattimento | COMBAT | TODO | | |
| M4-02 | M4 | Statistiche, razioni da campo, borsa del bottino | COMBAT | TODO | | |
| M4-03 | M4 | Motore del combattimento | COMBAT | TODO | | |
| M4-04 | M4 | Contenuto del combattimento | DATA | TODO | | |
| M4-05 | M4 | Pagina del combattimento | UI | TODO | | |
| M4-06 | M4 | Test di M4 | QA | TODO | | |
| M4-07 | M4 | Integrazione di M4 | REV | TODO | | |
| M5-01 | M5 | Altare del Rift | CORE | TODO | | |
| M5-02 | M5 | Contenuto della Legatura del Rift e nodi dell'artigianato | DATA | TODO | | |
| M5-03 | M5 | Pagina dell'Altare | UI | TODO | | |
| M5-04 | M5 | Test di M5 | QA | TODO | | |
| M5-05 | M5 | Integrazione di M5 | REV | TODO | | |
| M6-01 | M6 | Simulazione offline | CORE | TODO | | ownership aggiunta: event_bus.gd (solo firma offline_completed: OfflineSummary) e riga offline_completed di test_event_bus.gd; tipizzare Game.last_offline_summary |
| M6-02 | M6 | Schermate dell'offline | UI | TODO | | |
| M6-03 | M6 | Impostazioni (porting) | PORT | TODO | | |
| M6-04 | M6 | Sistema dei suggerimenti | CORE | TODO | | |
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
