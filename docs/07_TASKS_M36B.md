# 07. Task, M36B: Panoramica con logica (CORE + UI, i «should»)

Estensione di `07_TASKS.md`; **dopo M36 chiusa**. Fonte: V46, `01_GDD_M36.md` §44.2 (parti M36B), `02_FORMULAS_M36.md` (F-204…F-208), `04_DATA_SCHEMA_M36.md` (§37), `05_INTERFACES_M36.md`
(§3j, §5.48, §5.49, §6j, §7.af), Q228-Q236. Il design non si riscrive nei brief. `sonnet`; save v12 invariato. Lezioni come `07_TASKS_M36.md`. `run_checks.ps1` una sola volta **dopo il merge di tutti**.

| ID | Titolo | Ruolo | Dim. | Dip. | File disgiunti da |
|---|---|---|---|---|---|
| M36B-1 | CORE: `GatherStats`, `in_offline`, parametro, test | CORE | M | design M36B | 2, 3 |
| M36B-2 | CORE: `GatherNeeds`, `GatherAdvice`, test | CORE | M | design M36B | 1, 3 |
| M36B-3 | UI: Statistiche, Progressione, «Cosa ti serve», «migliore zona», screenshot | UI | M | 1 + 2 + M36 | 1, 2 |
Ordine: **1 e 2 insieme** (file disgiunti, nessun contratto in comune), poi **3**. Massimo 2 agenti: 1 e 2; il 3 parte dopo il merge di entrambi.

## M36B-1: CORE, statistiche di sessione
- **Leggere**: `02_FORMULAS_M36.md` F-204, F-205; `05_INTERFACES_M36.md` §3j, §5.48; `core/offline/offline_simulator.gd` (`run`, `advance_silently`), `core/offline/debug_time_skip.gd`,
  `core/session/game_session.gd`, `systems/encounters/node_work.gd` e `combat/combat_cycle.gd` (emissione di `node_finished`, `node_skill()`), `systems/skills/skills_system.gd` (`xp_gained`).
- **Ownership**: `systems/encounters/gather_stats.gd` (nuovo), `core/session/game_session.gd` (solo `in_offline` e la composizione di `gather_stats`), `core/offline/offline_simulator.gd` (solo il flag),
  `core/data/**` (solo validatore e lettura di `gather_stats.min_sample_ms`), `data/config/balance.json` (solo la chiave `gather_stats`), `tests/systems/encounters/test_gather_stats.gd` (nuovo),
  `tests/integration/test_m36b_stats_offline.gd` (nuovo). **Non toccare**: `ui/**`, `core/autoload/game.gd`, `systems/disciplines/**`, `docs/**`.
- **Accettazione**: (1) tutti gli esempi di F-204 e F-205 (soglia di campione, `too_hard`/`not_learned` non contano, XP solo con nodo in corso); (2) **offline**: dopo `OfflineSimulator.run` con 12 h di nodi, contatori
  e `elapsed_ms()` identici a prima; stesso per `advance_silently` e `DebugTimeSkip`; `in_offline` torna falso anche se la simulazione fallisce a metà (nessun `await` lascia il flag acceso); (3) nessuna
  voce di salvataggio (`to_save` della sessione invariato, v12); (4) validatore: `min_sample_ms` ≤ 0 o mancante rifiutato; (5) i test esistenti di `offline` e `session` restano verdi.

## M36B-2: CORE, fabbisogno e consigli
- **Leggere**: `02_FORMULAS_M36.md` F-206, F-207, F-208 (con le tabelle di esempio in testa); `05_INTERFACES_M36.md` §5.49; `systems/actions/action_runner.gd` (`jobs()`),
  `production_queue_loader.gd` (`cycles_possible`), `systems/quests/quests.gd` e `core/data/defs/quest_def.gd`, `systems/encounters/encounter_cycle.gd` (`resource_odds`), `core/data/discipline_index.gd`
  (`zones_of_action`), `systems/character/` (livello).
- **Ownership**: `systems/disciplines/gather_needs.gd`, `systems/encounters/gather_advice.gd` (nuovi), `tests/systems/disciplines/test_gather_needs.gd`, `tests/systems/encounters/test_gather_advice.gd`
  (nuovi), `tests/fixtures/data/**` solo se serve una fixture con tabelle di zona per gli esempi (altrimenti `GameData` costruito nel test). **Non toccare**: `ui/**`, `core/session/**`,
  `core/offline/**`, `data/**`, `docs/**`.
- **Accettazione**: tutti gli esempi di F-206 (coda non ripetuta, ripetuta, somma di più lavori con una scorta, incarico che ignora la scorta, `other`, lavoro di progetto escluso, vuoto), F-207
  (L 10/C 25 → z3, L 25/C 25 → z2, C 15, motivi `level` e `access`, parità) e F-208; funzioni **pure** (nessun segnale, nessuno stato, la sessione non cambia: confronto di `to_save` prima/dopo);
  nessun riferimento a `ui/`.

## M36B-3: UI, le sezioni della Panoramica e la «migliore zona»
- **Leggere**: `01_GDD_M36.md` §44.2 (Panoramica M36B, Risorse M36B), §44.4; `05_INTERFACES_M36.md` §5.48, §5.49, §7.af; `ui/pages/skill/gather/**` (da M36), `resource_row.gd`, `resource_detail.gd`.
- **Ownership**: `ui/pages/skill/gather/**` (`stats_section.gd`, `progress_section.gd`, `needs_section.gd`, testi), `ui/pages/skill/resource_row.gd` e `resource_detail.gd` (solo la colonna Zona e il dettaglio),
  `ui/pages/skill/skill_page.gd` (solo l'inoltro di `page_requested` per «+N di altre discipline»), `tests/ui/test_gather_sections_smoke.gd` (nuovo), `tools/shot_m36b.gd` (+ `.tscn`). **Non toccare**: `core/**`,
  `systems/**`, `data/**`, le altre pagine. Se `skill_page.gd` è oltre 390 righe estrarre l'inoltro in `GatherBody`.
- **Accettazione**: (1) `StatsSection` mostra nodi, unità, unità/h, XP, XP/h e il tempo al livello (testi «…» se non disponibili, «massimo» al livello massimo) leggendo `session.gather_stats`;
  (2) `ProgressSection`: XP mancanti, tempo, «cosa si sblocca» (`next_unlocks`, vuoto = «nessuna novità»), pool di maestria; (3) `NeedsSection`: una riga per voce di `GatherNeeds.of` («Coda: mancano N» /
  «Incarico: mancano N»), con la migliore zona e «Vai» (`combat.start` via `go_to_area_requested`), il contatore «+N di altre discipline» apre la pagina dell'altra disciplina; sezione nascosta se vuota e
  `other` = 0; (4) la colonna Zona delle righe usa `best_zone` (testi per i motivi `level`/`access`); (5) **la UI non calcola nulla** (Grep: nessuna formula, nessun accesso a `quests`/`bank`/`actions`
  per i fabbisogni); (6) le sezioni ridisegnano ogni secondo e sugli eventi già usati; (7) screenshot 1280x720 e 1600x900 con coda e incarico che chiedono risorse, e con sessione appena aperta («…»).
