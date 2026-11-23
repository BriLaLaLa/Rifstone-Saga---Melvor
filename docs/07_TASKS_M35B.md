# 07. Task, M35B: Risorse per zona con percentuali (toglie la raccolta mirata)

Estensione di `07_TASKS.md`. Fonte: V45, `01_GDD_M35B.md` (§43), `02_FORMULAS_M35B.md` (F-200…F-203), `04_DATA_SCHEMA_M35B.md` (§36), `05_INTERFACES_M35B.md`, Q220-Q227. Il design non si
riscrive nei brief. `sonnet`; save v12 (nessuna migrazione di versione). Lezioni come `07_TASKS_M35.md`: `git checkout -B task/<ID> main`; mai `-gtest=`; test mirati con il filtro di
`CLAUDE.md`; screenshot 1280x720 e 1600x900 in cartelle separate guardati con Read; togliere i `*.uid` non tracciati prima del merge; nessun processo Godot in background;
`run_checks.ps1` una sola volta **dopo il merge di tutti e tre**; file ≤ 400 righe; i test esistenti restano verdi: cambiano solo quelli dichiarati qui.

| ID | Titolo | Ruolo | Dim. | Dip. | File disgiunti da |
|---|---|---|---|---|---|
| M35B-1 | CORE: tabelle per zona, tiro della risorsa, via la raccolta mirata, sim, test | CORE | M | design M35B | 2, 3 |
| M35B-2 | DATA: `gen_nodes.gd`, `nodes.json`, profilo in `balance.json`, guida | DATA | S | 1 (loader che legge `resources`) | 1, 3 |
| M35B-3 | UI: «Si trova in» con percentuali, via «Raccogli questa», scheda del nodo, screenshot | UI | S | 1 + 2 | 1, 2 |
Ordine: **1 → 2 → 3**; massimo 2 agenti insieme: 1 e 2 possono partire insieme (codice contro dati) ma i test sui dati veri passano solo dopo il merge di entrambi. **Merge in blocco**:
CORE toglie API che la UI di M35 usa (`set_focus`, `focus_of`, chiavi di stato) e non può toccare `ui/**`; quindi il Reviewer fonde 1, 2 e 3 uno dopo l'altro **prima** di lanciare
`run_checks.ps1` (i branch si tagliano da `main` + il precedente; tra i merge `main` non passa la suite UI né `validate_data` sui dati veri: è atteso). Nessun'altra sessione M35 è attiva.

## M35B-1: CORE
- **Leggere**: `01_GDD_M35B.md` §43.2-§43.4; `02_FORMULAS_M35B.md` (tutta); `05_INTERFACES_M35B.md` §3i-§6i; `04_DATA_SCHEMA_M35B.md` §36.1 (solo per il loader e il validatore);
  `systems/encounters/encounter_cycle.gd`, `node_work.gd`, `cycle_state.gd`, `systems/disciplines/disciplines.gd` e `gather_focus.gd`, `core/data/` (`AreaNodesDef`, `NodeEntryDef`, validatore
  dei nodi, `GameData.area_nodes`), `core/session/rng_service.gd` (`pick_weighted`), `tools/sim_encounters.gd`.
- **Ownership**: `systems/encounters/**`, `systems/disciplines/**` (**cancella** `gather_focus.gd`), `core/data/**` (loader/validatore di `resources`, `NodeResourceDef`, `GameData.zones_of_action`,
  validatore di `encounters.resource_profile`), `core/autoload/event_bus.gd` (toglie il segnale), `core/common/reasons.gd` (solo se `LEVEL_TOO_LOW` resta senza usi), `tests/core/autoload/test_event_bus.gd`,
  `tests/systems/encounters/**`, `tests/systems/disciplines/**` (cancella `test_focus.gd`; cancella `tests/systems/encounters/test_gather_focus.gd`), `tests/integration/test_m35_offline_equivalence.gd`
  e `tests/integration/test_m35b_*.gd` (nuovi), `tests/fixtures/data/**` (solo `encounters/nodes.json`: una risorsa con peso 100 per voce), `tools/sim_encounters.gd`. **Non toccare**: `ui/**`,
  `data/**` (è M35B-2: per i test sui dati veri attendere il merge; i test del CORE usano fixture e `GameData` costruiti nel test), `tools/gen_nodes.gd`, `docs/**`.
- **Accettazione** (ogni punto = un test, con gli esempi di `02_FORMULAS_M35B.md` come casi):
  1. **F-200**: tutti gli esempi (zona 3 `L` 45/25/5, nodo saltato, zona 10 fallback/Ossidiana/Astrite, zona 1 Rame/Ferro); **posizione del generatore**: nessun avanzamento con `|E| ≤ 1` e nodo
     saltato, **un** `pick_weighted` con `|E| ≥ 2` (con un RNG finto che registra le chiamate), poi il tiro del nodo ricco; risorsa fissata all'inizio e uguale dopo salva/ricarica a metà nodo
     (nessun tiro al caricamento); colore invariato (F-154: gli esempi di colore di `02_FORMULAS_M24.md` passano con le risorse date, non più con il tetto).
  2. **Tiro reale**: con seme fisso, 10.000 nodi nella zona 3 a `L` 45 danno frequenze entro ±2 punti da 5/25/55/15 (statistico, un solo test).
  3. **F-202**: `resource_odds` (nominale, effettiva, `workable`; esempi zona 3 `L` 25/45/5); `GameData.zones_of_action` (Ferro, Rame, Riftite con l'ordinamento di F-202) su dati con tabelle proprie.
  4. **F-203**: media dell'XP atteso (esempio 38,2% zona 4 `L` 40, 100% zona 1 `L` 10) in `test_expected_resource.gd`; `tools/sim_encounters.gd` usa la risorsa attesa al posto di `worked_action` e
     stampa le medie per zona e disciplina e le soglie (2) e (3) di F-156 **come misura** (nessun fallimento di build: Q226); chiede i pesi a `resource_odds`.
  5. **Via la raccolta mirata**: `set_focus`, `focus_of`, `GatherFocus`, `gather_focus_changed`, `focused`/`focus_blocked`/`worked_action` non esistono più (nessun riferimento nel codice del CORE: `Grep`);
     `reset_skill`/`unlearn` invariati nei loro effetti; `to_save` non scrive `focus`; `from_save` con `disciplines.focus` presente lo **ignora** senza errore (test con un v12 di M35); `format_version` 12.
  6. **Validatore**: i casi rifiutati di §36.1 (mancante, vuoto, azione di altra disciplina, doppia, livelli non crescenti, peso 0, somma ≠ 100, azione non raggiungibile in nessuna zona); fixture valide.
  7. **Offline**: `test_m35_offline_equivalence` aggiornato e `tests/integration/test_m35b_offline_resource.gd`: 12 h in un colpo = passi da 100 ms = blocchi da 60 s con una zona a ≥ 2 risorse idonee,
     **stessa sequenza di risorse** e stato finale uguale; tutorial: nodo forzato in zona 1 a `L` 1 senza tiri.
  8. Regressione: `test_head_balance.gd` e gli altri che usavano `worked_action` passano un'azione data (`data.action(...)`); tutti i test di `encounters`, `disciplines`, `armory`, `modifiers` e i golden
     dei nodi restano verdi (le fixture hanno una risorsa sola: nessun tiro in più); i test con dati veri che avviano un nodo a `L` ≥ 10 con ≥ 2 idonee **possono cambiare sequenza**: il CORE li
     elenca nel report e li adegua solo se sono sequenze scritte a mano (mai tolti).

## M35B-2: DATA
- **Leggere**: `04_DATA_SCHEMA_M35B.md` (tutta); `02_FORMULAS_M35B.md` F-201 (regola e tabella); `tools/gen_nodes.gd`; `data/combat/areas.json` (`level_min`, `level_max`, `order`);
  `data/actions/{forestry,quarrying,angling,herbalism}.json` (id e livelli); `data/config/balance.json` (`encounters`); `data/guide/*.json` che parlano di raccolta o aree.
- **Ownership**: `tools/gen_nodes.gd` (**regola F-201**, `--check`, errori), `data/encounters/nodes.json` (rigenerato), `data/config/balance.json` (solo `encounters.resource_profile`),
  `data/guide/*.json` (solo le righe su dove trovare le risorse), `tests/tools/test_gen_nodes.gd` e `tests/data/test_node_resources_data.gd` (nuovi). **Non toccare**: codice del gioco
  (`core/`, `systems/`, `ui/`), `tests/fixtures/**`, `docs/**`.
- **Accettazione**:
  1. `gen_nodes.gd`: calcola `h`, profilo, normalizzazione a 100 col resto più grande (F-201) **per le quattro discipline, dalle azioni lette in `data/actions/`**; il profilo viene da `balance.json`;
     idempotente; `--check`; errore (exit 1, nulla scritto) se una disciplina ha meno azioni del profilo richiede o una zona senza voci; il Rame ha 79% in `redrock_plains`.
  2. Le tabelle del file coincidono con la tabella di F-201 per tutte e 10 le zone (test riga per riga sul Minatore; per le altre discipline stessa forma con i loro id); ogni lista somma 100; ogni
     azione di raccolta compare in almeno una zona; in ordine di livello crescente.
  3. `-s tools/validate_data.gd` sui dati veri: verde (dopo il merge del CORE); `-s tools/gen_nodes.gd -- --check`: «up to date».
  4. Controllo di raggiungibilità dei dati che citano risorse (`data/quests/**`, `data/tutorial/**`, `data/hints/**`): ogni azione citata esiste ed è trovabile in qualche zona con livello
     ≤ quello richiesto dall'obiettivo; eventuali eccezioni nel report (non si cambiano quest o tutorial).
  5. Guida: testo breve a mano («ogni zona ha le sue percentuali…»), niente tabella nuova.

## M35B-3: UI
- **Leggere**: `01_GDD_M35B.md` §43.3; `05_INTERFACES_M35B.md` §7.ad e §5.47; `ui/pages/skill/resource_table.gd/.tscn`, `resource_row.gd`, `skill_page.gd`, `ui/pages/combat/node_card.gd` e
  `node_card_texts.gd`, `GuideIndex.uses_of`; `tests/ui/test_resource_table_smoke.gd`; `tools/shot_m35.gd`.
- **Ownership**: `ui/pages/skill/**` (resource_table, resource_row, testi centralizzati: nessun testo nuovo fuori da `UiStyle`/file di testi), `ui/pages/combat/node_card.*` e `node_card_texts.gd`
  **solo** per togliere `FocusLabel` e i testi «Mirata» e «Qui lavori solo fino a …», `tests/ui/test_resource_table_smoke.gd`, `tools/shot_m35.gd` (+ `.tscn`). **Non toccare**: `systems/**`,
  `core/**`, `data/**`, altre pagine.
- **Accettazione**: nessun riferimento a `focus_of`, `set_focus`, `focus_requested`, `FocusButton_*`, `AutoButton`, «Mirata» (`Grep`); colonna «Si trova in» con una riga «Zona NN%» per zona
  (da `GameData.zones_of_action`), zona attuale evidenziata, tooltip con la probabilità effettiva; risorsa bloccata dal livello ancora con «Si trova in»; la UI **non calcola** percentuali,
  colori o ordine (tutto dal modello); `NodeCard` senza le due righe; screenshot 1280x720 e 1600x900 (pagina del Minatore con la tabella in zona 1 e in una zona alta; scheda del nodo); smoke
  test (colonne presenti, righe senza bottone, «Si trova in» con le percentuali attese per una risorsa nota).
