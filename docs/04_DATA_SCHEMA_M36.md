# 04. Schema dei dati, §37: Statistiche di raccolta (M36B; V46)

Estensione di `04_DATA_SCHEMA.md`. Un solo parametro nuovo, in `data/config/balance.json` (regole di §0-§1 invariate; validatore: intero > 0, chiave obbligatoria).

## 37.1 `balance.json` → `gather_stats`
```json
"gather_stats": { "min_sample_ms": 120000 }
```
| Campo | Tipo | Regola |
|---|---|---|
| `min_sample_ms` | int | > 0; sotto questo tempo di gioco online le «/h» di F-204 non sono disponibili (evita «7200 unità/h» dopo un solo nodo) |

Nessun altro dato nuovo: M36 (UI) non tocca `data/**`; i testi stanno nei file di testi della UI (italiano). Save invariato (v12).
