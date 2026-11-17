# 07. Task, M26: Alpha 2

Estensione di `07_TASKS.md`. Fonte: V31-V32 e M26-01 (`DECISIONS_LOG.md`), `01_GDD_M26.md` §38, `02_FORMULAS_M26.md` F-166…F-176, `04_DATA_SCHEMA_M26.md` §31,
`05_INTERFACES_M26.md`, Q146-Q158. Il design **non** si riscrive nei brief: si citano ID e sezioni. Max **2** agenti insieme.

**Filoni** (indipendenti dopo M26-02): **A** = livello a colori e sblocchi (03, 05); **B** = schemi, reagenti e mercanti (06, 07); **C** = Casa d'Aste a popolazione (08, 09, 10).
Il generatore dei dati (04) serve ad A e B. **Ordine consigliato**:
M26-02 → (**M26-03 ∥ M26-08**) → (**M26-04 ∥ M26-09**) → (**M26-06 ∥ M26-10**) → (**M26-05 ∥ M26-11**) → **M26-07** → **M26-12**.
Perché: 02 tocca i file comuni (`core/data/**`, validatori, fixture) e va da solo; 03 (`systems/professions/`, resolver, sessione) e 08 (`systems/auction/`, dati e validatore della Casa
d'Aste) hanno file disgiunti; 05 e 07 toccano entrambi la pagina della professione (`ui/pages/skill/`) e **non** vanno in parallelo.

| ID | Titolo | Ruolo | Dim. | Dip. | Accettazione |
|---|---|---|---|---|---|
| M26-01 | Design di Alpha 2: GDD §38, F-166…F-176, schema §31, contratto, task, V31-V32, Q146-Q158 | REV | M | m25-done | **DONE** (questo commit) |
| M26-02 | Fondamenta A+B: `ActionDef.colors`, `TrainerDef.vendor`, categoria `reagent`, botteghe e categoria `profession`, `GameData.shop_entries_of_vendor`/`shop_entry_selling`, `DataValidatorProfessions`, regola delle Ricette "drop o shop", `Bank.SORT_CATEGORIES`, fixture (§31.8), helper dei test `teach_recipes`/`give_reagents` (§5.36) | CORE | M | 01 | `validate_data` verde su dati veri (ancora senza `colors`: la regola "ogni azione ha `colors`" è attiva **solo** se almeno un'azione li ha, poi la attiva M26-04) e fixture; ogni caso rifiutato di §31.8 è un test; test mirati di `tests/core/data` verdi; nessun cambio di comportamento del gioco |
| M26-03 | **A** Logica: `ProfessionMath`, `Professions` (F-166…F-169), aggancio in `ArtisanResolver`, sessione, save additivo `professions` | CORE | M | 02 | tutti gli esempi di F-167 e F-168 sono test; `unlocks`/`next_unlocks`/`recipe_source` sulle fixture (F-169); ricetta senza `colors` = XP di oggi (test esistenti di `ArtisanResolver` verdi senza modifiche); nessun tiro in più del generatore della coda (test: sequenza dell'`RngService` della coda uguale con e senza `colors`); `skill_reset` azzera `frac`; equivalenza 12 h = 100 ms = 60 s = 6 h + salva/carica + 6 h con ricette gialle e verdi (estende `test_m24_offline_equivalence.gd`); salva → carica → salva identico; `game_session.gd` ≤ 243 righe |
| M26-04 | **A+B** Dati: `tools/gen_professions.gd` (§31.6): `colors`, `discover`, reagenti negli `inputs`, 28 schemi, 12 reagenti, voci `profession` dello shop, `trainers[].vendor`; nomi in `NOMI.md`, icone, pagine della Guida (Professioni, Mercanti) | DATA | M | 02 | `validate_data` verde; `gen_professions.gd --check` esce 0 dopo la generazione (idempotente); conteggi di F-169 (28 schemi, 12 reagenti) e prezzi di F-170/F-171 in `tests/data/test_data_validity.gd`; `auction_items.json` invariato (`gen_auction.gd --check`); nomi originali (nessuno da WoW o Melvor); Guida senza numeri copiati; **i test sui dati veri rotti dai nuovi schemi e reagenti** (coda, Bacheca, integrazione, `sim_quests`, `sim_village`) si riallineano **solo nella preparazione** con gli helper di M26-02 (elenco nel report; ciò che verificano non cambia): la suite completa del Reviewer dopo il merge deve essere verde |
| M26-05 | **A** UI: colori delle ricette, "Avanzamento: n%", origine, **Prossimi sblocchi** (§7.r) | UI | S | 03, 04 | smoke test della pagina della professione aggiornato (nodi presenti); nessun calcolo né numero di design nella UI (grep); screenshot 1280×720 e 1600×900 (Forgia con ricette dei quattro colori e uno schema bloccato) |
| M26-06 | **B** Logica: `Shop.can_buy_many`/`buy_many`, controllo `recipe_known`, Bacheca `craft` solo ricette note, `migration_9_to_10.gd` (v10), helper `TestFactory`, test esistenti sui dati veri riallineati | CORE | M | 02, 04 | casi di §5.36 sono test (ordine dei motivi, atomicità: nulla cambia se un controllo fallisce, `shop_purchased` una volta con il totale); **migrazione** (`test_migration_9_to_10.gd`): Forgia appresa a livello 25 → noti `forge_ashlead_plate` e `forge_stormzinc_plate`, non `forge_duskcobalt_plate`; Forgia non appresa → nessuno schema; lavoro in coda di `cook_riftmaw` → noto; ricette già note non duplicate; XP, maestria, coda, Deposito e shop identici; catena v7 → v10; `CURRENT_VERSION` 10; incarichi `craft` di una ricetta non nota non candidati (`test_quests`; i test della Bacheca sui dati veri imparano le ricette nella preparazione); suite mirata verde |
| M26-07 | **B** UI: scheda **Mercante** nella pagina della professione, botteghe nuove nella pagina Shop, "Impara ora", quantità 1/10/100 (§7.r) | UI | M | 05, 06 | smoke test `test_merchant_panel_smoke.gd`; nessuno stato nella UI; motivi dei pulsanti da `can_buy_many`; screenshot (mercante con schema bloccato, acquistabile, da imparare, noto; reagenti) |
| M26-08 | **C** Logica e dati: fasce (`population.json`), `auction.population` e i due valori nuovi in `balance.json`, `AuctionParams`/`AuctionPopulationBand`, validatore (F-174), `AuctionMath` (aggiunte), `AuctionPricing` (F-172…F-176), `population()` | CORE | M | 02 | tutti gli esempi e i vettori di F-172…F-176 sono test (`test_auction_population.gd`); `test_auction_math.gd` invariato e verde; proprietà `advance(a); advance(b)` ≡ `advance(a+b)` su oggetti delle 4 fasce; garanzia di F-176 su 1.000 stati casuali per ogni acquistabile; save `auction` identico a v9 (nessun campo nuovo); casi rifiutati di §31.7 sono test |
| M26-09 | **C** QA: `tools/sim_market.gd` con la popolazione (F-176) | QA | S | 08 | sim verde sulle soglie (1)-(5); numeri nel report (recupero e rifornimento per fascia, rapporto (5) min-max); se (5) salta: nessun ritocco, numeri al Reviewer |
| M26-10 | **C** UI: compratori, venditori e domanda nel dettaglio della Casa d'Aste | UI | S | 08 | smoke test della pagina della Casa d'Aste verde; nessun calcolo nella UI; screenshot 1280×720 |
| M26-11 | QA: `tools/sim_professions.gd` (ore per arrivare ai tetti dei gradi per ogni professione, prima = M25 e dopo = colori, con la politica "ricetta nota più alta"; oro speso in schemi e reagenti rispetto all'oro/h di combattimento); prova di equivalenza offline con A, B e C insieme | QA | M | 03, 04, 06, 08 | report con le tabelle; rallentamento atteso solo nei "buchi" fra gradini (F-167); nessun ritocco dei dati (Q122): proposte al Reviewer (Q151); test di integrazione `test_m26_offline_equivalence.gd` (coda con ricette gialle e reagenti, Casa d'Aste con vendite, 12 h in un colpo = a passi = salva/carica) verde |
| M26-12 | Integrazione: merge, `run_checks.ps1` verde, `01_GDD.md`/`03_ARCHITECTURE.md`/`GUIDA.md` allineati a §38, Q146-Q158 riviste, tag `m26-done` (e `alpha-2` se l'utente lo chiede); `STATUS.md` a cura dell'Orchestratore | REV | S | tutti | `run_checks.ps1` verde su main; nessun riferimento vietato; un save v9 reale caricato senza perdite (test con file di esempio); push solo a cura dell'Orchestratore |

## Rischi
- **Equivalenza offline** (basso): A non tira numeri e il resto è salvato; i cicli della coda sono già a passi di `tick_ms` (Q124). C non ha stato nuovo e resta additivo. Il rischio vero è un
  `frac` non salvato o ricalcolato con il livello **dopo** l'XP: i test di M26-03 lo coprono (salva/carica a metà).
- **Test esistenti** (medio): (1) 28 ricette diventano `discover` e chiedono un reagente → i test sui **dati veri** che mettono in coda piastre T2+, anime, manici o cotture T2+ (coda,
  Bacheca, integrazione, `sim_quests`, `sim_village`) falliscono con `recipe_unknown`/`missing_inputs`: li riallinea M26-04 con gli helper di M26-02 (04 è il primo task dopo il quale la suite completa può diventare rossa per questo); (2) XP ridotta per ricette gialle/verdi nei test sui
  dati veri con livelli alti (le **fixture non hanno `colors`**: invariate); (3) `CURRENT_VERSION` 9 → 10 nei test di migrazione; (4) Casa d'Aste: i numeri di `test_auction_pricing`/`house` che
  dipendono da `eq` (seme 12345) cambiano con la pressione e la liquidità per fascia; la fascia 3 tiene quelli di M23; (5) `MAX_SESSION_LINES` 240 → 243.
- **Bilanciamento** (medio, nessuna ritaratura): prezzi di schemi e reagenti e liquidità per fascia sono valori di partenza; le misure di M26-09 e M26-11 vanno al Reviewer (Q151, Q155).

## M26-02 — dettaglio
- **Leggere**: `04_DATA_SCHEMA_M26.md` §31.1-§31.5, §31.8; `05_INTERFACES_M26.md` §4c; `04_DATA_SCHEMA_M24.md` §29.4 (Ricette).
- **Ownership**: `core/data/**` (definizioni, `game_data.gd`, indici, `data_validator*.gd` salvo `data_validator_auction.gd`), `systems/bank/bank.gd` (solo `SORT_CATEGORIES`), `tests/fixtures/data/**`
  (salvo `auction/`), `tests/core/data/**`, il file degli helper dei test (`TestFactory`: solo `teach_recipes`, `give_reagents`).
- **Fuori**: `data/**` veri (li scrive M26-04), `systems/**` salvo la riga della Bank, `ui/**`.

## M26-03 — dettaglio
- **Leggere**: `02_FORMULAS_M26.md` F-166…F-169; `05_INTERFACES_M26.md` §5.35, §6d (solo `professions`); `05_INTERFACES_M24.md` §5.32, §5.34; `01_GDD_M24.md` §35.9.
- **Ownership**: `systems/professions/**`, `systems/actions/artisan_resolver.gd`, `core/session/game_session.gd`, `tests/systems/professions/**`, `tests/systems/actions/test_artisan_resolver.gd`,
  `tests/core/session/test_game_session.gd` (solo `MAX_SESSION_LINES`), `tests/integration/test_m24_offline_equivalence.gd`.

## M26-04 — dettaglio
- **Leggere**: `04_DATA_SCHEMA_M26.md` §31.1-§31.6; `02_FORMULAS_M26.md` F-166, F-169…F-171; `NOMI.md` (regole dei nomi).
- **Ownership**: `tools/gen_professions.gd`, `data/actions/{forging,woodwright,hearthcraft}.json`, `data/items/recipes.json`, `data/items/reagents.json`, `data/shop/shop.json` (solo voci `profession`),
  `data/disciplines/trainers.json` (solo `vendor`), `data/guide/**` (pagine nuove), `assets/icons/items/reagent_*.svg`, `assets/icons/items/recipe_*.svg` (se servono), `NOMI.md`, `tests/data/**`,
  la **preparazione** dei test sui dati veri rotti dagli schemi (solo chiamate agli helper), `tools/sim_quests.gd` e `tools/sim_village.gd` (solo la preparazione).

## M26-06 — dettaglio
- **Leggere**: `05_INTERFACES_M26.md` §5.36, §6d; `05_INTERFACES.md` §5.11 (Shop); `05_INTERFACES_M25.md` §6c (procedura della migrazione); `01_GDD_M26.md` §38.4, §38.7.
- **Ownership**: `systems/shop/shop.gd`, `systems/quests/quests.gd` (solo il candidato `craft`), `core/save/migrations/migration_9_to_10.gd`, `core/save/save_migrator.gd`, `tests/systems/shop/**`,
  `tests/systems/quests/**`, `tests/core/save/**`.

## M26-08 — dettaglio
- **Leggere**: `02_FORMULAS_M26.md` F-172…F-176, §9d; `02_FORMULAS.md` §5k (F-145…F-152); `04_DATA_SCHEMA_M26.md` §31.7; `05_INTERFACES_M26.md` §5.37; `05_INTERFACES.md` §5.30.
- **Ownership**: `systems/auction/**`, `core/data/data_validator_auction.gd`, `core/data/defs/auction_params.gd`, `core/data/defs/auction_population_band.gd`, il caricamento di `auction`
  in `core/data/` (solo le righe della Casa d'Aste), `data/auction/population.json`, `data/config/balance.json` (solo `auction`), `tests/fixtures/data/auction/**`, `tests/fixtures/data/config/balance.json`
  (solo `auction`), `tests/systems/auction/**`.

## M26-05, M26-07, M26-10 — dettaglio (UI)
- **Leggere**: `01_GDD_M26.md` §38.8; `05_INTERFACES_M26.md` §7.r; `docs/09_CONVENTIONS.md` (UI); `tools/shot_ui.gd`.
- **Ownership**: M26-05 `ui/pages/skill/recipe_row.gd`, `recipe_detail.gd`, `profession_view.gd`, `profession_unlocks.gd` (nuovo), `profession_texts.gd`, `tests/ui/test_profession_page_smoke.gd`;
  M26-07 `ui/pages/skill/merchant_panel.gd` (nuovo), `profession_view.gd` (solo la scheda), `ui/pages/shop/shop_texts.gd`, `tests/ui/test_merchant_panel_smoke.gd`;
  M26-10 `ui/pages/auction/auction_detail.gd`, `auction_texts.gd`, il suo smoke test.
