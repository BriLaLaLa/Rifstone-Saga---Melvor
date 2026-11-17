# 02. Formule, §5m: Nodi con tentativi (F-161…F-165; M25, V25-V26)

Estensione di `02_FORMULAS.md` e `02_FORMULAS_M24.md` (§5l): **modifica** F-155 (resa del nodo) e F-156 (forma chiusa), non F-153 né F-154 (risorsa e
colore restano; il colore si calcola ora a ogni tentativo). Convenzioni: `floor`, `round` a metà verso l'alto, `T(stat, ctx)` = F-05. Gli esempi sono
**casi di test**. Regole in `01_GDD_M25.md` (§36), dati in `04_DATA_SCHEMA_M25.md` (§30), chiavi §9c. Valori di partenza: nessuna ritaratura (Q122, Q127).

Simboli: `A0` = `encounters.attempts`; `N` = `encounters.node_units`; `L` = livello della disciplina (F-01, dopo F-160); `D` = difficoltà del nodo (F-161);
`a` = risorsa di F-154 (fissata all'inizio).

## F-161 Difficoltà, tentativi e istanti dei tentativi
- **Difficoltà** `D` = `difficulty` della voce dell'area in `nodes.json` (se assente: `max_level` dell'area, cioè il tetto `M` di F-154). **Livello minimo**
  `min_level` (se assente 1): con `L < min_level` il nodo è **saltato** come uno non appreso (durata `skip_ms`, nessun tiro, motivo `too_hard`).
- **Ricco** (F-164) o no decide `A` e la durata: `A = A0` (3), oppure `A0 + encounters.rich_extra_attempts` (+2 = 5).
- **Durata totale** `Dt`: F-155 (`node_ms`, ridotta da `skill_interval_pct`, minimo `node_min_ms`), per un nodo ricco `round(Dt × rich_ms_pct / 100)`; fissata all'inizio.
- **Istante del tentativo `k`** (1…A, dall'inizio del nodo): `t_k = round(k × Dt / A)`; `t_A = Dt`. Il tentativo `k` si risolve quando `elapsed ≥ t_k` (anche
  più di uno nello stesso passo: in ordine). Il nodo finisce con l'ultimo tentativo.
Esempi: `Dt` 12.000, `A` 3 → `t` = **4.000, 8.000, 12.000**; `Dt` 10.800 → **3.600, 7.200, 10.800**; `Dt` 10.000 → **3.333, 6.667, 10.000**; nodo ricco con
`Dt` 12.000 → durata **18.000**, `A` 5 → **3.600, 7.200, 10.800, 14.400, 18.000**; `Dt` minimo 3.000, `A` 3 → **1.000, 2.000, 3.000**.
`L` < `min_level` → saltato, durata 1.500, motivo `too_hard`; `min_level` 1 → mai.
Test: `tests/systems/encounters/test_attempts.gd`.

## F-162 Resa per tentativo (bottino garantito)
- **Scarto** `g = D − L`. **Resa** `y` (%): `y = 100` se `g ≤ encounters.yield_free_levels` (5); altrimenti
  `y = max(encounters.yield_min_pct, 100 − (g − yield_free_levels) × encounters.yield_loss_pct)` (25 e 4). `y` si calcola **a ogni tentativo** con il `L` di quel momento.
- **Unità totali previste** `Ne` = `N` (nodo normale) o `floor(N × rich_units_pct / 100)` (ricco).
- **Unità del tentativo `k`**: `u_k = max(1, floor(k × Ne × y / (100 × A)) − floor((k−1) × Ne × y / (100 × A)))` (somma cumulativa intera, nessuna perdita per arrotondamento).
  Il **minimo di 1** è la garanzia: ogni tentativo dà almeno un'unità se c'è posto.
- Ogni unità ha i tiri di F-155 (doppio F-06, Frammento F-07, sottoprodotto F-103) su `session.rng`, nell'ordine, e il controllo dello spazio (`bank_full`
  chiude il **nodo**: le unità già messe restano, i tentativi mancanti non si fanno; motivo `bank_full`).
Esempi (`N` 80, `A` 3): `y` 100 → **26, 27, 27** (80); `y` 80 → **21, 21, 22** (64); `y` 25 → **6, 7, 7** (20); ricco (`Ne` 120, `A` 5, `y` 100) → **24 ×5**.
Garanzia: `N` 2, `A` 3, `y` 25 → **1, 1, 1**.
`y`: `D` 30, `L` 27 → `g` 3 → **100**; `L` 25 → `g` 5 → **100**; `L` 24 → **96**; `L` 20 → `g` 10 → **80**; `L` 5 → `g` 25 → 20 → **25**; `L` 1 → **25**;
`D` 10, `L` 1 → `g` 9 → **84**; `L` > `D` → **100**.
Test: `tests/systems/encounters/test_attempts.gd`, `tests/systems/actions/test_gathering_resolver.gd`.

## F-163 XP e maestria per tentativo
Ad ogni tentativo `k` con `n_k` unità effettivamente messe, `L_k` il livello **prima** del tentativo:
- **colore** (F-154) con `d = L_k − level(a)` → `xp_pct`; `base = floor(n_k × a.xp × xp_pct / 100)`, poi F-02 con `T(skill_xp_pct, ctx)`, poi F-160; `base` 0 → nessuna XP né segnale;
- **maestria**: `mxp = n_k × F-10(a)`, con F-10 calcolata **prima di ogni tentativo** (livello di maestria della risorsa e rapporto `R` della disciplina di
  quel momento, prima del guadagno); pool: F-12 su `mxp` (una volta per tentativo).
Un cambio di livello della disciplina a metà nodo cambia il colore dal tentativo dopo; un cambio del livello di maestria (o di `R`) cambia F-10 dal tentativo dopo
(anche più volte nello stesso nodo: la maestria sale già col primo tentativo). La risorsa non cambia mai nel nodo.
Esempi (Betulla `xp` 10, maestria e pool a 0 all'inizio, `y` 100): arancione **260, 270, 270** (800, come F-155); giallo **130, 135, 135** (400); verde **52, 54, 54** (160);
grigio **0**; maestria **78, 108, 108** (294): F-10 = 3 al primo tentativo (26 × 3), poi la maestria della Betulla passa al livello 4 e F-10 = 4 (27 × 4), al
terzo è al livello 6 e F-10 resta 4 (27 × 4). Il test fissa la regola (`mxp` = `n_k` × F-10 del momento) e il primo valore (78); i successivi dipendono dalla
tabella della maestria dei dati veri. Con `y` 80, arancione: **210, 210, 220**. Doppio e Frammento: per unità, come F-155.
**Deposito pieno**: un tentativo in cui **nessuna** unità trova posto non conta (`attempt` non sale, nessuna XP, maestria né segnale) e chiude il nodo con `bank_full`;
se ne entra almeno una, il tentativo conta con le unità messe e poi il nodo si chiude.
Test: `tests/systems/encounters/test_node_attempts.gd` (e `test_node_work.gd`).

## F-164 Nodo ricco
Quando un nodo **lavorato** inizia (`NodeWork.begin`, dopo i controlli di disciplina e `min_level`), **un** tiro `roll_pct(encounters.rich_chance_pct)` (10) su
`session.rng`. Riuscito → ricco: `A = A0 + rich_extra_attempts`, `Ne = floor(N × rich_units_pct / 100)`, durata `× rich_ms_pct / 100` (F-161, F-162).
Un nodo saltato non tira (la sequenza del generatore resta quella di F-153). La risorsa, il colore, la difficoltà e la resa `y` sono quelli di un nodo normale.
Il tiro avviene **sempre** per un nodo lavorato, anche con probabilità 0 o 100 (la sequenza avanza di uno; i test fissano il generatore). Esempi: 0 → mai ricco; 100 → sempre;
valori di partenza: 5 tentativi, 120 unità previste, 18 s (contro 3, 80, 12 s).
Test: `tests/systems/encounters/test_node_work.gd`.

## F-165 Forma chiusa con tentativi (sostituisce l'uso di `N̄` e delle unità di F-156)
Con `r = rich_chance_pct / 100`: moltiplicatore di durata `mM = 1 + r × (rich_ms_pct/100 − 1)` (1,05), di unità `mU = 1 + r × (rich_units_pct/100 − 1)` (1,05).
F-156 resta, con `N̄ = Σ w_s × node_ms(s) × mM / Σ w_s` (tutte le altre voci invariate, `S` = `skip_ms`; il `min_level` fa contare la disciplina tra le saltate se
`L < min_level`); **unità all'ora** di `s` = nodi lavorati di `s` × `node_units` × `mU` × `y_s` (`y_s` da F-162 con `L` e `D` della sessione di misura).
Esempio (come F-156: `travel_ms` 2.500, `q` 0,25, `E_F` 50.000, `p_L` 0,5, `N̄` 12.000 × 1,05 = **12.600**, `S` 1.500): `E[T]` = **41.762,5** ms; `R` = **86,20**/h;
scontri **64,65**/h; nodi lavorati **10,78**/h (**5,39** per disciplina); unità **452,6**/h per disciplina con `y` 100 (**84** unità per nodo in media, 80 senza ricchi:
stesso ordine di F-155).
**Offline** (§36.8): nessuna forma chiusa nel gioco; l'offline è il motore a eventi, i tentativi sono eventi del nodo. Equivalenza Q124: `advance` in un blocco da 12 h,
passi da 100 ms o blocchi da 60 s dà lo **stesso stato completo** anche con nodi a più tentativi, nodi ricchi e coda attiva (stesso taglio in passi di `tick_ms`, un
tentativo si risolve nel passo in cui `elapsed` supera `t_k`, in ordine, con il generatore del combattimento). `tools/sim_encounters.gd` confronta con F-165 (±5%).
Test: `tests/systems/encounters/test_encounter_cycle.gd` (`expected` con `rich_*`), `tests/integration/test_m24_offline_equivalence.gd` (esteso), `tools/sim_encounters.gd`.

## 9c. Chiavi di `balance.json` (M25), sezione `encounters`
| Chiave | Valore | Usata in |
|---|---|---|
| `encounters.attempts` | 3 | F-161 |
| `encounters.yield_free_levels` | 5 | F-162 |
| `encounters.yield_loss_pct` | 4 | F-162 |
| `encounters.yield_min_pct` | 25 | F-162 |
| `encounters.rich_chance_pct` | 10 | F-164 |
| `encounters.rich_extra_attempts` | 2 | F-161 |
| `encounters.rich_units_pct` | 150 | F-162 |
| `encounters.rich_ms_pct` | 150 | F-161 |
`node_ms`, `node_min_ms`, `skip_ms`, `node_units`, `colors`, `travel_ms`, `node_chance_pct` invariate (F-155, §9b).
