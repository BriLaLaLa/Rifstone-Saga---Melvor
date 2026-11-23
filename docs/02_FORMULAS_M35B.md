# 02. Formule, §5o: Risorse per zona con percentuali (F-200…F-203; M35B, V45)

Estensione di `02_FORMULAS.md`: **sostituisce** la parte «risorsa» di F-154 (`02_FORMULAS_M24.md`) e **abroga F-195** (`02_FORMULAS_M35.md`, raccolta mirata). Restano di F-154 il
**colore** e il fallback (vedi sotto); F-155, F-161…F-165, F-198, F-199 invariate. Convenzioni: `floor`, `round` a metà verso l'alto. Gli esempi sono **casi di test**. Regole in
`01_GDD_M35B.md` (§43), dati in `04_DATA_SCHEMA_M35B.md` (§36). Gradini del Minatore (livello): Rame 1, Ferro 10, Ferro scuro 20, Ferro nero 30, Argento runico 45, Ossidiana 60,
Astrite 75, Riftite 90 (le altre tre discipline hanno gli stessi livelli: stessa tabella per indice di gradino).

## F-200 Risorsa del nodo: tiro con i pesi della zona (sostituisce F-154 «risorsa» e F-195)
Per un nodo della disciplina `s` nella zona `a`, con `L` = livello di `s` (F-01, già limitato da F-160) e `T(a, s)` = tabella dei pesi della zona (voci `{action, weight}` **in ordine di
livello crescente**, come nel file; `04_DATA_SCHEMA_M35B.md` §36.1):
1. **Idonee** `E` = le voci con `level(action) ≤ L`, nell'ordine della tabella. Il tetto `max_level` della zona **non interviene più** sulla risorsa (resta il campo per difficoltà e
   livello minimo, `04_DATA_SCHEMA_M25.md` §30.1).
2. **`|E| ≥ 2`** e nodo lavorato → **un solo** `session.rng.pick_weighted([peso di ogni voce di E])`: la voce all'indice estratto è la risorsa. I pesi **non si ricalcolano**: la
   rinormalizzazione delle voci scartate è implicita in `pick_weighted` (probabilità = `peso / somma dei pesi di E`).
3. **`|E| = 1`** → quella voce, **nessun tiro** (il generatore non avanza).
4. **`|E| = 0`** (nessuna voce della zona è ancora lavorabile) → **fallback = regola di F-154 senza tetto**: l'azione di `s` con il `level` più alto tale che `level ≤ L` (a parità la prima
   nel file; esiste sempre, il gradino 1 ha livello 1); **nessun tiro**.
5. **Nodo saltato** (`not_learned` o `too_hard`): la risorsa è la voce di `E` con il peso più alto (la prima nell'ordine a parità), o il fallback se `E` è vuoto; **nessun tiro**
   (come oggi un nodo saltato non consuma il generatore).
**Quando e dove**: in `NodeWork.begin`, **all'inizio** del nodo, **prima** del tiro del nodo ricco (F-199) e prima di ogni altro tiro; l'ordine dei tiri del nodo è
`[risorsa (se |E| ≥ 2), ricco]`. La risorsa si salva nel nodo in corso come oggi (`combat.node.action`); **nessun tiro** al caricamento, nessuna ripetizione. Durata (F-155),
unità, colore (F-154: `d = L − level(risorsa)`, prima voce di `encounters.colors` con `d < below`), XP e maestria usano la risorsa estratta e **non cambiano**.
**Offline**: il tiro sta nello stesso punto (`begin`) del percorso che usano tutti i passi del motore; 12 h in un colpo = passi da 100 ms = blocchi da 60 s, con la stessa
sequenza di risorse (test dedicato). Il **tutorial** (`force_node`, M31/M33) a livello basso (`L` < 10 nella zona 1: `E` = {Rame}) non tira.
Esempi (tabelle di F-201; `pick_weighted` simulato):
- Zona 3 (Rame 5, Ferro 25, Ferro scuro 55, Ferro nero 15), `L` 45, `pick_weighted` → 2: pesi `[5,25,55,15]` → **Ferro scuro**; `d` 25 → **verde**.
- Zona 3, `L` 25, → 1: `E` = {Rame, Ferro, Ferro scuro}, pesi `[5,25,55]` (probabilità 5,9% / 29,4% / 64,7%) → **Ferro**; `d` 15 → **giallo**.
- Zona 3, `L` 5: `E` = {Rame} → **Rame**, **nessun tiro** (posizione del generatore invariata).
- Zona 3, `L` 25, nodo saltato (`not_learned`): **Ferro scuro** (peso massimo di `E`), nessun tiro.
- Zona 10 (Ossidiana 6, Astrite 29, Riftite 65), `L` 1: `E` vuoto → fallback **Rame**, nessun tiro; `L` 62 → `E` = {Ossidiana} → **Ossidiana**, nessun tiro; `L` 80, → 1 su `[6,29]` → **Astrite**.
- Zona 1 (Rame 79, Ferro 21), `L` 10, → 0 → **Rame**, `d` 9 → **arancione** (XP 100%); → 1 → **Ferro**, `d` 0 → **arancione**.
- Il tiro è **uno solo** per nodo: dopo `begin` il generatore è avanzato di 2 passi (risorsa + ricco) se `|E| ≥ 2`, di 1 altrimenti (nodo lavorato), di 0 (nodo saltato).
Test: `tests/systems/encounters/test_resource_roll.gd` (nuovo), `test_encounter_cycle.gd` (colore e fallback), `tests/integration/test_m35b_offline_resource.gd`.

## F-201 Tabella dei pesi per zona (regola del generatore `tools/gen_nodes.gd`)
Per ogni zona `a` (da `data/combat/areas.json`: `level_min`, `level_max`) e ogni disciplina di raccolta `s`, con le azioni di `s` ordinate per livello `A[0..n-1]`:
1. **Gradino di casa** `h` = indice dell'azione con il `level` più alto tale che `level ≤ floor((level_min + level_max) / 2)` (se nessuna, 0).
2. **Profilo** per scarto `i − h` (parametri in `balance.json` → `encounters.resource_profile`, valori di partenza): `−2 → 5`, `−1 → 25`, `0 → 55`, `+1 → 15`; ogni altro scarto → assente
   (nessuna voce). Le voci con indice fuori da `0..n−1` non esistono.
3. **Normalizzazione a 100** con il metodo del **resto più grande**: `raw_i` = peso del profilo, `S = Σ raw_i`, `q_i = raw_i × 100 / S`; si parte da `floor(q_i)` e si assegna `+1` alle
   voci con i resti più grandi finché la somma fa 100 (a parità di resto, prima la voce di livello più basso). Così **ogni peso è una percentuale intera** e la somma è **100**.
4. Si scrivono solo le voci con peso ≥ 1, in ordine di livello crescente. Stessa regola per le quattro discipline (nessun profilo per disciplina).
Casa per zona (mediana → gradino): z1 (5) Rame, z2 (15) Ferro, z3 (25) Ferro scuro, z4 (35) Ferro nero, z5 (45) Argento runico, z6 (55) Argento runico, z7 (65) Ossidiana, z8 (75)
Astrite, z9 (85) Astrite, z10 (95) Riftite. Ogni gradino è casa di almeno una zona (il Rame solo di z1).
| Casa `h` | Zone | Pesi (gradino: %) |
|---|---|---|
| 0 | z1 | Rame 79, Ferro 21 |
| 1 | z2 | Rame 26, Ferro 58, Ferro scuro 16 |
| 2 | z3 | Rame 5, Ferro 25, Ferro scuro 55, Ferro nero 15 |
| 3 | z4 | Ferro 5, Ferro scuro 25, Ferro nero 55, Argento runico 15 |
| 4 | z5, z6 | Ferro scuro 5, Ferro nero 25, Argento runico 55, Ossidiana 15 |
| 5 | z7 | Ferro nero 5, Argento runico 25, Ossidiana 55, Astrite 15 |
| 6 | z8, z9 | Argento runico 5, Ossidiana 25, Astrite 55, Riftite 15 |
| 7 | z10 | Ossidiana 6, Astrite 29, Riftite 65 |
Verifica dei casi con normalizzazione: z1 `raw` 55/15 (S 70): `q` 78,57/21,43 → floor 78/21 (somma 99) → il resto più grande (0,57) → **79/21**; z2 `raw` 25/55/15 (S 95): `q` 26,32/57,89/15,79 →
floor 26/57/15 (98) → resti 0,32/0,89/0,79 → **26/58/16**; z10 `raw` 5/25/55 (S 85): `q` 5,88/29,41/64,71 → floor 5/29/64 (98) → resti 0,88/0,41/0,71 → **6/29/65**.
**Regole del validatore** (`04_DATA_SCHEMA_M35B.md` §36.1): somma dei pesi di ogni voce-disciplina = **100**; azioni uniche, della stessa disciplina, in ordine di livello crescente; ogni azione di
raccolta compare in **almeno una** zona (raggiungibilità); `--check` del generatore: il file coincide con il generato.
Test: `tests/tools/test_gen_nodes.gd` (la tabella sopra, riga per riga, per le quattro discipline), `tests/data/test_node_resources_data.gd`.

## F-202 Probabilità mostrate («Si trova in» e livello attuale)
Per una voce `e` di `T(a, s)`:
- **nominale** `P_nom(e) = weight(e)` (intero, % della zona, somma 100): è la colonna «Si trova in» della pagina di raccolta (una riga per zona dove l'azione compare, ordinate per `P_nom`
  decrescente, a parità per `order` della zona).
- **effettiva** al livello `L`: `P_eff(e) = weight(e) × 100 / Σ weight(E)` se `level(e) ≤ L` (`E` come in F-200), altrimenti 0; è la probabilità reale dei nodi della zona. Se `E` è vuoto
  (fallback) la probabilità del fallback è 100% e quella delle voci della zona 0.
Esempi: «Si trova in» del Ferro (Minatore): z1 21%, z2 58%, z3 25%, z4 5% (ordinate: z2 58, z3 25, z1 21, z4 5); del Rame: z1 79, z2 26, z3 5; della Riftite: z10 65, z9 15, z8 15 (a parità
di 15 prima la zona di `order` minore: z8, z9). `P_eff` zona 3 con `L` 25: Rame 5,9, Ferro 29,4, Ferro scuro 64,7, Ferro nero 0; con `L` 45: 5, 25, 55, 15; con `L` 5: Rame 100.
API in `05_INTERFACES_M35B.md` §5.47. Test: `tests/systems/encounters/test_resource_odds.gd`.

## F-203 Valore atteso del nodo (per `tools/sim_encounters.gd` e F-156)
`E[g] = Σ_e P_eff(e)/100 × g(e)` per una grandezza `g` della risorsa (XP `xp(e) × xp_pct(colore(L − level(e)))/100`, valore di vendita, unità/h…). Le soglie di F-156 si misurano con `L` =
`level_max` della zona (come oggi `L = M`) e la **risorsa attesa** al posto della «migliore ≤ min(L, M)».
Esempio (colore soltanto, zona 4, `L` 40: Ferro d 30 → grigio 0%, Ferro scuro d 20 → verde 20%, Ferro nero d 10 → giallo 50%; Argento runico non idoneo; pesi `[5,25,55]`, somma 85):
`xp_pct` atteso = (5 × 0 + 25 × 20 + 55 × 50) / 85 = **38,2%** (oggi: sempre Ferro nero, giallo, **50%**: −24%, voluto: chi sale oltre la zona rende meno e si sposta). Zona 1, `L` 10:
Rame d 9 e Ferro d 0 → entrambi arancione → **100%** (invariato).
Esempio di effetto sul prodotto: in zona 1 a `L` 10 il 79% dei nodi dà Rame (XP della risorsa di livello 1) e il 21% Ferro: il valore atteso scende, rispetto a «sempre Ferro», di
`0,79 × (v(Ferro) − v(Rame))`. Le soglie (2) e (3) di F-156 si **misurano e riportano**; non si ritara l'economia (Q122) senza decisione (Q226).
Test: `tests/systems/encounters/test_expected_resource.gd`; `tools/sim_encounters.gd` stampa le nuove medie per zona e disciplina.

## Tabella dei parametri (`balance.json`)
| Chiave | Valore di partenza | Usata in |
|---|---|---|
| `encounters.resource_profile` | `[{"offset":-2,"weight":5},{"offset":-1,"weight":25},{"offset":0,"weight":55},{"offset":1,"weight":15}]` | F-201 (solo il generatore la legge; il gioco legge `nodes.json`) |
