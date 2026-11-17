# 02. Formule, §5n: Casa d'Aste v2 e monete (F-177…F-184; M27, V33-V34)

Estensione di `02_FORMULAS.md` (che supera le 400 righe): vale come la sua sezione **§5n**, con le chiavi §9e. Convenzioni di `02_FORMULAS.md` §5k: interi, **ppm** (`PPM` =
1.000.000; ogni `*_pct` dei dati si converte con `ppm = roundi(pct × 10000)`), `a ÷ b` divisione intera troncata verso zero (come GDScript), `ceil_div(a, b) = (a + b − 1) ÷ b`
per `a ≥ 0`, `H` = hash di F-146. Gli esempi sono **casi di test**. Regole in `01_GDD_M27.md` (§39), dati in `04_DATA_SCHEMA_M27.md` (§32), contratto in `05_INTERFACES_M27.md`.
Nessuna stat nuova in `stats.json`; nessuna sorgente nuova in `ModifierService`. **Invariate nella forma**: F-145…F-152, F-172…F-176 (cambia solo l'unità del denaro, F-177).

---

## Filone A: monete

### F-177 Monete: unità, scomposizione, conversione dei dati e del salvataggio
**Unità**: ogni importo di denaro (portafoglio, prezzi, valori, ricompense, depositi) è un intero in **rame**. `CPS` = `currency.copper_per_silver` (100), `SPG` =
`currency.silver_per_gold` (100), `CPG = CPS × SPG` (10.000).
**Scomposizione** di `c ≥ 0`: `g = c ÷ CPG`; `s = (c mod CPG) ÷ CPS`; `r = c mod CPS`. Ricomposizione `c = g × CPG + s × CPS + r` (campi del prezzo nella UI, con `g, s, r ≥ 0`).
**Testo** (`Money.text`): le parti diverse da zero in ordine oro, argento, rame, ognuna `<n><simbolo>`, separate da uno spazio; `c = 0` → `"0" + simbolo del rame`; `c < 0` →
`"−" + testo(−c)` (solo per i delta). Simboli di `currency.symbols` (`o`, `a`, `r`; Q160). Nessun separatore delle migliaia.
Esempi (= test, `tests/core/common/test_money.gd`): 0 → (0, 0, 0) **"0c"**; 7 → **"7c"**; 100 → (0, 1, 0) **"1a"**; 10.000 → **"1o"**; 12.540 → (1, 25, 40) **"1g 25s 40c"**;
125.000 → **"12g 50s"**; 1.000.005 → (100, 0, 5) **"100o 5r"**; 6.760.916 → **"676o 9a 16r"**; −250 → **"−2s 50c"**. Ricomposizione (1, 25, 40) → 12.540; (0, 0, 0) → 0.

**Conversione una tantum (M27-03)**: `LEGACY` = **100** (costante storica `V11_COPPER_PER_GOLD` di `migration_10_to_11.gd`, congelata): **1 oro di prima = 1 argento = 100 rame**.
- **Dati**: ogni campo di denaro elencato in `04_DATA_SCHEMA_M27.md` §32.2 si moltiplica per `LEGACY` (anche le coppie min-max e le liste); i rapporti (`*_growth`, `*_mult`,
  `*_weight`, `*_pct`, `reward_mult`, `cost_mult`) **no**. Lo fa uno script una tantum su `data/` e su ogni cartella di fixture.
- **Generatori** (dopo la conversione): **lavorano in argento**. Leggono un importo dei dati con `÷ CPS`, calcolano con le loro costanti e regole di oggi, scrivono `× CPS`.
  Per questo le formule dei generatori di `02_FORMULAS*.md` (F-131, F-134, F-170, F-171, gli importi di `gen_areas`, `gen_dungeon`, `gen_equipment`, `gen_market`…) si leggono
  **in argento** invariate e i dati rigenerati sono **esattamente** ×100 di quelli di M26 (`--check` di ogni generatore verde). I validatori che ricalcolano costi del Villaggio
  (F-131) e ricompense della Bacheca (F-134) arrotondano a `10 × CPS` rame (prima: a 10 oro): stesso risultato ×100.
- **Salvataggio** v10 → v11: `wallet.gold` (intero ≥ 0, anche float intero del JSON) → `wallet.copper = gold × LEGACY`. Esempi: 1.250 → **125.000** ("12g 50s"); 0 → **0**;
  1250.0 → **125.000**; `"x"` o −5 → chiave tolta (il portafoglio carica 0 con `Log.warn`, come oggi); modulo `wallet` assente → resta assente (partita nuova).
Esempi sui dati veri (= test, `tests/data/test_data_validity.gd`): `redbirch_grip` `value` 2 → **200**; `riftite_plate` 595 → **59.500**; `buy_recipe_forge_ashlead_plate`
`cost.gold` 1.050 → **105.000** (F-170 in argento: `max(100, 50 × 21)` = 1.050 a); reagenti della Forgia (F-171 in argento) prezzi 2, 7, 21, 60 → **200, 700, 2.100, 6.000**,
valori 0, 1, 5, 15 → **0, 100, 500, 1.500**; `start.gold` 50 → **5.000**; `auction.stock.gold` 6.000 → **600.000**; fasce di `population.json` `max_value` 9, 59, 249 →
**900, 5.900, 24.900**; `auction_house` livello 1 → **30.000**, livello 4 → **82.000**, livello 8 → **316.000**; `quest.gold_by_tier[0]` 80 → **8.000**.
**Invarianti** (= test): `S(v)` di F-150 e la fascia di F-172 non cambiano per nessun oggetto (numeratore e denominatore scalano insieme): `redbirch_grip` `S` 500, fascia 1;
`riftite_plate` `S` 10, fascia 4; `shardcedar_grip` (3.600) fascia 2, `S` 166; `seared_riftmaw` (17.000) fascia 3, `S` 35.

**A runtime** le formule calcolano in rame. Quelle lineari danno esattamente ×100 (F-18, prezzi e costi letti dai dati, F-158/F-159, raffinazione, F-94 (attrezzi), F-134). Quelle che arrotondano un importo a ogni operazione ora arrotondano al rame (**arrotondamento fine**, differenza < 1 argento per operazione, Q168): F-31 (`randi_range`
sull'intervallo ×100 e `floor` con `gold_drop_pct`), F-139 (miniboss) e F-110 (Fratture: `round` dell'intervallo × `reward_mult`), F-142/F-143 (dungeon), F-148/F-175 (vendita), F-151/F-176
(acquisto). Esempi ricalcolati (= test, `seed` 12345):
- F-148 (`v` 1.000, `sat` 0, `q` 100, `eq` 1.150.000): `Σ` 113.762.500 → **113.762** rame (prima 1.137 oro); in due vendite da 60 e 40: **68.557 + 45.205 = 113.762** (nessuna perdita
  d'arrotondamento); `v` 100, `q` 2.000 → **180.522**; `v` 7.000, `sat` 400.000, `q` 10 → **52.421**.
- F-175: `redbirch_grip` (`v` 200), `q` 100 → **22.802**; `v` 100 in fascia 1, `q` 2.000 → **190.020**; `riftite_plate` (`v` 59.500), `q` 100 → **6.760.916**.
- F-176: `riftite_plate` blocco 0, `sat` 0 → `unit` = ⌈59.500 × 2.695.823 / 10⁶⌉ = **160.402** (prima 1.605 oro = 160.500 rame); vendita di un pezzo **71.151**; `unit` al minimo
  dell'indice ⌈59.500 × 2,2⌉ = **130.900**.

## Filone B: libro delle inserzioni e inserzioni del giocatore

Parametri (`balance.json` `auction.book`, `auction.listing`, §9e; `population.json` `stack`): `PL` = `persist_blocks` 6; `LO` = `ask_min_pct` 0 → 0; `HI` = `ask_max_pct` 25 →
250.000; `SPL` = `sellers_per_listing` 10; `KMIN` 4, `KMAX` 12; `FILL` = `fill_pct` 50 → 500.000; `FMAX` = `fill_max_pct` 90 → 900.000; `Q` = `stack` della fascia (200, 60, 20, 5);
`MA` = `max_active` 10; `CUT` = `cut_pct` 5 → 50.000; `MAXP` = `max_price_pct` 1.000 → 10.000.000; durate `short` 12 h (deposito 1% → 10.000), `medium` 24 h (2%), `long` 48 h (4%).
`v` = `value` dell'oggetto in rame; `block` = blocco del mercato (F-145); `idx` = indice di F-174 al blocco con la saturazione attuale; `seed` = seme del mercato (F-146).

### F-178 Inserzioni dei PNG (senza stato)
Al blocco `b`, per l'oggetto `id` (fascia → `B0`, `S0`, `Q`) con saturazione `sat`:
- `(B, Sv)` = popolazione di F-173 al blocco `b`; **numero** `K = clamp(Sv ÷ SPL, KMIN, KMAX)`; **epoca** `e = b ÷ PL`;
- per `j` = 0…K−1: **ricarico** `off_j = LO + H(id + "|ask|" + str(seed) + "|" + str(e) + "|" + str(j)) mod (HI − LO + 1)`; **quantità** `q_j = 1 + H(id + "|qty|" + str(seed) + "|" + str(e) + "|" + str(j)) mod Q`;
- **prezzo** `ask_j = max(1, (v × idx × (PPM + off_j)) ÷ PPM²)` (rame per pezzo; prodotto < 2⁶² con il vincolo `v ≤ 1.000.000` degli oggetti in elenco);
- **ordine**: `ask` crescente, a parità `j` crescente. **Volume** `V = Σ q_j`.
Vettori (= test, `tests/systems/auction/test_auction_book.gd`, `seed` 12345): `H("redbirch_grip|ask|12345|0|0")` = **2.300.331.800** → `off_0` = **72.599**;
`H("redbirch_grip|qty|12345|0|0")` = **1.891.832.868** → `q_0` = **69**.
Esempi (= test, `sat` 0):
- `redbirch_grip` (`v` 200, fascia 1, `Q` 200), blocco 0: `B` 102, `Sv` 125 → `K` **12**, `idx` 1.201.052 (prezzo di mercato **240**); libro (prezzo × quantità, `j`): **241×69** (11),
  **247×169** (5), **250×53** (6), **252×79** (1), **257×69** (0), **257×154** (3), **264×154** (8), **273×18** (10), **279×113** (4), **282×69** (9), **291×176** (7), **297×70** (2); `V` **1.193**.
- stesso, blocco 5 (stessa epoca): stessi ricarichi, `idx` 1.194.395 → prima inserzione **239×69**; blocco 6 (epoca 1): ricarichi nuovi, `V` **950**, prima **258×69**.
- stesso, blocco 36: `B` 136, `Sv` 118 → `K` **11**, `idx` 1.150.372, `V` **1.245**, prima **240×194**.
- `riftite_plate` (`v` 59.500, fascia 4, `Q` 5), blocco 0: `B` 107, `Sv` 88 → `K` **8**, `idx` 1.195.823 (mercato **71.151**); libro **72.640×4, 73.168×4, 74.627×4, 79.671×3,
  80.070×3, 81.958×5, 86.514×2, 87.939×2**; `V` **27**.
Proprietà: stesso `seed`, `id`, `b`, `sat` → stesso libro; `ask_j ≤ v × MAX × (PPM + HI) ÷ PPM²`; nessun tiro; nulla di salvato.

### F-179 Domanda e vendita a ogni blocco
- **Domanda** `fill = min(FMAX, FILL × B ÷ Sv)`; `D = V × fill ÷ PPM` (pezzi che i compratori comprano nel blocco, partendo dal più economico; `D < V` perché `FMAX < PPM`).
- **Davanti** a un'inserzione `L` del giocatore (prezzo `p`, pezzi rimasti `r` all'inizio del blocco, id `n`): `ahead(L) = Σ q_j` delle inserzioni PNG con `ask_j ≤ p` (a parità di
  prezzo i PNG passano prima) `+ Σ r_M` delle inserzioni `M` del giocatore **sullo stesso oggetto** con `(p_M, n_M) < (p, n)`.
- **Venduti** `sold(L) = clamp(D − ahead(L), 0, r)`. Un'inserzione sopra l'ultima PNG non vende mai (`ahead ≥ V > D`).
Esempi (= test, `seed` 12345, `sat` 0): `redbirch_grip` blocco 0: `fill` 500.000 × 102 ÷ 125 = **408.000**, `D` **486**; blocco 1: `B` 103, `Sv` 125, `fill` **412.000**, `D` **491**;
due inserzioni al blocco 1: `L1` (id 1) a 245 con 100 pezzi → `ahead` **69** → venduti **100**; `L2` (id 2) a 250 con 600 → `ahead` 69 + 169 + 53 + 100 = **391** → venduti **100**.
Blocco 36: `fill` **576.271**, `D` **717**. `riftite_plate` blocco 0: `fill` **607.954**, `D` **16**.

### F-180 Inserzione del giocatore: creazione, ciclo di vita, deposito, commissione
**Creazione** al blocco corrente `b0`: `1 ≤ qty ≤ posseduti`; `1 ≤ price ≤ max_price = max(1, v × MAXP ÷ PPM)` (10 × `v`); `deposit = max(1, ceil_div(v × qty × DEP_d, PPM))`
(speso subito, mai restituito); `end = b0 + hours_d × 3.600.000 ÷ block_ms` (12 h → +144, 24 h → +288, 48 h → +576); al massimo `MA` inserzioni attive.
Esempi: `redbirch_grip` 600 pezzi `short` → deposito **1.200**, `max_price` **2.000**; `riftite_plate` 10 `long` → **23.800**; 1 pezzo da `v` 100 `short` → **1** (minimo).
**A ogni blocco** `b` con `b0 < b ≤ end` (dentro `AuctionHouse.advance`, F-184), in quest'ordine:
1. il mercato avanza di un blocco (recupero della saturazione e rifornimento delle scorte di F-175, una volta);
2. per ogni oggetto con inserzioni attive, libro (F-178) e `D` (F-179) del blocco `b` con la saturazione dopo il recupero; `sold` di ogni inserzione dell'oggetto (F-179);
3. per ogni inserzione con `sold > 0`: `gross = sold × price`; `cut = ceil_div(gross × CUT, PPM)`; `net = gross − cut`; `r −= sold`; `sold_total += sold`; `earned += net`;
4. per ogni oggetto: `sat = min(CAP, sat + Σ sold × STEP_i)` (F-175, una volta per blocco);
5. Posta, in ordine di id dell'inserzione: `net` in un messaggio `auction_sold` (F-183); un'inserzione con `r = 0` si chiude (`sold_out`);
6. inserzioni con `b = end` e `r > 0`: **scadute**, i `r` pezzi in un messaggio `auction_expired`; chiuse.
**Annullare** (comando, inserzione attiva): i `r` pezzi in un messaggio `auction_cancelled`; deposito perso; chiusa. Le vendite già fatte restano.
Esempi (= test, `seed` 12345, `redbirch_grip`, creazione al blocco 0 con `sat` 0, durata `short`):
- **600 a 250**: deposito 1.200; blocco 1 `ahead` 291, `D` 491 → **200** (`gross` 50.000, `cut` 2.500, `net` **47.500**; `sat` 40.000); blocchi 2-3 `ahead` 593 → 0; blocco 4 → **139**
  (`net` **33.012**); blocco 5 → 0; blocco 6 → **261** (`net` **61.987**), chiusa. Ricavo netto **142.499** (Vendi subito di 600 al blocco 0: 136.938; F-18: 120.000).
- **300 a 270** (il mercato scende, poi risale): blocchi 1-11 **nessuna vendita**; blocco 12 → **96**; blocchi 13-29 nulla; 30 → **55**, 31 → **62**, 32 → **43**, 33 → **44**, chiusa.
- **100 a 300**: mai venduta; al blocco **144** scade e i 100 pezzi vanno in Posta.
- `riftite_plate` **10 a 75.000**: blocco 1 → **4**, blocco 2 → **4**, blocco 3 → **2** (`sat` dopo i blocchi: 1.108, 1.108, 554).

### F-181 Prezzo di mercato, prezzo suggerito, stato e riepilogo del libro
- **Prezzo di mercato** = `sell_quote(id, 1)` = `(v × idx) ÷ PPM` (F-175). **Suggerito** = `max(1, ask_min − 1)`, con `ask_min` = la PNG più economica del blocco corrente.
  Esempi (blocco 0, `sat` 0): `redbirch_grip` mercato **240**, suggerito **240**; `riftite_plate` **71.151**, suggerito **72.639**.
- **Stato** di un'inserzione attiva (previsione col blocco corrente, non una storia): `selling` se `D − ahead(L) > 0`, altrimenti `undercut` ("superata"). Esempi (blocco 0):
  600 a 250 → `ahead` 291 < 486 → **selling**; a 270 → `ahead` **747** ≥ 486 → **undercut**.
- **Libro mostrato** = PNG + inserzioni del giocatore, ordinati per prezzo (a parità: PNG prima, poi `j`, poi id); **riepilogo**: `listings` = `K` + inserzioni del giocatore
  sull'oggetto, `units` = `V` + i loro `r`.
- **Tempo rimasto** = `(end − block) × block_ms − pending_ms` (creata al blocco 0 con `pending_ms` 120.000, `short` → **43.080.000** ms).

### F-182 Nessun guadagno senza rischio (vincolo del validatore e simulazione)
- Un pezzo di un'inserzione si vende a un prezzo `p ≤` l'inserzione PNG più cara del blocco `≤ v × MAX × (PPM + HI) ÷ PPM²`; il banco vende a `unit ≥ v × (MIN + SPREAD) ÷ PPM`
  (F-151). **Vincolo** nuovo: `(MIN + SPREAD) × PPM > MAX × (PPM + HI)` (con i valori di partenza 2,2 × 10¹² > 1,575 × 10¹²). Quindi ogni pezzo comprato costa più di quanto renda
  in qualunque vendita futura (Deposito, Vendi subito, inserzione), prima ancora di deposito e commissione. Esempi: `riftite_plate` vendita massima **93.712**, banco minimo **130.900**;
  `redbirch_grip` **315** contro **440**.
- Altri vincoli: `0 ≤ LO < HI`; `0 < FILL ≤ FMAX < PPM`; `1 ≤ KMIN ≤ KMAX ≤ 50`; `SPL ≥ 1`, `PL ≥ 1`; `stack ≥ 1`; `1 ≤ MA ≤ 50`; `0 ≤ CUT < PPM`; `MAXP ≥ PPM`; durate: id unici,
  `hours ≥ 1`, `hours × 3.600.000` multiplo di `block_ms`, `deposit_pct ≥ 0`; ogni oggetto in elenco `v ≤ 1.000.000`.
- **Simulazione** (`tools/sim_market.gd`, M27-09; esce con 1 se una soglia salta; soglie (1)-(5) di F-176 invariate in rame): (6) per ogni oggetto in elenco e 1.000 stati casuali
  (blocco, `sat`): ogni `ask` ≤ il limite sopra e, se acquistabile, < `unit`; (7) 2.000 strategie casuali per oggetto acquistabile su 48 h (compra, metti in vendita a prezzi
  casuali, annulla, vendi subito, attendi, ritira la posta): **denaro finale + pezzi rimasti × `v·MAX` ≤ denaro iniziale**; (8) 1 h di produzione dei grezzi T1-T8 messa in vendita al
  suggerito per 12 h: ricavo netto rispetto a F-18 **tra 0,85 e 1,40** e frazione venduta (stampata); (9) equivalenza di F-184 con 3 inserzioni. Stampa anche, per fascia, il tempo
  medio di vendita al suggerito e a +10%. Se (8) salta: nessun ritocco, numeri al Reviewer (Q164).

## Filone C: Posta

### F-183 Posta: consegna, raggruppamento, capienza, ritiro
- Messaggio: `id` (contatore da 1), `kind` (`auction_sold`, `auction_sale`, `auction_expired`, `auction_cancelled`), `item`, `qty`, `price`, `listing` (0 se nessuna), allegato
  `money ≥ 0` **oppure** `items` (`[{item, qty}]`), `read`. Ordine mostrato: `id` decrescente.
- **Consegna**: `auction_sold` si **fonde** con un messaggio `auction_sold` non ritirato della **stessa inserzione** (`money += net`, `qty += sold`, `read = false`); `auction_sale`
  con un `auction_sale` non ritirato dello **stesso oggetto**; i messaggi con oggetti non si fondono. Altrimenti un messaggio nuovo con `id` = contatore.
- **Capienza** `CAP_M` = `mail.capacity` 50: i **comandi** che creano posta (Vendi subito, Metti in vendita) falliscono con `mailbox_full` se i messaggi sono `≥ CAP_M`; la posta
  **automatica** e quella degli annullamenti si consegna sempre. Quindi i messaggi restano `< CAP_M + 2 × MA` (70).
- **Ritira** un messaggio: `unknown_id`; se ha oggetti e `bank.can_add` è falso per uno di essi → `bank_full` e nulla cambia; altrimenti denaro al portafoglio (`add_gold`, se `> 0`) e
  oggetti al Deposito, poi il messaggio si toglie. **Ritira tutto**: in ordine di `id` crescente, ritira ogni messaggio ritirabile; restituisce quanti ne ha ritirati.
- Nessuna scadenza, nessun orario (Q166). Il testo si compone nella UI dai modelli dei dati (variante = `id mod` numero di modelli del tipo).
Esempi (= test): inserzione 600 a 250 di F-180 senza ritirare → **un** messaggio `auction_sold` con `qty` 600, `money` **142.499**; ritirando dopo il blocco 4 → ritirati **80.512**
(`qty` 339), poi al blocco 6 un messaggio **nuovo** (`id` 2) da **61.987** (`qty` 261). Due Vendi subito di `redbirch_grip` (100 e 50) → un messaggio. Con 50 messaggi: `can_list` e `can_sell`
→ `mailbox_full`; una vendita automatica di un'inserzione nuova → 51 messaggi. Deposito pieno e un messaggio di 100 `riftite_plate` non presenti → `bank_full`, messaggio intatto;
"Ritira tutto" con un messaggio di denaro e quello → **1** ritirato.

### F-184 Orologio con inserzioni ed equivalenza
`AuctionHouse.advance(Δ)`: senza inserzioni attive → `AuctionPricing.advance(Δ)` come F-145. Con inserzioni attive: a pezzi fino a ogni confine di blocco (`ms_to_next_block`), e a ogni
blocco intero i passi di F-180. Ogni blocco dipende solo dallo stato all'inizio del blocco e dal suo numero, quindi `advance(a); advance(b)` ≡ `advance(a + b)` (test di proprietà con
inserzioni). `auction_updated(blocks)` una volta per `advance` (somma dei blocchi). **Equivalenza** (= test, `tests/integration/test_m27_offline_equivalence.gd`): tre inserzioni
(una si vende tutta, una a pezzi, una scade), una Vendi subito e la posta non ritirata: 12 h in un colpo = passi da 100 ms = blocchi da 60 s = 6 h + salva/carica + 6 h → stato
completo identico (`auction` con le inserzioni, `mail`, `wallet`, `bank`).

## 9e. Chiavi di `balance.json` (M27)
| Chiave | Valore | Formula |
|---|---|---|
| `currency.copper_per_silver` | 100 | F-177 |
| `currency.silver_per_gold` | 100 | F-177 |
| `currency.symbols` / `currency.names` | `o`/`a`/`r`; "Oro"/"Argento"/"Rame" | F-177 (testi, Q160) |
| `auction.book.persist_blocks` | 6 | F-178 |
| `auction.book.ask_min_pct`, `ask_max_pct` | 0, 25 | F-178, F-182 |
| `auction.book.sellers_per_listing`, `min_listings`, `max_listings` | 10, 4, 12 | F-178 |
| `auction.book.fill_pct`, `fill_max_pct` | 50, 90 | F-179 |
| `auction.listing.max_active` | 10 | F-180 |
| `auction.listing.cut_pct` | 5 | F-180 |
| `auction.listing.max_price_pct` | 1000 | F-180 |
| `auction.listing.durations` | `short` 12 h 1%, `medium` 24 h 2%, `long` 48 h 4% | F-180 |
| `mail.capacity` | 50 | F-183 |
| `population.json` `bands[].stack` | 200, 60, 20, 5 | F-178 |
**Convertite ×100** (F-177): `start.gold`, `village.gold_base`, `quest.gold_by_tier[]`, `trainer.learn_gold`, `trainer.gold_base`, `trainer.unlearn_min_gold`,
`upgrade.levels[].gold_per_grade`, `tool_upgrade.levels[].gold`, `auction.stock.gold`; `population.json` `bands[].max_value`. Invariate: `*_growth`, `*_mult`, `*_pct`.
