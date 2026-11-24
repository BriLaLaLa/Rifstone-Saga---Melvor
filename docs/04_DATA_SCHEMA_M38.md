# 04. Schema dei dati, §39: Casa d'Aste, libro unico (M38; V48)

Estensione di `04_DATA_SCHEMA.md` (§28), `04_DATA_SCHEMA_M27.md` (§32), `04_DATA_SCHEMA_M37.md` (§38). Regole di §0-§1 invariate. Nessun dato nuovo in `data/auction/` (`auction_items.json` e `population.json` invariati). **Save v13 → v14**.

## 39.1 `balance.json` → `auction`
```json
"auction": {
  "...": "invariato: block_ms, history_max, index, drift, saturation, trend, population, book, listing, mail",
  "buy":       { "markup_pct": 45, "blueprint_margin_pct": 3, "confirm_share_pct": 50, "confirm_premium_pct": 25 },
  "supply":    { "refill_pct_per_block": 1.5 },
  "reference": { "window_epochs": 24 }
}
```
**Tolte**: `auction.stock` (`gold`, `min`, `max`, `refill_pct_per_block`) e `auction.buy.spread_pct` (chiave sconosciuta = errore, nessun fallback).
| Campo | Tipo | Regola |
|---|---|---|
| `buy.markup_pct` | numero | `≥ 0` e `< 1000`; vincolo F-217 `EQMIN × (PPM + MK) × PPM > MAX × (PPM + HI) × (PPM − CUT)` (43 % il minimo con i valori attuali); campo `AuctionParams.markup_ppm` |
| `buy.blueprint_margin_pct` | numero | come oggi (solo validatore) |
| `buy.confirm_share_pct`, `confirm_premium_pct` | numero | `0 < share ≤ 100`, `premium ≥ 0`; campi `confirm_share_ppm`, `confirm_premium_ppm` |
| `supply.refill_pct_per_block` | numero | `> 0`; campo `refill_ppm` (già esistente, ora legge questa chiave); vincolo: per ogni fascia `ceil_div(KMAX × stack, r_i) ≤ offline.max_hours × 3.600.000 ÷ block_ms` (F-216, F-217) |
| `reference.window_epochs` | int | 1..200; campo `reference_epochs` |
`AuctionParams`: tolti `stock_gold`, `stock_min`, `stock_max`, `spread_ppm`; aggiunti `markup_ppm`, `confirm_share_ppm`, `confirm_premium_ppm`, `reference_epochs`. Le fixture di `tests/fixtures/data` si aggiornano con le stesse chiavi.
**Progetti**: il validatore ricalcola `Σ qty × c(x) ≥ value(pezzo) × (100 + margine)/100` con `c(x)` di F-217; i progetti che non lo rispettano si correggono in `data/` (M38-2), non con eccezioni nel validatore.

## 39.2 Save: `auction.taken` (v14)
Dentro la chiave `auction` (accanto a `seed`, `block`, `pending_ms`, `items`, listings, `history`): `"taken": {"redbirch_grip": 120, "riftite_plate": 3}`.
| Campo | Tipo | Regola |
|---|---|---|
| chiave | string | oggetto acquistabile (`buy_level ≥ 1`) esistente nei dati; altrimenti scartata con `Log.warn` |
| valore | int | ≥ 0 (float intero accettato); negativo o non numerico → voce scartata (vale 0); oltre `KMAX × stack` → riportato a quel valore |
Chiave assente = tutto 0. `auction.items[<id>].stock` di v13 si **ignora** alla lettura e non si scrive più. `new_game`: `taken` vuoto. `migration_13_to_14` toglie `stock` da ogni oggetto e aggiunge `auction.taken = {}`; un v13 vero carica
senza altre differenze (le monete, il Deposito, le inserzioni, la Posta e lo storico restano). `SaveMigrator.CURRENT_VERSION` = 14.
