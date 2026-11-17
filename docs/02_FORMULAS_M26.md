# 02. Formule, §5m: Alpha 2 (F-166…F-176; M26, V31-V32)

Estensione di `02_FORMULAS.md` (che supera le 400 righe): vale come la sua sezione **§5m**, con le chiavi §9d. Convenzioni di `02_FORMULAS.md` e della Casa
d'Aste (§5k): `floor`, `round` a metà verso l'alto, `a ÷ b` divisione intera **troncata verso zero** (come GDScript), `ceil_div(a, b) = (a + b − 1) ÷ b` per `a ≥ 0`,
**ppm** = parti per milione (`PPM` = 1.000.000). Gli esempi sono **casi di test**. Regole in `01_GDD_M26.md` (§38), dati in `04_DATA_SCHEMA_M26.md` (§31),
contratto in `05_INTERFACES_M26.md`. Nessuna stat nuova in `stats.json`; nessuna sorgente nuova in `ModifierService`.
**Invariate** (non toccarle): F-01, F-02, F-154 (colori dei nodi), F-155…F-165, F-158…F-160, F-157, F-146 (variazione con seme), F-151 nella forma.

---

## Filone A: livello della professione e colori

### F-166 Soglie di colore di una ricetta (dati generati)
Ogni azione `artisan` di `forging`, `woodwright`, `hearthcraft` (salvo `single`) ha `colors = {yellow, green, grey}` interi, scritti da `tools/gen_professions.gd`:
`yellow = level + 10`, `green = level + 20`, `grey = level + 30` (costanti del generatore, uguali ai `below` di `encounters.colors` di F-154: stessa distanza = stesso
colore; Q147). Il gioco legge **solo** il campo dei dati (si può ritoccare a mano una ricetta: il validatore controlla l'ordine, non la regola).
**Vincoli del validatore**: `level < yellow < green < grey ≤ 200`; campo ammesso solo per azioni `artisan` non `single`.
Esempi: `forge_ashlead_plate` (livello 10) → **20 / 30 / 40**; `forge_riftite_plate` (90) → **100 / 110 / 120**; `cook_brookfin` (1) → **11 / 21 / 31**.
Test: `tests/data/test_data_validity.gd` (dati veri), `tests/core/data/test_data_validator_professions.gd` (casi rifiutati).

### F-167 Colore e probabilità di avanzamento (skill-up)
Con `L` = livello della disciplina (F-01, già limitato da F-160) e le soglie `y`, `g`, `x` (giallo, verde, grigio) della ricetta:
- **colore**: `L < y` → `orange`; `L < g` → `yellow`; `L < x` → `green`; altrimenti `grey`;
- **probabilità** in ppm: `L < y` → `PPM`; `L ≥ x` → 0; altrimenti `chance = (x − L) × PPM ÷ (x − y)`.
Ricetta **senza** `colors` → colore `&""`, `chance = PPM` (comportamento di oggi).
Esempi (= test, `forge_ashlead_plate` 20/30/40): `L` 15 → arancione **1.000.000**; 20 → giallo **1.000.000**; 25 → giallo **750.000**; 29 → giallo **550.000**;
30 → verde **500.000**; 35 → verde **250.000**; 39 → verde **50.000**; 40 → grigio **0**; 99 → grigio **0**. `forge_duskcobalt_plate` (30: 40/50/60) con `L` 44 → giallo
**800.000** (il "buco" tra i gradini 30 e 45). `forge_riftite_plate` con `L` 99 → arancione. Senza `colors` → **1.000.000**.
Test: `tests/systems/professions/test_profession_math.gd`.

### F-168 XP di un ciclo come avanzamento atteso (resto per disciplina)
A ogni ciclo **completato** di una ricetta (dove oggi `ArtisanResolver` chiama `add_xp(action.xp)`), con `L` **prima** dell'XP di quel ciclo:
`t = frac(s) + action.xp × chance(L)`; `base = t ÷ PPM`; `frac(s) = t mod PPM` (0 ≤ `frac` < `PPM`); poi `add_xp(s, base, ctx)` (F-02 con `skill_xp_pct`, poi F-160).
`base = 0` → nessuna chiamata, nessun segnale (il resto cresce). Senza `colors`: `t = frac + xp × PPM` → `base = xp` se `frac = 0` (identico a oggi; senza colori `frac` resta 0).
Nessun tiro: il generatore della coda (Q124) avanza come oggi. `frac` è stato dello slot (`professions`), azzerato da `skill_reset(s)`.
Esempi (= test, `forge_ashlead_plate` `xp` 33, `frac` 0): `L` 25 (750.000) → quattro cicli **24, 25, 25, 25** (= 99 = 4 × 24,75), `frac` **0**; `L` 35 (250.000) → **8, 8, 8, 9**
(resto 250.000, 500.000, 750.000, 0); `L` 15 → **33** a ogni ciclo; `L` 40 → **0** (nessun `xp_gained`), `frac` invariato. Con `skill_xp_pct` 10: `base` 24 → **26** (F-02).
`smelt_emberbronze` (`xp` 8) con 250.000 → **2, 2, 2, 2**. Livello che sale fra due cicli: il secondo usa il nuovo `L`.
**Equivalenza** (= test, estende `tests/integration/test_m24_offline_equivalence.gd`): coda con una ricetta gialla e una verde, 12 h in un blocco = passi da 100 ms = blocchi
da 60 s = 6 h + salva/carica + 6 h: stato completo identico, `frac` compreso.
Test: `tests/systems/professions/test_professions.gd`, `tests/systems/actions/test_artisan_resolver.gd`.

### F-169 Origini e sblocchi a soglie (tabella generata)
**Origine** di un'azione `artisan`: `scheme` se `discover` e la sua Ricetta è venduta da una voce dello shop; `drop` se `discover` senza voce; `trainer` altrimenti.
**Regola del generatore** (`tools/gen_professions.gd`, costanti dello script; Q149; gradino `t` di un'azione = posizione 1…8 del suo `level` in `village.woodwright_levels`, come
in `gen_auction.gd`): sono schemi, per i gradini **2-8**, `forge_*_plate` (Forgia), `carve_*_shieldcore` e
`carve_*_handle` (Falegnameria), `cook_*` (Cucina e alchimia); i Tonici restano `drop`; tutto il resto è `trainer`.
**Sblocchi** di una disciplina `s` (lettura del modello, ordine per livello, poi tipo `trainer` < `scheme` < `reagent`, poi ordine di file): ogni ricetta `trainer` al suo
`level`; ogni voce dello shop del mercante di `s` al suo `requires.skills[s]` (schema o reagente). Tabella di partenza (= test sui dati veri):
| Livello | Forgia (`fabbro`) | Falegnameria (`falegname`) | Cucina e alchimia (`cuoco`) |
|---|---|---|---|
| 1 | lingotto e piastra T1 (Maestro) | impugnatura, anima, manico T1, borsa di tela (Maestro) | cottura T1 (Maestro) |
| 10 | lingotto T2 (Maestro); schema piastra T2; reagente fascia 1 | impugnatura T2; schemi anima e manico T2; reagente fascia 1 | schema cottura T2; reagente fascia 1 |
| 20 | lingotto T3; schema piastra T3 | impugnatura T3; schemi T3 | schema cottura T3 |
| 30 | lingotto T4; schema T4; reagente fascia 2 | impugnatura T4; schemi T4; reagente fascia 2 | schema T4; reagente fascia 2 |
| 45 | lingotto T5; schema T5 | impugnatura T5, borsa rinforzata; schemi T5 | schema T5 |
| 60 | lingotto T6; schema T6; reagente fascia 3 | impugnatura T6; schemi T6; reagente fascia 3 | schema T6; reagente fascia 3 |
| 75 | lingotto T7; schema T7 | impugnatura T7; schemi T7 | schema T7 |
| 90 | lingotto T8; schema T8; reagente fascia 4 | impugnatura T8; schemi T8; reagente fascia 4 | schema T8; reagente fascia 4 |
I Tonici restano `drop` e le azioni `single` (`blueprint_craft`) non sono sblocchi: `unlocks` non li elenca. Schemi in tutto: **7 + 14 + 7 = 28**; reagenti **12**.
Esempio di `unlocks(forging)` (primi 4): `{1, trainer, smelt_emberbronze}`, `{1, trainer, forge_emberbronze_plate}`, `{10, trainer, smelt_ashlead}`,
`{10, scheme, buy_recipe_forge_ashlead_plate}`. Test: `tests/systems/professions/test_professions.gd` (fixture) e `tests/data/test_data_validity.gd` (conteggi veri).

## Filone B: schemi e reagenti

### F-170 Prezzo degli schemi
`gold(schema di a) = max(100, 50 × value(primo output di a))` (costanti del generatore: `SCHEME_VALUE_MULT` 50, `SCHEME_MIN_GOLD` 100; scritto in `cost.gold` della voce).
`max_purchases` 1; requisito `requires.skills = {s: a.level}`. Lo schema vale 0 (non si vende).
Esempi: `forge_ashlead_plate` (piastra 21) → **1.050**; `forge_riftite_plate` (595) → **29.750**; `carve_ashpine_handle` (6) → **300**; `cook_ashgill` (6) → **300**;
`carve_riftspruce_shieldcore` (340) → **17.000**. Totale per professione: Forgia **70.700**, Falegnameria **60.600**, Cucina **20.200** (da confrontare con l'oro/h in M26-11, Q151).

### F-171 Reagenti: fasce, prezzo, valore, non-arbitraggio
Fasce per gradino: **1** = T2-T3, **2** = T4-T5, **3** = T6-T7, **4** = T8; un reagente per fascia e professione (`reagent_<skill>_<fascia>`). Ogni ricetta-schema del gradino `t` ha in
`inputs` **1** reagente della sua fascia (in coda agli altri ingredienti). Sblocco = livello del primo gradino della fascia (10, 30, 60, 90).
`m_f` = il più piccolo `value` del primo output fra gli schemi del primo gradino della fascia; **prezzo** `p_f = max(1, round(0,10 × m_f))`; **valore** (vendita F-18)
`v_f = floor(p_f × 25 / 100)` (costanti del generatore `REAGENT_PRICE_PCT` 10, `REAGENT_VALUE_PCT` 25). Voce dello shop con `effect.item` qty 1, `max_purchases` 0.
Esempi (= test sui dati veri): Forgia **2, 7, 21, 60** (valori **0, 1, 5, 15**); Falegnameria **1, 2, 6, 17** (valori **0, 0, 1, 4**); Cucina **1, 2, 6, 17** (**0, 0, 1, 4**).
Peso sul prodotto: piastra T2 (21) +2 oro = **9,5%**; piastra T3 (42) **4,8%**.
**Non-arbitraggio (vincoli del validatore)**: per ogni voce dello shop con `effect.item`: `cost.gold > value(item) × qty`; la categoria `reagent` non entra nell'elenco della Casa
d'Aste (§34.2); un reagente non è output di nessuna azione; nessuna regola sui valori dei prodotti cambia (un reagente in più non aumenta il valore di ciò che si crea, quindi
compra-lavora-rivendi rende meno di prima). `buy_many(n)` costa `n × p_f` (nessuno sconto).

## Filone C: Casa d'Aste a popolazione (modifica F-147…F-152; F-145 e F-146 invariate)

Parametri: `auction.population` in `balance.json` (§9d) e fasce in `data/auction/population.json`. Valori di partenza: `ref` 100, `period_blocks` `PB` 36 (3 h),
`variation_pct` 20 (`VAR` 200.000 ppm), `pressure_pct` 10 (`PRESS` 100.000 ppm). Cambiano due valori di M23: `index.max_pct` 125 → **126** (`MAX` 1.260.000) e
`saturation.max_pct` 55 → **56** (`CAP` 560.000), per i vincoli di F-174. Fasce di partenza (oggetto nella prima fascia con `value ≤ max_value`; l'ultima senza tetto):
| Fascia | `max_value` | compratori `B0` | venditori `S0` |
|---|---|---|---|
| 1 | 9 | 125 | 115 |
| 2 | 59 | 110 | 105 |
| 3 | 249 | 100 | 100 |
| 4 | — | 90 | 85 |
La fascia 3 è il riferimento: con `B0 = S0 = ref` saturazione, recupero e rifornimento sono quelli di M23.

### F-172 Liquidità per oggetto (costanti per oggetto, dalla fascia)
`STEP_i = max(1, STEP × ref ÷ B0)`; `REC_i = max(1, REC × B0 ÷ ref)`; `r_i = max(1, (S × REFILL × S0 ÷ ref + 500.000) ÷ 1.000.000)` (`S` = scorta massima di F-150, invariata).
Esempi (= test): fasce 1-4 → `STEP_i` **200, 227, 250, 277**; `REC_i` **6.250, 5.500, 5.000, 4.500**; recupero completo dal tetto `ceil_div(CAP, REC_i)` = **90, 102, 112, 125**
blocchi (7,5 h … 10,4 h, tutti ≤ 144 = 12 h). `redbirch_grip` (`v` 2, fascia 1, `S` 500) → `r` **8** (M23: 7); `riftite_plate` (595, fascia 4, `S` 10) → **1**;
`shardcedar_grip` (36, fascia 2, `S` 166) → **2**; `seared_riftmaw` (170, fascia 3, `S` 35) → **1**.

### F-173 Onde di compratori e venditori, pressione (senza stato)
Nodo `j` dell'onda `k` ∈ {`b`, `s`}: `wk(id, k, j) = (H(id + "|" + k + "|" + str(seed) + "|" + str(j)) mod (2·VAR + 1)) − VAR` (`H` e `seed` di F-146).
Al blocco `block`: `j = block ÷ PB`, `f = block mod PB`, `w_k = wk(j) + ((wk(j + 1) − wk(j)) × f) ÷ PB`.
**Popolazione**: `B = B0 × (PPM + w_b) ÷ PPM`, `Sv = S0 × (PPM + w_s) ÷ PPM` (interi, mostrati nella pagina); **pressione** `press = PRESS × (B − Sv) ÷ (B + Sv)`.
Vettori (= test, `tests/systems/auction/test_auction_population.gd`, `seed` 12345): `H("redbirch_grip|b|12345|0")` = **1.871.622.662**; nodi `b` di `redbirch_grip` **−182.017, 93.705, 103.282**,
nodi `s` **90.166, 28.650, 116.736**; `riftite_plate` `b` **189.615, −168.726, 108.115**, `s` **35.745, −97.349, −73.653**.
`redbirch_grip` (fascia 1): blocco 0 → `w_b` −182.017, `w_s` 90.166, `B` **102**, `Sv` **125**, `press` **−10.132**; blocco 18 → `w_b` **−44.156**, `w_s` **59.408**, `B` 119, `Sv` 121,
`press` **−833**; blocco 36 → `B` 136, `Sv` 118, `press` **7.086**. `riftite_plate` (fascia 4) blocco 0 → `B` 107, `Sv` 88, `press` **9.743**.
Proprietà: stesso `seed`, `id`, `block` → stesso valore; `|w_k| ≤ VAR`; nessun tiro, nessuno stato salvato.

### F-174 Equilibrio e indice (sostituisce `eq` di F-147)
`eq(id, block) = BASE + drift(id, block) + press(id, block)`; `index = clamp(eq − sat, MIN, MAX)` (come F-147).
**Vincoli del validatore** (con `PB+` = massimo su tutte le fasce di `PRESS × (Bmax − Smin) ÷ (Bmax + Smin)` e `PB−` = massimo di `PRESS × (Smax − Bmin) ÷ (Bmin + Smax)`, dove
`Bmax = B0 × (PPM + VAR) ÷ PPM`, `Bmin = B0 × (PPM − VAR) ÷ PPM` e così `Smax`, `Smin`; la pressione è crescente in `B` e decrescente in `Sv`, quindi gli estremi sono esatti):
`MIN < BASE − AMP − PB−`; `BASE + AMP + PB+ ≤ MAX`; `CAP ≥ BASE + AMP + PB+ − MIN`; `SPREAD > MAX − MIN` (F-151); `ceil_div(CAP, REC_i) ≤ offline.max_hours × 3.600.000 ÷ block_ms`
per ogni fascia; `1 ≤ ref`, `B0`, `S0 ≥ 1`, `0 ≤ VAR < PPM`, `PRESS ≥ 0`, `PB ≥ 1`, `max_value` strettamente crescenti.
Con i valori di partenza: `PB+` = **23.966** (fascia 1: 150 contro 92), `PB−` = **20.000** (fascia 3: 80 contro 120); `BASE + AMP + PB+` = 1.253.966 ≤ 1.260.000; `CAP` 560.000 ≥ 553.966.
Esempi (= test, `seed` 12345, `sat` 0): `redbirch_grip` blocco 0 → `drift` 61.184 + `press` −10.132 → **1.201.052**; blocco 18 → 27.235 − 833 → **1.176.402**; blocco 36 → −6.714 + 7.086 →
**1.150.372**; `riftite_plate` blocco 0 → 36.080 + 9.743 → **1.195.823**. Con `sat` 560.000 al blocco 0 `redbirch_grip` → 641.052 → **700.000** (minimo).

### F-175 Vendita, recupero e rifornimento per oggetto (modifica F-148, F-149, F-150); orologio e equivalenza
- **Vendita** (F-148 con `STEP_i`): `n1 = 0` se `x0 ≤ MIN`, altrimenti `min(q, ceil_div(x0 − MIN, STEP_i))`; `Σ = n1·x0 − STEP_i·n1·(n1 − 1)/2 + (q − n1)·MIN`; oro `(v × Σ) ÷ PPM`;
  poi `sat = min(CAP, sat + q·STEP_i)`. Esempi (`eq` 1.150.000, `sat` 0): `redbirch_grip` (`v` 2, `STEP_i` 200), `q` 100 → `Σ` 114.010.000 → **228** oro, poi `sat` 20.000;
  `v` 1 in fascia 1, `q` 2.000 → `Σ` 1.900.200.000 → **1.900**, poi `sat` 400.000; `riftite_plate` (`v` 595, `STEP_i` 277), `q` 100 → **67.609** (con 250, la fascia 3: 67.688).
  Un oggetto della fascia 3 dà esattamente gli esempi di F-148.
- **Recupero** (F-149 con `REC_i`): `sat = max(0, sat − n·REC_i)`. Esempi: fascia 1, `sat` 500.000, 30 blocchi → **312.500**; fascia 4, `sat` 560.000, 125 blocchi → **0**, 124 → **2.000**.
- **Rifornimento** (F-150 con `r_i`): `stock = min(S, stock + n·r_i)`. Esempio: `redbirch_grip` da 0, 63 blocchi → **500** (piena; 62 → 496).
- **Orologio** (F-145 invariato): `advance(a); advance(b)` ≡ `advance(a + b)`: `STEP_i`, `REC_i`, `r_i` sono costanti per oggetto e `press` non ha stato, quindi recupero e rifornimento
  restano additivi in `n` (test di proprietà di M23 esteso con oggetti di tutte le fasce).

### F-176 Tendenza, acquisto e garanzia (F-151 e F-152 con F-174)
- **Tendenza** (F-152 con `eq` di F-174 e `REC_i`): `now` = indice al blocco `b`; `next` = indice al blocco `b + trend.blocks` con `sat' = max(0, sat − trend.blocks·REC_i)`.
  Esempi (= test, `seed` 12345): `redbirch_grip`, blocco 0, `sat` 0 → `now` 1.201.052, `next` 1.184.315, `d` −16.737 → **down**; `sat` 100.000 → 1.101.052 → 1.159.315 (`sat'` 25.000),
  `d` +58.263 → **up**; `riftite_plate`, blocco 66 → 1.106.410 → 1.107.803, `d` +1.393 → **stable**.
- **Acquisto** (F-151 invariata nella forma): `riftite_plate` blocco 0, `sat` 0 (indice 1.195.823) → `unit` = ⌈595 × 2.695.823 / 10⁶⌉ = **1.605**; vendita di un pezzo **711**.
- **Garanzia**: con i vincoli di F-174 l'indice resta in `[MIN, MAX]` e `SPREAD > MAX − MIN`, quindi `unit ≥ v·(MIN + SPREAD)/10⁶ > v·MAX/10⁶ ≥` ogni pezzo venduto, e
  `v·MAX/10⁶ ≥ v` (F-18): **comprare e rivendere perde sempre oro**. Con i valori di partenza `unit` sta tra **2,20 e 2,76** volte `v`, la vendita tra **0,70 e 1,26**.
  Il controllo dei progetti di F-151 (validatore) non cambia.
- **Popolazione mostrata**: `population(id)` = `{"buyers": B, "sellers": Sv, "demand": high|normal|low}` con `DT` = `demand_threshold_pct` in ppm (5.000):
  `demand` = `high` se `press ≥ DT`, `low` se `press ≤ −DT`, altrimenti `normal`. Esempi: `redbirch_grip` blocco 0 → **low**; blocco 18 → **normal**; blocco 36 → **high**.
- **Simulazione** (`tools/sim_market.gd`, aggiornata in M26-09; soglie di M23-05 invariate): (1) `unit` > vendita del pezzo al tetto e > `v` per ogni acquistabile e 1.000 stati casuali
  (blocchi casuali: la pressione cambia); (2) 10.000 strategie compra/vendi/attendi su 12 h per oggetto: nessun guadagno dal nulla; (3) controllo dei progetti; (4) 12 h in un colpo =
  passi da 100 ms = blocchi da 60 s; (5) 1 h di produzione dei grezzi T1-T8 venduta in un colpo, rapporto con F-18 **tra 0,85 e 1,25**; stampa anche recupero e rifornimento per fascia.
  Se la (5) salta: nessun ritocco, numeri al Reviewer (Q122).

## 9d. Chiavi di `balance.json` (M26)
| Chiave | Valore | Formula |
|---|---|---|
| `auction.population.ref` | 100 | F-172 |
| `auction.population.period_blocks` | 36 | F-173 |
| `auction.population.variation_pct` | 20 | F-173 |
| `auction.population.pressure_pct` | 10 | F-173, F-174 |
| `auction.population.demand_threshold_pct` | 0,5 | F-176 (5.000 ppm; si converte in ppm come le altre `*_pct`) |
| `auction.index.max_pct` | **126** (era 125) | F-174 |
| `auction.saturation.max_pct` | **56** (era 55) | F-174 |
Nessuna chiave nuova per i filoni A e B: soglie, prezzi e reagenti sono **nei dati** (`data/actions/`, `data/shop/shop.json`, `data/items/`), scritti dal generatore con le sue costanti
(come `gen_areas.gd` e `gen_dungeon.gd`); il gioco legge solo i dati.
