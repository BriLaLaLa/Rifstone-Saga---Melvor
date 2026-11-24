# 04. Schema dei dati, §38: Casa d'Aste, storico (M37; V47)

Estensione di `04_DATA_SCHEMA.md` (§28 `auction`, `04_DATA_SCHEMA_M27.md`). Regole di §0-§1 invariate. Un parametro nuovo e una chiave di save additiva (**save v12 → v13**).

## 38.1 `balance.json` → `auction.history_max`
```json
"auction": { "...": "...", "history_max": 50 }
```
| Campo | Tipo | Regola |
|---|---|---|
| `history_max` | int | 1..200, obbligatorio (nessun fallback; chiave sconosciuta dentro `auction` resta errore); campo `AuctionParams.history_max` |

Validatore: `DataValidatorAuction` (intero; fuori range → errore). Le fixture di `tests/fixtures/data` si aggiornano con la stessa chiave.

## 38.2 Save: `auction.history` (v13)
Dentro la chiave `auction` già esistente (accanto a `seed`, `block`, `pending_ms`, `items`, listings):
```json
"history": [ {"k": "listing_sold", "item": "ashlead_ingot", "qty": 6, "unit": 300, "net": 1710, "block": 101, "listing": 7} ]
```
| Campo | Tipo | Regola |
|---|---|---|
| `k` | string | uno tra `listing_sold`, `instant_sold`, `expired`, `cancelled`; altro → voce scartata |
| `item` | string | oggetto esistente nei dati; altrimenti scartata |
| `qty` | int | ≥ 1 |
| `unit` | int | ≥ 0 |
| `net` | int | ≥ 0 |
| `block` | int | ≥ 0 |
| `listing` | int | ≥ 0 (0 per `instant_sold`) |

Ordine: la più recente per prima. Caricamento **tollerante** (come `AuctionListings.from_save`): float JSON interi accettati, voci invalide scartate con `Log.warn`, lista troncata a `history_max`;
chiave assente = lista vuota. `new_game` svuota. **Migrazione** `migration_12_to_13`: aggiunge `auction.history = []` se `auction` è un dizionario e la chiave manca; non tocca altro; versione 13
(`SaveMigrator.CURRENT_VERSION`). Nessun altro dato nuovo; i testi stanno nei file di testi della UI e nella Guida (`data/guide/casa_aste.json`, solo testo).
