# 04. Schema dati, §30: Nodi con tentativi (M25)

Estensione di `04_DATA_SCHEMA_M24.md` §29.3 e §29.6. Le formule sono in `02_FORMULAS_M25.md` (F-161…F-164).

## 30.1 `data/encounters/nodes.json`: campi nuovi (facoltativi)
Per ogni voce di `nodes` di un'area:
| Campo | Tipo | Vincoli |
|---|---|---|
| `difficulty` | int, facoltativo | 1..99; se assente vale il `max_level` dell'area (F-161). Il generatore `tools/gen_nodes.gd` può scriverlo per area e disciplina |
| `min_level` | int, facoltativo | 1..99, ≤ `difficulty` effettiva; se assente 1 (mai saltato per difficoltà) |
`NodeEntryDef` guadagna `difficulty: int` e `min_level: int` (valori già risolti: mai 0). `AreaNodesDef.difficulty_of(skill) -> int`, `min_level_of(skill) -> int`.
Il validatore rifiuta: `difficulty` o `min_level` fuori campo, `min_level` > `difficulty`, tipi sbagliati. Con i dati di partenza M25 **non cambia nessun valore** di `nodes.json`
(i campi si omettono; l'eventuale ritocco è di M25-03, sulla base di F-165 e della sim).

## 30.2 `balance.json`, sezione `encounters` (chiavi nuove, **obbligatorie** dopo M25-02)
`attempts` int 1..10; `yield_free_levels` int ≥ 0; `yield_loss_pct` int 0..100; `yield_min_pct` int 1..100; `rich_chance_pct` int 0..100; `rich_extra_attempts` int 0..10;
`rich_units_pct` int ≥ 100; `rich_ms_pct` int ≥ 100. Nessun vincolo tra durata e `tick_ms`: più tentativi possono cadere nello stesso passo (F-161). Valori di partenza e usi: `02_FORMULAS_M25.md` §9c.
Fixture (`tests/fixtures/data`): chiavi presenti con `rich_chance_pct` 0, `attempts` 1 e `node_chance_pct` 0 (il comportamento dei test esistenti non cambia); casi rifiutati: chiave
mancante, `rich_units_pct` < 100, `yield_min_pct` 0, `min_level` > `difficulty`.

## 30.3 Immagini animate dei nodi (`assets/nodes/`)
Per ogni disciplina di raccolta una cartella `assets/nodes/<skill_id>/` con i fotogrammi `frame_0.svg` … `frame_N.svg` (4-8, stesso riquadro) e un'icona `ricco.svg` per il badge;
la UI costruisce lo `SpriteFrames` dai file per convenzione (nessun JSON). Le particelle sono configurate nella scena della scheda (nessun asset). Nomi originali (clean room).
