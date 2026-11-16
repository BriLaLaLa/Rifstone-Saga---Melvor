# 02. Formule, §5l: Incontri e Mestieri (F-153…F-160; M24, V16-V24)

Estensione di `02_FORMULAS.md` (che supera le 400 righe): vale come la sua sezione **§5l**, con le tabelle §8.10-§8.11 e le chiavi §9b.
Convenzioni di `02_FORMULAS.md` (`floor`, `round` a metà verso l'alto, `T(stat, ctx)` = F-05). Gli esempi sono **casi di test**. Valori di
partenza fissati da M24-01, chiavi in `balance.json` (§9b) e in `data/disciplines/trainers.json` (`04_DATA_SCHEMA_M24.md` §29); la verifica di
bilanciamento è di `tools/sim_encounters.gd` (M24-07). Regole in `01_GDD_M24.md` (§35).

## F-153 Viaggio e tipo del prossimo incontro
Alla fine di ogni incontro di un'**area** (scontro vinto, nodo lavorato o saltato; mai in Frattura o Dungeon):
1. `travel_ms = encounters.travel_ms` (2.500), fisso (nessuna stat in M24).
2. Tipo del prossimo incontro, deciso **ora**, tiri su `session.rng` in quest'ordine:
   - Monolito in attesa (F-87) o miniboss in attesa (F-139, tirato prima in `_cleared`) → `fight`, **nessun tiro**;
   - area senza voce in `nodes.json` o senza nodi → `fight`, nessun tiro;
   - altrimenti `roll_pct(encounters.node_chance_pct)` (25): fallito → `fight`; riuscito → `node`, e la disciplina è
     `entries[rng.pick_weighted(pesi)]` (pesi interi delle voci dell'area, nell'ordine del file).
3. Se la disciplina scelta non è appresa (`Disciplines.is_learned`) il nodo sarà **saltato** (F-155); nessun tiro in più.
Il primo incontro dopo `start(area)` è sempre `fight` (nessun viaggio, come oggi).
Esempi (area con pesi `forestry 40, quarrying 20, angling 30, herbalism 10`): Monolito in attesa → `fight` e la sequenza del generatore non avanza;
`node_chance_pct` 0 → sempre `fight`; 100 → sempre `node`; con `pick_weighted` che restituisce 2 → `angling`; area senza nodi → `fight`.
Test: `tests/systems/encounters/test_encounter_cycle.gd`.

## F-154 Risorsa lavorata e colore
Per un nodo della disciplina `s` con tetto `M` (`max_level` della voce dell'area) e `L` = livello di `s` (F-01, già limitato da F-160):
- **risorsa**: l'azione di raccolta di `s` con il `level` più alto tale che `level ≤ min(L, M)` (a parità, la prima nel file). Esiste sempre (il gradino 1 ha
  livello 1). La risorsa si fissa **all'inizio** del nodo e si salva.
- **colore** alla **fine** del nodo: `d = L − level` (≥ 0); il colore è la prima voce di `encounters.colors` (in ordine) con `d < below`:
  `orange` (below 10, `xp_pct` 100), `yellow` (20, 50), `green` (30, 20), `grey` (100, 0).
Esempi (gradini 1, 10, 20, 30, 45, 60, 75, 90): `L` 27, `M` 30 → risorsa di livello **20**, `d` 7 → **arancione**; `L` 45, `M` 30 → **30**, `d` 15 →
**giallo**; `L` 90, `M` 10 → **10**, `d` 80 → **grigio**; `L` 74, `M` 80 → **60**, `d` 14 → **giallo**; `L` 75, `M` 80 → **75**, `d` 0 → **arancione**;
`L` 52, `M` 50 → **45**, `d` 7 → **arancione**; `L` 1 → sempre la risorsa di livello 1, arancione.
Test: `tests/systems/encounters/test_encounter_cycle.gd`.

## F-155 Durata e resa del nodo
**Nodo lavorato** (disciplina appresa), `a` = risorsa di F-154, `ctx = ModifierContext.for_action(s, a)`:
- durata `node_ms = max(encounters.node_min_ms, round(encounters.node_ms × (1 + T(skill_interval_pct, ctx)/100)))` (12.000 e 3.000), fissata all'inizio;
- alla fine, `N = encounters.node_units` (80) **unità**, nell'ordine, ognuna con i tiri di un ciclo di raccolta su `session.rng`: doppio (F-06), Frammento (F-07),
  sottoprodotto (F-103 se la maestria di `a` è ≥ 25). Prima di aggiungere un'unità si controlla lo spazio (oggetti nuovi, come `GatheringResolver`): se
  manca, il nodo si chiude qui (`bank_full`) e `n` = unità già messe; altrimenti `n = N`;
- **XP**: `base = floor(n × a.xp × xp_pct(colore) / 100)`, poi F-02 con `T(skill_xp_pct, ctx)`, poi il limite F-160; `base` 0 → nessuna XP né segnale;
- **maestria**: `mxp = n × F-10(a)` (F-10 calcolato una volta, con `L` e `R` di fine nodo prima del guadagno); pool: F-12 su `mxp` (una volta).
**Nodo saltato** (disciplina non appresa): dura `encounters.skip_ms` (1.500); nessun tiro, prodotto, XP o maestria.
Esempi: `p` 0 → **12.000** ms; `p` −10 → **10.800**; `p` −18 → **9.840**; `p` −80 → 2.400 → **3.000**. Betulla (`xp` 10), 80 unità: arancione `base` **800**
(pct 0 → **800**); giallo **400** (pct 15 → **460**); verde **160**; grigio **0**. Doppio 0% → **80** legni; 100% → **160**. Deposito senza posto per il
sottoprodotto alla 37ª unità → `n` = **36**, motivo `bank_full`. Maestria: Betulla con `L` 1 e `R` ≈ 0 (F-10 = 3) → `mxp` **240**, pool **48**.
Test: `tests/systems/encounters/test_node_work.gd`, `tests/systems/actions/test_gathering_resolver.gd` (`resolve_units`).

## F-156 Forma chiusa del ciclo (riferimento per offline e sim)
Simboli: `q = node_chance_pct / 100`; pesi `w_s` dell'area e `W = Σ w_s`; `p_L = Σ_{s appresa} w_s / W`; `E_F` = durata media di uno scontro (da
`encounter_started` a `encounter_cleared`, misurata dalla sim); `N̄ = Σ_{s appresa} w_s × node_ms(s) / Σ_{s appresa} w_s` (0 se nessuna); `S = skip_ms`.
- `E[T] = travel_ms + (1 − q) × E_F + q × (p_L × N̄ + (1 − p_L) × S)` (Monoliti e miniboss in attesa trascurati: < 2% degli incontri);
- incontri all'ora `R = 3.600.000 / E[T]`; scontri `(1 − q) × R`; nodi lavorati di `s` `q × w_s / W × R`; unità di `s` all'ora = nodi × `node_units`;
  XP di `s` all'ora ≈ unità × `a.xp` × `xp_pct / 100` × (1 + pct/100).
Esempio: `travel_ms` 2.500, `q` 0,25, `E_F` 50.000, due discipline apprese con `w_s/W` = 0,25 ciascuna (`p_L` 0,5), `N̄` 12.000, `S` 1.500 →
`E[T]` = **41.687,5** ms; `R` = **86,36**/h; scontri **64,77**/h; nodi lavorati **10,79**/h (**5,40** per disciplina, **431,8** unità/h ciascuna).
Nessuna appresa (`p_L` 0) → `E[T]` **40.375**, scontri **66,87**/h. Motore di prima (`respawn_ms` 1.500, nessun nodo) → 3.600.000 / 51.500 = **69,90**
scontri/h: con il ciclo **−7,3%**.
**Uso**: l'offline **non** usa la forma chiusa (stesso motore a eventi del gioco, §35.9, Q109); `tools/sim_encounters.gd` controlla che 12 ore simulate
diano scontri/h e nodi lavorati/h entro **±5%** di F-156 calcolata con l'`E_F` misurato nella stessa simulazione.
**Soglie di M24-07** (se una salta: nessun ritocco dei dati, si riporta al Reviewer): (1) uccisioni/h con il ciclo ≥ **90%** di quelle con
`node_chance_pct` 0 e `travel_ms` = `combat.respawn_ms`; (2) unità/h di una disciplina appresa al gradino giusto tra **300 e 600**; (3) XP/h di una
raccolta appresa al gradino giusto ≥ **30%** di quella del lavoro dedicato di §8.1 (T1: 12.000 XP/h → ≥ 3.600).
Test: `tests/systems/encounters/test_encounter_cycle.gd` (`expected`), `tools/sim_encounters.gd`.

## F-157 Durata dei lavori di produzione
- **Ciclo** di una ricetta: `cycle_ms = F-03(a.interval_ms, T(skill_interval_pct, for_action(s, a)))`, fissato all'inizio di ogni ciclo.
- **Progetto**: durata F-90, fissata quando arriva in testa alla coda (e consuma i materiali).
- **Stime per la UI** (lette dal modello, mai calcolate dalla UI): lavoro a ripetizioni `r` → `r × cycle_ms − elapsed` (solo la testa ha `elapsed`); lavoro
  "finché ci sono ingredienti" → `c × cycle_ms − elapsed` con `c = min_i floor(posseduti_i / qty_i)` (conservazione e doppio ignorati); coda = somma.
- Coda: al massimo `production.queue_slots` (5) lavori; ripetizioni `1 ≤ r ≤ production.max_job_count` (9.999).
Esempi: Lingotto 2.000 ms, `p` −10 → **1.800**; 50 lingotti → **90.000** ms; Piastra 2.400, `p` −10 → **2.160**, 20 → **43.200**; coda dei due → **133.200** ms;
con 600 ms già fatti del primo ciclo → **132.600**. "Finché ci sono ingredienti" con 37 minerali (2 a ciclo) → 18 cicli → **32.400** ms. Sesto lavoro →
`queue_full`; `r` 0 o 10.000 → `invalid_amount`.
Test: `tests/systems/actions/test_production_queue.gd`.

## F-158 Gradi dei Maestri
Gradi `g` = 1…5 in `data/disciplines/trainers.json` `grades` (ordine): `cap` = **20, 40, 60, 80, 99**; `character_level` = **1, 15, 35, 55, 75**.
- **oro**: `gold(1) = trainer.learn_gold` (0); `gold(g ≥ 2) = round(trainer.gold_base × trainer.gold_growth^(g − 2))` (250, 5) → **250, 1.250, 6.250, 31.250**;
- **imparare** = comprare il grado 1: posto libero nella categoria (`disciplines.max_per_category` 2), livello del personaggio ≥ `character_level(1)`, oro;
- **grado successivo** `g ≥ 2`: livello della disciplina ≥ `cap(g − 1) − trainer.skill_margin` (5), livello del personaggio ≥ `character_level(g)`, oro `gold(g)`.
  Ordine dei controlli: `unknown_id` → `not_a_discipline` → `not_learned` → `max_grade` → `level_too_low` (disciplina) → `requirement_not_met`
  (personaggio) → `not_enough_gold`.
- **grado gratuito della migrazione** (§35.10): il più piccolo `g` con `cap(g) ≥` livello attuale.
Esempi: grado 2 con la disciplina a 14 → `level_too_low` (serve **15**); a 15, personaggio 15, 250 oro → ok; grado 5: disciplina ≥ **75**, personaggio ≥ **75**,
**31.250** oro; spesa totale fino al grado 5: **39.000**. Migrazione: livello 27 → grado **2**; 20 → **1**; 61 → **4**; 99 → **5**.
Test: `tests/systems/disciplines/test_disciplines.gd`.

## F-159 Disimparare
`unlearn_gold(g) = max(trainer.unlearn_min_gold, round(trainer.unlearn_pct / 100 × Σ_{k=1..g} gold(k)))` (100, 50). Poi: XP della disciplina a 0,
maestria (azioni, pool, nodi) a 0, grado 0, lavori della disciplina tolti dalla coda; il posto si libera.
Esempi: grado 1 → **100**; 2 → **125**; 3 → **750**; 4 → **3.875**; 5 → **19.500**. Oro insufficiente → `not_enough_gold`, nulla cambia.
Test: `tests/systems/disciplines/test_disciplines.gd`.

## F-160 Limite di livello del grado
`xp_max(s)` = `xp_curve.xp_cap` se `cap(g) ≥ xp_curve.max_level`, altrimenti `xp_for_level(cap(g))` (F-01); disciplina non appresa → nessun guadagno;
Incisore e skill senza disciplina → `xp_cap` (come oggi). In `SkillsSystem.add_xp`: `xp' = min(xp + granted, xp_max)`; se `xp + granted > xp_max` la
differenza è **persa** e si emette `xp_capped(skill, persa)` (dopo `xp_gained`, se c'è stato un guadagno).
Esempi: grado 1, XP 4.900, guadagno 100 → XP **4.941** (livello 20), persa **59**; grado 1 già a 4.941 → nessun `xp_gained`, `xp_capped(s, 100)`;
grado 2 → `xp_max` **34.011**; grado 3 → **206.723**; grado 4 → **1.327.438**; grado 5 → **50.000.000**.
Test: `tests/systems/skills/test_skills_cap.gd`.

## 8.10 Erborista (`herbalism`, M24-05)
Otto erbe agli stessi gradini di §8.1 (livello, intervallo, XP, quantità, valore); 8 sottoprodotti (traguardo 25), traguardi 50/99 come gli altri mestieri
(§8.8b, stat a scelta del Data Designer tra quelle della raccolta) e un albero della maestria proprio (6-8 nodi). Nessun attrezzo in M24 (Q111).

## 8.11 Alchimia (ricette di `hearthcraft`, `discover: true`, M24-05)
| Ricetta (gradino n) | Ingredienti | Intervallo | XP | Cura (`food.heal`) | Valore |
|---|---|---|---|---|---|
| Tonico Tn | 2 × erba Tn + 1 × pesce crudo Tn | 3.000 | `floor(1,2 × XP raccolta Tn)`: 12, 21, 33, 48, 69, 96, 129, 174 | `round(1,5 × cura del pesce cotto Tn)`: 30, 53, 83, 120, 165, 225, 300, 390 | `2 × valore erba Tn + 2 × valore pesce Tn`: 4, 12, 24, 40, 72, 120, 200, 340 |
Livello della ricetta = livello del gradino. Ingredienti **solo grezzi** (mai il pesce cotto): la regola del validatore della Casa d'Aste (M23-01) vieta che
un oggetto acquistabile sia ingrediente di un'azione. Il valore raddoppia solo la parte del pesce, come la cottura (§8.2): nessun guadagno nuovo a
trasformare e rivendere (F-151). Il Tonico è un cibo, quindi entra tra gli acquistabili della Casa d'Aste rigenerata (§34.2).
Le **Ricette** (oggetti `recipe`, valore 0) cadono dalle tabelle di drop delle aree il cui `level_max` ≥ livello del gradino; obiettivo circa **una Ricetta
del gradino dell'area ogni 2 ore** di combattimento (probabilità scelte da M24-05, misurate da M24-07). **Lastra runica** (§8.7): ingredienti
`rift_dust` × 3 + `rift_shard` × 1 (niente minerale), stesso intervallo e XP.

## 9b. Chiavi di `balance.json` (M24)
| Chiave | Valore | Formula |
|---|---|---|
| `encounters.travel_ms` | 2500 | F-153 |
| `encounters.node_chance_pct` | 25 | F-153 |
| `encounters.node_ms` / `node_min_ms` | 12000 / 3000 | F-155 |
| `encounters.skip_ms` | 1500 | F-155 |
| `encounters.node_units` | 80 | F-155 |
| `encounters.colors` | `[{"id":"orange","below":10,"xp_pct":100}, {"id":"yellow","below":20,"xp_pct":50}, {"id":"green","below":30,"xp_pct":20}, {"id":"grey","below":100,"xp_pct":0}]` | F-154 |
| `disciplines.max_per_category` | 2 | F-158 |
| `trainer.learn_gold` / `gold_base` / `gold_growth` | 0 / 250 / 5 | F-158 |
| `trainer.skill_margin` | 5 | F-158 |
| `trainer.unlearn_pct` / `unlearn_min_gold` | 50 / 100 | F-159 |
| `production.queue_slots` / `max_job_count` | 5 / 9999 | F-157 |
Tolte: `helper` (tutta la sezione, F-101/F-102 eliminate). Invariata: `combat.respawn_ms` (solo Fratture). `village.woodwright_levels` resta con lo stesso nome e
gli stessi valori ma è confrontato con il **livello del personaggio** (§35.8, nome storico, Q114). Regole del validatore in `04_DATA_SCHEMA_M24.md` §29.6.
