# M21: Mappa del Villaggio (V7 punto 6)

Seguito di `M19_VILLAGGIO.md` e `M20_BACHECA.md`: una vista a mappa della pagina Villaggio. Design in `01_GDD.md` §32, schema in `04_DATA_SCHEMA.md` §26,
contratto UI in `05_INTERFACES.md` §7.r, task M21-02…04 in `07_TASKS.md`. **Nessuna formula, nessuna stat, nessun `sim_*`** (solo UI); save v7 invariato.

## Fissato da M21-01 (2026-11-13)
- **Affianca, non sostituisce**: la pagina ha le viste **Mappa** (predefinita) ed **Elenco** (la griglia di box attuale, invariata). Sulla mappa un clic seleziona un edificio e il suo box compare come **pannello di dettaglio** (stesso `VillageBox`, un solo comando `upgrade`).
- **Dati**: `map_pos` obbligatorio per edificio in `buildings.json` (validato: 0..1, nessuna sovrapposizione `|dx| ≥ 0,22` o `|dy| ≥ 0,16`) e `page` facoltativo (`noticeboard` → Bacheca, `market` → `shop`). I `levels` generati non cambiano; `gen_village.gd` conserva i due campi.
- **Stati del nodo** (derivati): `locked` (livello 0 e Falegname troppo basso), `unbuilt`, `ready` (pagabile ora), `built`, `maxed`, `placeholder`. Funzione pura `VillageNodeState.of(...)`, testata a tabella.
- **Pulsante "Apri"** nel dettaglio di Bacheca e Mercato: abilitato solo se costruiti; `VillagePage` emette `page_requested`, `page_host` lo collega a `show_page`.
- **Riuso di `combat_map.gd`**: si copia lo schema (ancore per `map_pos`, un bottone per nodo, bordo per stato), nessun componente comune e nessun refactor del combattimento (overlay modale contro vista incorporata). `combat_map.gd` non si tocca.
- **Stato di vista** (Mappa/Elenco, selezione): solo nella pagina, non salvato. Nessun asset nuovo (icone di `assets/icons/ui`, `missing` come ripiego).
- **Parallelismo**: M21-02 (DATA/CORE) in parallelo con M21-03 (UI, con lo stub), poi M21-04 (QA/REV, tag `m21-done`).
- **Scartati**: edifici trascinabili o terreno con strade e abitanti (Township), animazioni, nebbia o sblocco progressivo della mappa, mappa come overlay modale, ricordare la vista per slot (Q90).
