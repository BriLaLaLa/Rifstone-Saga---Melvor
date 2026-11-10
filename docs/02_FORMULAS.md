# 02. Formule e bilanciamento

Ogni formula ha un id `F-xx`, i parametri (con il percorso nel file di dati), almeno un esempio numerico verificabile
e il test GUT che la verifica. Gli esempi sono **casi di test**: il test deve riprodurre esattamente quei numeri.

**Unica fonte dei valori.** I valori qui sotto sono la specifica iniziale. Il task M0-05 li scrive in
`res://data/config/balance.json` e `res://data/config/stats.json`; da quel momento **i file sono la fonte di verità**
e il codice legge solo da lì (nessun numero di design nel codice). Chi cambia un valore aggiorna file, test ed esempio
qui nello stesso task.

Convenzioni: `floor` = troncamento verso il basso, `round` = arrotondamento a metà verso l'alto (`roundi` di Godot),
`clamp(x, a, b)`. `T(stat, ctx)` = valore totale della stat nel contesto (F-05). Percentuali "pct" = punti percentuali.

---

## 1. Esperienza e livelli

### F-01 Tabella dell'esperienza (skill)
XP per passare dal livello `L` a `L+1` (L = 1..98):
`delta(L) = floor(base × growth^(L−1) + linear × (L−1))`
XP totale per raggiungere il livello `L`: `xp_for_level(L) = Σ delta(k), k = 1..L−1` (livello 1 = 0).
`level_for_xp(xp)` = il più alto `L ≤ max_level` con `xp_for_level(L) ≤ xp`.
Parametri: `xp_curve.base = 70`, `xp_curve.growth = 1.1`, `xp_curve.linear = 8`, `xp_curve.max_level = 99`,
`xp_curve.xp_cap = 50000000`.

| Livello | XP totale | | Livello | XP totale |
|---|---|---|---|---|
| 2 | 70 | | 50 | 83.388 |
| 3 | 155 | | 60 | 206.723 |
| 5 | 372 | | 70 | 520.603 |
| 10 | 1.236 | | 80 | 1.327.438 |
| 20 | 4.941 | | 90 | 3.411.599 |
| 30 | 13.639 | | 99 | 8.009.532 |
| 40 | 34.011 | | | |

Esempi: `level_for_xp(69) = 1`, `level_for_xp(70) = 2`, `level_for_xp(154) = 2`, `level_for_xp(155) = 3`,
`level_for_xp(50000000) = 99`; `delta(1) = 70`, `delta(2) = 85`, `delta(10) = 237`.
Test: `tests/core/progression/test_xp_table.gd`.

### F-02 XP guadagnata
`granted = floor(base_xp × (1 + T(skill_xp_pct, ctx)/100))`; poi `xp = min(xp + granted, xp_cap)`.
Esempi: base 10, pct 0 → 10; base 10, pct 15 → 11; base 28, pct 25 → 35.
Test: `tests/systems/skills/test_skills_system.gd`.

## 2. Azioni

### F-03 Intervallo di un'azione
`p = T(skill_interval_pct, ctx)` (già limitato tra −80 e +100 da `stats.json`)
`interval_ms = max(action.min_interval_ms, round(base_interval_ms × (1 + p/100)))`; `action.min_interval_ms = 250`.
Esempi: 3000 ms, p = −10 → 2700; 3000, p = −90 (limitato a −80) → 600; 1000, p = −80 → 200 → **250**; 2500, p = 0 → 2500.
Test: `tests/systems/actions/test_action_math.gd`.

### F-04 Progresso della barra
`progress = clamp(elapsed_ms / interval_ms, 0, 1)`. Esempio: 1200 / 3000 → 0,4. Test: `test_action_runner.gd`.

### F-05 Valore totale di una stat
`T(stat, ctx) = clamp(Σ value dei modificatori con stat = stat e scope applicabile a ctx, stat.min, stat.max)`.
Scope applicabile: `global` sempre; `skill:<id>` se `ctx.skill_id = id`; `action:<id>` se `ctx.action_id = id`.
Esempio: modificatori `skill_interval_pct`: global −3, skill:forestry −5, action:cut_ashpine −2, skill:quarrying −10;
nel contesto (forestry, cut_ashpine) → −10; nel contesto (forestry, cut_redbirch) → −8; somma −95 → limitata a −80.
Test: `tests/core/modifiers/test_modifier_service.gd`.

### F-06 Doppio prodotto
`chance = T(double_item_chance, ctx)` (0..100). Se `rng.roll_pct(chance)`: quantità di ogni prodotto × 2.
Esempio con seme fisso: vedi test; caso deterministico: chance 0 → mai; chance 100 → sempre (prodotto 1 → 2).
Test: `tests/systems/actions/test_gathering_resolver.gd`.

### F-07 Frammento del Rift
Raccolta: `chance = gathering.rift_shard_base_chance_pct (0.5) + T(rift_shard_chance, ctx)` (limite totale 0..100).
Mostro: `chance = monster.rift_shard_chance + T(rift_shard_chance, global)`.
Esempi: 0,5 + 0,25 = 0,75%; mostro 2,0 + 0 = 2,0%. Con chance 100 → sempre 1 `rift_shard`.
Test: `test_gathering_resolver.gd`, `tests/systems/combat/test_combat_engine.gd`.

### F-08 Conservazione degli ingredienti (artigianato)
`chance = T(preservation_chance, ctx)` (0..80, massimo in `stats.json`). Se riesce: nessun ingrediente consumato.
Esempi: somma 95 → 80; chance 0 → sempre consumati. Test: `tests/systems/actions/test_artisan_resolver.gd`.

## 3. Maestria

### F-09 Tabella della maestria
Come F-01 con `mastery_curve.base = 20`, `growth = 1.1`, `linear = 4`, `max_level = 99`.
| Livello | XP | Livello | XP |
|---|---|---|---|
| 2 | 20 | 50 | 25.825 |
| 10 | 412 | 75 | 241.822 |
| 25 | 2.864 | 99 | 2.296.551 |
Test: `test_xp_table.gd` (stessa classe con parametri diversi).

### F-10 Maestria per ciclo
`t = action.interval_ms / 1000` (intervallo **base**, non ridotto: ridurre l'intervallo aumenta la maestria all'ora)
`R = (Σ livelli di maestria delle azioni con maestria della skill) / (99 × numero di quelle azioni)`
`mxp = max(1, floor(t × (base_factor + per_level × L + ratio_weight × R) × (1 + T(mastery_xp_pct, ctx)/100)))`
Parametri: `mastery.base_factor = 1.0`, `mastery.per_level = 0.1`, `mastery.ratio_weight = 3.0`.
Esempi: t 3, L 1, R 1/792 → **3**; t 3, L 50, R 0,25 → **20**; t 3, L 99, R 1,0 → **41**; t 2,5, L 10, R 0,05, pct 5 → **5**.
Test: `tests/systems/mastery/test_mastery_math.gd`.

### F-11 Bonus della maestria per oggetto (dal M12 solo artigianato; la raccolta usa F-103 e F-108) — **SOSTITUITA da F-122 (M14)**
Per ogni regola in `skill.mastery_bonuses`: `every_levels: k` → valore × `floor(L/k)`; `at_level: n` → valore se `L ≥ n`.
Scope dei modificatori: `action:<id>`. Regole iniziali:
- ~~raccolta: `every_levels 10 → double_item_chance +1`; `at_level 99 → double_item_chance +5`~~ (**sostituita in M12** dai traguardi per risorsa, F-103/F-108; gli esempi di raccolta qui sotto non valgono più);
- artigianato: `every_levels 10 → preservation_chance +1.5`; `at_level 99 → skill_interval_pct −5`.
Esempi: raccolta L 35 → +3; L 99 → +9 +5 = **+14**; artigianato L 50 → +7,5 conservazione; L 99 → +13,5 e −5% intervallo.
Test: `tests/systems/mastery/test_mastery_system.gd`.

### F-12 Quota del pool
`pool_gain = round(mxp × mastery.pool_share_pct / 100)`; `pool_share_pct = 20`.
Esempi: mxp 3 → 1; mxp 20 → 4; mxp 41 → 8; mxp 2 → 0.
`pool = min(pool + pool_gain, pool_cap)`. Test: `test_mastery_math.gd`.

### F-13 Tetto del pool
`pool_cap = numero di azioni con maestria della skill × mastery.pool_cap_per_item`; `pool_cap_per_item = 300000`.
Esempio: 8 azioni → 2.400.000. Test: `test_mastery_math.gd`.

### F-14 Spesa del pool su un'azione
`needed = xp_for_level_mastery(99) − mastery_xp(azione)`; `spent = min(amount, pool, needed)`; `amount ≤ 0` → errore.
Esempi: pool 10.000, amount 5.000, maestria 0 → spesi 5.000, maestria livello **30** (`xp_for_level(30) = 4.584`,
`xp_for_level(31) = 5.017`); maestria 2.296.000, amount 5.000 → spesi **551**; pool 300, amount 5.000 → spesi 300.
Test: `test_mastery_system.gd`.

### F-15 Costo di un nodo
`cost = ceil(pool_cap × node.cost_pct / 100)`. Esempio: cap 2.400.000, 10% → 240.000; 7,5% → 180.000.
Test: `tests/systems/mastery/test_mastery_nodes.gd` (`test_f15_examples`, `test_node_cost_uses_the_pool_cap_of_the_skill`, `test_f15_real_forestry_nodes`).

## 4. Bank, oro, shop

### F-16 Capienza della bank — **SOSTITUITA da F-100 (M12, W1)**
La capienza è una sola per Bank e Armeria (Deposito); la stat `bank_slots` e `bank.*` spariscono.

### F-17 Prezzo della prossima casella — **ELIMINATA in M12 (W2)**: le caselle non si comprano più, vedi le borse (§8.6b, F-100). Testo storico:
`n` = caselle già comprate. `price(n) = min(bank.slot_cost_cap, floor(bank.slot_cost_base × bank.slot_cost_growth^n))`
Parametri: `slot_cost_base = 400`, `slot_cost_growth = 1.09`, `slot_cost_cap = 2000000`. Massimo di caselle comprabili: `max_purchases` della voce `bank_slot` (§8.6, `data/shop/shop.json`, 150).
| n | prezzo | n | prezzo |
|---|---|---|---|
| 0 | 400 | 20 | 2.241 |
| 1 | 436 | 30 | 5.307 |
| 2 | 475 | 50 | 29.743 |
| 5 | 615 | 75 | 256.476 |
| 10 | 946 | 100 | 2.000.000 (tetto) |
Totale delle prime 50 caselle: 326.011. Test: `tests/systems/shop/test_shop.gd`.

### F-18 Vendita
`gold = item.value × qty`. Esempio: valore 6, quantità 25 → 150. Oggetto bloccato o `value = 0` → errore.
Test: `test_shop.gd`.

### F-19 Modificatori dello shop
Per ogni voce con effetto `modifiers`: valore effettivo = `value × acquisti`. Esempio: "Tasca della borsa" (+4
`loot_bag_slots`) comprata 2 volte → +8. Test: `test_shop.gd`.

## 5. Combattimento

Le stesse formule valgono per giocatore e mostri (decisioni D3, D5 di `DECISIONS_LOG.md`). Per il giocatore il livello
usato da F-20, F-21, F-22 e F-27 è il **livello del personaggio** `L_char` (F-70): le 5 skill di combattimento non
esistono più. Bonus = `T(stat, global)` (equipaggiamento, tratti, Altare, shop); con due spade le stat d'attacco sono
quelle della mano che colpisce (F-74). Per i mostri: livelli e bonus dai dati (`attack_level`, `power_level`,
`defence_level`, `accuracy_bonus`, `power_bonus`, `evasion_bonus`, `damage_reduction`), senza modificatori.

### F-20 Precisione (Accuracy Rating)
`AR = floor((L + combat.acc_level_offset) × (accuracy_bonus + combat.acc_bonus_offset) × (1 + accuracy_pct/100))`;
`L` = `L_char` (giocatore) o `attack_level` (mostro).
Parametri: `acc_level_offset = 8`, `acc_bonus_offset = 50`.
Esempi: (1, 0, 0) → **450**; (10, 20, 0) → **1.260**; (10, 20, 10) → **1.386**; (50, 60, 0) → **6.380**; (99, 150, 0) → **21.400**;
due spade (10, 20, −10) → **1.134**.
Test: `tests/systems/combat/test_combat_math.gd`.

### F-21 Evasione (Evasion Rating)
`ER = floor((L + acc_level_offset) × (evasion_bonus + acc_bonus_offset) × (1 + evasion_pct/100))`; `L` = `L_char` o `defence_level`.
Esempi: (1, 0, 0) → 450; (16, 18, 0) → 1.632; (24, 30, 0) → 2.560. Test: `test_combat_math.gd`.

### F-22 Danno massimo, minimo e tiro (rivista in M14: danno dell'arma, Y2)
`max_hit = floor((L + combat.maxhit_level_offset) × (W_max + power_bonus + combat.maxhit_bonus_offset) / maxhit_bonus_offset × (1 + power_pct/100))`;
`L` = `L_char` o `power_level`. **`W_max`** = `dmg_max` dell'arma che colpisce (§8.4; con due spade quella della mano che colpisce, F-74), 0 senza arma e per i mostri (che usano `power_bonus` dei dati come prima). Il danno dell'arma **sostituisce** il vecchio `power_bonus` dei modelli base;
`power_bonus` e `power_pct` degli affissi, dei tratti e delle rune si sommano ancora.
`min_hit = max(1, floor(max_hit × r))` con `r = dmg_min / dmg_max` dell'arma (la forbice propria del modello: spada 0,6, spadone 0,5) oppure `combat.min_hit_ratio` (0,1) senza arma e per i mostri; tiro = intero uniforme in `[min_hit, max_hit]`.
Con un Capolavoro o un leggendario (F-119, F-120) `dmg_min` e `dmg_max` sono già moltiplicati; con la raffinazione F-86 vale lo stesso ordine di F-119.
Parametri: `maxhit_level_offset = 10`, `maxhit_bonus_offset = 40`, `min_hit_ratio = 0.1`.
Esempi: senza arma (1, 0, 0) → max 11, min 1; mostro (10, 20, 0) → 30 / 3; mostro (50, 60, 0) → 150 / 15; mostro (99, 150, 0) → 517 / 51; mostro (10, 20, 10) → floor(33,0) = 33 / 3 (invariati);
**spada grado 1** (dmg 4-6) a livello 1: floor(11 × (6 + 40)/40) = floor(12,65) = **12**, min floor(12 × 4/6) = **8**; **spada grado 15** (37-62) a livello 90: floor(100 × (62 + 40)/40) = **255**, min floor(255 × 37/62) = **152**;
spadone grado 8 (dmg 34-68) a livello 50: floor(60 × (68 + 40)/40) = **162**, min **81**; spada grado 8 con `power_bonus +10` e `power_pct +10` a livello 50: floor(60 × (34 + 10 + 40)/40 × 1,1) = floor(138,6) = **138**.
**Danno al secondo dell'arma** (scheda dell'oggetto, `WeaponMath.dps`): `dps = (dmg_min + dmg_max) / 2 / (intervallo ms / 1000)`, dove l'intervallo è quello di F-26 con il totale `attack_interval_pct`; non dipende dal livello. Esempi: spada grado 1 (4-6, 2000 ms) → 2,5; spadone grado 1 (6-12, 3200 ms) → 2,81; spada grado 15 con `attack_interval_pct` −10 → 49,5 / 1,8 = 27,5.
Test: `tests/systems/combat/test_combat_math.gd` (`test_weapon_damage`, `test_weapon_dps`).

### F-23 Probabilità di colpire
`hit = clamp(AR / (AR + ER), combat.hit_chance_min, combat.hit_chance_max)`; `min = 0.05`, `max = 0.95`.
Esempi: 450 vs 450 → 0,50; 1.080 vs 450 → 0,7059; 450 vs 1.800 → 0,20; 100 vs 10.000 → 0,05; 10.000 vs 100 → 0,95;
1.000 vs 0 → 0,95. Caso limite `AR + ER ≤ 0` (solo con `accuracy_pct`/`evasion_pct` ≤ −100): rapporto grezzo 1, poi
il limite → `hit_chance_max`. Test: `test_combat_math.gd`.

### F-24 Triangolo
Relazione dal punto di vista dell'attaccante: `blade` batte `arcana`, `arcana` batte `marksmanship`,
`marksmanship` batte `blade`; stesso stile = neutro. Nell'MVP il giocatore è sempre `blade` (tutte le spade, D6);
lo stile del giocatore viene dall'arma (`weapon.style`) o da `combat.unarmed.style`.
- vantaggio: danno × `triangle.advantage_damage_mult` (1,15) e riduzione del difensore × `triangle.defender_dr_mult` (0,75);
- svantaggio: danno × `triangle.disadvantage_damage_mult` (0,85);
- neutro: nessun cambio.
Il danno moltiplicato si tronca (`floor`) prima della riduzione. Esempi: `triangle(blade, arcana) = advantage`;
`triangle(blade, marksmanship) = disadvantage`; `triangle(arcana, arcana) = neutral`. Test: `test_combat_math.gd`.

### F-25 Riduzione del danno (rivista in M14: Armatura e Barriera)
- **Difensore giocatore**: `dr_eff = rid%` di F-117 (Armatura contro `blade`/`marksmanship`, Barriera contro `arcana`, rendimenti decrescenti, massimo `combat.armor.cap_pct`), × 0,75 se il giocatore è in svantaggio (triangolo). Gli effetti `armor_pierce_pct` valgono solo per gli attacchi del giocatore.
- **Difensore mostro**: `dr_eff = damage_reduction` dei dati del mostro (percentuale piatta, 0..80, invariata) × (0,75 se in svantaggio); un effetto `armor_pierce_pct` del giocatore moltiplica `dr_eff` per `(1 − pct/100)`.
`danno = max(1, floor(danno_dopo_triangolo × (1 − dr_eff/100)))`
Esempi: mostro con DR 25 colpito da 20 → **15**; 3, DR 80 → **1**; tiro 20, giocatore in vantaggio, DR del mostro 10 → floor(20×1,15) = 23 → dr_eff 7,5 → floor(23 × 0,925) = **21**; tiro 20, svantaggio, DR 10 → floor(17) = 17 → floor(15,3) = **15**.
**Giocatore difensore**: tiro 40, mostro `blade` livello 20, Armatura 100 (rid 35,71%), triangolo neutro → floor(40 × 0,6429) = **25**; stesso colpo con il giocatore in svantaggio → dr_eff 26,79% → floor(40 × 0,7321) = **29**; mostro `arcana` (livello 30), Barriera 121 e Armatura 500 → rid 33,52% (l'Armatura non conta) → tiro 40 → floor(26,59) = **26**.
Test: `tests/systems/combat/test_combat_math.gd`.

### F-26 Intervallo d'attacco
`interval = max(combat.min_attack_interval_ms, round(base_ms × (1 + T(attack_interval_pct)/100)))`; min 800 ms.
`base_ms` = `weapon.attack_interval_ms`, F-73 con due spade, o `combat.unarmed.attack_interval_ms` (2400).
Mostro: `attack_interval_ms` dei dati.
Esempi: 2400, −10 → 2160; 1000, −50 → 500 → **800**; due spade 1800, −10 → 1620. Test: `test_combat_math.gd`.

### F-27 Punti vita massimi
`max_hp = combat.hp_base + combat.hp_per_level × L_char + floor(T(max_hp_flat))`; `hp_base = 50`, `hp_per_level = 10`.
Esempi: livello 1 → 60; livello 10 e +20 → 170; livello 99 → 1.040. Test: `test_combat_math.gd`.

### F-28 Esperienza di combattimento (per uccisione)
Ogni nemico ucciso dà al personaggio `base_xp = floor(xp del mostro × combat.kill_xp_mult)` (campo `xp` del mostro,
`04_DATA_SCHEMA.md` §8), che passa da F-71. Nessuna XP per danno, nessuna stance (D3). Una Pietra del Rift (F-87) dà il
suo `xp` con la stessa regola. Valori: tabella §8.5 (`xp = 4 × PV`, tranne le Miniere Crepate a 3,2 × PV, tarate da B1);
**B1 (M10-07, ritarato in M14-10)**: `combat.kill_xp_mult` = **0,064** (era 0,11; dopo i nuovi mostri e le armi con forbice), tarato con `tools/sim_combat.gd` e `tools/sim_progress.gd`: livello 99 in circa
320 h (319,6) nell'area giusta (la più alta consentita dal livello; offline compreso, stesso motore) e una notte offline (12 h) dal 50
**M15 (Monoliti da Metin, M15-08)**: con i Monoliti (1-2/h per area, bottino e XP) il livello 99 si raggiunge in circa **369 ore**; banda del test di bilanciamento **250-380 ore**.
dà al massimo +12 livelli (Q54). Con 1,0 si ottiene la regola dell'MVP.
Esempi (mult 0,064): `plains_boar` (xp 80) → base 5; +25% → 6; gruppo di 3 `plains_boar` → 15; `redrock_raider` (200) → 12;
Pietra con xp 240 → 15. Con mult 1,0: 80, 100, 240. Test: `tests/systems/combat/test_combat_engine.gd::test_kill_grants_character_xp`.

### F-29 Cura del cibo
`heal = floor(food.heal × (1 + T(food_healing_pct)/100))`; `hp = min(max_hp, hp + heal)`.
Esempi: 20 e +80% → 36 (il cibo dell'esempio di F-30); 20 e 0 → 20. Test: `tests/systems/combat/test_auto_eat.gd`.

### F-30 Razioni da campo
`tier = clamp(floor(T(auto_eat_tier)), 0, 3)`; soglie in `combat.auto_eat_tiers[tier] = {threshold_pct, target_pct}`:
livello 1 = 30/60, 2 = 40/75, 3 = 50/90 (livello 0 = spento).
Dopo un colpo subito: se `hp ≤ floor(max_hp × threshold/100)`, ripete "mangia 1 pezzo" finché
`hp ≥ ceil(max_hp × target/100)` o il cibo finisce. Un tratto `low_hp_damage_mult` con `no_auto_eat` lo spegne (F-81).
Esempio: max 170, livello 1 (soglia 51, obiettivo 102), cibo 36: hp 45 → 81 → 117 → si ferma (**2 pezzi**). Con hp 52: non mangia.
Test: `test_auto_eat.gd`.

### F-31 Oro dei mostri
`gold = floor(randi_range(gold_min, gold_max) × (1 + T(gold_drop_pct)/100))`, per ogni nemico ucciso. Esempio: tiro 10, +25% → 12.
Test: `test_combat_engine.gd`.

### F-32 Drop
Ogni voce `{item, chance_pct, qty_min, qty_max}` tira in modo indipendente `roll_pct(chance_pct)`; quantità uniforme.
Esempio: chance 100, qty 2-2 → sempre 2; chance 0 → mai. Le voci di equipaggiamento (M7) creano istanze con F-84.
Test: `test_combat_engine.gd`.

### F-33 Capienza della borsa del bottino
`capacity = combat.loot_bag_base_slots (12) + floor(T(loot_bag_slots))`. Esempio: 2 tasche → 20. Test: `tests/systems/combat/test_loot_bag.gd`.

### F-34 Incontro di riferimento (test di integrazione)
Giocatore: personaggio livello 1, a mani nude, nessun tratto e nessuna abilità (AR 450, max 11, 2400 ms, 60 PV). Area
di prova con un solo gruppo di un solo `plains_boar` (tabella §8.5: L 1, 20 PV, 0 bonus, 2800 ms, max 11). Probabilità
di colpire per entrambi 0,5. Danno medio per attacco del giocatore 3 → in 1.000 incontri simulati (seme fisso, senza
attesa tra gli incontri) il tempo medio per uccisione deve stare tra **15 e 21 s** (simulazione di controllo in fase di
design: 18,0 s). Test: `tests/integration/test_reference_encounter.gd`.

## 5a. Personaggio, assetti, gruppi, tratti e abilità (F-70…F-81)

### F-70 Valori base del personaggio
Dal livello del personaggio `L_char` vengono i valori base, lineari nel livello: precisione (F-20 con `L = L_char`),
evasione (F-21), danno massimo (F-22), PV massimi (F-27). Il resto viene da equipaggiamento (pezzi, affissi,
raffinazione), assetto, tratti, Altare e shop, tutti come modificatori (F-05).
Esempi (mani nude, nessun modificatore): livello 1 → AR 450, ER 450, max 11 / min 1, 60 PV; livello 10 → AR 900,
ER 900, max 20 / min 2, 150 PV; livello 50 → AR 2.900, max 60 / 6, 550 PV.
Test: `tests/systems/combat/test_combatant_stats.gd::test_player_base_from_character_level`.

### F-71 Livello ed esperienza del personaggio
Stessa forma di F-01 con i parametri `character_curve.{base, growth, linear, max_level, xp_cap}` = 70, 1.1, 8, 99,
50000000 (valori iniziali uguali a `xp_curve`: la tabella di F-01 vale anche per il personaggio finché non cambiano).
XP guadagnata: `granted = floor(base_xp × (1 + T(skill_xp_pct, global)/100))` (solo modificatori `global`);
`xp = min(xp + granted, character_curve.xp_cap)`.
Esempi: `level_for_xp(1236) = 10`; base 80, pct 0 → 80; base 80, pct 15 → 92; xp 49.999.990 + 80 → 50.000.000.
Test: `tests/systems/character/test_character_system.gd`.

### F-72 Assetto
`setup` = il primo assetto della classe (`setups` nel file della classe, in ordine) con `weapon` = `kind` dell'arma
indossata e `offhand` = `kind` dell'offhand (`""` se vuoto). Arma vuota → `unarmed` (valori `combat.unarmed`).
I modificatori dell'assetto valgono come sorgente `setup:<id>`.
Esempi (classe `rift_blade`): spadone + offhand vuoto → `greatsword`; spada + scudo → `sword_shield`; spada + spada →
`dual_swords`; spada + vuoto → `sword`; nessuna arma + scudo → `unarmed`.
Test: `tests/systems/equipment/test_equipment.gd::test_setup_derivation`.

### F-73 Intervallo della doppia spada
Con un assetto `alternate: true`: `base_ms = round((i_weapon + i_offhand) / 2 × combat.dual_wield.interval_mult)`,
poi F-26; `interval_mult = 0.75`. I colpi base **alternano** le mani: il primo attacco dopo `start` è della mano
principale, poi offhand, e così via (il contatore `hand` è salvato).
Esempi: 2400 e 2400 → 1800; 2400 e 2000 → 1650; 1650 con `attack_interval_pct` −10 → 1485.
Test: `tests/systems/combat/test_combat_math.gd::test_dual_wield_interval`.

### F-74 Stat della mano che colpisce
Con due spade le stat d'attacco (`accuracy_bonus`, `accuracy_pct`, `power_bonus`, `power_pct`) della mano `h` sono
`T(stat)` senza la sorgente dell'altra mano (`equipment:offhand` per la principale, `equipment:weapon` per l'offhand),
poi limitate da `stats.json` (`ModifierService.total_without`). Le altre stat sono i totali normali.
Esempio: spada T3 in mano (acc 24, pot 18), spada T1 in offhand (acc 8, pot 6), anello acc +5: mano principale acc 29,
pot 18; offhand acc 13, pot 6 (sono i bonus). Al livello 1, con l'`accuracy_pct` dell'assetto `dual_swords` (F-72),
AR 639 / 510 e danno massimo 15 / 12. Test: `tests/systems/combat/test_combatant_stats.gd::test_dual_wield_hand_stats`.

### F-75 Parata
Se il giocatore ha uno scudo (`kind: shield`) nell'offhand e un nemico lo colpisce (F-23 riuscito), si tira
`roll_pct(T(block_chance))` (limite 0..50 in `stats.json`): se riesce il colpo è **parato**, danno 0, nessun aggancio
`on_damaged`, nessun cibo automatico. Valore dello scudo Tn: `block_chance = 5 + floor(10 × (n − 1) / 7)` (§8.4).
Esempi: scudo T1 → 5; T4 → 9; T8 → 15; T8 + affisso +40 → 55 → limitato a **50**; senza scudo → nessun tiro.
Test: `tests/systems/combat/test_combat_engine.gd::test_block_chance`.

### F-76 Ordine di risoluzione e bersaglio
A ogni istante in cui scadono uno o più timer: attacco base del giocatore, poi abilità in ordine di slot, poi nemici per
posizione (0..n−1). Bersaglio dell'attacco base e delle abilità a bersaglio singolo: regola `first` (il vivo con la
posizione più bassa); `lowest_hp` (meno PV, a parità la posizione più bassa); `highest_hp` (simmetrica).
Esempio: PV [0, 30, 12] (il primo è morto) → `first` = 1, `lowest_hp` = 2, `highest_hp` = 1.
Test: `tests/systems/combat/test_combat_engine.gd::test_target_rules`.

### F-77 Scelta del gruppo
All'inizio di ogni incontro: `i = rng.pick_weighted([pack.weight ...])` tra i `packs` dell'area; i nemici prendono le
posizioni nell'ordine della lista del gruppo, con PV pieni e timer pari al proprio intervallo. Esempio: pesi [3, 1] con
seme fisso → la frequenza del primo gruppo su 4.000 estrazioni sta tra 72% e 78%. Test: `test_combat_engine.gd::test_pack_weights`.

### F-78 Slot di tratti e abilità (M6)
`trait_slots(L) = |{x ∈ traits.slot_levels : x ≤ L}|`, `ability_slots(L) = |{x ∈ abilities.slot_levels : x ≤ L}|`;
`traits.slot_levels = [1, 10, 25, 50]`, `abilities.slot_levels = [1, 1, 30]` (Q35, Q36).
Esempi: livello 1 → 1 tratto, 2 abilità; 10 → 2 / 2; 30 → 3 / 3; 99 → 4 / 3. Test: `test_character_system.gd::test_slot_counts`.

### F-79 Ricarica delle abilità (M6)
Ogni abilità equipaggiata e ammessa dall'assetto ha un timer che parte da `cooldown_ms` all'avvio del combattimento e
continua tra un incontro e l'altro; allo zero si usa appena c'è un bersaglio valido (per `heal`: PV < massimo; per
`buff`: buff non attivo), poi riparte da `cooldown_ms`. Abilità non ammessa dall'assetto: timer fermo.
Esempio: cooldown 8000, avvio a t=0, nemico sempre presente → usi a 8000, 16000, 24000. Test: `tests/systems/combat/test_abilities.gd`.
Precisazioni (M6-03): le abilità si usano solo con un incontro in corso (in `BETWEEN` i timer scendono comunque e un'abilità pronta parte all'inizio dell'incontro successivo); un buff si riusa solo dopo che è finito; più abilità pronte nello stesso istante partono in ordine di slot, dopo l'attacco base.

### F-80 Effetto delle abilità (M6)
- `strike` / `cleave`: per ogni bersaglio (uno; `targets` = N primi vivi; 0 = tutti) tiro F-23, poi
  `danno = floor(tiro F-22 × power_mult)` → F-24 → F-25.
- `heal`: `hp = min(max_hp, hp + floor(max_hp × heal_pct/100))`.
- `buff`: i `modifiers` dell'abilità valgono come sorgente `ability:<id>` per `duration_ms`, poi spariscono (anche a
  fine combattimento o alla morte).
Precisazioni (M6-03): i colpi delle abilità usano le stat della mano 0 e non sono parabili (i nemici non parano); `every_nth_attack_all` e `low_hp_damage_mult` valgono solo per l'attacco base; `leech_pct` (`EffectSet.hit`) vale anche per i colpi delle abilità. Ordine dei tiri: prima tutti i bersagli in ordine (colpo, poi danno se colpisce).
Esempi: tiro 30, `power_mult` 2,0, neutro, DR 10 → 60 → **54**; `heal_pct` 20 con 170 PV max e 100 PV → **134**;
buff 6000 ms usato a t=8000 → attivo fino a 14000. Test: `test_abilities.gd`.

### F-81 Tipi di effetto dei tratti (M6)
| Tipo | Parametri | Aggancio | Regola | Esempio |
|---|---|---|---|---|
| `every_nth_attack_all` | `n` | `on_before_attack` | ogni `n`-esimo attacco base (contatore del combattimento) colpisce tutti i nemici vivi, un tiro F-23 e F-22 per bersaglio | n 3 → attacchi 3, 6, 9 |
| `on_kill_timer_cut` | `pct` | `on_kill` | `timer_base = floor(timer_base × (1 − pct/100))` | 2000 ms rimasti, 50 → 1000 |
| `low_hp_damage_mult` | `hp_pct`, `mult`, `no_auto_eat` | `on_before_attack`, `on_low_hp` | con `hp ≤ floor(max_hp × hp_pct/100)`: danno dopo F-24 × `mult` (floor), prima di F-25; con `no_auto_eat` F-30 non scatta | max 170, 30% → soglia 51; hp 50, tiro 20, × 2 → 40 |
| `stat_trade` | `zero` (stat), `mult` ({stat: fattore}) | `modify_stats` | dopo il calcolo delle stat: le stat in `zero` valgono 0, le altre × fattore, poi i limiti di `stats.json` | ER 1.632 → 0; DR 12 × 2 → 24; DR 50 × 2 → 80 |
| `target_rule` | `rule` | `choose_target` | regola di F-76 | `lowest_hp` |
| `reflect_pct` | `pct` | `on_damaged` | l'attaccante perde `floor(danno subito × pct/100)` (nessun tiro, nessuna riduzione; può ucciderlo) | 37 × 20% → 7 |
| `leech_pct` | `pct` | `on_hit` | cura `floor(danno inflitto × pct/100)` | 60 × 5% → 3 |
| `opening_strike` | — | `on_encounter_start` | il timer dell'attacco base va a 0: il primo attacco parte subito | timer 2400 → 0 |
Test: `tests/systems/combat/effects/test_<tipo>.gd` (uno per tipo).
M14: gli stessi tipi (e i tipi nuovi di F-120: `block_heal_pct`, `kill_heal_pct`, `armor_pierce_pct`, `hit_cap_pct`, `stat_convert`, `double_hit_pct`, `execute_mult`, `monolith_loot_mult`, `gather_bonus_item`, `gather_grade_up_pct`, `byproduct_mult`, `card_drop_mult`) sono usati dagli effetti dei leggendari; `stat_trade` e `stat_convert` lavorano su `armor` e `barrier` al posto di `damage_reduction`.
`stat_trade`, mappa stat -> numero di combattimento (M6-02, `CombatantStats.scale_stat`; × fattore con floor, poi i limiti di `stats.json` dove esistono): `accuracy_bonus`/`accuracy_pct` -> accuratezza; `evasion_bonus`/`evasion_pct` -> evasione; `power_bonus`/`power_pct` -> `max_hit` (`min_hit` segue, F-22); `max_hp_flat` -> PV massimi; `armor`, `barrier` e `block_chance` (limiti della stat; M14: `armor` e `barrier` sostituiscono `damage_reduction`). Ogni altra stat non alimenta nulla (sarebbe decorativa): il validatore la rifiuta (restringimento in M6-04); a runtime è ignorata con `Log.warn`.
`leech_pct` e abilità: il colpo di un'abilità chiama `EffectSet.hit` come l'attacco base (M6-03).
Intervalli di formato dei parametri (validatore, `04_DATA_SCHEMA.md` §14): `n` int 2..20; `pct`, `hp_pct` in (0, 100]; `mult` in (0, 10]; `stat_trade` con almeno una stat in `zero` o `mult`, nessuna in comune, fattori > 0.

## 5b. Armeria e bottino (F-82…F-89)

### F-82 Capienza dell'Armeria e prezzo delle caselle — **ELIMINATA in M12 (W1, W2)**: capienza unica F-100. Testo storico:
`capacity = armory.base_slots + floor(T(armory_slots, global))`; `armory.base_slots = 40` (Q33). Contano solo i pezzi
**non indossati**. Prezzo della prossima casella (voce `armory_slot` dello shop, `cost.formula = "armory_slot"`):
`price(n) = min(armory.slot_cost_cap, floor(armory.slot_cost_base × armory.slot_cost_growth^n))`, con 1000, 1.12, 2000000.
Esempi: 10 caselle comprate → capienza 50; prezzo n 0 → 1.000; 1 → 1.120; 2 → 1.254; 5 → 1.762; 10 → 3.105; 20 → 9.646;
30 → 29.959. Test: `tests/systems/armory/test_armory.gd`, `tests/systems/shop/test_shop.gd::test_armory_slot_price`.

### F-83 Rarità nell'artigianato — **SOSTITUITA da F-91 (M10, R1)**
Nessuna ricetta produce più equipaggiamento: la rarità per maestria non esiste più. `rarity.craft.*` esce da
`balance.json`, `ItemRoller.craft_chances` esce dal contratto (sostituita da `blueprint_rare_chance`, F-91). Il tiro
`roll_rarity` (`r < p_rare` → raro; `r < p_rare + p_magic` → magico; altrimenti comune) resta ed è usato anche da F-84.

### F-84 Rarità nei drop (M7)
> M14: `rarity.drop` vale 25 e 5 (F-121); Capolavoro e leggendari non escono mai da questo tiro.
`p_magic = rarity.drop.magic_pct × k`, `p_rare = rarity.drop.rare_pct × k` (`k = 1 + T(item_rarity_pct, ctx)/100` e tiro come in F-91, con `p_magic` e `p_rare` entrambi presenti); valori
20, 3 per i mostri, `rarity.rift_stone.magic_pct` 40 e `rare_pct` 12 per le Pietre del Rift. Esempio: mostro con +50% →
30 / 4,5. Test: `test_item_roller.gd::test_drop_rarity`.

### F-85 Affissi
Numero: `randi_range(a, b)` con `rarity.affix_count.magic = [1, 2]`, `rarity.affix_count.rare = [3, 4]`, comune 0.
Per ogni affisso, in ordine: candidati = affissi di `data/affixes/affixes.json` ammessi dallo slot del pezzo, non già
presenti sul pezzo, con almeno un grado `min_ilvl ≤ ilvl`; `pick_weighted(weight)`; grado = uniforme tra i gradi
sbloccati; valore = `min + randi_range(0, floor((max − min) / step)) × step` (`step` di default 1). Senza candidati si
smette (il pezzo ha meno affissi). `ilvl` = livello del grado del progetto (F-90); per i drop (M7) il massimo tra `attack_level`, `power_level` e
`defence_level` del mostro; per una Pietra del Rift il massimo di questo valore sui mostri dell'area.
Esempi: gradi con `min_ilvl` 1, 20, 45 e ilvl 25 → 2 gradi sbloccati; grado `{min 3, max 6}` → 3..6; `{min 0.5, max 1.5,
step 0.25}` → 0,5, 0,75 … 1,5; slot con 2 soli affissi ammessi e raro da 4 → 2 affissi.
Test: `test_item_roller.gd::test_affix_rolls`.

### F-86 Raffinazione (M7)
Tentativo da `+N` a `+N+1` (N 0..8, Q28): costo `upgrade.levels[N] = {success_pct, gold_per_grade, ingots, shards}`:
oro `gold_per_grade × grado`, `ingots` lingotti del grado del pezzo, `shards` frammenti del Rift e (M14, dal passo che porta al +5) `dust` Polvere del Rift; "grado" qui è il **grado del materiale** `m(g)` (§8.4, 1…8), non il grado del pezzo. Vale per tutte le rarità, anche Capolavoro e leggendari.
`chance = min(100, success_pct × (1 + T(upgrade_success_pct)/100))` (da M10 `upgrade_success_pct` include il
bonus del livello del Fabbro, F-93). Vale per **armi e armature**; gli attrezzi unici usano F-94 (sempre riuscita). Successo → `+N+1`. Fallimento: materiali persi;
se `N ≥ upgrade.downgrade_from` (4) il pezzo scende a `+N−1`, salvo il Sigillo di salvaguardia (`upgrade.seal_item`,
consumato); mai distrutto (Q27). Modificatori base del pezzo × `(1 + upgrade.mod_pct_per_level × N / 100)` (10); gli
affissi non cambiano.
| N → N+1 | 0→1 | 1→2 | 2→3 | 3→4 | 4→5 | 5→6 | 6→7 | 7→8 | 8→9 |
|---|---|---|---|---|---|---|---|---|---|
| `success_pct` | 95 | 90 | 85 | 75 | 65 | 55 | 45 | 35 | 25 |
| `gold_per_grade` | 50 | 100 | 200 | 400 | 800 | 1600 | 3200 | 6400 | 12800 |
| `ingots` | 1 | 1 | 2 | 2 | 3 | 3 | 4 | 4 | 5 |
| `shards` | 0 | 0 | 0 | 0 | 0 | 5 | 10 | 15 | 20 |
| `dust` (M14, Q71) | 0 | 0 | 0 | 0 | 10 | 20 | 30 | 40 | 50 |
Esempi: +5 → +6 con +10% → 60,5%; fallimento da +5 → +4; fallimento da +3 → resta +3; `power_bonus` 48 a +3 → 62,4;
spada T4, +5 → +6: 6.400 oro, 3 lingotti T4, 5 frammenti. Test: `tests/systems/armory/test_upgrade.gd`.

### F-87 Monoliti del Rift (M7; ex "Pietre del Rift", W7: solo il nome visibile cambia, id invariati)
> M15: appare uno dei Monoliti del pool dell'area (uguale probabilità, §5f); PV F-125, impulso fisso, ondate F-126, bottino F-127, salto F-128; niente `hp`/`pulse_damage` nei dati.
Dopo ogni uccisione (non di una Pietra): `since += 1`; appare una Pietra se `since ≥ rift_stone.pity_kills` (300)
oppure `roll_pct(chance)` con `chance` = `rift_stone_chance_pct` dell'area se presente, altrimenti `rift_stone.chance_pct` (0.5; Q46); quando appare `since = 0` e il prossimo incontro (dopo `BETWEEN`) è la
Pietra dell'area. La Pietra non attacca: ogni `pulse_ms` infligge `pulse_damage` al giocatore (senza tiro, ridotto da
F-25, parabile con F-75). Una Pietra in attesa (`pending`) ferma conteggio e tiri: le uccisioni durante l'attesa non contano. Stile della Pietra:
`combat.unarmed.style` (neutro; nessun campo di tipo di danno nell'MVP). Esempi: `since` 299 → uccisione → Pietra
garantita; chance 100 → sempre. Test:
`tests/systems/combat/test_rift_stone.gd`.

### F-88 Smantellamento (M7) — **SOSTITUITA da F-95 (M10, R2)**
Restituiva lingotti in base alla ricetta del pezzo; senza ricette in serie restituisce componenti (F-95).

### F-89 Castoni (M8)
`sockets = sockets.by_rarity[rarity] + (1 se upgrade ≥ sockets.bonus_at_upgrade)`; comune 0, magico 1, raro 2, **Capolavoro 2, leggendario 2** (M14), bonus a
+7. Esempi: raro +7 → 3; comune +9 → 1; magico +6 → 1. Test: `tests/systems/armory/test_sockets.gd`.

## 5c. Progetti, attrezzi unici e smantellamento a componenti (F-90…F-95, M10)

Riforma del bottino (R1-R3, `01_GDD.md` §5.1, §23.1). **Tutti i numeri di questa sezione sono valori di partenza da
tarare** (Q53) con `tools/sim_combat.gd` e `tools/sim_gear_economy.gd`, tranne quelli fissati dall'utente: durata
(Q48), livello per l'affisso scelto (Q50), raffinazione +0…+9 sempre riuscita, un livello minimo per passo (+4 =
mestiere 25), kit iniziale (Q51). Il grado `n` va da 1 a 8; "livello del grado" = livello Tn di §8.1 (1, 10, 20, 30,
45, 60, 75, 90).

### F-90 Craft di un progetto (azione a ciclo unico)
> M14: il progetto crea un Capolavoro (F-119). Il grado `n` qui è il **grado del materiale** `m(g)` (§8.4); le quantità dei `inputs` sono moltiplicate per `blueprint.cost_mult` (3) e il progetto chiede **due** componenti rari diversi (Q68). Durata, livello del Fabbro e XP invariati; `ilvl` del pezzo = `lvl(g)` di §8.4 (il livello del grado del pezzo, F-85).
Livello richiesto del Fabbro: il livello del grado `n` del progetto. Durata (Q48):
`duration_min = blueprint.duration_base_min + blueprint.duration_per_grade_min × (n − 1)` con 10 e 7 (grado 1: 10
minuti; grado 8: 59), poi F-03 con `skill_interval_pct` (contesto `for_action(forging, blueprint_craft)`), minimo
`action.min_interval_ms`. XP (poi F-02): `xp = floor(blueprint.xp_mult × duration_min × xp_min(n))` con
`xp_min(n) = XP della ricetta di fusione del grado n × 60000 / intervallo della ricetta` e `blueprint.xp_mult` = 1,5
(la durata è quella base, senza F-03). Nessuna maestria. Materiali: la lista `inputs` del progetto (piastre del Fabbro,
impugnature o telai del Falegname) più il componente raro del grado, tutti consumati all'avvio (restituiti se il
lavoro si ferma prima della fine). `ilvl` del pezzo = livello del grado.
Esempi: grado 1 → 10 min, `xp_min` 8 × 60000/2000 = 240, XP 3.600; grado 4 (fusione XP 32) → 31 min, XP 44.640;
grado 8 (fusione XP 116) → 59 min, XP 307.980; con `skill_interval_pct` −10 il grado 1 dura 9 min. Test:
`tests/systems/actions/test_blueprint_craft.gd::test_duration_and_xp`.

### F-91 Rarità di un progetto (rivista in M14: il progetto crea un Capolavoro, Y4)
Il pezzo di un progetto è sempre un **Capolavoro** (`masterwork`, F-119): la rarità non si tira più. Quello che cresce con il livello del Fabbro è il **numero di affissi**: `k = 1 + T(item_rarity_pct, ctx)/100` (come in F-84) e `L` = livello del Fabbro:
`p_two = min(100, (blueprint.rare_base_pct + blueprint.rare_per_forging_level × L) × k)` con 10 e 0,5; tiro `r = rng.randf() × 100`; `r < p_two` → **2 affissi**, altrimenti **1** (`rarity.masterwork.affix_count` = [1, 2]).
Esempi: L 1, +0% → 10,5; L 50, +0% → 35; L 50, +20% → 42; L 99, +0% → 59,5; L 99, +100% → 100 (119 limitato). Con `p_two` 35: r 20 → 2 affissi; r 50 → 1 affisso. Test: `tests/systems/items/test_item_roller.gd::test_blueprint_rarity` (rinominato in M14 `test_masterwork_affix_count`).

### F-92 Affisso scelto
Disponibile se `L ≥ blueprint.choose_affix_level` (50, Q50), altrimenti il comando è rifiutato (`invalid_choice`). Il
giocatore sceglie un affisso tra quelli ammessi dallo slot del pezzo con almeno un grado sbloccato da `ilvl`; il grado
è fisso: `min(blueprint.chosen_affix_tier, gradi sbloccati)` con `chosen_affix_tier` = 2; il valore si tira nel grado
come in F-85. L'affisso scelto è il **primo** degli affissi e conta nel numero della rarità (Capolavoro 1-2; era magico 1-2, raro 3-4,
`rarity.affix_count`); gli altri si tirano con F-85 senza duplicarlo. Ordine dei tiri su `rng`: rarità, numero di
affissi, valore dell'affisso scelto, poi gli altri (scelta, grado, valore). Esempi: `ilvl` 20 con gradi `min_ilvl` 1,
20, 45 → 2 gradi sbloccati, si usa il grado 2; `ilvl` 1 → grado 1; L 49 → rifiutato. Test:
`tests/systems/items/test_item_roller.gd::test_chosen_affix`.

### F-93 Bonus del Fabbro alla raffinazione
Sorgente `skill_level:forging` (si ricostruisce a ogni `level_up` e a `from_save`): modificatore globale
`upgrade_success_pct = skills.forging.level_modifiers[0].per_level × L` con `per_level` = 0,4 (campo `level_modifiers`
di `data/skills/skills.json`, `04_DATA_SCHEMA.md` §4). Poi F-86 come sempre. Esempi: L 1 → 0,4; L 50 → 20; L 99 →
39,6; passo +5 → +6 (`success_pct` 55) con L 50 → 55 × 1,2 = 66. Test:
`tests/systems/armory/test_upgrade.gd::test_forging_level_bonus`.

### F-94 Raffinazione degli attrezzi (+0…+9, sempre riuscita)
Passo verso `+T` (T 1..9) sull'attrezzo unico della skill `s`. Condizioni: mestiere `s` al livello `min_level(T)`;
costo `plates(T)` piastre del grado `grade(T)` (item `tool_upgrade.plate_items[grado − 1]`), `handles(T)` manici dello
stesso grado (`handle_items`) e `gold(T)` oro. **Riesce sempre**: nessun tiro, nessuna discesa, nessun Sigillo.
| Verso | +1 | +2 | +3 | +4 | +5 | +6 | +7 | +8 | +9 |
|---|---|---|---|---|---|---|---|---|---|
| `min_level` del mestiere | 1 | 10 | 20 | 25 | 35 | 50 | 65 | 80 | 90 |
| `grade` dei componenti | 1 | 2 | 3 | 3 | 4 | 5 | 6 | 7 | 8 |
| `plates` | 2 | 2 | 3 | 3 | 4 | 4 | 5 | 5 | 6 |
| `handles` | 1 | 1 | 1 | 1 | 2 | 2 | 2 | 2 | 3 |
| `gold` | 100 | 250 | 600 | 1.200 | 2.500 | 5.000 | 10.000 | 20.000 | 40.000 |
Effetto: `skill_interval_pct = −(tool_upgrade.interval_base_pct + tool_upgrade.interval_per_level_pct × N)` con 5 e 2
(+0 → −5; +9 → −23), scope `skill:<s>`; più `upgrade_extras` dell'attrezzo (`data/items/tools.json`): a +5
`double_item_chance` +2 (Boscaiolo, Minatore) o `rift_shard_chance` +10 (Pescatore); a +9 altri +3 / +15. La tabella sta
in `balance.json` (`tool_upgrade.levels`); l'effetto in `balance.json` e nei dati dell'attrezzo.
Rifiuti, in ordine: `unknown_id`, `not_a_tool` (non è un attrezzo unico), `upgrade_max`, `level_too_low` (mestiere),
`not_enough_gold`, `not_enough_items`; atomico. Esempi: Accetta +3 → +4: Boscaiolo al livello 25, 3 piastre di acciaio,
1 manico di quercia, 1.200 oro; Accetta +4 → `skill_interval_pct` −13, +9 → −23 più `double_item_chance` +5; Piccone +0 → +1
con il Minatore al livello 1: 2 piastre di rame, 1 manico di betulla, 100 oro. Test:
`tests/systems/armory/test_upgrade_tool.gd`.

### F-95 Smantellamento a componenti
> M14: `grado` = grado del materiale `m(g)` (§8.4); i pezzi senza progetto (anelli, colli, Cuoio, Tessuto runico, drop di basi non progettabili, leggendari) restituiscono 0 componenti e i soli frammenti; per un Capolavoro la base del progetto è la sua (componenti × `salvage.component_ratio`, con le quantità maggiorate di F-119).
Sostituisce F-88. Il progetto con `base` uguale a quella del pezzo (uno per base) elenca i componenti: per ognuno,
tranne il componente raro, restituisce `floor(qty × salvage.component_ratio)` (0,4) dello stesso oggetto;
frammenti: `salvage.shards_by_rarity[rarity] × grado + N` (comune 0, magico 1, raro 3, come prima). Anelli e amuleti
(nessun progetto) → 0 componenti. Esempi (quantità di §8.2): spada grado 3 magica +0 → 2 piastre di acciaio, 0
impugnature, 3 frammenti; corpo grado 3 → 4 piastre; spadone grado 8 raro +2 → 4 piastre di Riftite, 0 impugnature, 26
frammenti; anello grado 5 raro → 0 componenti, 15 frammenti. Test: `tests/systems/armory/test_salvage.gd`.

## 5d. Deposito, aiutanti, maestria per risorsa e Incisore (F-100…F-108, M12, Riforma 2)

Fonte: decisioni W1-W7 (`DECISIONS_LOG.md`). Tutti i valori sono **valori di partenza** (chiavi di `balance.json` in §9) da
tarare in M12-07 con `tools/sim_combat.gd` (Q58-Q61); gli esempi sono casi di test e cambiano insieme ai valori.

### F-100 Capienza del Deposito
`capacity = deposit.base_slots + Σ slots delle borse negli slot borsa` (`deposit.base_slots = 60`, `deposit.bag_slots = 6`;
una borsa è un oggetto `category: bag` con `bag.slots`, §8.6b). `used = caselle della Bank (un tipo di oggetto impilato = 1)
+ pezzi dell'Armeria non indossati (1 ciascuno) + Carte della Frattura (M13, 1 ciascuna)`; `free = capacity − used`. Le borse messe negli slot borsa **non** occupano
caselle; una borsa fuori dagli slot è un oggetto della Bank (1 casella). Il solo scopo della capienza è accettare o rifiutare
oggetti nuovi (`bank_full` / `armory_full`; una Carta che non entra è persa, `card_rejected`, F-113).
Togliere una borsa dallo slot (`unequip_bag`): la borsa torna nella Bank; si può solo se, dopo, `used' ≤ capacity'`, con
`capacity' = capacity − bag.slots` e `used' = used + 1` (1 solo se la borsa non ha già uno stack nella Bank); altrimenti
`deposit_not_empty`. Mettere una borsa (`equip_bag`) la toglie dalla Bank (1 pezzo) e aumenta la capienza.
Esempi: nessuna borsa → **60**; Borsa di tela (+6) e Borsa di cuoio (+10) → **76**; sei Borse runiche (+24) → **204**.
Con capienza 76 e `used` 66: togliere la Borsa di cuoio → 66 + 1 = 67 > 66 → `deposit_not_empty`; con `used` 65 → 66 ≤ 66 → ok.
Test: `tests/systems/deposit/test_deposit.gd`.

### F-101 Intervallo dell'aiutante
`p_h = total_without(skill_interval_pct, ctx_action, [equipment:tool_<skill>])` (come F-05 senza la sorgente dell'attrezzo del
giocatore: l'aiutante non lo usa; nodi, maestria della risorsa e del mestiere, rune valgono anche per lui).
`base_h = F-03(base_interval_ms, p_h)` (con il minimo `action.min_interval_ms`); `interval_h = round(base_h × mult(grade))`,
`mult` da `helper.grades[].interval_mult` = 3,0 (Apprendista), 2,5 (Garzone), 2,0 (Esperto), 1,5 (Maestro).
Esempi: Betulla 3000 ms, `p_h` 0 → Apprendista **9000**, Garzone **7500**, Esperto **6000**, Maestro **4500**;
`p_h` −10 → base 2700, Maestro **4050**; 1000 ms con `p_h` −80 → base 250 (minimo), Maestro **375**.
Per costruzione l'aiutante è almeno `mult` volte più lento del giocatore con la stessa azione. Test:
`tests/systems/helpers/test_helper_math.gd`.

### F-102 XP e maestria dell'aiutante
`xp_h = floor(F-02(base_xp, T_h(skill_xp_pct)) × helper.xp_pct / 100)` con `helper.xp_pct = 25` (`T_h` come in F-101);
`mxp_h = round(F-10 × helper.mastery_pct / 100)` con `helper.mastery_pct = 25`; il pool riceve la quota F-12 di `mxp_h`.
Prodotti, doppio prodotto (F-06), Frammento (F-07) e sottoprodotto (F-103) come per il giocatore (**tutte le risorse**).
Esempi: XP base 10, pct 0 → F-02 = 10 → **2**; base 28, pct 25 → 35 → **8**; base 3 → 0 (nessun `xp_gained`).
`mxp`: F-10 = 3 → **1**; 20 → **5**; 41 → **10**; 5 → **1**; F-12 su `mxp_h` 5 → **1**.
**Invariante di bilanciamento** (test): `3 × helper.xp_pct / (100 × min(interval_mult)) ≤ 1` (3 aiutanti Maestro: 3 × 25 /
150 = 0,5 ≤ 1: combattere con tre aiutanti non dà più XP di mestiere all'ora del lavorare di persona su un solo mestiere).
Test: `tests/systems/helpers/test_helper_math.gd`, `tests/data/test_balance_invariants.gd`.

### F-103 Traguardi della maestria per risorsa
Ogni azione di raccolta ha 3 traguardi in `milestones` (`data/actions/<skill>.json`, `04_DATA_SCHEMA.md` §6), al **livello di
maestria dell'azione** `L` (F-09), soglie da `mastery.milestones.{byproduct_at, resource_at, trade_at}` = 25, 50, 99:
- **25 (sottoprodotto)**: se `L ≥ 25`, dopo il tiro del Frammento (F-07) un tiro `roll_pct(mastery.milestones.byproduct_chance_pct)`
  (2,0) dà 1 sottoprodotto (`item` del traguardo; mai raddoppiato da F-06). Vale anche per l'aiutante (F-102). Ordine dei
  tiri su `session.rng`: doppio (F-06), Frammento (F-07), sottoprodotto.
- **50 (bonus della risorsa)**: se `L ≥ 50`, i `modifiers` del traguardo con scope `action:<id>` (sorgente
  `mastery_item:<action_id>`, la stessa che F-11 usava per le skill di raccolta). Valori di partenza in §8.8b.
- **99 (bonus del mestiere)**: vedi F-108.
Per le skill di raccolta questi traguardi **sostituiscono** le regole per oggetto di F-11 (`mastery_bonuses` di `skills.json`
dev'essere assente per le skill `gathering`); F-11 resta per l'artigianato.
Esempi: livello 24 → nessun tiro; livello 25 con chance 100 → sempre 1 sottoprodotto (chance 0 → mai); Betulla al livello 49 →
nessun bonus, al 50 → il bonus di §8.8b solo su Betulla (non sulle altre azioni del Boscaiolo).
Test: `tests/systems/mastery/test_mastery_milestones.gd`, `tests/systems/actions/test_gathering_resolver.gd`.

### F-104 Cristallizzare (Incisore)
Azione con `kind: crystallize` (inputs: Polvere del Rift ×`N`, output: 1 Cristallo). Con `L` = livello dell'Incisore (1..99):
`chance_pct = crystal_chance_min_pct + (crystal_chance_max_pct − crystal_chance_min_pct) × (L − 1) / 98`
(`engraver.crystal_chance_min_pct = 40`, `engraver.crystal_chance_max_pct = 90`). Il tiro `roll_pct(chance_pct)` si fa a fine ciclo.
Riuscito: consuma `N` Polvere, dà il Cristallo, XP e maestria pieni. Fallito: consuma `lost = floor(N × engraver.crystal_fail_loss_pct / 100)`
Polvere (`crystal_fail_loss_pct = 50`), niente Cristallo, XP = `floor(xp × lost / N)` (poi F-02), niente maestria; il ciclo
conta e l'azione continua se restano `N` Polvere (altrimenti si ferma con `missing_inputs`).
Esempi: L 1 → **40**; L 50 → **65**; L 99 → **90**; L 25 → **52,2449…**; `N` 10 → perse **5**; `N` 25 → perse **12**;
`N` 50 con XP 160 → XP del fallimento **80**. Test: `tests/systems/actions/test_engraver_resolver.gd`.

### F-105 Fondere (Incisore)
Ricetta deterministica (azione `craft` ordinaria): `engraver.merge_ratio` (3) oggetti di una pietra della stessa famiglia e dello
stesso grado → 1 del grado successivo (Scheggia `_chip` → Pietra `_stone` → Pietra perfetta `_heart`); famiglie di forza (`ember`), di precisione (`eye`), di agilità
(`shade`), di tempra (`root`): ids `stone_<famiglia>_<grado>` (`NOMI.md`). Nessun tiro. Esempi: 9 Schegge di forza → 3 cicli → **3** Pietre di forza; 3 Pietre di
agilità → **1** Pietra perfetta di agilità; 2 Schegge → `missing_inputs`; la Pietra perfetta non si fonde oltre. Il validatore
controlla che ogni ricetta `fuse_*` abbia la quantità uguale a `engraver.merge_ratio`. Test:
`tests/data/test_engraver_recipes.gd`, `tests/systems/actions/test_artisan_resolver.gd`.

### F-106 Potenziare una runa (Incisore)
Ricetta deterministica: `rune.upgrade_ratio` (3) rune di grado `N` (1..4) → 1 runa di grado `N+1` (stessa famiglia). Esempi:
3 × "Runa della rapidità II" → **1** "Runa della rapidità III"; 81 rune di grado I → 1 di grado V (3⁴); il grado V non ha ricetta di
potenziamento. Livello richiesto: livello della runa di grado I + 5 × (`N`), massimo 99. Test: `tests/data/test_engraver_recipes.gd`.

### F-107 Effetto del grado di una runa
Una runa di grado `g` (1..5) ha, per ogni modificatore della runa di grado I, `value_g = value_I × rune.grade_mult[g−1]`
(`rune.grade_mult = [1, 2, 3, 4, 5]`). Esempi: Rapidità `skill_interval_pct −3` → grado III **−9**; Baluardo `max_hp_flat +60` →
grado V **+300**; Senso del Rift `rift_shard_chance +0.5` → grado II **+1,0**. L'Altare usa i `modifiers` dell'oggetto-runa
(sorgente `rift_socket:<i>`, invariato). Test: `tests/data/test_rune_grades.gd`.

### F-108 Bonus del mestiere dalla maestria (traguardo 99)
Per ogni azione di raccolta con `L ≥ mastery.milestones.trade_at` (99): i `modifiers` del suo traguardo `trade` (scope
`skill:<id>`, sorgente unica `mastery_trade:<skill_id>` ricostruita da `MasterySystem.rebuild_modifiers` e a ogni `mastery_level_up`
che attraversa il 99) **si sommano tra le risorse** e poi vale il limite della stat (F-05). Valori di partenza in §8.8b.
Esempi (Boscaiolo, `skill_interval_pct −0,5` per risorsa): 0 risorse al 99 → nessuna sorgente; 3 → **−1,5**; 8 → **−4,0**.
Test: `tests/systems/mastery/test_mastery_milestones.gd`.

---
## 5e. Equipaggiamento vero, leggendari, drop e maestria visibile (F-117…F-122, F-124; M14, Alpha, Y1-Y9)

Fonte: `ALPHA.md` (storica dopo R-05). Tutti i numeri sono **valori di partenza** (chiavi di `balance.json`, §9) da tarare in M14-10 con la sim (Q66-Q77); gli esempi sono casi di test e cambiano insieme ai valori. F-118 è la tabella di §8.4; F-123 (tetto ai rischi delle Carte) è in §7.
Stat nuove: `armor` (sostituisce `damage_reduction`) e `barrier`. Nessun altro sistema nuovo: i leggendari usano il sistema degli effetti dei tratti (F-81) con nuovi tipi.

### F-117 Armatura e Barriera
Il danno subito dal giocatore da un colpo che ha superato F-23 si riduce con rendimenti decrescenti. `A = floor(T(armor))`, `B = floor(T(barrier))` (totali del giocatore, F-05). Con `L_att` = `power_level` del mostro attaccante (scalato in Frattura) e lo stile del mostro:
`X` = `A` se lo stile è `blade` o `marksmanship`, `B` se è `arcana` (gli impulsi dei Monoliti e delle Fratture, senza stile, contano come `combat.unarmed.style`: Armatura);
`rid% = min(combat.armor.cap_pct, 100 × X / (X + combat.armor.k × (L_att + combat.armor.level_offset)))` con `k` 6, `level_offset` 10, `cap_pct` 75. Va usata in F-25 al posto della vecchia riduzione piatta.
Esempi: X 100, L_att 20 → 100/(100 + 180) = **35,71%**; X 724, L_att 92 → 724/(724 + 612) = **54,19%**; X 2000, L_att 10 → 94,3% → limitato a **75**; X 0 → 0; arcana: B 121, L_att 30 → 121/(121 + 240) = **33,52%** (l'Armatura non conta).
Budget dei set e valori dei modelli: §8.4 (F-118). Test: `tests/systems/combat/test_combat_math.gd::test_armor_reduction`, `test_barrier_arcane`.

### F-119 Capolavoro e progetti a costo alto
- **Rarità `masterwork`** (viola), **solo da progetti** (mai da drop). Un progetto produce una base propria (`equip.masterwork: true`, nome proprio in `NOMI.md`) dello stesso slot, grado e materiale (Piastre per le armature, Q75) del modello normale. Tutti i valori base del modello
  (modificatori e, per le armi, `dmg_min`/`dmg_max`) si moltiplicano a runtime per `rarity.masterwork.base_mult` (1,25): corpo Piastre grado 11, armor 121 → **151,25**; spada grado 8 (20-34) → **25-42,5**. Ordine: `base × 1,25 × (1 + upgrade.mod_pct_per_level × N / 100)` (F-86), nessun arrotondamento prima del colpo.
- **Affissi**: `rarity.masterwork.affix_count` = [1, 2] (invece di magico 1-2 / raro 3-4): vedi F-91 (rivista). **Castoni**: `sockets.by_rarity.masterwork` = 2 (F-89).
- **Costo** (Q68): `inputs` del progetto = quantità di §8.2 × `blueprint.cost_mult` (3), più **due componenti rari diversi** (`rare_components`, i due che cadono nell'area del grado; quantità come l'attuale `rare_component`). Durata, livello del Fabbro e XP: F-90 col grado del materiale `m(g)`, invariati.
- Fonte dei progetti: pool dei mostri (F-121, `loot.blueprint`) e Monoliti come oggi.
Esempio: se §8.2 chiede 4 piastre per il corpo del materiale 6, il progetto del corpo Piastre grado 11 (materiale 6) ne chiede 12 più 2 componenti rari diversi; smantellare (F-95) un Capolavoro restituisce `floor(12 × 0,4) = 4` piastre. Test: `tests/systems/items/test_masterwork.gd`, `tests/systems/actions/test_blueprint_craft.gd`.

### F-120 Leggendari
- **Rarità `legendary`** (arancione), niente affissi, un'**istanza** come ogni pezzo. Base con `equip.legendary: {source, effects}` (`04_DATA_SCHEMA.md` §5). Statistiche: quelle del modello (§8.4) di slot, grado e materiale indicati × `rarity.legendary.base_mult` (1,4) a runtime (stesso ordine di F-119);
  raffinazione +0…+9 (F-86) e castoni (`sockets.by_rarity.legendary` = 2, F-89) come ogni pezzo non unico. Le armi leggendarie hanno `dmg_min`/`dmg_max` come le altre. Il filtro dell'Armeria non smantella mai un leggendario; a mano si può vendere e smantellare (frammenti, nessun componente).
- **Attrezzi leggendari** (`slot: tool_*`): sostituiscono l'attrezzo unico nello slot (l'unico torna tra i pezzi non indossati: mai vendibile, riequipaggiabile); requisito il livello del mestiere; modificatori fissi con scope `skill:<id>` (valori di partenza per fonte in `NOMI.md`: `skill_interval_pct` −26…−35, `double_item_chance` +3…+7; l'attrezzo unico a +9 ha −23) e nessuna raffinazione (`upgrade_tool` e `upgrade` → `not_equippable`).
- **Fonte** (`legendary.source`, sempre dichiarata e mostrata dalla Guida a scoperta): `{"type":"boss","id":<boss>,"chance_pct":0,6}`: alla vittoria su quel boss, `roll_pct(chance_pct)` per ogni leggendario di quella fonte, in ordine; `{"type":"monolith","id":<Monolito>,"chance_pct":0,3}`: uccidendo quel Monolito (F-87), stesso tiro.
  Nessun `item_rarity_pct`. Consegna: dal boss nella borsa della Frattura (F-116, solo a vittoria); dal Monolito direttamente nell'Armeria. Deposito pieno: il leggendario **si perde** con notifica (`armory_rejected`), come le Carte (Q64).
  Obiettivo (Q69): circa 1 leggendario ogni 15-30 ore di Fratture del grado giusto (3 leggendari × 0,6% = 1,8% a vittoria, tarato in M14-10: un leggendario di boss ogni 17-26 ore di Fratture; i Monoliti restano allo 0,3%).
- **Tipi di effetto** (elenco **chiuso**, stesso `EffectSet` di F-81; i tipi di F-81 restano validi anche sui leggendari). Nuovi agganci: `on_block` (parata riuscita, F-75), `on_gather` (ciclo di raccolta riuscito del giocatore, mai dell'aiutante), `on_monolith` (Monolito ucciso).

| Tipo | Parametri | Aggancio | Regola | Esempio |
|---|---|---|---|---|
| `on_kill_timer_cut` (F-81) | `pct` | `on_kill` | con 100 il prossimo attacco parte subito | timer 2000 → 0 |
| `block_heal_pct` | `pct` | `on_block` | parata riuscita: cura `floor(max_hp × pct/100)` (non oltre i PV massimi) | max 200, 10 → +20 |
| `kill_heal_pct` | `pct` | `on_kill` | uccisione: cura `floor(max_hp × pct/100)` | max 1.000, 2 → +20 |
| `armor_pierce_pct` | `pct` | `on_before_attack` | la riduzione del bersaglio (F-25) × `(1 − pct/100)` | DR 20, 50 → 10 |
| `hit_cap_pct` | `pct` | `on_damaged` | un colpo subito non supera `floor(max_hp × pct/100)` (minimo 1), dopo F-25 | max 400, 25, colpo 180 → 100 |
| `stat_convert` | `from`, `to`, `pct` | `modify_stats` | dopo il calcolo delle stat: `to += floor(from × pct/100)`, poi i limiti di `stats.json` | barrier 100, 50 → armor +50 |
| `double_hit_pct` | `pct` | `on_hit` | `roll_pct(pct)`: un secondo colpo base sullo stesso bersaglio (F-23 e F-22 nuovi) | pct 100 → sempre 2 colpi |
| `execute_mult` | `hp_pct`, `mult` | `on_before_attack` | danno dopo F-24 × `mult` (`floor`) se il bersaglio ha PV ≤ `hp_pct`% dei suoi massimi | 30%, ×2, tiro 40 → 80 |
| `monolith_loot_mult` | `mult` | `on_monolith` | quantità di ogni voce di bottino del Monolito × `mult` (`round`) | ×2, Polvere 30 → 60 |
| `gather_bonus_item` | `items` (lista, uno a caso), `pct` | `on_gather` | `roll_pct(pct)`: +1 oggetto di `items` oltre al prodotto | 5%, 200 cicli → ~10 |
| `gather_grade_up_pct` | `pct` | `on_gather` | `roll_pct(pct)`: il prodotto è quello della risorsa di grado successivo dello stesso mestiere (se esiste; XP della risorsa lavorata) | 10%, Trota → Persico |
| `byproduct_mult` | `mult` | `on_gather` | probabilità dei sottoprodotti di maestria (F-103) × `mult` | 2,0% × 3 → 6% |
| `card_drop_mult` | `mult` | `on_kill` | probabilità delle Carte dai mostri e dai Monoliti (F-113) × `mult` | ×2 |

Intervalli di formato: `pct`, `hp_pct` in (0, 100] (`hit_cap_pct` in [1, 100]); `mult` in (1, 10]; `stat_convert`: `from` ≠ `to`, entrambe stat esistenti. Test: `tests/systems/combat/effects/test_<tipo>.gd` per i tipi di combattimento, `tests/systems/actions/test_gather_effects.gd`,
`tests/systems/combat/test_monolith_effects.gd`, `tests/data/test_legendaries.gd` (fonte ed effetto di ognuno).

### F-121 Drop di equipaggiamento e progetti (Y6, Q69)
Ogni mostro può far cadere **tutti gli slot** del grado giusto, senza liste fisse di modelli. Alla morte di ogni nemico (anche nelle Fratture, con il livello scalato), con `L_m` = massimo di `attack_level`, `power_level` e `defence_level`:
1. `roll_pct(loot.equipment.chance_pct)` (2,9, tarato in M14-10): se riesce cade un pezzo;
2. tipo: `pick_weighted(loot.equipment.kind_weights)` tra i 10 tipi (spada, spadone, scudo, elmo, corpo, gambe, piedi, mani, anello, collo; peso 1 ciascuno); per armature e scudo il materiale è uniforme tra Piastre, Cuoio, Tessuto runico;
3. grado: uniforme tra i gradi `g` con `lvl(g) > L_m − loot.equipment.level_window` (15) e `lvl(g) ≤ L_m + loot.equipment.level_ahead` (5);
4. rarità: F-84 (`rarity.drop.magic_pct` 25, `rare_pct` 5; mai Capolavoro né leggendario); `ilvl` e affissi come F-85.

I **progetti** cadono con lo stesso schema: `roll_pct(loot.blueprint.chance_pct)` (0,4), tipo tra gli 8 progettabili (spada, spadone, scudo, elmo, corpo, gambe, piedi, mani; Piastre), grado come al punto 3. Anello e collo non hanno progetto (Q30).
Esempi: mostro con `L_m` 46 → gradi con livello in (31, 51] = 35, 40, 45, 50 → gradi 8-11; `L_m` 92 → (77, 97] = 80, 90 → gradi 14-15; `L_m` 1 → gradi 1-2. Con ~300 uccisioni all'ora: 7,5 pezzi/ora (3,75 ogni 30 minuti), 0,94 magici ogni 30 minuti, un raro ogni ~2,7 ore, ~1,2 progetti/ora (Q49).
Il pool sostituisce le voci di equipaggiamento e di progetto nei `drops` dei mostri (che restano per materiali e componenti rari). Test: `tests/systems/combat/test_equipment_drop.gd` (grado, tipo e materiale con seme fisso), `tests/integration/test_drop_rates.gd` (sim).

### F-122 Bonus di maestria ogni 10 livelli (Y8, Q70)
Vale per **ogni azione con maestria**, di raccolta e di artigianato (Incisore compreso). `n = floor(mastery_level / mastery.step.every_levels)` (10; 0…9 fino al livello 99). L'azione ha i modificatori di `mastery.step.gathering` (raccolta: `skill_interval_pct −2`, `double_item_chance +1`)
o di `mastery.step.crafting` (artigianato: `preservation_chance +2`, `skill_interval_pct −2`), ognuno × `n`, con ambito azione (sorgente `mastery_step:<action_id>`, la stessa dei vecchi bonus per oggetto). Sostituisce F-11 (bonus per oggetto dell'artigianato) e **si somma** ai traguardi 25/50/99 (F-103, F-108).
La carta dell'azione mostra il livello di maestria, i **bonus attuali** e il **prossimo** ("Al livello 40: −2% intervallo, +1% prodotto doppio"; a 99 nessun prossimo).
Esempi: maestria 9 → nessun bonus, prossimo al livello 10; 10 → −2% e +1%; 47 (n = 4) → −8% intervallo e +4% doppio; 99 (n = 9) → −18% e +9%. Artigianato 30 (n = 3) → +6% conservazione e −6% intervallo; 99 → +18% e −18%.
Le funzioni stanno in `MasteryMath` (`step_bonus`, `next_step`, `05_INTERFACES.md` §5.7). Test: `tests/systems/mastery/test_mastery_step.gd`.

### F-124 Scoperte della Guida (wiki a scoperta, Y7)
Regola, non formula. Lo stato per slot è `discoveries.items`, l'insieme degli id di base degli oggetti **ottenuti almeno una volta**. Un oggetto è ottenuto quando entra in possesso del giocatore per qualsiasi via (Bank, borsa del bottino, Armeria, `CardStore`, kit iniziale, Frattura consegnata,
aiutanti, offline), segnalato da `item_obtained(item_id, qty)`; i pezzi e le Carte contano per l'id della loro base. L'insieme è monotono (non si perde mai). Effetti sulla Guida: oggetto non scoperto → casella bloccata ("???", icona in ombra), pagina chiusa; scoperto → pagina con **Si ottiene da** e la **% base**; pagina di
mostro, area, Monolito o attività → **tutto ciò che può dare**, in caselle bloccate fino alla scoperta (sbloccate mostrano la %). La % di un pezzo del pool (F-121) è `chance_pct × (peso del tipo / somma dei pesi) × (1 / n. di gradi candidati) × (1/3 per il materiale, se armatura o scudo)`. Il tooltip e la scheda
dell'oggetto **non** mostrano più "Si ottiene da" (resta "Serve a"); le meccaniche (testi) restano sempre visibili.
Esempio: un Persico mai pescato è una casella bloccata nella pagina della Lenza; al primo Persico pescato si sblocca e mostra la sua fonte e la % dai dati. Pezzo del pool: mostro `L_m` 46, corpo di Cuoio grado 9 → 2,5 × (1/10) × (1/4) × (1/3) = **0,0208%**. Test: `tests/core/guide/test_discoveries.gd`, `tests/core/data/test_guide_index_sources.gd`.


## 5f. Monoliti da Metin (F-125…F-128; M15, Z1-Z9, R-06)

Fonte: `METIN.md` (storica dopo M15-01). Tutti i numeri sono **valori di partenza** in `balance.json` (§9), da tarare in M15-08 (Q78); gli esempi sono casi di test e cambiano insieme ai valori. F-87 (quando appare un Monolito) è invariata.

### F-125 PV del Monolito e impulso
`hp = round(metin.hp_base × (1 + metin.hp_per_level × L))` con `L` = `level` del Monolito (dati, multiplo di 5). Obiettivo di taratura: ~60-90 s per abbatterlo con il DPS atteso a `L` (Q78). Il campo `hp` dei dati sparisce.
Impulso: ogni `pulse_ms` (dati, 3000) infligge `metin.pulse_damage` (1) al giocatore: **danno fisso**, senza tiro di colpo, **ignora Armatura e Barriera** (niente F-25 né F-117/F-118), non parabile; riduce comunque i PV (il cibo automatico agisce, F-30).
Valori di partenza: `metin.hp_base` 200, `metin.hp_per_level` 0,25.
Esempi: L 5 → 200 × 2,25 = **450**; L 10 → 200 × 3,5 = **700**; L 15 → 200 × 4,75 = **950**; L 65 → 200 × 17,25 = **3450**; L 95 → 200 × 24,75 = **4950**. Impulso con Armatura 40%: sempre 1.
Test: `tests/systems/combat/test_metin_hp.gd` (i casi sopra + l'impulso ignora la difesa).

### F-126 Ondate di evocazione
Soglie `metin.wave_thresholds` = [75, 50, 25] (% dei PV massimi) più il **primo colpo ricevuto** (valore 100). Un colpo del giocatore che porta i PV a `h1` fa scattare ogni soglia `s` non ancora scattata con
`h1 × 100 < s × hp_max` (stretto); il primo colpo scatta sempre. Una soglia scatta **una volta sola** per Monolito; un colpo che ne attraversa due le fa scattare **entrambe**, in ordine decrescente di `s`. Ogni scatto evoca
`metin.wave_size` (7) mostri: si pescano gruppi pesati (F-77) tra i `wave_packs` del Monolito (o tutti i gruppi dell'area) finché si raggiunge `wave_size`, l'ultimo gruppo è troncato; i mostri nascono con `summoned = true`,
**livelli (attacco, potenza, difesa) = `min(99, L)`**, PV, danno e ricompense invariati (Q79); non danno XP, oro né drop e non contano come uccisioni (F-87), come i richiami del boss (F-112). Totale massimo: 4 ondate = 28 mostri + il Monolito.
Esempi (`hp_max` 1000): primo colpo 1000 → 960 → 1 ondata (7 mostri); poi 960 → 749 → scatta il 75% (749 < 750; con 750 no) → 14 in tutto; poi 749 → 240 → scattano 50% **e** 25% → 28 in tutto; ancora colpi: nulla.
Con un solo colpo 1000 → 200 si evocano le 4 ondate insieme (28). Un Monolito caricato dal salvataggio ricorda le soglie già scattate (`combat.wave.fired`). Test: `tests/systems/combat/test_metin_waves.gd` (incluso il salvataggio a metà ondata).

### F-127 Bottino del Monolito
Alla morte del Monolito, oltre a Frammenti (`shards`, F-87), `drops` e `loot_tables` (F-32) e leggendari (F-120):
1. **pezzo garantito** (`metin.guaranteed_pieces` = 1): F-121 senza il tiro di probabilità del punto 1; tipo, grado e materiale come F-121 punti 2-3 con `L_m` = `L` del Monolito; rarità come F-84 con fonte `rift_stone` e
   `k = 1 + (T(item_rarity_pct, ctx) + metin.rarity_bonus_pct)/100` (`metin.rarity_bonus_pct` = 100); `ilvl` e affissi come F-85;
2. **un tiro di Progetto**: `roll_pct(loot.blueprint.chance_pct)` come F-121, con `L_m` = `L`.
I pezzi vanno nel Bottino (`01_GDD.md` §10.14).
Esempi: `L` 45 → gradi con livello in (30, 50] = 35, 40, 45, 50 → gradi 8-11 (come F-121 con `L_m` 46); con +0%, `k` = 2 → `p_magic` 80 e `p_rare` 24 (limite e ordine dei tiri come F-84); con +50%, `k` = 2,5. Il pezzo c'è sempre (probabilità 100%).
Test: `tests/systems/combat/test_metin_loot.gd` (pezzo sempre presente; grado dalla finestra di F-121; `k`).

### F-128 Salto dei Monoliti
Stato dello slot `combat.skip_stone_level` = `S` (0 = disattivato; intero 0..`character_curve.max_level`; valore iniziale di un nuovo slot = `combat.skip_stone_level` di `balance.json`, 0). Quando il prossimo incontro sarebbe il Monolito
pendente: se `S ≠ 0` e `level ≤ S` il Monolito è **scartato**: nessun incontro, nessuna uccisione, `pending = false`, `since = 0`, e si estrae il gruppo normale (F-77). Anche un Monolito appena estratto (F-87) è scartato subito
se il suo livello è ≤ `S`. Cambiare `S` non tocca un Monolito già in combattimento.
Esempi: `S` 10 e Monolito di livello 10 → scartato; livello 15 → combattuto; `S` 0 → mai scartato; `S` 99 → scartati tutti. Test: `tests/systems/combat/test_metin_skip.gd` (anche salvataggio e caricamento).

## 6. Offline

### F-40 Tempo offline
`elapsed = clamp(now_unix_ms − saved_at_unix_ms, 0, offline_cap_ms)`; `offline_cap_ms = 43200000` (12 h),
`capped = (now − saved) > offline_cap_ms`.
Esempi: 5 h → 18.000.000, capped false; 20 h → 43.200.000, capped true; orologio indietro → 0. Con
`elapsed < offline_min_ms (60000)` nessuna schermata. Test: `tests/core/offline/test_offline_simulator.gd`.

### F-41 Blocchi della simulazione
`chunks = ceil(elapsed / offline_chunk_ms)`, `offline_chunk_ms = 60000`. Esempio: 12 h → 720 blocchi; 90 s → 2 (60 s + 30 s).
Equivalenza: simulare 600.000 ms in un blocco o in 10 blocchi dà lo stesso stato con lo stesso seme. Test: idem.

## 7. Fratture come mappe (M13; X1-X4, R-04)

Le **corsie parallele** sono **eliminate** (W3): le sostituiscono gli aiutanti (F-101, F-102). F-51, `parallel.*` e la stat `parallel_lanes` non esistono più. La **Frattura casuale a tempo** è eliminata (X1): niente `fractures.*` in
`balance.json`, niente stat `fracture_duration_pct`. Le Fratture sono incursioni aperte dal giocatore con una Carta (`01_GDD.md` §17). Tutti i numeri sono **valori di partenza** (chiavi di `balance.json` `fracture`, §9) da tarare in
M13-06 con la sim (Q63-Q65); gli esempi sono casi di test e cambiano insieme ai valori. Stat nuove: nessuna.

### F-50 Struttura della Frattura
Apertura: la Carta esce dal `CardStore` e la Frattura parte con il gruppo 1 (nessun timer, nessuna estrazione). La Frattura ha `fracture.groups` (16) gruppi, in ordine; il gruppo `i` è scelto come F-77 (`pick_weighted` sui pesi) tra i `packs`
di **tutte** le aree di `fracture.grades[g].areas` (unione, pesi dei gruppi invariati); i suoi mostri sono scalati con F-110/F-111 (più `pack_bonus`, F-111). Tra un gruppo e l'altro passa `combat.respawn_ms` (stato `BETWEEN`). Cancellato
l'ultimo gruppo, dopo `combat.respawn_ms` entra il **boss** del grado (F-112, F-115). Boss ucciso = vittoria. Morte o abbandono = sconfitta (X4). Nessun tiro di Monolito e nessun conteggio F-87 dentro la Frattura.
Esempio (`fracture.groups` = 3 nelle fixture): gruppo 1, `BETWEEN`, gruppo 2, `BETWEEN`, gruppo 3, `BETWEEN`, boss; tre `fracture_group_cleared(i, 3)`, poi `fracture_boss_started`, poi `fracture_finished(&"won", g, 3, …)`. Morte al gruppo 2 →
`fracture_finished(&"died", …)` e borsa persa. Durata attesa di una Frattura nel grado giusto: 15-30 minuti (obiettivo della sim). Test: `tests/systems/fractures/test_fracture_run.gd`, `test_fracture_flow.gd`.

### F-109 Carta: rarità e modificatori
- **Rarità** (Carte da drop e da Frattura): un solo `randf`; `p_magic = fracture.card_rarity.magic_pct × k`, `p_rare = fracture.card_rarity.rare_pct × k`, `k = 1 + T(item_rarity_pct)/100` (stesso tiro di F-84/F-91: rara se `r < p_rare`,
  magica se `r < p_rare + p_magic`, altrimenti comune). Esempio: +50% → 37,5 e 9. Il numero di modificatori è `randi_range(a, b)` con `fracture.mod_count[rarità]` (comune [0,0], magica [1,2], rara [3,4]).
- **Scelta**: per ogni modificatore, in ordine: candidati = voci di `data/maps/map_mods.json` con `min_grade ≤ grado`, `id` non già sulla Carta e `risk.type` non già sulla Carta; `pick_weighted(weight)`; poi l'**intensità**
  `step = randi_range(0, fracture.intensity_steps)` (10). Senza candidati si smette. Ordine dei tiri su `rng`: rarità, numero, poi per ogni modificatore scelta e `step`.
- **Tetto ai rischi** (M14): vedi F-123 (i punti di rischio non superano `fracture.risk_cap`).
- **Valore**: `value(x) = x.min + round((x.max − x.min) × step / fracture.intensity_steps)` per il rischio e per il premio **con lo stesso `step`** (più rischio, più premio). Il salvataggio tiene solo `{mod, step}`: i valori si ricalcolano dai dati.
- **Cristalli** (`CardStore.use_currency`): `to_magic` (comune → magica: aggiunge modificatori fino al numero tirato per la magica), `to_rare` (magica → rara: tiene i vecchi e ne aggiunge fino al numero tirato per la rara, senza duplicati),
  `reroll` (magica o rara: ritira tutti i modificatori, stessa rarità, stessa regola). Rarità non adatta → `requirement_not_met`.
- Esempio di valore: "Mostri robusti" (`risk` `monster_hp_pct` 20-60, `reward` `loot_qty_pct` 5-15), `step` 5 → +40% PV e +10% quantità; `step` 0 → +20% / +5%; `step` 10 → +60% / +15%. Carta di grado 1 magica: candidati solo con `min_grade` 1;
  rara di grado 5: fino a 4 modificatori di tipi di rischio diversi. Test: `tests/systems/fractures/test_map_card_roller.gd`.

### F-110 Scala dei gradi
Per il grado `g` (1-10) la riga `fracture.grades[g]`:
- **Mostri** di un gruppo (da una delle aree della riga): `attack_level`, `power_level`, `defence_level` = `min(99, livello + level_bonus)`; `hp = round(hp × hp_mult)`; `xp` e `gold` × `reward_mult` (`round`); danno (min e max dopo F-22) × `damage_mult`
  (`floor`, minimo 1); il resto invariato. Poi si applicano i modificatori della Carta (F-111). Gli `hp` ottenuti sono i massimi dell'incontro.
- **`ilvl`** dei pezzi caduti: come F-85, ma sui livelli **scalati** del mostro (quindi cresce con il grado, fino a 99).
- `piece_grade` = grado della base del pezzo garantito dal boss (F-115); `recommended_level` = livello del personaggio consigliato (solo informazione per la UI, nessun blocco).

Esempio: `crack_golem` (L 38, 320 PV) al grado 3 → livelli 46, PV 320 × 1,30 = 416, danno ×1,16; `vein_witch` (L 55) al grado 3 → livello 63; `shard_wraith` (L 65) al grado 4 → livello 65 e PV invariati.
Tabella di partenza:

| g | aree | `level_bonus` | `hp_mult` | `damage_mult` | `reward_mult` | `piece_grade` | `recommended_level` |
|---|---|---|---|---|---|---|---|
| 1 | cracked_mines | 0 | 1,00 | 1,00 | 1,0 | 5 | 45 |
| 2 | cracked_mines | 4 | 1,15 | 1,08 | 1,2 | 5 | 50 |
| 3 | cracked_mines | 8 | 1,30 | 1,16 | 1,4 | 6 | 56 |
| 4 | rift_threshold | 0 | 1,00 | 1,00 | 1,6 | 6 | 70 |
| 5 | rift_threshold | 3 | 1,15 | 1,08 | 1,8 | 7 | 76 |
| 6 | rift_threshold | 6 | 1,30 | 1,16 | 2,0 | 7 | 82 |
| 7 | rift_threshold | 7 | 1,50 | 1,25 | 2,3 | 8 | 88 |
| 8 | rift_threshold | 7 | 1,75 | 1,35 | 2,6 | 8 | 94 |
| 9 | rift_threshold | 7 | 2,05 | 1,50 | 3,0 | 8 | 99 |
| 10 | rift_threshold | 7 | 2,40 | 1,70 | 3,5 | 8 | 99 |

Test: `tests/systems/fractures/test_fracture_scaler.gd`.

### F-111 Tipi di rischio e di premio dei modificatori
Elenco **chiuso** (il validatore rifiuta altri tipi). Un tipo non è una stat: o è un effetto del motore, o applica una stat esistente con sorgente `fracture:<uid>` mentre la Frattura è in corso (`FractureSystem.rebuild_modifiers`). Effetti dello stesso
tipo sulla stessa Carta si sommano (i rischi sono unici per Carta, F-109).

| Tipo | Famiglia | Effetto con valore `v` |
|---|---|---|
| `monster_hp_pct` | rischio | PV massimi dei mostri e del boss × `(1 + v/100)` (dopo F-110, `round`) |
| `monster_damage_pct` | rischio | danno min e max dei mostri e del boss × `(1 + v/100)` (`floor`, minimo 1) |
| `monster_speed_pct` | rischio | intervallo d'attacco = F-26 con `pct = −v` (minimo `combat.min_attack_interval_ms`) |
| `monster_defence_pct` | rischio | evasione dei mostri e del boss × `(1 + v/100)` (F-21, `round`) |
| `pack_bonus` | rischio | `+v` mostri in ogni gruppo (non nel boss), ripetendo in ordine i mostri del gruppo, fino a `combat.max_pack_size` |
| `food_heal_pct` | rischio | la cura del cibo (F-29) × `(1 − v/100)`, `floor`, minimo 0 |
| `pulse` | rischio | ogni `fracture.pulse_ms` (4000), durante un incontro, danno `max(1, floor(PV massimi del giocatore × v/100))` senza tiro di colpo, ridotto da F-25 (relazione neutra), parabile (F-75), come l'impulso dei Monoliti (F-87) |
| `loot_qty_pct` | premio | quantità dei drop di oggetti dei mostri (`drops` e tabelle; non pezzi né Carte) × `(1 + v/100)`, `round`, minimo la quantità tirata |
| `item_rarity_pct` | premio | stat `item_rarity_pct` `+v` (F-84, F-109) |
| `xp_pct` | premio | stat `skill_xp_pct` `+v`, scope `global` (XP del personaggio, F-71) |
| `gold_drop_pct` | premio | stat `gold_drop_pct` `+v` (F-31) |
| `blueprint_pct` | premio | probabilità dei drop di categoria `blueprint` × `(1 + v/100)` (massimo 100) |
| `dust_pct` | premio | quantità di Polvere del Rift (`rift_dust`) dei drop × `(1 + v/100)`, `round` |
| `card_chance_pct` | premio | probabilità di Carta (F-113) × `(1 + v/100)` |

Tabella iniziale (12 modificatori, Q65; nomi in `NOMI.md`):

| id | Nome | `min_grade` | `weight` | Rischio (min-max) | Premio (min-max) |
|---|---|---|---|---|---|
| `sturdy` | Mostri robusti | 1 | 10 | `monster_hp_pct` 20-60 | `loot_qty_pct` 5-15 |
| `assault` | Assalto | 1 | 10 | `monster_speed_pct` 10-35 | `item_rarity_pct` 10-35 |
| `famine` | Fame | 1 | 8 | `food_heal_pct` 20-60 | `blueprint_pct` 25-75 |
| `brutal` | Brutalità | 1 | 8 | `monster_damage_pct` 15-45 | `gold_drop_pct` 20-60 |
| `hordes` | Orde | 2 | 8 | `pack_bonus` 1-2 | `xp_pct` 10-30 |
| `pulses` | Impulsi | 2 | 8 | `pulse` 2-5 | `dust_pct` 20-60 |
| `shrouded` | Velati | 3 | 6 | `monster_defence_pct` 20-60 | `card_chance_pct` 20-60 |
| `fasting` | Digiuno | 4 | 6 | `food_heal_pct` 50-90 | `xp_pct` 25-50 |
| `titans` | Titani del Rift | 5 | 6 | `monster_hp_pct` 60-120 | `card_chance_pct` 30-70 |
| `spectral` | Lame spettrali | 5 | 6 | `monster_damage_pct` 40-90 | `item_rarity_pct` 30-70 |
| `frenzy` | Frenesia del Rift | 6 | 6 | `monster_speed_pct` 30-60 | `loot_qty_pct` 15-35 |
| `abyssal` | Tempesta dell'Abisso | 8 | 6 | `pulse` 4-8 | `blueprint_pct` 60-120 |

Esempi: Mostri robusti +40 su un mostro da 320 PV al grado 3 → 416 × 1,40 = 582 (`round`); Assalto +20 su 2800 ms senza altri bonus → F-26 con pct −20 → 2240 ms; Impulsi 4 con 500 PV massimi → 20 di danno ogni 4 s prima di F-25;
Fame +40 con un cibo da 100 → 60. Test: `tests/systems/fractures/test_fracture_effects.gd`.

### F-112 Abilità del boss
Un'abilità per boss (`data/maps/bosses.json`), dal momento in cui parte l'incontro del boss. Il timer dell'abilità parte da `every_ms`, si risolve **dopo** l'attacco base del boss nello stesso istante (F-76) e si ripete finché il boss è vivo.
- `heavy_strike` `{every_ms, mult}`: colpo senza tiro di precisione, danno `floor(max_hit del boss × mult)`, poi F-25 con la relazione del boss; parabile (F-75).
- `shield` `{every_ms, duration_ms, shield_pct}`: il boss ottiene uno scudo di `floor(PV massimi × shield_pct/100)` che assorbe il danno prima dei PV per `duration_ms` (poi svanisce con quel che resta); uno scudo attivo non si rinnova.
- `summon` `{every_ms, count, max_alive, monsters}`: se gli evocati vivi sono meno di `max_alive`, evoca `count` mostri (presi da `monsters`, in ordine ripetuto; scalati come i mostri del grado, F-110/F-111) nelle posizioni libere; boss + evocati
  ≤ `combat.max_pack_size`. Gli evocati **non danno XP, oro né drop**; il boss ucciso termina la Frattura anche se restano evocati.

Esempio: `heavy_strike` ogni 8000 ms, `mult` 2,0, `max_hit` 40, riduzione del giocatore 10% → `floor(40 × 2,0)` = 80 → 72 dopo F-25; `shield` 20% su 1000 PV → 200 di scudo per `duration_ms`. Test: `tests/systems/fractures/test_boss_abilities.gd`.

### F-113 Carte dalle Fratture e dalle tabelle
Dentro la Frattura, a ogni uccisione di un mostro (non evocato): `roll_pct(fracture.card_drop.monster_pct × (1 + card_chance_pct/100))`; se riesce, `delta = pick_weighted(fracture.card_drop.monster_delta)` (pesi per +0, +1, +2), la Carta ha grado
`min(10, g + delta)` e rarità F-109. Boss ucciso: `roll_pct(fracture.card_drop.boss_pct)` e `boss_delta`. Le Carte cadute vanno nella borsa della Frattura. Ordine dei tiri: probabilità, delta, rarità (poi i tiri di F-109).
**Fuori** dalle Fratture le Carte escono dalle tabelle di drop dei mostri e dei Monoliti (F-32, voce con `item` di categoria `map`, `qty` [1, 1], rarità F-109); gradi di partenza: Pianure 1; Bosco 1-2; Miniere 1-3; Soglia 2-3; Monoliti 1-4
(`loot_tables.json`). Obiettivo (Q64): fuori dalle Fratture una Carta ogni 2-4 ore di combattimento nell'area giusta; dentro, ~1 Carta di grado uguale o superiore per Frattura.
Valori di partenza: `monster_pct` 0,5; `boss_pct` 70; `monster_delta` [70, 27, 3]; `boss_delta` [20, 70, 10].
Esempi: grado 4 con `card_chance_pct` 50 → 0,6% per uccisione; grado 10 → il grado resta 10 per ogni delta; `boss_pct` 100 con seme fisso → una Carta a ogni boss. Test: `tests/systems/fractures/test_card_drops.gd`.

### F-114 Smantellamento di una Carta
`dust = floor(fracture.salvage.dust_per_grade × grado × fracture.salvage.rarity_mult[rarità])` Polvere del Rift (`rift_dust`) nella Bank. Valori: `dust_per_grade` 5; `rarity_mult` comune 1, magica 1,5, rara 2.
Esempi: grado 3 rara → 30; grado 1 comune → 5; grado 4 magica → 30. Carta bloccata → `item_locked`; Bank senza posto per la Polvere → `bank_full` (nulla cambia). Test: `tests/systems/fractures/test_card_store.gd`.

### F-115 Ricompense del boss
Alla vittoria, oltre ai drop del boss (che seguono F-32 e F-84): **un pezzo almeno magico** (base `equipment` ammessa dalla classe, a caso tra quelle di grado `fracture.grades[g].piece_grade`; rarità F-84 con fonte `monster`, e se esce comune diventa
magica; affissi F-85 con `ilvl` del boss), `randi_range(rewards.dust)` Polvere del Rift (campo del boss, × `(1 + dust_pct/100)`) e la Carta di F-113. Tutto nella borsa della Frattura, poi consegnato con la vittoria. XP e oro del boss come
quelli dei mostri (`reward_mult` non si applica: i valori del boss sono già nei dati).
Esempio: grado 6 → base di grado 7; boss con `dust` [20, 30] e `dust_pct` 40 → 28-42. Test: `tests/systems/fractures/test_boss_rewards.gd`.

### F-116 Consegna del bottino della Frattura
Alla vittoria, per ogni voce della borsa nell'ordine di inserimento: oggetti → `bank.add` (ciò che non entra resta **in attesa**); pezzi → `armory.add_drop` (filtro automatico dell'Armeria, `01_GDD.md` §25: il filtro smantella, un Deposito pieno smantella come per ogni drop;
nulla resta in attesa); Carte → `cards.add` (Deposito pieno → restano in attesa). `collect()` riprova con le voci in attesa. Alla sconfitta la borsa è svuotata e conta come persa (`fracture_loot_lost`).
Esempio: borsa con 40 tipi di oggetto e la Bank con 25 caselle libere → 25 consegnati, 15 in attesa; fatto spazio e `collect()`, entrano. Test: `tests/systems/fractures/test_fracture_delivery.gd`.

### F-123 Tetto ai rischi della Carta (M14, Q72)
Una Carta rara di grado basso con 3-4 rischi pesanti era punitiva. I rischi hanno un **tetto**: `cap(g) = fracture.risk_cap.base + fracture.risk_cap.per_grade × (g − 1)` (40 + 10 per grado: grado 1 → 40, grado 5 → 80, grado 10 → 130). I **punti di rischio** di un modificatore sono
`risk_value × fracture.risk_unit[tipo di rischio]` (default 1; `pack_bonus` 20, `pulse` 5), con `risk_value` di F-109. La somma dei punti di tutti i modificatori della Carta è ≤ `cap(g)`.
Regola nella scelta (F-109, nessun tiro in più su `rng`): dopo la scelta di un candidato e il tiro dello `step`, se la somma supererebbe il tetto lo `step` si **riduce** al massimo che ci sta (`step_max`); se anche `step` 0 non ci sta il candidato è scartato dai candidati e la scelta si
ripete (senza nuovi tiri se non quelli di scelta e `step`); senza candidati si smette. Il premio segue lo `step` ridotto. Vale anche per i Cristalli (`to_rare`, `reroll`).
Esempi (grado 1, tetto 40): "Brutalità" (`monster_damage_pct` 15-45, unità 1) con `step` 10 → 45 > 40, ridotto a `step` 8 → 15 + round(30 × 8/10) = **39** punti; resta 1: nessun altro modificatore ci sta (il minimo è 10), la Carta rara ha un solo modificatore.
"Mostri robusti" (20-60) `step` 1 → 24; restano 16, "Assalto" (10-35) a `step` 2 → 10 + round(25 × 0,2) = 15 (totale 39). "Orde" (`pack_bonus` 1-2, unità 20) al grado 2 (tetto 50): `pack_bonus` 2 → 40 punti. "Impulsi" (`pulse` 2-5, unità 5) a `step` 10 → 25 punti.
Test: `tests/systems/fractures/test_map_card_roller.gd::test_risk_cap`; i dati veri: `tests/data/test_map_data_validation.gd` (almeno un candidato di rischio ≤ 40 per il grado 1, in modo che la scelta non si blocchi).

### F-51 Penalità della corsia secondaria — **ELIMINATA in M12** (corsie parallele sostituite dagli aiutanti, F-101)

---

## 8. Tabelle di bilanciamento iniziali

I nomi degli oggetti li sceglie il Data/Content Designer (originali, a tema RiftStone). Le tabelle fissano i numeri.

### 8.1 Raccolta (stessi gradini per Selvicoltura, Cavatura, Lenza)
| Grado | Livello | Intervallo ms | XP | Prodotto | Valore (oro) |
|---|---|---|---|---|---|
| T1 | 1 | 3000 | 10 | 1 | 1 |
| T2 | 10 | 3200 | 18 | 1 | 3 |
| T3 | 20 | 3500 | 28 | 1 | 6 |
| T4 | 30 | 3800 | 40 | 1 | 10 |
| T5 | 45 | 4200 | 58 | 1 | 18 |
| T6 | 60 | 4600 | 80 | 1 | 30 |
| T7 | 75 | 5000 | 108 | 1 | 50 |
| T8 | 90 | 5500 | 145 | 1 | 85 |
Controllo: T1 = 12.000 XP/h → livello 10 in circa 6 minuti; T8 ≈ 94.900 XP/h.

### 8.2 Artigianato
| Skill | Ricetta (grado n) | Ingredienti | Intervallo | XP | Valore |
|---|---|---|---|---|---|
| Fabbro | Lingotto Tn | 2 × minerale Tn | 2000 | `floor(0,8 × XP raccolta Tn)` (8, 14, 22, 32, 46, 64, 86, 116) | 3 × valore minerale |
| Fabbro | Piastra Tn (M10, componente) | 2 × lingotto Tn | 2400 | `floor(2 × XP lingotto × 1,2)` | 7 × valore minerale |
| Cuoco | Pesce cotto Tn | 1 × pesce Tn | 2500 | `floor(0,9 × XP pesca Tn)` | 2 × valore pesce |
| Falegname | Impugnatura Tn (componente di spade e spadoni) | 1 × legno Tn | 1600 | `XP legno × 0,8` | 2 × valore legno |
| Falegname | Telaio dello scudo Tn (era "anima dello scudo", componente degli scudi) | 2 × legno Tn | 2000 | `2 × XP legno × 0,9` | 4 × valore legno |
| Falegname | Manico Tn (componente della raffinazione degli attrezzi, F-94) | 1 × legno Tn | 1600 | `XP legno × 0,8` | 2 × valore legno |
Livello richiesto della ricetta Tn = livello del grado Tn (8.1). Gli arrotondamenti delle XP sono `floor`. **Dalla
riforma (M10, R2) le ricette di spade, spadoni, scudi, armature e attrezzi sono eliminate**; restano lingotti, piastre,
cibo e i componenti del Falegname (la piastra e il telaio sono nuovi o rinominati: gli id dei vecchi oggetti restano,
Q52). I pezzi si ottengono con i **progetti** (F-90, tabella sotto), dai drop e dal kit iniziale.

**Progetti** (uno per base; 8 basi × 8 gradi = 64; quantità di partenza, da tarare, Q53):
| Progetto di | Piastre Tn | Falegname Tn | Componente raro |
|---|---|---|---|
| Spada | 6 | 2 impugnature | 3 |
| Spadone | 10 | 2 impugnature | 3 |
| Scudo | 8 | 2 telai | 3 |
| Corpo | 10 | — | 3 |
| Gambe | 8 | — | 3 |
| Elmo | 6 | — | 3 |
| Mani / Piedi | 4 | — | 3 |
Il componente raro è un drop di un mostro dell'area del grado (un solo oggetto per grado, scelto nei dati: es. Nucleo di
golem); un'area di grado `g` (1, 3, 5, 7) lascia progetti di grado `g` e `g+1`, i gradi pari usano i componenti
rari dell'area precedente. Probabilità di drop dei progetti (Q49): circa 1 progetto/ora nell'area del proprio livello;
1 Pietra del Rift su 3 ne lascia uno. Archi e
bastoni arcani non sono nell'MVP (Q37): tornano con le loro classi.
Gli attrezzi non hanno ricette (F-94). I pezzi `equipment` prodotti da un progetto sono istanze dell'Armeria con rarità F-91 e affissi F-85 (`ilvl` = livello del grado).

### 8.3 Cibo (Cuoco)
| Grado | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 |
|---|---|---|---|---|---|---|---|---|
| `heal` | 20 | 35 | 55 | 80 | 110 | 150 | 200 | 260 |

### 8.4 Equipaggiamento: 15 gradi (M14, Y2-Y3, Q66, Q67, Q74, Q77; **F-118**)
Sostituisce la vecchia tabella a 8 gradi. Il **grado del pezzo** `g` (1…15, `equip.grade`) dà il **livello** `lvl(g)` = `equipment.grade_levels[g−1]` (1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90), che è il requisito `{"character": lvl}`
e l'`ilvl` degli affissi (F-85). Il **grado del materiale** `m(g)` (1…8) = `equipment.grade_material[g−1]` (1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8) decide lingotti e componenti di raffinazione (F-86), progetti (F-90) e smantellamento (F-95).
Slot e tipi: spada, spadone, scudo, elmo, corpo, gambe, piedi, mani, anello, collo (amuleto). **Valori di partenza** (generati nei dati da questa tabella, da tarare in M14-10):

| Pezzo | `kind` / stile | Valori base del modello di grado `g` | Intervallo |
|---|---|---|---|
| Spada | `sword`, `blade`, una mano (`weapon` o `offhand`) | `weapon.dmg_max = 6 + 4 (g−1)`, `dmg_min = round(0,6 × dmg_max)`, `accuracy_bonus 4g` | 2000 ms |
| Spadone | `greatsword`, `blade`, due mani | `dmg_max = 12 + 8 (g−1)`, `dmg_min = round(0,5 × dmg_max)`, `accuracy_bonus 5g` | 3200 ms |
| Elmo, Corpo, Gambe, Piedi, Mani | tre **materiali** (`equip.material`: `plate` Piastre, `leather` Cuoio, `cloth` Tessuto runico) | `armor`, `barrier`, `evasion_bonus` come sotto | — |
| Scudo (offhand) | `shield`, anch'esso in tre materiali | `armor`, `barrier`, `evasion_bonus` come sotto, `block_chance 5 + floor(10 × (g−1) / 14)` | — |
| Anello | — | `accuracy_bonus 3g` | — |
| Collo (amuleto) | — | `max_hp_flat 6g + 4` | — |
| Attrezzo unico (M10, R3) | — | invariato: `skill_interval_pct −(5 + 2N)`, scope `skill:<skill>`, N = raffinazione +0…+9 (F-94) | — |

**Armature** (budget per set): `A_set(g) = 4 + 8 × lvl(g)` (Armatura e Barriera, `equipment.set_budget.armor`) e `E_set(g) = round(2 + 1,5 × lvl(g))` (evasione, `set_budget.evasion`). Pesi degli slot `w` (`equipment.slot_weights`): corpo 0,30, gambe 0,20, elmo 0,15,
scudo 0,15, mani 0,10, piedi 0,10 (somma 1). Moltiplicatori del materiale (`combat.armor.materials`): Piastre {armor 1,0, barrier 0, evasion 0,2}, Cuoio {0,6, 0,4, 1,0}, Tessuto runico {0,3, 1,0, 0,4}.
`armor = round(A_set × w × m_armor)`, `barrier = round(A_set × w × m_barrier)`, `evasion_bonus = round(E_set × w × m_evasion)`; un valore 0 non si scrive nel modificatore.
Identità: **Piastre** = Armatura alta, niente Barriera; **Cuoio** = Armatura media, poca Barriera, molta Schivata; **Tessuto runico** = Armatura bassa, Barriera alta.
Esempi (grado 11, livello 50: `A_set` 404, `E_set` 77): corpo Piastre → armor 121, evasion 5; corpo Cuoio → armor 73, barrier 48, evasion 23; corpo Tessuto → armor 36, barrier 121, evasion 9; set Piastre completo con scudo → armor 121 + 81 + 61 + 61 + 40 + 40 = **404**.
Spada: grado 1 → 4-6, `accuracy_bonus 4`, danno al secondo 2,5; grado 8 → 20-34; grado 15 → 37-62, DPS 24,75. Spadone: grado 1 → 6-12, DPS 2,81; grado 15 → 62-124, DPS 29,06. Scudo: `block_chance` 5 (g1), 10 (g8), 15 (g15). Anello g15 → `accuracy_bonus 45`; collo g15 → `max_hp_flat 94`.
Un **Capolavoro** (F-119) e un **leggendario** (F-120) sono basi proprie con gli stessi valori del modello di grado/slot/materiale, moltiplicati a runtime per la loro rarità. Test: `tests/data/test_equipment_table.gd` (i dati veri coincidono con la tabella),
`tests/systems/items/test_equipment_values.gd`. Modificatori degli assetti (`data/classes/rift_blade.json`): solo `dual_swords` con `accuracy_pct −10` (Q39, provvisorio); gli altri nessuno.

### 8.5 Mostri
| Area | Id | L (att = pot = dif) | PV | Stile | Interv. ms | acc / pot / eva | DR | Oro | Frammento % | XP |
|---|---|---|---|---|---|---|---|---|---|---|
| Pianure di Roccarossa | `plains_boar` | 1 | 20 | blade | 2800 | 0 / 0 / 0 | 0 | 1-4 | 0,5 | 80 |
| | `ember_rat` | 4 | 32 | arcana | 2400 | 5 / 4 / 5 | 0 | 2-6 | 0,5 | 128 |
| | `redrock_raider` | 8 | 50 | marksmanship | 2600 | 10 / 8 / 8 | 2 | 4-10 | 0,75 | 200 |
| Bosco dei Sussurri | `whisper_wolf` | 16 | 81 | blade | 2600 | 20 / 15 / 18 | 4 | 6-13 | 1,0 | 324 |
| | `moss_troll` | 22 | 118 | arcana | 3000 | 25 / 22 / 30 | 8 | 9-18 | 1,0 | 472 |
| | `hollow_archer` | 30 | 155 | marksmanship | 2400 | 30 / 18 / 20 | 5 | 11-22 | 1,0 | 620 |
| Miniere Crepate | `crack_golem` | 38 | 198 | blade | 3200 | 45 / 35 / 50 | 12 | 16-31 | 1,5 | 633 |
| | `deep_crawler` | 46 | 248 | marksmanship | 2200 | 50 / 30 / 35 | 8 | 19-37 | 1,5 | 793 |
| | `vein_witch` | 55 | 322 | arcana | 2800 | 55 / 40 / 40 | 10 | 25-50 | 1,5 | 1030 |
| Soglia del Rift | `shard_wraith` | 65 | 287 | arcana | 2600 | 70 / 55 / 60 | 15 | 25-49 | 2,0 | 1148 |
| | `rift_knight` | 78 | 390 | blade | 2400 | 85 / 65 / 80 | 20 | 37-70 | 2,5 | 1560 |
| | `riftborn_colossus` | 92 | 533 | marksmanship | 3400 | 100 / 80 / 110 | 25 | 61-123 | 3,0 | 2132 |

**Ritaratura M14-10** (`tools/sim_combat.gd`): PV dei mostri del Bosco ×0,74, delle Miniere ×0,62, della Soglia ×0,41 (Pianure invariate: ancorano l'incontro di riferimento); `xp` = 4 × PV (3,2 × PV nelle Miniere) e oro in proporzione. Uccisioni all'ora con il set del grado giusto: Pianure 334, Bosco 245, Miniere 238, Soglia 250.
I drop di oggetti (pelli, ossa, materiali dell'area) li definisce il Data Designer: al massimo 8 voci per mostro,
probabilità tra 1% e 40%. Requisito di ogni area: `{"character": n}` con n = livello del primo mostro dell'area (1, 16, 38, 65).

**Gruppi** (`packs`, D5, Q38): ogni area ha 3-6 gruppi pesati di 1..`combat.max_pack_size` (6) mostri della stessa
area; dimensione massima per area: Pianure 2, Bosco 3, Miniere 4, Soglia 6. Almeno un gruppo per area è di un solo
mostro (il più debole). Esempio (Pianure): `[plains_boar]` peso 4, `[plains_boar, plains_boar]` peso 2,
`[ember_rat]` peso 3, `[ember_rat, plains_boar]` peso 2, `[redrock_raider]` peso 1. I numeri dei gruppi si
confermano con `tools/sim_combat.gd` (M5): un personaggio con il set forgiato del grado dell'area e il cibo del grado
deve avere 0 morti in 1 ora simulata nel gruppo più facile e tenere almeno 60 uccisioni/ora nell'area.

### 8.5b Tabelle di drop dell'Incisore e delle borse (M12, W6, Q58)
Pietre, valute e materia grezza **cadono dai mostri e dai Monoliti** (non si producono più da frammenti e materiali di raccolta).
Si definiscono in `data/combat/loot_tables.json` (`04_DATA_SCHEMA.md` §8b) e si attaccano alle aree (valgono per ogni mostro
dell'area), ai mostri e ai Monoliti, in aggiunta ai `drops` propri (che restano al massimo 8). Valori di partenza per **ogni
uccisione** (da tarare in M12-07 con `sim_combat`; i gradi alti delle pietre e i Cristalli sono più frequenti nelle aree alte):
| Voce | Pianure / Bosco / Miniere / Soglia | Quantità |
|---|---|---|
| Polvere del Rift (`rift_dust`) | **8%** (M14, Q71: era 20%) | **1** (era 1-2) |
| Scheggia (per ciascuna delle 4 famiglie) | 1% | 1 |
| Pietra (per ciascuna famiglia) | 0,05% (solo Bosco, Miniere, Soglia) | 1 |
| Cristallo del risveglio / mutamento / ascesa | 0,05% / 0,03% / 0,02% (solo Bosco, Miniere, Soglia) | 1 |
| Contratto (per ciascuno dei 3 mestieri) | Apprendista 0,02% nelle Pianure e nel Bosco; Garzone 0,015% (Bosco, Miniere); Esperto 0,01% (Miniere, Soglia); Maestro 0,005% (Soglia) | 1 |
| Borsa di cuoio | 0,05% (Pianure, Bosco) | 1 |
| Borsa del viandante | 0,02% (Miniere) | 1 |
**Monoliti** (tabella di ogni Monolito, che oggi lascia già frammenti e materiali): Polvere 100% (20-40); Scheggia di ogni famiglia
100% (2-4); Pietra di ogni famiglia 20%; Cristallo del risveglio 15%, del mutamento 10%, dell'ascesa 5%; Borsa runica 5% (solo
il Monolito della Soglia); un Contratto di grado pari al massimo dell'area con probabilità 2% per mestiere.
La borsa del bottino del combattimento (12 caselle + `loot_bag_slots`) non cambia: più tipi di oggetto in caduta la riempiono
prima (Q56): M12-07 verifica la perdita con `sim_combat` (`lost/h`).

### 8.6 Shop
| Id | Nome | Costo | Max | Requisiti | Effetto |
|---|---|---|---|---|---|
| ~~`bank_slot`~~ | ~~Spazio nel deposito~~ | **tolta in M12** (W2: sostituita dalle borse, §8.6b) | | | |
| `auto_eat_1` | Razioni da campo I | 2.000 (**già posseduta dall'inizio**, `start.purchases`, B2) | 1 | — | `auto_eat_tier +1` |
| ~~`armory_slot`~~ | ~~Spazio nell'armeria~~ | **tolta in M12** (W2) | | | |
| `auto_eat_2` | Razioni da campo II | 25.000 | 1 | `auto_eat_1`, personaggio 25 | `auto_eat_tier +1` |
| `auto_eat_3` | Razioni da campo III | 250.000 | 1 | `auto_eat_2`, personaggio 50 | `auto_eat_tier +1` |
| `auto_loot` | Raccolta automatica del bottino | 50.000 | 1 | — | `auto_loot +1` |
| `loot_pocket` | Tasca della borsa | 5.000 | 3 | — | `loot_bag_slots +4` |
| ~~`second_thought`~~ | ~~Secondo pensiero~~ | **tolta** (corsie parallele eliminate, W3) | | | |

### 8.6b Borse (M12, W2, Q58)
Oggetti `category: bag` (`bag.slots`, `04_DATA_SCHEMA.md` §5), da mettere negli slot borsa del Deposito (F-100).
| Id | Nome | Caselle | Fonte |
|---|---|---|---|
| `bag_canvas` | Borsa di tela | +6 | ricetta del Falegname (livello 1, comune) |
| `bag_leather` | Borsa di cuoio | +10 | drop delle Pianure di Roccarossa e del Bosco dei Sussurri (tabella d'area) |
| `bag_reinforced` | Borsa rinforzata | +14 | ricetta del Falegname (livello 45) che usa sottoprodotti della maestria (traguardo 25, §8.8b) |
| `bag_wayfarer` | Borsa del viandante | +18 | drop raro delle Miniere Abbandonate (tabella d'area) |
| `bag_runic` | Borsa runica | +24 | drop dei Monoliti del Rift (tabelle dei Monoliti) |
Gli id dei nuovi oggetti sono quelli della colonna; il Falegname produce le borse con ricette ordinarie (ingredienti e quantità
nei dati, valori di partenza da tarare in M12-07). Valore in oro 0 (non vendibili).

### 8.7 Altare, rune e Incisore (M8, riscritta in M12; mestiere `riftbinding` = **Incisore**)
Incavi dell'Altare sbloccati ai livelli dell'Incisore `rift.sockets`: 1, 20, 40, 60, 80 (invariato). Le **rune** hanno 5 gradi
(F-107, `rune.grade_mult`); id: grado I = id attuale (`inf_swift_hands`, …), gradi II-V = `<id>_2` … `<id>_5`.

**Azioni dell'Incisore** (`data/actions/riftbinding.json`, sostituiscono tutte le ricette precedenti; la skill ha maestria):
| Azione (id) | Livello | Ingredienti | Prodotto | XP | Intervallo ms |
|---|---|---|---|---|---|
| `make_rune_slab` (base) | 1 | 2 Minerale di rame (grado 1 del Minatore: la "pietra grezza" della fonte, nessun oggetto nuovo) + 1 `rift_shard` | 1 Lastra runica (`rune_slab`) | 6 | 3000 |
| `fuse_<famiglia>_stone` (×4) | 10 | 3 Schegge della famiglia (F-105) | 1 Pietra | 20 | 3000 |
| `fuse_<famiglia>_heart` (×4) | 40 | 3 Pietre della famiglia | 1 Pietra perfetta | 60 | 4000 |
| `crystallize_spark` | 5 | 10 Polvere del Rift (F-104) | 1 Cristallo del risveglio | 25 | 3000 |
| `crystallize_flux` | 25 | 25 Polvere del Rift | 1 Cristallo del mutamento | 80 | 4000 |
| `crystallize_crown` | 45 | 50 Polvere del Rift | 1 Cristallo dell'ascesa | 160 | 5000 |
| `engrave_<runa>` (×9) | livello della runa (sotto) | 1 Lastra runica + 3 drop tematici (sotto) | 1 runa di grado I | XP della runa (sotto) | intervallo della runa |
| `upgrade_<runa>_<g>` (×36, g = 2..5) | livello della runa I + 5 × (g−1), max 99 | 3 rune di grado g−1 (F-106) | 1 runa di grado g | XP della runa × g | intervallo della runa |
Le azioni `fuse_*`, `crystallize_*`, `engrave_*`, `upgrade_*` consumano **solo drop dei mostri** (o prodotti di altre azioni
dell'Incisore): per questo l'Incisore sale di livello consumando drop; la Lastra runica è l'unica azione "base". Valori di partenza
da tarare in M12-07. Le valute di sola uscita (`currency_*`) restano nei dati con l'effetto di prima (nomi nuovi, `NOMI.md`).

**Rune** (grado I; i modificatori sono quelli di prima, F-107 li scala):
| Livello | Runa (id) | Drop tematico (quantità per runa in `riftbinding.json`, ritarata il 2026-11-09) | Modificatori (global) | XP | Intervallo |
|---|---|---|---|---|---|
| 1 | `inf_swift_hands` | Zanna di cinghiale (Pianure) | `skill_interval_pct −3` | 40 | 4000 |
| 15 | `inf_bountiful` | Pelliccia di ratto (Pianure) | `double_item_chance +2` | 70 | 4000 |
| 25 | `inf_scholar` | Zanna di lupo (Bosco) | `skill_xp_pct +6` | 110 | 4500 |
| 35 | `inf_keen_edge` | Punta di freccia (Bosco) | `accuracy_pct +4` | 150 | 4500 |
| 45 | `inf_stoneskin` | Muschio di troll (Bosco) | `armor +10` (M14: era `damage_reduction +2`) | 200 | 5000 |
| 55 | `inf_deep_roots` | Nucleo di golem (Miniere) | `mastery_xp_pct +10` | 260 | 5000 |
| 65 | `inf_hearthfire` | Chitina di ragno (Miniere) | `food_healing_pct +10` | 330 | 5500 |
| 75 | `inf_riftsense` (unica) | Velo dello spettro (Soglia) | `rift_shard_chance +0.5` | 420 | 5500 |
| 85 | `inf_bulwark` | Placca del caduto (Soglia) | `max_hp_flat +60` | 520 | 6000 |
Nomi: "Runa della rapidità" … "Runa del baluardo" + grado in cifre romane ("Runa della rapidità III"). Togliere una runa
dall'incavo la distrugge (invariato).

### 8.8 Nodi della maestria (esempio completo: Selvicoltura)
| Id | Costo % del tetto | Prerequisiti | Modificatori (scope `skill:forestry`) |
|---|---|---|---|
| `forestry_n1_quick_axe` | 5 | — | `skill_interval_pct −3` |
| `forestry_n2_keen_eye` | 7,5 | n1 | `double_item_chance +3` |
| `forestry_n3_lore` | 7,5 | n1 | `skill_xp_pct +4` |
| `forestry_n4_rift_bark` | 10 | n2 | `rift_shard_chance +0.25` |
| `forestry_n5_patience` | 10 | n3 | `mastery_xp_pct +5` |
| `forestry_n6_master` | 20 | n4, n5 | `skill_interval_pct −5`, `double_item_chance +5` |
Totale 60% del tetto. Le altre skill con maestria seguono lo stesso schema (6 nodi, totale 55-65%). **Da M12 (W4, Q26 chiusa)**
gli alberi di Minatore e Pescatore **non** sono più copie di quello del Boscaiolo: vedi §8.8b (questa tabella resta
il Boscaiolo). Disposizione (`pos` = `[col, row]`) comune ai tre alberi: n1 `[1,0]`, n2 `[0,1]`, n3 `[2,1]`,
n4 `[0,2]`, n5 `[2,2]`, n6 `[1,3]`.

### 8.8b Alberi per mestiere e traguardi per risorsa (M12, W4, Q60)
**Alberi di nodi** (costi in % del tetto, prerequisiti e `pos` come §8.8; ogni albero totale 60%; scope `skill:<id>`; i nomi
dei nodi e i testi li scrive il Data Designer, a tema del mestiere). Id: `<skill>_n1_…` … `<skill>_n6_…`.
| Nodo | Boscaiolo (ritmo e velocità) | Minatore (quantità) | Pescatore (esperienza e Frammenti) | Costo % | Prerequisiti |
|---|---|---|---|---|---|
| n1 | `skill_interval_pct −3` | `double_item_chance +2` | `skill_xp_pct +3` | 5 | — |
| n2 | `double_item_chance +3` | `rift_shard_chance +0.25` | `skill_interval_pct −3` | 7,5 | n1 |
| n3 | `skill_xp_pct +4` | `mastery_xp_pct +4` | `rift_shard_chance +0.25` | 7,5 | n1 |
| n4 | `rift_shard_chance +0.25` | `double_item_chance +4` | `skill_xp_pct +5` | 10 | n2 |
| n5 | `mastery_xp_pct +5` | `skill_xp_pct +5` | `double_item_chance +3` | 10 | n3 |
| n6 | `skill_interval_pct −5`, `double_item_chance +5` | `double_item_chance +6`, `rift_shard_chance +0.25` | `skill_interval_pct −5`, `rift_shard_chance +0.5` | 20 | n4, n5 |
Il validatore (e `tests/data/test_data_validity.gd`) controlla: costo totale 55-65% per albero; **i tre alberi di raccolta non
sono identici** (l'insieme delle coppie stat-valore per nodo differisce almeno in 3 nodi su 6).

**Traguardi per risorsa** (F-103, F-108). Ogni azione di raccolta (8 per mestiere, T1-T8) ha `milestones` con 3 voci:
| Soglia | Tipo | Boscaiolo | Minatore | Pescatore |
|---|---|---|---|---|
| 25 | `byproduct` | 1 sottoprodotto per risorsa (oggetto `material` raro, nome a una parola, es. Betulla → Resina) | Rame → Pepita | Trota → Squama |
| 50 | `resource` (scope `action:<id>`) | `skill_interval_pct −8` | `double_item_chance +8` | `skill_xp_pct +10` |
| 99 | `trade` (scope `skill:<id>`, F-108) | `skill_interval_pct −0,5` | `double_item_chance +0,5` | `skill_xp_pct +0,5` |
Il sottoprodotto è un oggetto diverso per ogni risorsa (24 oggetti `material` in `data/items/materials.json`, valore 0 salvo
quelli per la Borsa rinforzata e i progetti, §8.6b, §8.2); la probabilità è `mastery.milestones.byproduct_chance_pct` (2,0)
uguale per tutte. Con tutte le 8 risorse al 99 il bonus del mestiere vale: Boscaiolo −4% intervallo, Minatore +4 doppio prodotto,
Pescatore +4% XP del mestiere. Test dei dati: ogni azione di raccolta ha esattamente 3 traguardi nell'ordine 25/50/99 e i tipi sopra.

### 8.9 Affissi (`data/affixes/affixes.json`, M4)
Gradi sbloccati a `min_ilvl` 1, 20, 45, 75 (livelli dei gradi T1, T3, T5, T7 di §8.1); intervalli `min..max` interi
salvo dove indicato. Lo slot è quello della base (`equip.slot`): una spada è `weapon` anche nell'offhand, quindi gli
affissi `offhand` escono solo sugli scudi. Gli id sono indicativi; nomi originali del Data Designer.
| Id | Stat | Slot | G1 | G2 | G3 | G4 | Peso |
|---|---|---|---|---|---|---|---|
| `keen` | `accuracy_bonus` | weapon, hands, ring | 2..4 | 5..8 | 9..14 | 15..22 | 10 |
| `heavy` | `power_bonus` | weapon, hands, ring | 2..3 | 4..6 | 7..10 | 11..16 | 10 |
| `precise` | `accuracy_pct` | weapon, neck | 1..2 | 3..4 | 5..6 | 7..9 | 6 |
| `brutal` | `power_pct` | weapon, neck | 1..2 | 3..4 | 5..6 | 7..9 | 6 |
| `swift` | `attack_interval_pct` | weapon, hands, feet | −2..−1 | −3..−2 | −4..−3 | −6..−4 | 4 |
| `nimble` | `evasion_bonus` | head, body, legs, feet, hands, offhand | 2..4 | 5..8 | 9..14 | 15..22 | 10 |
| `evasive` | `evasion_pct` | legs, feet | 1..2 | 3..4 | 5..6 | 7..9 | 6 |
| `warded` (M14: era `damage_reduction`) | `armor` | head, body, legs, feet, hands, offhand | 4..8 | 10..18 | 20..32 | 35..55 | 6 |
| `runeward` (M14, nuovo; nome di gioco in `NOMI.md`) | `barrier` | head, body, legs, feet, hands, offhand | 4..8 | 10..18 | 20..32 | 35..55 | 4 |
| `hale` | `max_hp_flat` | head, body, legs, feet, neck, ring, offhand | 5..10 | 11..20 | 21..35 | 36..55 | 10 |
| `hearty` | `food_healing_pct` | head, body, neck | 2..4 | 5..8 | 9..12 | 13..18 | 4 |
| `bulwark` | `block_chance` | offhand | 1..2 | 2..3 | 3..4 | 4..5 | 4 |
| `prosperous` | `gold_drop_pct` | neck, ring | 2..4 | 5..8 | 9..12 | 13..18 | 4 |
| `fortunate` | `item_rarity_pct` | neck, ring | 2..4 | 5..8 | 9..12 | 13..18 | 3 |
| `hasty` | `skill_interval_pct` | tool_* | −2..−1 | −3..−2 | −4..−3 | −5..−4 | 10 |
| `bountiful` | `double_item_chance` | tool_* | 1..2 | 2..3 | 3..4 | 4..6 | 8 |
| `learned` | `skill_xp_pct` | tool_* | 1..2 | 2..3 | 3..5 | 5..7 | 8 |
| `devoted` | `mastery_xp_pct` | tool_* | 1..2 | 2..4 | 4..6 | 6..8 | 6 |
| `riftsense` | `rift_shard_chance` | tool_* | 0,05..0,10 | 0,10..0,15 | 0,15..0,25 | 0,25..0,35 | 4 |
`riftsense` ha `step` 0,05. `tool_*` = i tre slot degli attrezzi, con scope `skill:<skill dello slot>` (Q32).
Ogni slot ha almeno 4 affissi ammessi (un raro ne chiede fino a 4). Controllo: spada T3 rara con 4 affissi di grado 2
→ al massimo `accuracy_bonus` +8, `power_bonus` +6, `accuracy_pct` +4, `power_pct` +4 oltre ai valori base.

## 9. Valori di `balance.json` (specifica iniziale completa)

| Chiave | Valore | Usata da |
|---|---|---|
| `tick_ms` | 100 | GameClock |
| `max_catchup_ms` | 5000 | GameClock |
| `autosave_interval_ms` | 10000 | Game |
| `slots.count` | 4 | SaveStore, menu |
| `player_name.{min_length, max_length}` | 1, 24 | Game.new_game, SlotTexts (`01_GDD.md` §1) |
| `start.gold` | 50 | GameSession.new_game |
| `start.items` | `[{"item": "seared_brookfin", "qty": 20}]` (20 pesci cotti di grado 1, Q51; l'id è quello del cibo T1 dei dati, nome "Trota alla griglia") | GameSession.new_game |
| `start.armory` (M10) | `[{"base": spada T1, "equip": "weapon"}, {"base": spadone T1, "equip": ""}, {"base": scudo T1, "equip": "offhand"}]` (comuni, grado 1; `equip` = slot in cui indossarlo, `""` = resta nell'Armeria; da confermare, Q51) | GameSession.new_game, `01_GDD.md` §1.1 |
| `start.tools` (M10) | `[{"base": accetta}, {"base": piccone}, {"base": canna}]` (a +0, indossati nello slot del mestiere) | GameSession.new_game |
| `start.purchases` (M10) | `{"auto_eat_1": 1}` (B2, Q12) | GameSession.new_game, Shop |
| `start.food` (M10) | id del cibo scelto all'inizio (il pesce cotto T1 di `start.items`) | GameSession.new_game |
| `xp_curve.{base, growth, linear, max_level, xp_cap}` | 70, 1.1, 8, 99, 50000000 | F-01 |
| `mastery_curve.{base, growth, linear, max_level}` | 20, 1.1, 4, 99 | F-09 |
| `mastery.{base_factor, per_level, ratio_weight, pool_share_pct, pool_cap_per_item}` | 1.0, 0.1, 3.0, 20, 300000 | F-10..F-13 |
| `mastery.pool_warning_pct` | 95 | MasteryPanel: avviso del pool quasi pieno (`01_GDD.md` §6.2); > 0 e ≤ 100 |
| `action.min_interval_ms` | 250 | F-03 |
| `gathering.rift_shard_base_chance_pct` | 0.5 | F-07 |
| ~~`bank.*`~~ | tolta in M12 | era F-16, F-17 (sostituite da F-100) |
| `deposit.{base_slots, bag_slots}` (M12) | 60, 6 | F-100 (Q58) |
| `helper.{xp_pct, mastery_pct}` (M12) | 25, 25 | F-102 (Q59) |
| `helper.grades` (M12) | `[{"id":"apprentice","interval_mult":3.0},{"id":"journeyman","interval_mult":2.5},{"id":"expert","interval_mult":2.0},{"id":"master","interval_mult":1.5}]` (in ordine di grado) | F-101 (Q59) |
| `mastery.milestones.{byproduct_at, resource_at, trade_at, byproduct_chance_pct}` (M12) | 25, 50, 99, 2.0 | F-103, F-108 (Q60) |
| `engraver.{crystal_chance_min_pct, crystal_chance_max_pct, crystal_fail_loss_pct, merge_ratio}` (M12) | 40, 90, 50, 3 | F-104, F-105 (Q61) |
| `rune.{upgrade_ratio, grade_mult}` (M12) | 3, `[1, 2, 3, 4, 5]` | F-106, F-107 |
| `combat.{acc_level_offset, acc_bonus_offset}` | 8, 50 | F-20, F-21 |
| `combat.{maxhit_level_offset, maxhit_bonus_offset, min_hit_ratio}` | 10, 40, 0.1 | F-22 |
| `combat.{hit_chance_min, hit_chance_max}` | 0.05, 0.95 | F-23 |
| `combat.triangle.{advantage_damage_mult, disadvantage_damage_mult, defender_dr_mult}` | 1.15, 0.85, 0.75 | F-24 |
| `combat.triangle.beats` | `{"blade":"arcana","arcana":"marksmanship","marksmanship":"blade"}` | F-24 |
| `combat.min_attack_interval_ms` | 800 | F-26 |
| `combat.unarmed` | `{"style":"blade","attack_interval_ms":2400,"dmg_min":0,"dmg_max":0}` (M14: senza arma il danno è solo F-22 con `min_hit_ratio`) | F-22, F-26, F-72 |
| `combat.{hp_base, hp_per_level}` | 50, 10 | F-27 (sostituisce `hp_per_vitality`) |
| `combat.dual_wield.interval_mult` | 0.75 | F-73 (Q39) |
| `combat.max_pack_size` | 6 | `01_GDD.md` §10.1, §8.5 (Q38) |
| `combat.auto_eat_tiers` | `[null, {30,60}, {40,75}, {50,90}]` | F-30 |
| `combat.{respawn_ms, loot_bag_base_slots}` | 1500, 12 | 10.1 (attesa `BETWEEN`), F-33 |
| `character_curve.{base, growth, linear, max_level, xp_cap}` | 70, 1.1, 8, 99, 50000000 | F-71 (Q34) |
| `character.start_class` | `"rift_blade"` | GameSession.new_game (`01_GDD.md` §19) |
| ~~`armory.*`~~ | tolta in M12 | era F-82 (sostituita da F-100) |
| ~~`rarity.craft.*`~~ | tolta in M10 | era F-83 (sostituita da F-91) |
| `blueprint.{duration_base_min, duration_per_grade_min, xp_mult, rare_base_pct, rare_per_forging_level, choose_affix_level, chosen_affix_tier}` (M10) | 10, 7, 1.5, 10, 0.5, 50, 2 | F-90, F-91, F-92 (Q48, Q50; il resto da tarare, Q53) |
| `tool_upgrade.{interval_base_pct, interval_per_level_pct, levels, plate_items, handle_items}` (M10) | 5, 2, tabella F-94 (9 voci `{min_level, grade, plates, handles, gold}`), 8 id delle piastre T1-T8, 8 id dei manici T1-T8 | F-94 |
| `combat.kill_xp_mult` (M10, M14-10) | 0.064 (tarato in M14-10, era 0.11; Q54) | F-28 |
| `rarity.affix_count.{magic, rare}` | `[1, 2]`, `[3, 4]` | F-85 |
| `traits.slot_levels` (M6) | `[1, 10, 25, 50]` | F-78 (Q35) |
| `abilities.slot_levels` (M6) | `[1, 1, 30]` | F-78 (Q36) |
| `rarity.drop.{magic_pct, rare_pct}`, `rarity.rift_stone.{magic_pct, rare_pct}` (M7; M14: drop 25, 5) | 25, 5; 40, 12 | F-84, F-121 |
| `upgrade.{levels, downgrade_from, mod_pct_per_level, seal_item, ingot_items}` (M7) | tabella F-86, 4, 10, id del Sigillo, 8 id dei lingotti T1-T8 | F-86 |
| `rift_stone.{chance_pct, pity_kills}` (M7) | 0.5, 300 | F-87; `chance_pct` è il default delle aree senza `rift_stone_chance_pct` (Q46) |
| `salvage.{component_ratio, shards_by_rarity}` (M7; M10: `ingot_ratio` rinominata `component_ratio`) | 0.4, `{"common":0,"magic":1,"rare":3}` | F-95 |
| `sockets.{by_rarity, bonus_at_upgrade}` (M8; M14: + masterwork, legendary) | `{"common":0,"magic":1,"rare":2,"masterwork":2,"legendary":2}`, 7 | F-89 |
| `rift.sockets` (già presente, usata in M8) | `[{"level":1},{"level":20},{"level":40},{"level":60},{"level":80}]` | 11 |
| `offline.{cap_ms, min_ms, chunk_ms}` | 43200000, 60000, 60000 | F-40, F-41 |
| `fracture.{groups, intensity_steps, pulse_ms, mod_count, card_rarity, card_drop, salvage, grades}` (M13, R-04; sostituisce `fractures.*`) | 16, 10, 4000, `{"common":[0,0],"magic":[1,2],"rare":[3,4]}`, `{"magic_pct":25,"rare_pct":6}`, `{"monster_pct":0.5,"boss_pct":70,"monster_delta":[70,27,3],"boss_delta":[20,70,10]}`, `{"dust_per_grade":5,"rarity_mult":{"common":1,"magic":1.5,"rare":2}}`, tabella F-110 (10 righe) | F-50, F-109…F-116 |
| `combat.armor.{k, level_offset, cap_pct, materials}` (M14, Y2, Q67, Q74) | 6, 10, 75, `{"plate":{"armor":1.0,"barrier":0,"evasion":0.2},"leather":{"armor":0.6,"barrier":0.4,"evasion":1.0},"cloth":{"armor":0.3,"barrier":1.0,"evasion":0.4}}` | F-117, F-118 |
| `equipment.{grade_levels, grade_material, slot_weights, set_budget}` (M14, Q66) | 15 livelli (1…90), mappa pezzo → materiale (1,1,2,2,3,3,4,4,5,5,6,6,7,7,8), pesi degli slot (corpo 0,30, gambe 0,20, elmo 0,15, scudo 0,15, mani 0,10, piedi 0,10), `{"armor":[4,8],"evasion":[2,1.5]}` (base, per livello) | F-118 |
| `rarity.masterwork.{base_mult, affix_count}` (M14, Y4) | 1.25, `[1, 2]` | F-119, F-91 |
| `rarity.legendary.base_mult` (M14, Y5) | 1.4 | F-120 |
| `blueprint.{cost_mult, extra_rare}` (M14, Q68) | 3, 2 componenti rari diversi | F-90, F-119 |
| `loot.equipment.{chance_pct, level_ahead, level_window, kind_weights}`, `loot.blueprint.chance_pct` (M14, Y6, Q69) | 2.9, 5, 15, 1 per ciascuno dei 10 tipi di pezzo; 0.4 | F-121 |
| `mastery.step.{every_levels, gathering, crafting}` (M14, Y8, Q70) | 10, `[{"stat":"skill_interval_pct","value":-2},{"stat":"double_item_chance","value":1}]`, `[{"stat":"preservation_chance","value":2},{"stat":"skill_interval_pct","value":-2}]` | F-122 |
| `fracture.{risk_cap, risk_unit}` (M14, Q72) | `{"base":40,"per_grade":10}`, `{"pack_bonus":20,"pulse":5}` | F-123 |
| `metin.{hp_base, hp_per_level, pulse_damage, wave_size, wave_thresholds, rarity_bonus_pct, guaranteed_pieces}` (M15, Z3-Z4) | 200, 0,25, 1, 7, `[75, 50, 25]`, 100, 1 | F-125…F-127 (Q78) |
| `combat.crowd_threshold` (M15, Z6) | 8 | `01_GDD.md` §10.13 (solo UI) |
| `combat.skip_stone_level` (M15, Z7) | 0 | F-128: **valore iniziale** del nuovo slot; il valore in uso è stato dello slot |
| `rift_stone_chance_pct` Pianure (M15, Z5) | 0 → 0,6 (dati dell'area) | F-87 (Q82) |
| `upgrade.levels[].dust` (M14, Q71) | 0,0,0,0,10,20,30,40,50 | F-86 |
| ~~`parallel.*`~~ | tolta | era F-51 (corsie eliminate) |

Chiavi tolte con la riforma (M4-01, D3): `combat.hp_per_vitality`, `combat.hp_skill`, `combat.defence_skill`,
`combat.xp_per_damage_style`, `combat.xp_per_damage_vitality`. Le chiavi segnate (M6)…(M13) le aggiunge il task che
le usa, insieme alla regola del validatore.

I limiti delle stat (es. `preservation_chance` max 80, `skill_interval_pct` min −80) stanno
**solo** in `stats.json` (§11), non in `balance.json`.

## 10. Numeri della UI non di gioco
Durate di animazioni, dimensioni della finestra, toast (4 visibili, 1 s di raggruppamento, 2 s di banner) sono costanti
di presentazione: stanno in `res://ui/theme/ui_style.gd` (unica definizione), non in `balance.json`.

## 11. Registro delle stat (`stats.json`)

Ogni stat: effetto, limiti del **totale**, formula, test che ne verifica l'effetto. Nessuna stat senza riga qui.
Nel campo `formula` di `stats.json` va l'id `F-xx` oppure, se la regola è in una sezione del GDD, il solo numero di
sezione (`auto_loot`: `"10.6"` = `01_GDD §10.6`; `04_DATA_SCHEMA.md` §2). Con più formule nella tabella (es.
`skill_xp_pct`, `item_rarity_pct`) il campo ha la prima, quella del test indicato.

| Stat | Min | Max | Effetto | Formula | Test dell'effetto |
|---|---|---|---|---|---|
| `skill_interval_pct` | −80 | 100 | riduce/aumenta l'intervallo delle azioni | F-03 | `tests/systems/actions/test_action_math.gd::test_interval_uses_skill_interval_pct` |
| `skill_xp_pct` | 0 | 1000 | aumenta l'XP delle skill e (solo `global`) del personaggio | F-02, F-71 | `tests/systems/skills/test_skills_system.gd::test_add_xp_applies_skill_xp_pct` |
| `mastery_xp_pct` | 0 | 1000 | aumenta la maestria | F-10 | `tests/systems/mastery/test_mastery_math.gd::test_mastery_xp_pct` |
| `double_item_chance` | 0 | 100 | probabilità di prodotto doppio | F-06 | `tests/systems/actions/test_gathering_resolver.gd::test_double_item_chance_100` |
| `preservation_chance` | 0 | 80 | probabilità di non consumare ingredienti | F-08 | `tests/systems/actions/test_artisan_resolver.gd::test_preservation_cap` |
| `rift_shard_chance` | 0 | 100 | aumenta la probabilità di frammento | F-07 | `tests/systems/actions/test_gathering_resolver.gd::test_rift_shard_chance` |
| `accuracy_bonus` | −1000 | 100000 | precisione piatta | F-20 | `tests/data/test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats` |
| `accuracy_pct` | −90 | 1000 | precisione percentuale | F-20 | `tests/data/test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats` |
| `power_bonus` | −1000 | 100000 | danno massimo piatto | F-22 | `tests/data/test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats` |
| `power_pct` | −90 | 1000 | danno massimo percentuale | F-22 | `tests/data/test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats` |
| `evasion_bonus` | −1000 | 100000 | evasione piatta | F-21 | `tests/data/test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats` |
| `evasion_pct` | −90 | 1000 | evasione percentuale | F-21 | `tests/data/test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats` |
| `armor` (M14; **sostituisce `damage_reduction`**, Y2) | 0 | 100000 | Armatura: riduce in % (rendimenti decrescenti, massimo `combat.armor.cap_pct`) il danno **fisico** (mostri `blade` e `marksmanship`) | F-25, F-117 | `tests/data/test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats` |
| `barrier` (M14, Y2) | 0 | 100000 | Barriera: come l'Armatura ma sul danno **arcano** (mostri `arcana`) | F-25, F-117 | `tests/data/test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats` |
| `attack_interval_pct` | −90 | 200 | velocità d'attacco | F-26 | `tests/data/test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats` |
| `max_hp_flat` | 0 | 100000 | PV massimi piatti | F-27 | `tests/data/test_stat_registry_coverage.gd::test_combat_stat_effects_through_player_stats` |
| `food_healing_pct` | 0 | 500 | cura del cibo | F-29 | `tests/systems/combat/test_auto_eat.gd::test_food_healing_pct` |
| `gold_drop_pct` | 0 | 1000 | oro dai mostri | F-31 | `tests/systems/combat/test_combat_engine.gd::test_gold_drop_pct` |
| `loot_bag_slots` | 0 | 100 | caselle della borsa | F-33 | `tests/systems/combat/test_loot_bag.gd::test_capacity_uses_loot_bag_slots` |
| `auto_loot` | 0 | 1 | bottino direttamente nella bank | 01_GDD §10.6 | `tests/systems/combat/test_loot_bag.gd::test_auto_loot_to_bank` |
| `auto_eat_tier` | 0 | 3 | livello delle razioni da campo | F-30 | `tests/systems/combat/test_auto_eat.gd::test_tier_thresholds` |
| `item_rarity_pct` (M4) | 0 | 1000 | probabilità di pezzi magici e rari | F-84, F-91 (M10: `formula` di `stats.json` passa da F-83 a F-84) | `tests/systems/items/test_item_roller.gd::test_item_rarity_pct` |
| `block_chance` (M5) | 0 | 50 | probabilità di parare un colpo con lo scudo (Q40) | F-75 | `tests/systems/combat/test_combat_engine.gd::test_block_chance` |
| `upgrade_success_pct` (M7) | 0 | 300 | probabilità di riuscita della raffinazione | F-86, F-93 (M10: sorgente `skill_level:forging`) | `tests/systems/armory/test_upgrade.gd::test_upgrade_success_pct` |

Stat **tolta in M13 (R-04)**: `fracture_duration_pct` (le Fratture non hanno più durata). Stat **tolte in M12** (nessuna stat decorativa: la capienza viene dalle borse, F-100; le corsie non esistono): `bank_slots`, `armory_slots`, `parallel_lanes`.
Nessuna stat nuova in M12: aiutanti, traguardi e Incisore usano stat esistenti (`skill_interval_pct`, `double_item_chance`, `skill_xp_pct`, `rift_shard_chance`, `mastery_xp_pct`).
