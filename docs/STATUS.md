# Stato dei task

Aggiornato dall'Orchestratore (unico che modifica questo file). Stati: TODO / IN_PROGRESS / REVIEW / DONE / BLOCKED.
Se la sessione si interrompe, si riparte da qui.

- **P-02 Scheda pezzo, Banco del fabbro, slot Cibo (2026-11-08, merge 55730ff)**: scheda del pezzo, Banco del fabbro nella pagina Fabbro, slot Cibo nella bambola, drag reale (fix a `EquipmentInventory.rebuild_grid`).
- P-02 aperto: layout non verificato a schermo; manca l'icona `food.svg`; il tipo del pezzo mostra il nome dello slot.
- P-02 nessun cambio di dati.
- **P-04 Rifiniture dalla review (2026-11-08)**: fatto. Scheda pezzo senza "+0" e con Vendi sotto Blocca/Smantella, scheda in cima alla colonna destra; rune dell'Altare con effetto numerico; totali dell'Equipaggiamento senza razioni/raffinazione; etichette ricetta a capo; Deposito con caselle vuote fino alla capienza; azioni di raccolta senza verbo.
- P-04: Shop per botteghe (campo `vendor` obbligatorio e validato: bottegaia, fabbro, deposito, armaiolo, mercante_armature; vuote = "In arrivo"; razioni -> Bottegaia, spazi/auto-loot/tasca -> Deposito, Fabbro vuoto perché lo shop non ha componenti né Sigilli). Q55 chiusa (NOMI.md allineato ai dati).
- P-04 aperto: layout 1600x900/1280x720 non visto a schermo (Vendi in vista solo per costruzione); Guida cita ancora le azioni di raccolta solo via dati.
- **P-03 Rinomina, Rune e Incavi (2026-11-08)**: fatto (merge dati `598d8a3`, UI `15bc0cf`). Rune/Incavi in dati, UI, Guida e NOMI.md (id invariati); pagina Guida "Pietre e Rune", Altare con stato degli incavi e elenco rune del Deposito con link a Legatura.
- P-03: tabelle Tratti/Abilità della Guida da `LoadoutDescribe` (ora `core/guide/`, `NumberFormat` spostato in `core/common/`); descrizioni dei dati senza cifre; `player_renamed` aggiorna la TopBar (chiude l'aperto di P-01).
- P-03 aperto: Q55 valute (flux/crown) invariata; layout 1600x900/1280x720, popup del cibo con mouse vero e icona `food.svg` non verificati; il test dedicato rinomina-pagina->barra passa da `PlayerName.rename`, non dal clic.
- **P-01 Pagina Personaggio (2026-11-08, dopo m11-done)**: nome del personaggio in grande con Rinomina (`PlayerName.rename`, limiti `player_name` di `balance.json`, salvataggio dello slot), sotto "Spadaccino · Livello N"; tolta la sezione Assetto; tratti e abilità in un riquadro a due schede.
- Descrizioni di tratti e abilità generate da effetti, parametri e ricarica (`ui/pages/character/loadout_describe.gd`, il campo `description` dei dati non si mostra più); stat `damage_reduction` ora si chiama "Armatura" (solo testo in `stats.json`).
- Aperto di P-01 chiuso da P-03 (`player_renamed`).

## Ripartenza (aggiornata il 2026-11-08, R-03 fatta: Riforma 2 nei documenti)
- **Stato**: **R-03 DONE**: la Riforma 2 (decisioni W1-W7, fonte `RIFORMA_2.md`) è nei documenti canonici (`NOMI.md`, `OPEN_QUESTIONS.md` Q58-Q61 e Q26 chiusa, `DECISIONS_LOG.md` W1-W7 e scelte R-03,
  `00_VISION.md`, `01_GDD.md` §4.1/§6.4/§7/§11/§18, `02_FORMULAS.md` F-100…F-108 e §8.5b-§8.8b, `03_ARCHITECTURE.md`, `04_DATA_SCHEMA.md` §20, `05_INTERFACES.md` §5.20-§5.22 e §7.w, `06_ROADMAP.md`,
  `07_TASKS.md`, `CLAUDE.md`). Hash: R-03 = commit `docs: R-03 riforma 2 nei documenti canonici` (`git log --grep "R-03"`); tag M11 `m11-done` già messo; P-01…P-04 (rifiniture) già su main.
  Codice e dati **non** toccati: il gioco è ancora quello di M11 (+ P-01…P-04); i documenti descrivono lo stato di arrivo di M12.
- **Prossimo passo**: **M12-01 Deposito unico e borse** (CORE; il suo primo sotto-punto allinea i riferimenti vecchi: `shop.json` `_doc` e `FORMULA_MILESTONES`), poi M12-02 aiutanti, M12-03 maestria per risorsa,
  M12-04 Incisore, M12-05 contenuti, M12-06 UI ∥ M12-07 bilanciamento, M12-08 test, M12-09 integrazione (`m12-done`). Poi **M13 Fratture come mappe** e M14+. Sessione nuova da questo file.
- **Milestone rinumerate (R-03)**: M12 Riforma 2, M13 Fratture come mappe, M14+ invariato; le **corsie parallele sono eliminate** (aiutanti, W3).
- **Formato del salvataggio**: `format_version` 4 da M12 (v1/v2/v3 "versione non supportata", nessuna migrazione).
- **Da tarare / aperto**: Q58-Q61 (borse, aiutanti, traguardi, Cristallizzare) con tutti i valori di partenza non presenti nella fonte (`deposit.base_slots` 60, probabilità dei sottoprodotti, bonus dei traguardi 50 e 99,
  nodi dei tre alberi, ricette e livelli dell'Incisore, `rune.grade_mult`, tabelle di drop di §8.5b): si tarano in M12-07. Q53 e Q55-Q57 invariate (Q56: più tipi di drop riempiono prima la borsa del bottino);
  foto di layout 1600x900/1280x720 non fatta; kit con spada e scudo già indossati da confermare. Q26 **chiusa**.
- **Ambiguità risolte da R-03** (`DECISIONS_LOG.md`): Borsa rinforzata = ricetta del Falegname (la fonte dice "progetto"); "pietra grezza del Minatore" = minerale di grado 1; Deposito pieno = l'aiutante attende e riparte;
  un contratto di grado uguale o inferiore non si consuma; `second_thought` e F-51 eliminati (non spostati a M13).
- **Pulizia a mano (non fatta)**: worktree `C:\Users\Davide\Desktop\AI\wt-*`, `RS-M10-02`, `rs-M10-05`, `RSI-worktrees\*` e `.claude/worktrees/agent-*`; poi `git worktree prune` e cancellare i branch `task/*` mergiati.

## Ripartenza precedente (fine M11, 2026-11-08)
- **Stato**: **M11 Guida in gioco completata**, tag `m11-done` (lo mette e lo pusha l'Orchestratore). Hash: R-02 `4097d40`, M11-01 `ce3d07c`, M11-02 `0cbf41b`,
  Q49 `6c8ad78`, M11-03 `d9e7eac` (+ allineamento tabelle `7042376`), M11-04 `4d766d1`, M11-05 `e6f9e66`, M11-06 `47dbfc5`; M11-07 = commit di chiusura.
  `run_checks` su main: 1958 test verdi, dati (fixture e veri), righe per file e riferimenti vietati OK.
- **Prossimo passo**: **M12 Fratture come mappe** (`01_GDD.md` §17 da rivedere a inizio milestone; task da definire), sessione nuova da questo file. Poi M13 corsie parallele, M14+ il resto.
- **Da tarare / aperto**: Q53 invariata; Q55-Q57 nuove (`OPEN_QUESTIONS.md`); foto di layout 1600x900 e 1280x720 non fatta (`tools/ui_shots` vuota, solo test sulle dimensioni minime);
  Q26, Q27-Q43, Q47 invariate; kit con spada e scudo già indossati da confermare.
- **Deviazioni di M11**: `guide_book.gd` e `item_index_m10.gd` extra per il limite di 400 righe; rotta `help` + `guide`; titoli di gruppo dell'indice come costanti in `guide_nav.gd`;
  Altare senza pagina propria nel "?"; etichette italiane in `GuideIndex`; nomi delle valute dei dati diversi da `NOMI.md` (`currency_flux` "Sabbia del mutamento", `currency_crown` "Essenza del Rift");
  con la borsa piena si perdono ~0,38 progetti/h in un seme.
- **Riferimenti vecchi ancora presenti (verificati con Grep su main; da R-03 si allineano nel primo sotto-punto di M12-01)**: `data/shop/shop.json` (`_doc`: "second_thought (M11)", ora M13) e `tests/data/test_stat_registry_coverage.gd` riga 34
  (`FORMULA_MILESTONES`: "F-50": "M10", "F-51": "M11", ora M12/M13): da allineare al primo task di M12.
- **Pulizia a mano (non fatta)**: worktree `C:\Users\Davide\Desktop\AI\wt-*`, `RS-M10-02`, `rs-M10-05`, `RSI-worktrees\*` e `.claude/worktrees/agent-*`; poi `git worktree prune` e cancellare i branch `task/*` mergiati.
- **Prove manuali consigliate**: Guida dalla sidebar (indice, ricerca, collegamenti, indietro); "?" in ogni pagina; tooltip con "Si ottiene da / Serve a"; layout 1600x900 e 1280x720; poi quelle di M10.

### Report di milestone M11
Guida in gioco: indice "da dove viene / a cosa serve" e tabelle generate dai dati (`core/guide/`), testi a mano in `data/guide/` con segnaposto risolti da `balance.json` e `stats.json`
e validatore, pagina Guida con ricerca e storico, pulsanti "?" in 7 pagine, righe dei tooltip, test di integrazione e copertura. Q49 chiusa: ~1 progetto/h, nessuna ritaratura.
Non verificato: foto di layout e prove manuali. Nessun cambio di formule o di bilanciamento.

## Ripartenza precedente (fine M10, R-02 fatta, 2026-11-08)
- **R-02 DONE** (2026-11-08): Guida in gioco (M11, decisioni G1-G2) riportata nei documenti canonici (`01_GDD.md` §27, `04_DATA_SCHEMA.md` §19, `05_INTERFACES.md` §5.19 e §7.y, `06_ROADMAP.md`, `07_TASKS.md` M11-01…M11-07); milestone rinumerate: M11 Guida, M12 Fratture come mappe, M13 corsie parallele, M14+ il resto. `GUIDA.md` superato, non si legge più.
- **R-02 DONE** (2026-11-08): Guida in gioco (M11, decisioni G1-G2) riportata nei documenti canonici (`01_GDD.md` §27, `04_DATA_SCHEMA.md` §19, `05_INTERFACES.md` §5.19 e §7.y, `06_ROADMAP.md`, `07_TASKS.md` M11-01…M11-07); milestone rinumerate: M11 Guida, M12 Fratture come mappe, M13 corsie parallele, M14+ il resto. `GUIDA.md` superato, non si legge più.
- **Stato**: **M10 completata**, tag `m10-done` su `main`. R-01 `4f990db`. Merge: M10-01 `7b1a226`, M10-02 `285e2de`, M10-03 `4a098cb`,
  M10-04 `793b445` (+ rifinitura drop/kit `79087c8`), M10-05 `42c4f99`, M10-06 `4ad4758`, M10-07 `42c3c50`, M10-08 `803b79a`; M10-09 = commit di chiusura.
  `run_checks` su main: 1848 test verdi, dati (fixture e veri), righe per file e riferimenti vietati OK.
- **Misure (M10-07, `06_ROADMAP.md`)**: livello 99 in circa 299 h; una notte offline dal 50 dà +11/+12 livelli; un pezzo ogni 21-22 min nelle 4 aree.
  `MAX_DROPS` alzato a 8 (64 progetti). `combat.kill_xp_mult` 0,11. Save `format_version` 3 (v1/v2 "versione non supportata").
- **Prossimo passo**: **M11-01** (CORE, in parallelo con M11-02): Guida in gioco, task in `07_TASKS.md` (M11-01…M11-07), sessione nuova da questo file. Poi M12 Fratture come mappe, M13 corsie parallele, M14+ il resto.
- **Da tarare / aperto**: Q53 (quantità componenti, tabella F-94 degli attrezzi, `xp_mult`); progetti dalle Pietre del Rift non misurati (stima ~1/h);
  Bosco e Soglia sforano di poco 20-40 min con la lettura stretta del grado; foto di layout 1600x900 e 1280x720 non fatta (pagina Progetti, pannello attrezzo);
  kit iniziale con spada e scudo già indossati (da confermare). Q26, Q27-Q43, Q47 invariate.
- **Pulizia a mano (non fatta)**: worktree `C:\Users\Davide\Desktop\AI\wt-*`, `RS-M10-02`, `rs-M10-05`, `RSI-worktrees\*` e `.claude/worktrees/agent-*`; poi `git worktree prune` e cancellare i branch `task/*` mergiati.
- **Prove manuali consigliate**: partita nuova (kit, cibo, primo suggerimento = combattimento); Fabbro: sezione Progetti (requisiti, affisso al liv. 50, craft, stop con rimborso, craft offline); raffinazione attrezzi +0…+9 nei tre mestieri; toast unico per più livelli; Deposito (nessun "Bank"); layout 1600x900 e 1280x720.

## Ripartenza precedente (inizio M10, R-01 fatta, 2026-11-07)
- **Stato**: MVP rilasciato (`m9-mvp`, `m9-done`). **R-01 DONE**: la riforma del bottino, degli attrezzi e dei nomi è nei documenti canonici
  (00-07, OPEN_QUESTIONS, DECISIONS_LOG; commit `docs: R-01 riforma del bottino e dei nomi`). Da ora i documenti canonici sono autosufficienti:
  `RIFORMA_BOTTINO.md` e `VISIONE_V2.md` non si leggono più; `NOMI.md` solo per i nomi (M10-05, M10-04 per i componenti).
- **Milestone rinumerate**: **M10 Riforma del bottino e dei nomi** (prima di far provare il gioco agli amici); M11 Fratture come mappe; M12 azioni in
  parallelo; M13+ seconda classe, boss, dungeon.
- **Task M10** (`07_TASKS.md`): M10-01 schema e validatore (CORE) TODO · M10-02 progetti (CORE) TODO · M10-03 attrezzi unici, F-93/F-94/F-95 (CORE) TODO ·
  M10-04 contenuti (DATA) TODO · M10-05 nomi (DATA) TODO · M10-06 UI (UI) TODO · M10-07 bilanciamento B1-B5 (COMBAT/QA) TODO · M10-08 test (QA) TODO ·
  M10-09 integrazione, tag `m10-done` (REV) TODO. Ordine: M10-01 → (M10-02 ∥ M10-03) → M10-04 → M10-05 → M10-06 → M10-07 → M10-08 → M10-09.
- **Prossimo passo**: lanciare M10-01 (CORE). Salvataggio `format_version` 3 (v1/v2 "versione non supportata"). **Da fare dell'Orchestratore**: aggiornare
  `CLAUDE.md` (milestone M10-M12 → M10 riforma e M11-M13+; stato) — il Reviewer non lo ha toccato.
- **Decisioni aperte per l'utente** (default in `OPEN_QUESTIONS.md`): Q48-Q52 (default di `RIFORMA_BOTTINO.md`), Q53 (valori di partenza non presenti
  nelle fonti, da tarare), Q54 (B1: `combat.kill_xp_mult` 0,15 da tarare); Q26, Q27-Q43 invariate. Ambiguità segnalate in R-01: grado 8 = 59 min (non 60), quantità
  di materiali e componente raro, kit con spada e scudo già indossati, un'area di grado g lascia progetti g e g+1 (vedi `DECISIONS_LOG.md` R-01).

## Ripartenza precedente (fine M9 = MVP, 2026-11-07)
- **Stato**: **M9 completata e MVP rilasciato**, tag locali `m9-mvp` e `m9-done` su `main` (il push lo fa l'Orchestratore).
  Merge M9: M9-00 `2e151d5`, M9-01 `7b477d7`, M9-04 `3da7c63`, M9-05 `04393ee`, M9-03 `625ff17`, M9-02 `17f9a27`, M9-06 `873886f`,
  fix suggerimenti `63d7899`, M9-07 `da61e20` (+ ritaratura `d9559bc`). run_checks: 1627 test verdi, dati e controlli di progetto OK.
  M9-08: test allineati a `inf_scholar` +6 / `inf_deep_roots` +10 e a 6 suggerimenti; correzione del validatore delle icone per
  l'esportazione (`ResourceLoader.exists`); `export_presets.cfg` (Windows Desktop); `docs/RELEASE_CHECKLIST_MVP.md`; `05_INTERFACES.md`
  §5.13-5.15b e `04_DATA_SCHEMA.md` §10 aggiornati.
- **Prossimo passo (post-MVP)**: sessione nuova da questo file. Prima di M10 (Fratture come mappe, `01_GDD.md` §17): le prove manuali
  di `docs/RELEASE_CHECKLIST_MVP.md` §4 (l'utente), poi rivedere le firme di M10 in `05_INTERFACES.md` §5.15 e `07_TASKS.md`. Poi M10-M12.
- **Decisioni aperte per l'utente** (default in `OPEN_QUESTIONS.md`): Q26, Q27-Q43 (Q44-Q46 ritarate/chiuse in M7-M9).
- **Pulizia a mano (non fatta)**: cartelle `C:\Users\Davide\Desktop\AI\wt-*` (almeno `wt-M6-02`, `wt-M7-03-04`) e worktree
  `.claude/worktrees/agent-*` (9); poi `git worktree prune`. Nessun branch o worktree cancellato da M9-08.
- **Limiti noti**: eseguibile non firmato, senza icona di applicazione; follow-up di M8 (vedi sotto).

## Ripartenza precedente (fine M8)
- **Stato**: **M8 completata**, tag `m8-done` su `main`. Merge: M8-00 `99e35d4`, M8-01 `36fa88d`, Q46 `426e5fa`, M8-02 `46e6a4e`,
  M8-03 `6c549c0`, M8-09 `be5c0b5`, M8-04 `f6bf583`, M8-06 `ecea8a4`, M8-05 `ea3c1a3`. run_checks: 1531 test verdi.
- **Prossimo passo**: **M9 Offline e polish** (ultima milestone dell'MVP), sessione nuova: M9-01 (CORE, offline, note N5-N6) e
  M9-04 (CORE, suggerimenti, N8), poi UI e QA.
- **Decisioni aperte per l'utente**: Q26, Q27-Q40, Q41, Q42, Q43. Q46 chiusa. Nuove: (a) Pianure a 1,13 Pietre/ora perche la
  pity globale (300) lo impone; per 1,00 serve `pity_kills` per area; (b) `inf_scholar` +3% e `inf_deep_roots` +5% non si
  vedono sugli XP bassi (floor F-02); (c) valori di pietre e valute scelti dal Data Designer, da ritarare.
- **Prove manuali consigliate (M8)**: pagina Altare (5 prese, sblocchi 1/20/40/60/80, Incastona, Togli con conferma, bonus
  attivi); bank: Incastona all'Altare e pietra su un pezzo; pannello del pezzo: castoni, pietre inattive in grigio dopo
  un calo della raffinazione, valute (anteprima, rifiuti, conferma del reroll); testi volanti max 3 per carta;
  Raffina/Smantella senza scorrere; layout a 1600x900 e 1280x720.
- **Follow-up**: getter del livello di sblocco in `RiftAltar` (la pagina legge `rift.sockets`); Incastona dalla bank non
  sceglie la presa; `CombatantStats.for_player` usato dai test ma assente da 05; pietre incastonabili tra i drop.
  Pulizia a mano: worktree `C:\Users\Davide\Desktop\AI\wt-*` (M7-03-04 e M8-*), poi `git worktree prune`.
- **Decisioni ritarate in M7-07**: Q44 e Q45 (whirl `power_mult` 1,0; rift_maul 2,0; shield_bash 1,8 con ricarica 6500 ms;
  drop dei mostri e delle Pietre; `pulse_damage` Miniere 10, Soglia 15). `balance.json` e formule invariati.
- **Decisioni aperte per l'utente** (default in `OPEN_QUESTIONS.md`): Q26, Q27-Q40, Q41, Q42, Q43, **Q46** (frequenza delle
  Pietre: una ogni circa 0,8 h in Pianure ma 2,4-2,6 h in Miniere e Soglia con `chance_pct` 0,5; opzioni `chance_pct` circa
  1,0 o valore per area). Provvisori confermati: affissi (`02_FORMULAS.md` §8.9), F-83, F-86, F-87, F-88.
- **Follow-up di bilanciamento (non bloccanti)**: pezzi rari/ora sotto il criterio di `06_ROADMAP.md` in Bosco (0,08/h
  su 12 h; a 4 h con `scope=easiest` 0,25/h); pezzi/ora sopra 12 in Pianure (17,7).
- **Testo da inserire nella sezione Stato di CLAUDE.md (serve l'OK dell'utente, autorizzazione data solo per M5/M6)**:
  "M7 (Bottino) completata, tag `m7-done`. Prossima milestone: **M8 Altare del Rift**, dopo l'OK dell'utente per M8-01;
  l'MVP è M0-M9." (sostituisce "M6 ... Prossima milestone: M6 Abilità e tratti" nella frase corrispondente, aggiungendo
  M6 completata, tag `m6-done`, se non già presente).
- **Prove manuali consigliate (M7)**: pagina Armeria: Raffina (costi e probabilità mostrati, esito, Sigillo), Smantella con
  conferma, filtro automatico per slot, "Nome +N" e "+N" nelle celle; pagina del combattimento: carta della Pietra (PV,
  impulso, comparsa, sconfitta, bottino); testi volanti impilati; layout a 1600x900 e 1280x720.
- **Pulizia a mano**: rimuovere `C:\Users\Davide\Desktop\AI\wt-M7-03-04` (Permission denied, probabile Godot headless orfano; poi `git worktree prune`).
- **Prove manuali consigliate (M7-00)**: impilamento dei testi volanti con piu colpi ravvicinati (danno, Mancato, Parato); piu carte nemici in fila che riempiono la zona senza tagli; etichette degli attrezzi con le skill reali nella bambola; tratti e abilita come carte con un solo avviso durante l'incontro; statistiche finali nell'Equipaggiamento; layout a 1600x900 e 1280x720.
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
| M7-07 | M7 | Test di M7 | QA | DONE | task/M7-07 | merge (9643a99); test d'integrazione loot, Pietra, save; sim_combat: scope=easiest con Pietre, opzioni loot=1 e loadout=auto; ritaratura Q44/Q45 solo in dati (rift_blade, monsters, rift_stones) |
| M7-08 | M7 | Integrazione di M7 | REV | DONE | main | tag m7-done sul commit docs finale; run_checks 1441 test, 1441 passati, 0 pending, 0 falliti; validate_data, righe per file e riferimenti vietati ok (1135 file); Prova del Giocabile 5/5 (test d'integrazione M7 + sim_combat loot=1 loadout=auto, misure in `06_ROADMAP.md`); Q44/Q45 ritarate, Q46 aperta; push di main e m7-done |
| M8-01 | M8 |Altare del Rift | CORE | DONE | task/M8-01 | merge 36fa88d; Altare, 15 test; nessun cambio di firma |
| M8-02 | M8 |Contenuto: Legatura e nodi dell'artigianato | DATA | DONE | task/M8-02 | merge 46e6a4e; 9 infusioni, 9 ricette, nodi di forging/hearthcraft/woodwright/riftbinding; DECISIONS_LOG |
| M8-03 | M8 |Castoni, pietre e valute del Rift | CORE | DONE | task/M8-03 | merge 6c549c0; Sockets F-89, Armory socket_*, categorie stone/currency; firme in 05 |
| M8-04 | M8 |Contenuto: pietre e valute | DATA | DONE | task/M8-04 | merge f6bf583; 12 pietre, 3 valute, ricette, balance.sockets obbligatoria |
| M8-05 | M8 |Pagine dell'Altare e dei castoni | UI | DONE | task/M8-05 | merge ea3c1a3; pagina Altare, castoni, valute, bank |
| M8-06 | M8 |Test di M8 | QA | DONE | task/M8-06 | merge ecea8a4; 137 test di integrazione, nessun bug; XP piccoli nascondono i bonus % (F-02) |
| M8-07 | M8 |Integrazione di M8 | REV | DONE | main | tag m8-done; run_checks 1531 test, 1531 passati, 0 falliti; validate_data, righe per file (201 file) e riferimenti vietati ok |
| M8-00 | M8 | Correzioni UI dalla prova visiva di M7 | UI | DONE | task/M8-00 | merge 99e35d4; testi volanti max 3, Raffina/Smantella in cima, Slot:, equipment_page 346 righe |
| Q46 | M8 | Pietra del Rift per area | COMBAT | DONE | task/Q46 | merge 426e5fa; Pianure 1,13/h (pity globale), Bosco/Miniere 1,00, Soglia 0,96 |
| M8-09 | M8 | Uso delle valute (use_currency) | CORE | DONE | task/M8-09 | merge be5c0b5; CurrencyUse, extend_affixes |
| M9-01 | M9 | Simulazione offline | CORE | DONE | merge 7b477d7 | note N5-N6 |
| M9-02 | M9 | Schermate dell'offline | UI | DONE | merge 17f9a27 | |
| M9-03 | M9 | Impostazioni (porting) | PORT | DONE | merge 625ff17 | nota N7 |
| M9-04 | M9 | Sistema dei suggerimenti | CORE | DONE | merge 3da7c63 (fix pending 63d7899) | nota N8 |
| M9-05 | M9 | Contenuto dei suggerimenti | DATA | DONE | merge 04393ee | |
| M9-06 | M9 | Feedback visivo e carta dei suggerimenti | UI | DONE | merge 873886f | nota N9 |
| M9-07 | M9 | Regressione, prestazioni, foto della UI | QA | DONE | merge da61e20, ritaratura d9559bc | nota N10 |
| M9-08 | M9 | Rilascio dell'MVP | REV | DONE | tag m9-mvp, m9-done (locali); preset export, checklist | tag m9-mvp, m9-done |
