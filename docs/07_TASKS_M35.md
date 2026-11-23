# 07. Task, M35-D: Attrezzi con teste e raccolta mirata

> **Aggiornato da V45 (M35B)**: i punti su raccolta mirata (F-195, `set_focus`, badge «Mirata», «Raccogli questa») di D1/D3 sono abrogati; vedi `07_TASKS_M35B.md`.

Estensione di `07_TASKS.md`. Fonte: V44, `M35_ATTREZZI_MINERALI.md`, `01_GDD_M35.md` §42, `02_FORMULAS_M35.md`, `04_DATA_SCHEMA_M35.md`, `05_INTERFACES_M35.md`, Q214-Q219. Il design non si
riscrive nei brief. `sonnet`; save v12 (nessuna migrazione di versione). Lezioni valide (come `07_TASKS_M34.md`): `git checkout -B task/<ID> main`; mai `-gtest=`; test mirati con il filtro
di `CLAUDE.md`; screenshot 1280x720 e 1600x900 in cartelle separate guardati con Read; togliere i `*.uid` non tracciati prima del merge; nessun processo Godot in background;
`run_checks.ps1` una sola volta dopo il merge; file ≤ 400 righe; i test esistenti restano verdi (golden e `sim_*` esistenti: solo quelli dichiarati cambiano).

| ID | Titolo | Ruolo | Dim. | Dip. | File disgiunti da |
|---|---|---|---|---|---|
| M35-D1 | CORE: stat, teste, Falcetto, raccolta mirata, salvataggio, test | CORE | L | m35 (design) | D2, D3 |
| M35-D2 | DATA: tools.json (teste e Falcetto), stats, balance, guida, icona | DATA | S | D1 (stat registrate: i test del registro) | D1, D3 |
| M35-D3 | UI: sezione Teste, tabella Risorse, scheda del nodo, screenshot | UI | M | D1 + D2 | D1, D2 |
Ordine: **D1 → D2 → D3**. D2 può partire insieme a D1 solo se D1 ha già registrato le tre stat (file `stats.json` è di D2, ma i test del registro stanno in D1): meglio in fila; D3 dopo
entrambi. Massimo 2 agenti insieme (`CLAUDE.md`): D1 e D2 non si toccano (codice contro dati) ma D2 non può passare i test finché D1 non ha letto `heads`.

## M35-D1: CORE
- **Leggere**: `01_GDD_M35.md` §42.2-§42.6; `02_FORMULAS_M35.md` (tutta); `05_INTERFACES_M35.md` §3h-§6h; `04_DATA_SCHEMA_M35.md` §35.1-§35.3 (solo per il loader); `systems/armory/armory.gd`
  (`upgrade_tool`, `tool_next_step`, `to_save`), `systems/equipment/equipment.gd` (`SLOTS`, ricostruzione dei modificatori), `systems/armory/armory_kit.gd`, `systems/disciplines/disciplines.gd`,
  `systems/encounters/encounter_cycle.gd`, `node_work.gd`, `core/gathering` (`GatheringResolver`), `core/data/` (loader e validatore degli attrezzi), `core/common/reasons.gd`.
- **Ownership**: `systems/armory/**`, `systems/equipment/**`, `systems/disciplines/**`, `systems/encounters/**`, `systems/actions/gathering_resolver.gd`, `core/data/**` (loader/validatori degli
  attrezzi e delle stat, `ToolDef` con `heads`), `core/common/reasons.gd`, `core/autoload/event_bus.gd`, `core/session/game_session.gd` (solo la chiamata a `ensure_tools`),
  `tests/systems/armory/**`, `tests/systems/disciplines/**`, `tests/systems/encounters/**`, `tests/systems/actions/test_gathering_resolver.gd`, `tests/integration/test_m35_*.gd` (nuovi),
  `tests/fixtures/data/**` (solo per le fixture degli attrezzi), `tools/sim_encounters.gd`. **Non toccare**: `ui/**`, `data/**` (è D2: per far girare i test D1 usa fixture e un `data/` temporaneo
  del test, non i file veri), `docs/**`.
- **Accettazione** (ogni punto = un test, con gli esempi di `02_FORMULAS_M35.md` come casi):
  1. **F-195**: tutti gli esempi (Automatico, Rame grigio, fallback `limit` 30, Ferro giallo/verde); `set_focus` rifiuti (`unknown_id`, `not_learned`, `level_too_low`), `&""` toglie; `gather_focus_changed`;
     `unlearn` e `reset_skill` tolgono la scelta; la risorsa si fissa all'inizio del nodo e la scelta nuova vale dal nodo dopo; stato del nodo `focused`/`focus_blocked`/`ne`.
  2. **F-196/F-197**: effetto base (`node_units_pct` = N, intervallo invariato), modificatori attivi per ogni combinazione di `heads` e `upgrade` (tutti gli esempi); `upgrade_extras` assente.
  3. **F-198**: `choose_tool_head` — prima scelta gratis, cambio a pagamento (15.000 / 125.000 / 1.000.000 con i dati veri o fixture equivalenti), tutti i rifiuti nell'ordine, atomico; `tool_head_cost`,
     `tool_heads`, `tool_next_step.head_step`; attrezzo leggendario → `not_equippable` e le teste dell'unico restano; `Ne` e unità per tentativo (esempi 26/27/27, 29/29/29, 33/33/33, 29/30/29/30/30).
  4. **F-199**: `p` del nodo ricco (10 → 28, tetto 100) con **un solo** tiro; sottoprodotto 2,0 + 3; forma chiusa e `tools/sim_encounters.gd` (Piccone +9: ≤ +30%, teste equivalenti entro 10%).
  5. **Falcetto e slot**: `Equipment.SLOTS` con `tool_herbalism`; `ArmoryKit.ensure_tools` crea il Falcetto a +0 in un v12 «vecchio» senza di esso (e non lo duplica con uno presente, indossato o in Armeria);
     `new_game` ne dà uno.
  6. **Salvataggio**: `to_save`/`from_save` di `focus`, `heads`, `ne`, `tool_herbalism`; un v12 senza i campi nuovi si carica (nessuna migrazione, `format_version` 12); campi invalidi ignorati (§6h).
  7. **Offline**: l'equivalenza 12 h = 100 ms = 60 s (`test_m24_offline_equivalence`) resta verde con focus, teste e nodo ricco; nessun tiro in più.
  8. **Registro delle stat**: le 3 stat nuove sono in `stats.json` con formula e test (D2 le scrive: il test del registro di D1 gira dopo D2 o con fixture).
  9. Regressione: tutti i test di `armory`, `disciplines`, `encounters`, `equipment`, `modifiers` restano verdi; golden dei nodi invariati dove `u` = 0 e `p` = 10.

## M35-D2: DATA
- **Leggere**: `04_DATA_SCHEMA_M35.md` (tutta); `02_FORMULAS_M35.md` F-197 (tabella dei valori) e §9d; `data/items/tools.json`; `data/config/balance.json` (`tool_upgrade`, `start`); `data/config/stats.json`
  (un blocco di esempio); `data/guide/mestieri.json` e quelle che citano gli attrezzi.
- **Ownership**: `data/items/tools.json`, `data/config/balance.json` (solo `tool_upgrade` e `start.tools`), `data/config/stats.json` (3 stat), `data/guide/*.json` (solo le righe sugli attrezzi),
  `assets/icons/items/unique_sickle.svg` (segnaposto), `tests/data/**` (nuovi), `tests/fixtures/data/**` solo se D1 lo chiede. **Non toccare**: codice (`core/`, `systems/`, `ui/`, `tools/` tranne uno
  script di generazione se serve), `docs/**`.
- **Accettazione**:
  1. `tools.json`: 4 attrezzi unici, ognuno con 2 teste × 3 passi esattamente come la tabella di F-197 (valori copiati, nomi e `description` originali in italiano); nessun `upgrade_extras`; Falcetto con slot
     `tool_herbalism` e icona.
  2. `balance.json`: `units_per_level_pct` 1, `head_steps` `[3,6,9]`, `respec_pct` 25, `start.tools` con `unique_sickle`; `levels` e gli altri valori **non cambiano**.
  3. `stats.json`: `node_units_pct`, `node_rich_pct`, `byproduct_chance_pct` come in §35.3 (con `formula` e `test`).
  4. Test (`tests/data/test_tool_heads_data.gd`): UE di ogni testa in [9, 15] e tutte le Resa a 15 (F-197), nessun `upgrade_extras`, stat ammesse, `head_steps` ⊂ `levels`.
  5. `-s tools/validate_data.gd` sui dati veri e sulle fixture: verde (dopo D1); guida aggiornata a quattro attrezzi e alle teste (testo breve, originale).

## M35-D3: UI
- **Leggere**: `01_GDD_M35.md` §42.3-§42.4; `05_INTERFACES_M35.md` §7.ac e §5.45-§5.46; `ui/pages/skill/tool_upgrade_panel.gd/.tscn`, `tool_upgrade_texts.gd`, `skill_page.gd` (`_build_extras`,
  `TOOL_SKILLS`), `action_card.gd`, `node_color_preview.gd`, `gathering_info.gd`; la scheda del nodo (`NodeCard`, `ui/pages/combat/`); `GuideIndex.uses_of`.
- **Ownership**: `ui/pages/skill/**` (nuovi `resource_table.gd/.tscn`, `resource_row.gd`, `head_section.gd`, testi centralizzati), `ui/pages/combat/node_card.*` **solo** per l'etichetta «Mirata» e la riga
  «Qui lavori solo fino a …», `tests/ui/test_resource_table_smoke.gd` e `test_tool_heads_smoke.gd` (uno smoke test per pagina), `tools/shot_*.gd` per gli screenshot. **Non toccare**: `systems/**`, `core/**`,
  `data/**`, `ui/pages/bank/**`, `ui/pages/rift/**`, `ui/screens/**` (altre sessioni M35 lavorano lì; se serve un componente condiviso, chiedere al Reviewer).
- **Accettazione**: `TOOL_SKILLS` a 4 (Erboristeria compresa); sezione «Teste» con tre righe, scelta con clic vero (`Viewport.push_input`), costo e «gratis», avviso «Scegli una testa», rifiuto in `MessageLabel`;
  `ResourceTable` al posto delle schede con tutte le colonne di §7.ac, «Raccogli questa», badge «Mirata», «Automatico», filtro; la UI **non calcola** nulla (colore, costi, stato: dal modello); testo in
  `UiStyle`/file centralizzati; nessuno stato di gioco nella UI; screenshot a 1280x720 e 1600x900 (pagina del Minatore con tabella, pannello Teste, scheda del nodo «Mirata»); smoke test per le due pagine
  (colonne presenti, un clic su «Raccogli questa» chiama `set_focus`).
- **Seconda fase fuori da M35**: **M3** «Ciò che serve» (focus derivato dalla coda e dagli incarichi) — task separato, solo dopo la chiusura di questo.
