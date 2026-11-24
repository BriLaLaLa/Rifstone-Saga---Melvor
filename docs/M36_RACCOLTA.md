# M36: Pagina di raccolta, proposta (DESIGN, in attesa delle scelte dell'utente)

> **Esito (2026-11-24)**: l'utente ha scelto: 3 schede (Panoramica, Risorse, Attrezzo) con Progressione e «Cosa ti serve» nella Panoramica; statistiche da quando apri il gioco; «Cosa ti serve» = coda + Bacheca, solo la disciplina (+ contatore altre); M36 = «must» (UI), M36B = «should» (CORE + UI). Il design definitivo è in `01_GDD_M36.md`, `02_FORMULAS_M36.md`, `05_INTERFACES_M36.md`, `07_TASKS_M36.md`, `07_TASKS_M36B.md` (V46). Questo file resta come analisi.


Richiesta dell'utente: «dobbiamo ripensare il senso delle tab della raccolta, adesso ci sono tantissime scritte che non servono a nulla… cosa ci potremmo mettere lì? di solito negli
altri giochi cosa ci mettono?». Documento di proposta: nessuna regola è ancora in GDD/formule. Dopo le scelte: V in `DECISIONS_LOG.md`, Q in `OPEN_QUESTIONS.md`, GDD §44,
F-204…, schema, `05_INTERFACES_M36.md`, `07_TASKS_M36.md`.

## 1. Stato attuale (letto dal codice)
`SkillPage` (`ui/pages/skill/skill_page.gd`, 399 righe) di una disciplina di raccolta mostra, in verticale: intestazione (livello, XP, barra pool di maestria, stato «Nodo in corso»),
riga «Si trova in» (`GatheringInfo`, ormai ridondante con la colonna omonima), `ToolUpgradePanel` (attrezzo, Raffina, **Teste sempre aperte**), `ResourceTable` (filtro, «Solo con scorta»,
una `ResourceRow` per risorsa con 8 colonne: Risorsa, Liv., Scorta, **Serve a** (testo di `GuideIndex.summary_line`), **Prezzo**, **Maestria** (livello + tag + **«Poi: …»** testo lungo),
**Colore ora** (nome + % XP), **Si trova in** (zone con %)). Non c'è nulla che dica «cosa devo fare adesso»: tutte le colonne sono dati di catalogo.

## 2. Cosa fanno gli altri giochi (idle/MMO con raccolta)
- **Melvor / RuneScape**: pagina per skill con *un solo* scopo: scegliere il nodo da lavorare; mostrano XP/h, tempo al livello, fabbisogno nel proprio zaino; la maestria è una scheda a parte.
- **Albion / WoW (professioni)**: lista risorsa → «dove si trova» (mappa/zone), non prezzi; i prezzi stanno nel mercato.
- **Path of Exile / Diablo**: la pagina utile è «cosa mi manca» (liste di obiettivi, requisiti dell'artigianato) più che il catalogo.
Sintesi: le pagine che funzionano rispondono a tre domande: **dove vado?** (zone/percentuali), **come sto andando?** (ritmo, tempo al prossimo livello), **cosa mi serve?** (fabbisogni
di coda e incarichi). Le colonne di catalogo (prezzo, «serve a» in forma lunga) stanno nel dettaglio al clic o nella Guida.

## 3. Proposta: cinque schede (`TabContainer` o barra a bottoni, scelta della UI)
Legenda lavoro: **S**olo UI · **C**ORE nuovo (calcolo nel modello, testabile) · **D**ato già disponibile. Taglia: S/M/L del task.

### 3.1 Panoramica (**must**)
Risponde a «come sto andando».
| Elemento | Origine | Lavoro |
|---|---|---|
| Zona attuale (`combat.area_id()`), risorse lavorabili qui con % nominale e colore XP al livello (rosso/giallo/verde…), a colpo d'occhio | `zones_of_action`, `EncounterCycle.resource_odds` (% effettiva, `workable`), `NodeColorPreview.of` | **D** + UI |
| Nodo in corso o «prossimo nodo: da fare» | `combat.node_skill()` (già in `SkillHeader.status_text`) | **D** |
| Stato attrezzo in una riga (nome «+N», effetto principale) | `armory.tool_uid`, `modifiers.breakdown` (già usati da `ToolUpgradePanel`) | **D** |
| **Statistiche di sessione**: unità/h, XP/h, nodi fatti, tempo al prossimo livello | segnali `node_finished(units)`, `xp_gained`, `node_started`; `XpTable.xp_to_next` | **C** (vedi §4) |
Il «valore atteso» al posto della sessione (XP/h e unità/h **teoriche** per zona, F-203) è alternativa/aggiunta: **C**, riusa la matematica di `EncounterCycle.expected` (oggi solo di riferimento per
`tools/sim_encounters.gd`, non usata dal gioco).

### 3.2 Risorse (**must**)
Lista compatta, una riga: icona, nome, livello (rosso se bloccato), **scorta**, **migliore zona** (zona lavorabile con % effettiva più alta, con «Vai» se ne esiste una) e un indicatore di colore.
Al clic la riga si apre (dettaglio): tutte le zone con % (oggi la colonna «Si trova in»), «Serve a» in forma breve (`GuideIndex.summary_line`), prezzo di vendita, maestria con livello e **una**
riga «prossimo bonus a liv. N» (non il testo lungo).
| Elemento | Origine | Lavoro |
|---|---|---|
| scorta, livello, colore, zone con %, «serve a», prezzo | `bank`, `skills`, `NodeColorPreview`, `zones_of_action`, `GuideIndex`, `ItemDef.value` | **D** |
| «Migliore zona» (max % effettiva tra le zone lavorabili) | `resource_odds` per zona (F-202) | **D** (UI sceglie il massimo; meglio un'unica funzione CORE `best_zone`, **C** piccola, per avere il test) |
| «Vai in zona» (clic) | comando che cambia zona di combattimento: la mappa/`combat` ha già l'entrata in zona; verificare la firma in `05_INTERFACES` (possibile solo se la zona è sbloccata) | **D** se esiste `combat.enter_area`; altrimenti segnalare |
Tolti dalla riga: colonna **Prezzo**, **«Poi: Al livello N…»**, colonna «Serve a» estesa, testo «Colore ora» lungo (resta una pallina colorata + % XP in tooltip), filtro testuale
(**should** tenerlo solo con > 8 risorse; «Solo con scorta» **later**).

### 3.3 Progressione (**should**)
Risponde a «cosa sblocco».
| Elemento | Origine | Lavoro |
|---|---|---|
| Prossima soglia di livello della disciplina: XP mancanti, tempo stimato (con XP/h di §3.1) | `skills.get_xp`, `XpTable.xp_to_next` | **D** + XP/h (**C**) |
| Cosa si sblocca al prossimo livello utile: risorse (`action.level`), zone con una nuova risorsa (`zones_of_action`), testa dell'attrezzo (passo +N dal livello `tool_next_step`) | `actions_for_skill`, `zones_of_action`, `armory.tool_next_step` | **C** piccola: una funzione `next_unlocks(skill, level)` che restituisce l'elenco (UI non deve scorrere i dati) |
| Maestria: pool corrente/tetto (`get_pool`, `get_pool_cap`), prossima tacca per risorsa (25/50/99, `milestones_reached`, `step_info.next`), bottone «Apri maestria» (c'è già) | `MasterySystem` | **D** |

### 3.4 Cosa ti serve (**should**; la parte più nuova; taglia **M**)
Elenco delle **risorse mancanti** di questa disciplina, per motivo, ciascuna con la migliore zona (come §3.2):
1. **Coda di produzione**: per ogni job `ActionRunner.jobs()` con `inputs` dell'`ActionDef` × cicli (`remaining`, o `cycles_possible` se `repeat`), meno scorta in `bank`.
2. **Incarichi attivi**: `Quests` (`quest_at/progress_at/target_at` + `QuestDef.type == gather`, `item`) → mancano `target - progress` unità di `item`.
3. **Primi passi** (`StarterQuests`): l'obiettivo è una `TutorialCondition` (event/metric): solo se `gather` con un item identificabile; verificare nei dati (`data/tutorial/starter_quests.json`);
   altrimenti **later**.
| Elemento | Origine | Lavoro |
|---|---|---|
| Fabbisogno aggregato `{item_id: {need, have, motivi: [coda, incarico]}}` | `ActionRunner.jobs`, `ActionDef.inputs`, `Quests`, `bank.get_count` | **C** (nuova classe in `systems/`, es. `Needs`, sola lettura, nessuno stato salvato, test con esempi F-204) |
| Rotta per risorsa → disciplina → zona migliore | `ActionDef.skill_id`, `zones_of_action`, `resource_odds` | **D** |
Nota di modello: una risorsa mancante può appartenere a *un'altra* disciplina (es. un'azione di Forgia che chiede Rame): la scheda di una disciplina mostra solo le sue risorse e un contatore
«+N di altre discipline» con link alla loro pagina (**should**); l'elenco globale è **later** (potrebbe stare nella Bacheca/Deposito).

### 3.5 Attrezzo (**must**, compatto)
Una riga: nome, «+N», effetto principale (da `modifiers.breakdown`), costo del prossimo passo («posseduto/richiesto») e bottone **Raffina**; bottone **Teste** che apre il pannello
(oggi `HeadSection`, sempre aperto) in una finestra o in una sezione richiudibile. Nessuna nuova logica: `ToolUpgradePanel` si riorganizza (**S**, solo UI). Priorità **must** perché è l'unica
azione del giocatore sulla pagina.

## 4. Statistiche di sessione: il punto con logica (taglia M)
Precedente: `CombatYield` (UI) è una finestra scorrevole di 1 h su eventi, **non salvata**, che parte all'apertura della pagina. Per la raccolta ha due problemi: (a) la pagina si distrugge
quando si cambia scheda/pagina, e la statistica ripartirebbe da zero ogni volta; (b) deve valere anche con l'app aperta ma la pagina chiusa e **non** contare l'offline come ritmo (12 h in un
colpo falserebbero il «per ora»).
Raccomandazione: un piccolo lettore nel modello, `GatherStats` (in `systems/encounters/` o `systems/skills/`), creato da `GameSession`, **non salvato** (parte da zero a ogni caricamento: «da
quando hai aperto il gioco»), che ascolta `node_finished`, `xp_gained`, `node_started` e tiene per disciplina {nodi, unità, XP, tempo di gioco attivo}; legge `session.play_time_ms`
(come `CombatYield`) e **ignora gli eventi dell'offline** (verificare in `offline/` se i segnali partono: se sì serve un flag; nota per il CORE). Formule: F-204 (unità/h, XP/h = totale ÷
tempo attivo, nulle sotto 1 s di campione come `MIN_ELAPSED_MS`), F-205 (tempo al livello = `xp_to_next(livello) - xp nel livello` ÷ XP/h, vuoto se XP/h = 0). Esempi → test.
Alternativa **leggera** (S): tenere la finestra nella pagina come `CombatYield`, accettando che riparta aprendo la pagina. Non consigliata: la scheda Panoramica sarebbe vuota ogni volta.

## 5. Da togliere
| Cosa | Dove | Perché |
|---|---|---|
| Colonna **Prezzo** | `ResourceRow`, `ResourceTexts.COLUMNS` | il prezzo serve a vendere: sta nel Deposito/Bottega; resta nel dettaglio al clic |
| Testo **«Poi: Al livello N…»** | `ResourceRow._next`, `NEXT_BONUS_TEXT` | lungo, ripetuto per riga; passa a Progressione, una volta per risorsa in forma breve |
| Colonna **«Serve a»** lunga | `_uses` | sposta nel dettaglio; resta nella Guida |
| **Colore ora** testuale | `_color` | una pallina colorata + % XP in tooltip |
| **Teste** sempre aperte | `HeadSection` in `ToolUpgradePanel` | sezione richiudibile o bottone |
| Riga **«Si trova in:»** della pagina | `GatheringInfo` | duplicata dalla scheda Risorse (resta il testo per la Guida se serve) |
| Filtro testo | `ResourceTable` | utile solo con tante righe: **later** |

## 6. Priorità e taglia
| Voce | Priorità | Lavoro | Taglia |
|---|---|---|---|
| Struttura a schede + Attrezzo compatto + Teste a richiesta | must | UI | S |
| Risorse compatte con dettaglio al clic (zone/% da `zones_of_action`) | must | UI (+ `best_zone` CORE piccolo) | S |
| Panoramica base (zona attuale, colore, nodo, attrezzo) | must | UI | S |
| `GatherStats` + F-204/F-205 (statistiche di sessione, tempo al livello) | should | **CORE** | **M** |
| Progressione con `next_unlocks` | should | CORE piccolo + UI | S/M |
| «Cosa ti serve» (`Needs`: coda + incarichi + zona migliore) | should | **CORE** + UI | **M** (L se si aggiunge «Primi passi» e l'elenco globale) |
| «Vai in zona» al clic | should | UI (se il comando esiste) | S |
| XP/h attesi per zona (F-203 portato nel gioco) | later | CORE | S |
| Elenco globale dei fabbisogni di tutte le discipline | later | CORE+UI | M |

## 7. Task proposti (quando le scelte sono fatte; file disgiunti)
- **M36-1 CORE**: `GatherStats`, `Needs`, `best_zone`, `next_unlocks` in `systems/**` (+ composizione in `GameSession`/`session_participants` solo se serve) e test; nessun file in `ui/**`.
- **M36-2 UI**: `ui/pages/skill/**` (schede, `ResourceRow` compatta, `ToolUpgradePanel` compatto, panoramica, «Cosa ti serve»), smoke test della pagina; usa le API di M36-1.
- Ordine: 1 → 2 (la UI di base «must» può partire prima con dati già esistenti; le schede «should» attendono il CORE). Nessun cambiamento di save (le statistiche non si salvano).

## 8. Domande per l'utente
1. **Schede**: ok le cinque (Panoramica, Risorse, Progressione, Cosa ti serve, Attrezzo)? Raccomandazione: **sì, ma «Cosa ti serve» e «Progressione» come sezioni della Panoramica** se la pagina deve restare a 3 schede (Panoramica, Risorse, Attrezzo).
2. **Statistiche di sessione**: da quando apri il gioco (consigliato, non salvato, ignora l'offline) o da quando apri la pagina (più semplice, riparte ogni volta)?
3. **«Cosa ti serve»**: coda + Bacheca (consigliato) o anche «Primi passi»? Solo la disciplina della pagina (+ contatore delle altre) o un elenco globale?
4. **«Vai in zona»**: se serve davvero cambiare zona con un clic (consigliato) o basta mostrare il nome della zona migliore?
5. **Prezzo**: tolto dalla tabella e tenuto nel dettaglio (consigliato), o via del tutto?
6. **Priorità**: tutto in M36 o prima i «must» (struttura + risorse compatte + attrezzo), e i «should» (CORE) in M36B?
