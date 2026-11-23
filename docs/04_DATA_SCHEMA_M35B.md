# 04. Schema dei dati, §36: Tabelle di risorse per zona (M35B; V45, `01_GDD_M35B.md` §43, `02_FORMULAS_M35B.md` F-200…F-203)

Estensione di `04_DATA_SCHEMA.md` e di `04_DATA_SCHEMA_M24.md` §29.3 (che vale con le modifiche qui sotto). Regole generali di §0-§1 invariate (id `snake_case`, nessun campo
sconosciuto, nessun fallback silenzioso).

## 36.1 `data/encounters/nodes.json`: `resources` in ogni voce di disciplina
Generato da `tools/gen_nodes.gd` (F-201), idempotente. Ogni elemento di `nodes` guadagna `resources` (**obbligatorio**):
```json
{"area": "redrock_plains", "max_level": 10,
 "nodes": [{"skill": "quarrying", "weight": 20,
            "resources": [{"action": "quarry_emberbronze", "weight": 79}, {"action": "quarry_ashlead", "weight": 21}]},
           {"skill": "forestry", "weight": 30, "resources": [...]}, ...]}
```
| Campo | Tipo | Regola |
|---|---|---|
| `resources` | array | non vuoto; **in ordine di `level` crescente** |
| `resources[].action` | string | azione di raccolta della stessa `skill` (esiste in `data/actions/<skill>.json`); unica nella lista |
| `resources[].weight` | int | ≥ 1; **la somma della lista vale 100** (sono percentuali) |
`weight` della voce di disciplina (la scelta di quale nodo) e `max_level` restano; `max_level` **non** limita più la risorsa (F-200), serve a difficoltà e livello minimo (§30.1 di M25).
**Regole globali del validatore**: ogni azione di raccolta di ogni disciplina compare in **almeno una** zona (raggiungibile); la disciplina ha almeno un'azione con `level` 1
(fallback di F-200); la regola vecchia di M24 «`skill` con almeno un'azione di `level ≤ 1`» resta. Classe: `AreaNodesDef` guadagna `NodeResourceDef` (`05_INTERFACES_M35B.md` §5.47).
Casi rifiutati (test del validatore): `resources` assente o vuoto; azione di un'altra disciplina; azione doppia; livelli non crescenti; peso 0; somma diversa da 100; azione mai raggiungibile.
Le **fixture** (`tests/fixtures/data/encounters/nodes.json`) usano un'unica risorsa con peso 100 (nessun tiro): i golden esistenti non cambiano; per i test di F-200 i test costruiscono
un `GameData` con tabelle proprie.

## 36.2 `data/config/balance.json`
`encounters.resource_profile`: lista di 4 oggetti `{"offset": int, "weight": int}` (offset interi unici da −3 a +3, pesi ≥ 1; valori di partenza in F-201). **Letta solo da
`tools/gen_nodes.gd`** (il gioco legge i pesi già scritti in `nodes.json`); il validatore ne controlla il formato. `encounters.colors` e gli altri valori invariati.

## 36.3 Salvataggio (v12, invariato)
Nessun campo nuovo. `disciplines.focus` **non è più scritto**; presente in un salvataggio, viene **ignorato** (`05_INTERFACES_M35B.md` §6i). Nodo in corso: `action` salvata come oggi.

## 36.4 `data/guide/*.json`
Le pagine di Guida che citano la raccolta mirata o «dove si trova» (`mestieri.json` e simili): riscrivere in poche righe «ogni zona ha le sue percentuali; per una risorsa
specifica vai dove è più comune» (testo breve a mano). `GuideIndex.sources_of`/`uses_of` leggono già `nodes.json`: **verificare** che «Si ottiene da» mostri le zone leggendo
`resources` (se facile con la percentuale); altrimenti nessuna modifica.
