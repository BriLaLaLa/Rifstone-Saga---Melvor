# 07. Task, M36: Pagina di raccolta a schede (solo UI, i «must»)

Estensione di `07_TASKS.md`. Fonte: V46, `01_GDD_M36.md` (§44), `05_INTERFACES_M36.md` (§7.ae), Q228-Q236. Il design non si riscrive nei brief. `sonnet`; save v12 invariato; **nessuna modifica a
`core/**`, `systems/**`, `data/**`**. Lezioni come `07_TASKS_M35B.md`: `git checkout -B task/<ID> main`; mai `-gtest=`; test mirati con il filtro di `CLAUDE.md`; screenshot 1280x720 e 1600x900
in cartelle separate guardati con Read; togliere i `*.uid` non tracciati prima del merge; nessun processo Godot in background; `run_checks.ps1` una sola volta **dopo il merge di entrambi**;
file ≤ 400 righe (**`skill_page.gd` è a 399**: M36-1 deve estrarre, non aggiungere); i test esistenti restano verdi: cambiano solo quelli dichiarati.

| ID | Titolo | Ruolo | Dim. | Dip. | File disgiunti da |
|---|---|---|---|---|---|
| M36-1 | UI: schede, Panoramica base, Attrezzo compatto con Teste richiudibili | UI | M | design M36 | 2 |
| M36-2 | UI: Risorse compatte con dettaglio al clic e «Vai» | UI | S | design M36 | 1 |
Ordine: 1 e 2 possono partire insieme (contratto di §7.ae). **Merge: 2 poi 1** (1 collega `ResourceTable.zone_requested`, introdotto da 2); il test di collegamento «Vai» si scrive in 1 dopo il merge di 2.

## M36-1: schede, Panoramica, Attrezzo
- **Leggere**: `01_GDD_M36.md` §44.2 (Panoramica, Attrezzo), §44.3-§44.4; `05_INTERFACES_M36.md` §7.ae; `ui/pages/skill/skill_page.gd` e `.tscn`, `tool_upgrade_panel.gd/.tscn`,
  `tool_upgrade_texts.gd`, `head_section.gd`, `skill_header.gd`, `node_color_preview.gd`, `gathering_info.gd`; `ui/pages/combat/combat_texts.gd` (`REASON_TEXTS`, colori).
- **Ownership**: `ui/pages/skill/skill_page.gd` e `skill_page.tscn`, `ui/pages/skill/gather/**` (nuova cartella: `gather_body.gd`, `gather_overview.gd`, `overview_texts.gd`), `ui/pages/skill/foldable_section.gd`,
  `tool_upgrade_panel.gd/.tscn`, `tool_upgrade_texts.gd`, `head_section.gd`, **cancella** `gathering_info.gd` (e il suo `.uid`), `tests/ui/test_gather_body_smoke.gd` (nuovo), i test UI esistenti che
  citano `GatheringInfo` o il pannello attrezzo, `tools/shot_m36.gd` (+ `.tscn`). **Non toccare**: `resource_table.gd`, `resource_row.gd`, `resource_texts.gd`, `resource_detail.gd` (M36-2), `core/**`,
  `systems/**`, `data/**`, altre pagine.
- **Accettazione**:
  1. Una pagina di raccolta ha la barra **Panoramica · Risorse · Attrezzo** (`GatherBody`), apre su Panoramica; le pagine di produzione e l'Incisore sono invariate (test: `Cards`/`ProfessionView` come oggi).
  2. **Panoramica**: zona attuale con le risorse della disciplina (nome, % nominale da `zones_of_action`, pallina del colore da `NodeColorPreview`, «non ancora lavorabile»), caso «nessuna zona»;
     riga attrezzo con bottone che porta alla scheda Attrezzo; i contenitori `StatsSection`, `ProgressSection`, `NeedsSection` esistono **nascosti** e vuoti.
  3. **Attrezzo**: una riga (nome «+N», effetto principale, costo del prossimo passo, **Raffina**), sotto `FoldableSection` «Teste» **chiusa all'apertura**; scegliere una testa e raffinare funzionano come prima
     (stessi comandi, stessi rifiuti mostrati).
  4. `SkillPage` rimane ≤ 400 righe (estrarre in `GatherBody`); nessun riferimento a `GatheringInfo` (`Grep`); nessun calcolo nella UI (percentuali, colori, ordine, effetti dal modello).
  5. `go_to_area_requested` inoltrato a `session.combat.start(area_id)` con rifiuto mostrato (test con una sessione finta o vera: area sbloccata → combattimento avviato; area non sbloccata → testo).
  6. Screenshot 1280x720 e 1600x900 (le tre schede del Minatore e dell'Erborista, Teste aperte e chiuse); smoke test (tre schede presenti, Teste chiuse, contenitori M36B nascosti).

## M36-2: Risorse compatte
- **Leggere**: `01_GDD_M36.md` §44.2 (Risorse), §44.3; `05_INTERFACES_M36.md` §7.ae; `ui/pages/skill/resource_table.gd`, `resource_row.gd`, `resource_texts.gd`, `mastery_bonus_tag.gd`,
  `node_color_preview.gd`; `tests/ui/test_resource_table_smoke.gd` e gli altri test che citano `ResourceRow`/`ResourceTable`.
- **Ownership**: `ui/pages/skill/resource_table.gd`, `resource_row.gd`, `resource_texts.gd`, `resource_detail.gd` (nuovo), `mastery_bonus_tag.gd` (solo se serve la riga breve «Prossimo bonus»),
  `tests/ui/test_resource_table_smoke.gd`, `tools/shot_m36b_resources.gd` (+ `.tscn`, solo screenshot). **Non toccare**: `skill_page.gd`, `gather/**`, `tool_upgrade_*`, `core/**`, `systems/**`, `data/**`.
- **Accettazione**:
  1. Riga compatta: icona e nome, livello (rosso se bloccato), scorta, **Zona** (zona con la % nominale più alta = prima voce di `zones_of_action`, formato «Zona NN%»), pallina del colore (tooltip: nome del colore e % XP);
     **nessuna** colonna Prezzo, «Serve a», «Poi:», testo del colore, nessun filtro testo né «Solo con scorta» (Grep dei testi tolti).
  2. **Clic sulla riga** apre/chiude `DetailBox_<id>` (una sola aperta: aprirne una chiude le altre): zone con % nominale e tooltip con % effettiva (`resource_odds`), **«Vai»** per zona
     (`GoButton_<id>_<area>`; disabilitato nella zona attuale; emette `zone_requested(area_id)`), «Serve a» (≤ 3 voci da `GuideIndex`), prezzo, maestria (livello, tag, una riga «Prossimo bonus: …» breve).
  3. Risorsa bloccata dal livello: riga in grigio, dettaglio apribile, «Vai» presente (la zona esiste) ma la riga lo dice con il testo «livello N»; nessuna logica nella UI (livello, % e ordine dal modello).
  4. Ridisegno su `bank_changed` ecc. mantiene la riga aperta (stato di vista) e non crea nodi duplicati; screenshot 1280x720 e 1600x900 (tabella chiusa, una riga aperta, riga bloccata);
     smoke test (colonne, apertura/chiusura, una sola aperta, «Vai» emette il segnale con l'area giusta, assenza dei testi tolti).
