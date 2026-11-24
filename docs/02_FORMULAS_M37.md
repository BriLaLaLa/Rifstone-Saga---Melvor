# 02. Formule, §5q: Casa d'Aste, storico e letture (F-209…F-213; M37, V47)

Estensione di `02_FORMULAS.md` (§9, F-145…F-152, F-172…F-183). Regole in `01_GDD_M37.md` (§45). Convenzioni: interi (rame), `floor`; «arrotonda» = metà **lontano da zero**.
Gli esempi sono **casi di test** con tabelle di prova scritte nel test (non i dati veri). Commissione negli esempi 5 % (`AuctionBook.cut`, F-180), `block_ms` = 600 000 (fixture).

## F-209 Voce di storico (`AuctionHistory`)
Struttura `{"kind", "item", "qty", "unit", "net", "block", "listing"}`; `kind` ∈ {`listing_sold`, `instant_sold`, `expired`, `cancelled`}; `listing` = id dell'inserzione (0 per `instant_sold`).
Eventi che scrivono (e solo questi, dentro `AuctionHouse`):
- inserzione, evento `sold` di `process_block` (pezzi `s`, prezzo `p`, netto `n`): voce `listing_sold` con `qty = s`, `unit = p`, `net = n`, `block` = blocco attuale. Se esiste già
  una voce `listing_sold` con lo stesso `listing` (l'id dell'inserzione è unico), **si fonde**: `qty += s`, `net += n`, `block` = attuale (unitario invariato) e la voce passa in cima;
- `sell(item, qty)` (Vendi subito) con ricavo `g`: `instant_sold`, `qty`, `unit = floor(g / qty)`, `net = g`, `listing = 0`; mai fusa;
- evento `expired` (pezzi `r`): `expired`, `qty = r`, `unit` = prezzo dell'inserzione, `net = 0`; `cancel_listing` (pezzi `r`): `cancelled`, stessi campi; l'evento `closed` (0 pezzi) **non** scrive.
Nuova voce in cima (la più recente è l'indice 0); dopo l'inserimento, se `size > history_max` si scartano le più vecchie.
Esempi: inserzione 7 (item X, prezzo 300), blocco 100 vende 4 → `{listing_sold, X, qty 4, unit 300, net 1140, block 100, listing 7}` (lordo 1200, commissione 60); blocco 101 vende altri 2
(net 570) → **una** voce `qty 6, net 1710, block 101`; blocco 102 vende 1 della 7 e 1 della 8 (ordine di `process_block`: per id) → la 7 diventa `qty 7`, e in cima c'è la nuova voce della 8: due voci in tutto, qualunque sia l'alternanza dei blocchi; Vendi subito 5 pezzi per 1500 → `unit 300, net 1500, listing 0`;
scadenza con 6 pezzi rimasti, prezzo 300 → `{expired, qty 6, unit 300, net 0}`; con `history_max` 50, la voce 51 scarta la più vecchia (restano 50, la più recente per prima);
evento `closed` → nessuna voce; `advance` offline di molti blocchi = stesse voci dell'online (test di equivalenza).
Test: `tests/systems/auction/test_auction_history.gd`.

## F-210 Scarto sulla media (`price_gap`)
`value` = `value_of(item)`; `unit` = `buy_quote(item, 1)` in Compra, `sell_quote(item, 1)` in Vendi (0 se non trattabile). Se `value ≤ 0` o `unit ≤ 0`: **non disponibile** (`NO_GAP`).
`gap_pct = arrotonda(100 × (unit − value) / value)` (intero, può essere negativo). Colore (UI): `good` se `gap_pct ≤ −2` in Compra o `≥ +2` in Vendi, `bad` nel caso opposto, neutro tra −1 e +1.
Esempi (`value` 1000): unit 1150 → +15; 940 → −6; 1005 → +1 (0,5 arrotondato lontano da zero); 995 → −1; 1000 → 0; `value` 0 → non disponibile; oggetto non trattato → non disponibile.
Test: `tests/systems/auction/test_auction_view_m37.gd`.

## F-211 Massimo acquistabile (`max_buyable`)
`unit = buy_quote(item, 1)`. Se l'oggetto non si compra, `unit ≤ 0`, o `buy_level(item) > level()` (edificio): **0**. Altrimenti `max = min(stock(item), floor(oro / unit))`, e se `can_buy(item, max)`
rifiuta con `bank_full` si riduce a quanto entra nel Deposito (la UI mostra il motivo di `can_buy` quando `max = 0`). La UI imposta la quantità a `max(max, 1)`.
Esempi (unit 250): scorta 40, oro 5000 → 20; scorta 12, oro 5000 → 12; scorta 40, oro 249 → 0; oggetto con `buy_level` 3 con edificio al livello 2 → 0; scorta 0 → 0; Deposito pieno → 0.
Test: `tests/systems/auction/test_auction_view_m37.gd`.

## F-212 Età di una voce
`age_ms = (block_now − block) × block_ms + pending_ms` se `block_now ≥ block` (con `block_now = block` vale `pending_ms`, 0 ≤ `pending_ms` < `block_ms`); se `block_now < block` (dato incoerente): 0.
Esempi (`block_ms` 600 000, `pending_ms` 120 000): voce al blocco 100, ora 100 → 120 000 (2 min); ora 103 → 1 920 000 (32 min); ora 99 → 0.
Test: `test_auction_history.gd`. Formato del testo (UI): «adesso» sotto 1 min, «N min», «N h», «N g».

## F-213 Riepilogo delle inserzioni attive
`count` = inserzioni attive; `units` = Σ `qty` (pezzi ancora in vendita); `expected_net` = Σ `listing_net(qty, price)` (F-180, commissione per inserzione, nessun deposito: già pagato).
Esempi: inserzione A qty 10 prezzo 200 (lordo 2000, commissione 100 → 1900) e B qty 3 prezzo 1000 (3000, 150 → 2850) → `count 2, units 13, expected_net 4750`; nessuna inserzione → `0, 0, 0`.
Test: `tests/systems/auction/test_auction_view_m37.gd`.
