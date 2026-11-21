# M32 - Cibo dalla carne e Cucina sempre apprendibile (design, M32-01)

Richiesta dell'utente (V41, testo in `DECISIONS_LOG.md`), prompt dell'Orchestratore in `M32_PROMPT_CIBO.md`.
Verificato nel codice: (a) le ricette `cook_*` di `data/actions/hearthcraft.json` hanno tutte un pesce di `angling`; (b) gli slot sono
`disciplines.max_per_category` (2) in `data/config/balance.json`, contati da `Disciplines.free_slots` / `can_learn`
(`systems/disciplines/disciplines.gd`); (c) i mostri hanno `drops` propri in `data/combat/monsters.json`, generati da `tools/gen_areas.gd`
(le tabelle di area in `loot_tables.json` valgono per tutti i mostri: la carne va nei `drops` del singolo mostro, non nella tabella);
(d) il passo `trainers` del tutorial e' forzato su una raccolta e il cibo iniziale e' solo Trote.

## Decisioni (default, da confermare: Q199-Q203)
1. **Carne**: 10 materiali crudi, uno per area (area 1..10), nomi originali; cadono solo da mostri-animali (bestie, rapaci, rettili, insetti
   giganti: non costrutti, spettri, umani, boss di tipo non animale). Almeno un mostro per area. Probabilita' e quantita' nei dati
   (`tools/gen_areas.gd`, non nei documenti): tarate perche' un personaggio senza Pesca abbia cibo sufficiente a ogni fascia (misura in M32-05).
2. **Cibi cotti**: 10 nuovi in `data/items/food.json`, cura = interpolazione della scala di F-... §8.3 sul livello della ricetta
   (livelli 1,10,20,30,40,50,60,70,80,90; cure 20,35,55,80,95,123,150,183,220,260; il pesce resta com'e').
3. **Ricette `cook_*` di carne**: livelli come sopra, 2500 ms, XP interpolata dalla curva delle ricette di pesce, reagenti `reagent_hearthcraft_1..4`
   con la stessa scala del pesce (nessuno a livello 1; 1 per 10-20; 2 per 30-40; 3 per 50-70; 4 per 80-90), `mastery: true`,
   **senza `discover`** (la carne non deve richiedere ricette da trovare). Le ricette di pesce restano com'erano (con `discover`).
4. **Cucina sempre apprendibile**: campo di dati `free_slot: true` nel Maestro di `hearthcraft` (`data/disciplines/trainers.json`): quella
   disciplina non conta negli slot della categoria `artisan` (ne' per `free_slots` ne' per `can_learn`). Nessun caso speciale per id nel codice.
   Primo grado gratuito come gli altri. **Save invariato** (la disciplina e' gia' salvata in `disciplines.learned`; uno slot v12 con Cucina
   gia' appresa libera semplicemente uno slot).
5. **Pagina Cucina**: ricette gia' ordinate per livello nella lista standard (`ui/pages/skill/`): pesce e carne insieme.
6. **Tonici** (`brew_tonic_*`): chiedono ancora un pesce (Pesca): invariati, Q202.
7. **Tutorial**: il passo `trainers` accetta anche la Cucina; nuovo incarico «Un fuoco da campo» (impara la Cucina e cucina una carne);
   la carne dei primi mostri deve cadere nelle prime uccisioni (area 1).
8. **Economia**: la carne puo' essere venduta e usata dalla Casa d'Aste come ogni materiale; nessuna ritaratura oltre ai drop (nota ore al 99).

## Domande aperte
| Id | Domanda | Default |
|---|---|---|
| Q199 | Le ricette di pesce da `discover` restano da scoprire? | Si', invariate; solo la carne e' sempre disponibile. |
| Q200 | Quanta carne per uccisione? | Beste: ~35% x 1-2; miniboss animale 50% x 2-4; da ritoccare con `sim_combat` (M32-05). |
| Q201 | Gli slot di produzione dello save v12 con Cucina gia' appresa? | Si liberano (Cucina non conta piu'); nessuna migrazione. |
| Q202 | Tonici senza Pesca? | No: servono ancora pesci; chi non pesca li compra in Casa d'Aste. |
| Q203 | Carne nella Casa d'Aste e prezzi? | Come ogni materiale, `value` per cura equivalente al pesce. |
