# 02. Formule, §5r: Casa d'Aste, libro unico (F-214…F-218; M38, V48)

Estensione di `02_FORMULAS.md` (§5k, F-145…F-152), `02_FORMULAS_M26.md` (F-172…F-176), `02_FORMULAS_M27.md` (F-177…F-184) e `02_FORMULAS_M37.md` (F-209…F-213). Regole in `01_GDD_M38.md` (§46), dati in
`04_DATA_SCHEMA_M38.md` (§39), contratto in `05_INTERFACES_M38.md`. Convenzioni di §5k: interi, **ppm** (`PPM` = 1.000.000, `ppm = roundi(pct × 10000)`), `a ÷ b` troncata verso zero, `ceil_div`,
`H` di F-146. Gli esempi sono **casi di test** (`seed` 12345, blocco 0, `sat` 0, `LO` 0, `HI` 250.000 = valori attuali; importi in rame). Stat nuove: nessuna; sorgenti di `ModifierService`: nessuna.

## Sostituzioni e cosa resta
| Formula | Esito |
|---|---|
| F-150 (scorta `S`, rifornimento `r(S)`) | **sostituita** da F-216 (`taken`); `stock.*` di `balance.json` **tolte** |
| F-151 (acquisto `v × (index + SPREAD)`, garanzia di non-arbitraggio) | **sostituita** da F-215 e F-217; `buy.spread_pct` → `buy.markup_pct` |
| F-172 (solo `r_i`) | `r_i` **sostituito** da F-216; `STEP_i`, `REC_i` invariati |
| F-176 (acquisto, garanzia) | la parte «Acquisto» e «Garanzia» **sostituita** da F-215/F-217; tendenza e popolazione invariate |
| F-182 (vincoli, simulazione) | vincolo `(MIN + SPREAD)…` **sostituito** da F-217; resto invariato; simulazione aggiornata (F-217) |
| F-210 (scarto sulla media) | **modificata**: il riferimento è F-214, non `value_of` |
| F-211 (`max_buyable`) | **modificata**: sul libro (F-215) |
| F-145…F-149, F-152, F-173…F-175, F-177…F-181, F-183, F-184, F-209, F-212, F-213 | **invariate** (il libro F-178 e la domanda F-179 restano come sono: `taken` non li tocca) |
**Il lato vendita non cambia affatto** (Vendi subito, inserzioni del giocatore, Deposito, commissione, deposito): nessun importo di vendita si sposta, la simulazione (8) di F-182 resta come è.

## F-214 Prezzo di riferimento («media recente»)
Per ogni oggetto trattato `id`, due serie sull'**epoca** `e` (`PL` blocchi di F-178; il primo blocco dell'epoca è `b_e = e × PL`), **senza saturazione** e senza `taken` (derivate da seme e blocco, nessuno stato):
- **vendita** `s_e = (v × clamp(eq(id, b_e), MIN, MAX)) ÷ PPM` (F-174: `eq = BASE + drift + press`; in pratica `eq` sta già in `[MIN, MAX]`);
- **acquisto** `a_e = ceil_div(ask_e × (PPM + MK), PPM)` con `ask_e = max(1, (v × clamp(eq(id, b_e), MIN, MAX) × (PPM + off_min,e)) ÷ PPM²)` e `off_min,e` = il più piccolo ricarico `off_j` delle `K` inserzioni
  dell'epoca (F-178, `j` = 0…K−1 con la popolazione al blocco `b_e`); `MK` = `buy.markup_pct` in ppm.
**Riferimento** `ref(id, mode, e_now)` = **mediana** degli ultimi `W` valori `x_e` per `e = e_now − W + 1 … e_now` (`W` = `reference.window_epochs`, 24 = 12 h; le epoche negative si saltano: la serie può avere meno
di `W` valori; nessun valore → 0 = non disponibile). Mediana: valori in ordine crescente, elemento di indice `n ÷ 2` (con `n` pari prende il **superiore**: intero, deterministico).
Esempi (= test, `tests/systems/auction/test_auction_reference.gd`): serie di prova (nel test) 100, 120, 90, 110 → ordinata 90, 100, 110, 120, indice 2 → **110**; serie 5, 9, 7 → indice 1 → **7**; una sola epoca → il suo valore;
`e_now` = 0 con `W` = 24 → un solo valore (epoca 0). Sui dati veri (`redbirch_grip`, `v` 200): `s_0` = 200 × 1.201.052 ÷ PPM = **240**; `off_min,0` = **4.039** (inserzione `j` 11), `ask_0` = **241**,
`a_0` = ceil_div(241 × 1.450.000, PPM) = ⌈349,45⌉ = **350**. `riftite_plate` (`v` 59.500): `s_0` = **71.151**; `ask_0` = **72.640**, `a_0` = ⌈105.328⌉ = **105.328**.
Proprietà: stesso `seed`, `id`, `e_now`, `W` → stesso valore; additività non richiesta (nessuno stato); il costo è `W × K` hash per oggetto e modo, da **mettere in cache per epoca** (la UI lo chiede per tutta la lista).

## F-215 Acquisto sul libro (prezzo per pezzo e costo)
Il libro d'acquisto di `id` al blocco `b` è il libro **PNG** di F-178 (`K` inserzioni; le inserzioni del giocatore **non** si comprano e **non** contano). Posizioni dei pezzi 0…`V`−1 nell'ordine di F-178
(`ask` crescente, a parità `j`): la posizione `p` appartiene all'inserzione `L(p)`.
**Scarsità**: `scar = taken × STEP_i` (ppm; `taken` e `STEP_i` di F-216/F-172); `idx_b = max(idx + scar, EQMIN)`, con `idx` = indice F-174 **con** la saturazione e `EQMIN = BASE − AMP − PB−` (F-174: **1.050.000** coi
valori attuali). **Prezzo del pezzo** in posizione `p` (inserzione `j`, ricarico `off_j`):
`ask_p = max(1, (v × idx_b × (PPM + off_j)) ÷ PPM²)` (come F-178 con `idx_b`) e `unit_p = ceil_div(ask_p × (PPM + MK), PPM)`.
**Disponibili** `avail = max(0, V − taken)`: i pezzi comprabili sono le posizioni `taken … V−1` (le `taken` più economiche sono già state prese). **Costo** di `q ≤ avail` pezzi = somma di `unit_p` per `p = taken … taken + q − 1`
(un ciclo sul libro: `V ≤ KMAX × stack` ≤ 2.400; nessun ordine di grandezza fuori da int64: `v ≤ 1.000.000`, `idx_b ≤ 2 × 10⁶`, `PPM + off ≤ 1,25 × 10⁶`). Dopo l'acquisto di `q`: `taken += q` (F-216). Il prezzo non cambia **dentro**
l'acquisto (si paga il prezzo mostrato di ogni inserzione, come in un'asta vera); cambia per chi compra dopo, tramite `taken`.
Prezzo mostrato «Comprare 1» = `unit` della posizione `taken` (la più economica disponibile). Un oggetto non acquistabile (`buy_level` 0), `q ≤ 0`, `q > avail` → `can_buy` rifiuta (`out_of_stock` se `q > avail`).
Esempi (= test; `redbirch_grip`, `v` 200, fascia 1, `STEP_i` 200, `MK` 450.000; libro di F-178: prezzi d'acquisto per inserzione, in ordine: `j`11 **350** (×69), `j`5 **359** (×169), `j`6 **363** (×53), `j`1 **366** (×79),
`j`3 **373** (×154), `j`0 **373** (×69), `j`8 **383** (×154), `j`10 **396** (×18), `j`4 **405** (×113), `j`9 **409** (×69), `j`7 **422** (×176), `j`2 **431** (×70); `V` 1.193):
- `taken` 0: comprare **1** = **350** (oggi 541: **−35 %**); **100** = 69 × 350 + 31 × 359 = **35.279**; **300** = **107.354**; **600** = **218.834**; **1.000** = **378.615**; **tutto (1.193)** = **460.691** (media 386, +10 % sul migliore).
- `taken` 400 (`scar` 80.000, `idx_b` 1.281.052; posizioni 400-499 nell'inserzione `j`3 con ask 274): **100** = 100 × ⌈274 × 1,45⌉ = 100 × **398** = **39.800**; `avail` **793**.
- `taken` 1.000 (`scar` 200.000): `avail` **193** (posizioni 1.000-1.192 in `j`7 e `j`2, `idx_b` 1.401.052); **1** = **493**; tutti i 193 = **95.919**.
- `riftite_plate` (`v` 59.500, fascia 4, `STEP_i` 277; `V` 27, libro: 4 × **105.328**, 4 × **106.094**, 4 × **108.210**, 3 × **115.523**, 3 × **116.102**, 5 × **118.840**, 2 × **125.446**, 2 × **127.512**): 1 = **105.328** (oggi 160.402: −34 %);
  10 = **1.062.108**; tutti i 27 = **3.073.519**; con `taken` 10 (`scar` 2.770): 5 pezzi = **564.290**.
- **Pavimento**: con `sat` 560.000 (indice 700.000) e `taken` 0, `idx_b` = **1.050.000** (non 700.000): `redbirch_grip` prima inserzione = ⌈⌊200 × 1.050.000 × 1.004.039 ÷ 10¹²⌋ × 1,45⌉ = ⌈210 × 1,45⌉ = **305** (senza pavimento 700.000 → 203).
Test: `tests/systems/auction/test_auction_buy.gd`.

## F-216 Pezzi presi (`taken`): stato, recupero, esaurimento
Stato per oggetto acquistabile: `taken` (intero ≥ 0), salvato (`auction.taken`, save v14). Nasce 0. **Acquisto di `q`**: `taken += q` (≤ `V`).
**Recupero** (i venditori PNG rifanno le inserzioni): ogni blocco intero `taken = max(0, taken − n·r_i)` per `n` blocchi (lineare, additivo in `n`: `advance(a); advance(b)` ≡ `advance(a + b)`).
**Ritmo** `r_i = max(1, (Vn × REFILL + 500.000) ÷ PPM)` con `Vn = (S0 ÷ SPL) × ((stack + 1) ÷ 2)` (volume nominale della fascia: `S0` venditori, `SPL` = `book.sellers_per_listing`, `stack` della fascia, F-178)
e `REFILL` = `supply.refill_pct_per_block` in ppm (15.000 = 1,5 %). Fasce 1-4: `Vn` **1.100, 300, 100, 24** → `r_i` **17, 5, 2, 1** pezzi a blocco; svuotamento completo del libro più grande possibile (`KMAX × stack` = 2.400, 720, 240, 60)
in **142, 144, 120, 60** blocchi (≤ 144 = 12 h; il validatore lo impone, F-217).
**Esaurito**: `avail = 0` (`V − taken ≤ 0`): il comando risponde `out_of_stock` e la UI scrive «Esaurito, torna tra ~N min» con `N = 5 × ceil_div(taken − V + 1, r_i)` (un blocco = 5 min). Ogni blocco tornano `r_i` pezzi, dal più economico
posizionato dopo `taken` (i prezzi sono quelli alti di F-215 + scarsità).
Esempi (= test): `redbirch_grip` (fascia 1, `r_i` 17) con `taken` 1.000, 30 blocchi → **490**; 59 blocchi → **0**; `taken` 1.193 con `V` 1.193 → `avail` 0, `N` = 5 × ⌈1/17⌉ = **5 min**; dopo 1 blocco `taken` 1.176, `avail` **17**;
`riftite_plate` (fascia 4, `r_i` 1) `taken` 27, `V` 27 → `avail` 0, torna tra **5 min**, dopo 10 blocchi `avail` **10**; `taken` 3, 2 blocchi → **1**. `V` che scende a un'epoca nuova sotto `taken` (es. `V` 950, `taken` 1.000): `avail` **0**
(`N` = 5 × ⌈51/17⌉ = **15 min**), `taken` non si tronca; `taken` non supera mai `KMAX × stack` (si limita all'acquisto: `taken + q ≤ V`).
**Offline**: `advance` di 12 h (144 blocchi) porta `taken` a 0 in tutte le fasce; l'avanzamento è O(oggetti acquistabili), il libro non si calcola in `advance`.
Esempi di equivalenza (= test): `advance(a); advance(b)` ≡ `advance(a + b)` con oggetti di tutte le fasce; 12 h in un colpo = passi da 100 ms = blocchi da 60 s (F-184 esteso: `taken` nello stato confrontato).

## F-217 Non-arbitraggio, vincoli del validatore, simulazione
**Perché il margine `MK`**: il lato vendita di M27 (F-178 `HI` 25 %, vendita al banco `v × MAX`) non cambia, quindi una inserzione del giocatore o Vendi subito rende al più `v × MAX × (PPM + HI) × (PPM − CUT) ÷ PPM³` per pezzo.
**Garanzia**: ogni `unit_p` ≥ `ceil_div(⌊v × EQMIN × (PPM + off_j) ÷ PPM²⌋ × (PPM + MK), PPM)` ≥ `v × EQMIN × (PPM + MK) ÷ PPM²` (per F-215 `idx_b ≥ EQMIN`, `off_j ≥ 0`), e la vendita di un pezzo è ≤ `v × MAX × (PPM + HI) × (PPM − CUT) ÷ PPM³`
(Vendi subito `v × MAX ÷ PPM`, Deposito `v`). **Vincolo del validatore**:
`EQMIN × (PPM + MK) × PPM > MAX × (PPM + HI) × (PPM − CUT)` (con `CUT` = `listing.cut_pct` in ppm; prodotti ≤ 1,6 × 10¹⁸ < 2⁶³; `EQMIN = BASE − AMP − PB−` di F-174 per ogni fascia, il minimo).
Valori attuali: `1.050.000 × 1.450.000 × 10⁶ = 1,5225 × 10¹⁸` > `1.260.000 × 1.250.000 × 950.000 = 1,4963 × 10¹⁸` (margine 1,8 %): **comprare e rivendere perde sempre** (anche deposito escluso). Con `MK` 40 % il vincolo salta (1,47 × 10¹⁸):
`MK` minimo ammesso = **43 %** (con `HI` 25 %, `CUT` 5 %). Altri vincoli: `0 ≤ MK < 10 × PPM`; `W ≥ 1`; `REFILL ≥ 1`; `ceil_div(KMAX × stack, r_i) ≤ offline.max_hours × 3.600.000 ÷ block_ms` per ogni fascia;
`blueprint_margin` come F-151 ma con il nuovo costo: `c(x) = ceil_div(⌊v_x × EQMIN × PPM ÷ PPM²⌋ × (PPM + MK), PPM)` se `x` è acquistabile (il minimo d'acquisto con `off` 0), altrimenti `v_x`; **da riverificare** (§ «Progetti»).
**Progetti (rischio noto)**: il costo minimo d'acquisto scende da 2,20 × `v` a 1,5225 × `v` (× 0,692). Il vincolo di F-151 `Σ qty × c(x) ≥ value(pezzo) × (100 + margine)/100` va rieseguito per **ogni** progetto: quelli che non lo rispettano
(il caso peggiore di M23, 1,051 con il vecchio costo, scenderebbe sotto 1 se i componenti fossero tutti acquistabili) si correggono nei **dati** (M38-2: un componente tolto dall'elenco acquistabile o più materiali rari), non nelle formule.
**Simulazione** (`tools/sim_market.gd`, M38-5): (1) per ogni acquistabile e 1.000 stati casuali (blocco, `sat`, `taken`): `unit` del primo pezzo > vendita di un pezzo al tetto (`v·MAX`) e > ricavo massimo di una inserzione;
(2) 10.000 strategie compra/vendi/attendi (con `taken` che si consuma e si rifà) su 12 h: **oro finale + pezzi × `v·MAX` ≤ oro iniziale**; (3) progetti come sopra; (4) equivalenza 12 h = 100 ms = 60 s con `taken`;
(5) e (8) di F-151/F-182 **invariate**; (6) ogni `ask` ≤ limite di F-182 (invariato); (7) 2.000 strategie su 48 h con acquisto sul libro, inserzioni e annullamenti: nessun guadagno; (10) **«compra tutto»**: dallo stato a riposo comprare tutto il libro
(`V`) e metterlo in vendita al suggerito per 12 h rende **meno** del costo (soglia: ricavo netto ≤ 0,95 × costo, tutte le fasce); stampa il costo totale/`V × v`, il prezzo medio sul migliore e le ore di recupero di `taken`;
(11) ritmo: pezzi acquistabili in 12 h per oggetto (`V + 144 × r_i`) stampato per confronto con M23 (`S + 144 × r(S)`, senza soglia). Se (1), (2), (7) o (10) saltano: nessun ritocco ai dati, numeri al Reviewer.

## F-210 (modificata) Scarto sulla media e F-211 (modificata) Massimo acquistabile
**F-210**: `ref` = F-214 (`mode` `buy` → serie acquisto `a_e`, `sell` → serie vendita `s_e`); `unit` = `buy_unit(id)` (F-215, prezzo del pezzo in posizione `taken`, 0 se nessuno disponibile) in Compra, `sell_quote(id, 1)` in Vendi.
`ref ≤ 0` o `unit ≤ 0` → `NO_GAP`. `gap_pct = arrotonda(100 × (unit − ref) ÷ ref)` (metà lontano da zero); colori e soglie ±2 / ±1 come in M37. Esempi (= test): `redbirch_grip` blocco 0, `taken` 0 → unit **350**, ref **350** → **0**
(oggi +171); `taken` 1.000 → unit **493** → +41; `sat` 56.000 (Vendi, indice 1.145.052) → unit ⌊200 × 1.145.052 ÷ PPM⌋ = **229** contro ref **240** → **−5**; `unit` 0 o `ref` 0 → `NO_GAP`.
**F-211**: `unit = buy_unit(id)`; `max_buyable` = 0 se non si compra, `unit ≤ 0`, `buy_level` > livello, `avail = 0`; altrimenti il più grande `q ≤ avail` con `costo(q) ≤ oro` (F-215, ricerca sul libro in un passaggio), poi ridotto a quanto entra nel Deposito.
Esempi (`redbirch_grip`, `taken` 0): oro **10.000** → **28** (28 × 350 = 9.800); oro **36.000** → **102** (69 × 350 + 33 × 359 = 35.997); oro 349 → **0**; `taken` 1.193 → **0**; oro enorme → `avail`; Deposito pieno → 0.
Test: `test_auction_reference.gd`, `test_auction_buy.gd`, `test_auction_view_m38.gd`.

## F-218 Conferma degli acquisti grandi
Dato un acquisto di `q` pezzi con `avail` disponibili e costo `C` (F-215): è **grande** se `q × PPM ≥ SH × avail` (con `SH` = `buy.confirm_share_pct` in ppm, 500.000 = 50 %) **o** se `C × PPM ≥ q × unit_best × (PPM + PR)`
(`PR` = `buy.confirm_premium_pct` in ppm, 250.000 = +25 % sul prezzo migliore). `avail ≤ 0` o `q ≤ 0` → non grande. La UI chiede conferma (con totale, prezzo medio e quota del libro) solo se è grande; **nessun tetto**, il comando `buy` non conosce la conferma.
Esempi (`redbirch_grip`, `taken` 0, `avail` 1.193, `unit_best` 350): `q` 100 → **no** (8 %; media 353, +0,8 %); `q` 596 → **no** (49,96 %; ma `q` 597 → **sì**, 50,04 %); `q` 1.000 → **sì**;
`taken` 1.000, `avail` 193, `q` 100 → **sì** (51,8 %); `riftite_plate` `q` 14 di 27 → **sì**; `q` 1 → no.
Test: `tests/systems/auction/test_auction_view_m38.gd`.

## 9f. Chiavi di `balance.json` (M38)
| Chiave | Valore | Formula |
|---|---|---|
| `auction.buy.markup_pct` | **45** (era `spread_pct` 150) | F-215, F-217 |
| `auction.buy.blueprint_margin_pct` | 3 (invariata) | F-217 |
| `auction.buy.confirm_share_pct`, `confirm_premium_pct` | 50, 25 | F-218 |
| `auction.supply.refill_pct_per_block` | 1,5 (ex `stock.refill_pct_per_block` 1,4) | F-216 |
| `auction.reference.window_epochs` | 24 | F-214 |
| `auction.stock.{gold, min, max, refill_pct_per_block}` | **tolte** | (F-150 sostituita) |
`book.ask_min_pct` (0) e `ask_max_pct` (25) **restano**: il lato vendita è invariato. (La proposta iniziale di `M38_CASA_ASTE_WOW.md` §4 di portare `LO`/`HI` a ≈ 20/60 è **ritirata**: vedi §8 di quel documento.)
