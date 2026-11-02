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
Esempio: modificatori `skill_interval_pct`: global −3, skill:forestry −5, action:cut_ashoak −2, skill:quarrying −10;
nel contesto (forestry, cut_ashoak) → −10; nel contesto (forestry, cut_redbirch) → −8; somma −95 → limitata a −80.
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

### F-11 Bonus della maestria per oggetto
Per ogni regola in `skill.mastery_bonuses`: `every_levels: k` → valore × `floor(L/k)`; `at_level: n` → valore se `L ≥ n`.
Scope dei modificatori: `action:<id>`. Regole iniziali:
- raccolta: `every_levels 10 → double_item_chance +1`; `at_level 99 → double_item_chance +5`;
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
Test: `test_mastery_system.gd`.

## 4. Bank, oro, shop

### F-16 Capienza della bank
`capacity = bank.base_slots + floor(T(bank_slots, global))`; `bank.base_slots = 24`.
Esempio: 3 caselle comprate → 27. Test: `tests/systems/bank/test_bank.gd`.

### F-17 Prezzo della prossima casella
`n` = caselle già comprate. `price(n) = min(bank.slot_cost_cap, floor(bank.slot_cost_base × bank.slot_cost_growth^n))`
Parametri: `slot_cost_base = 400`, `slot_cost_growth = 1.09`, `slot_cost_cap = 2000000`, `max_purchasable = 150`.
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

Le stesse formule valgono per giocatore e mostro. Per il giocatore: `L_style` = livello della skill dello stile
dell'arma, `L_def` = Guardia; bonus = `T(stat, global)` (equipaggiamento + altre sorgenti). Per il mostro: livelli e
bonus dai dati (`attack_level`, `power_level`, `defence_level`, `accuracy_bonus`, `power_bonus`, `evasion_bonus`,
`damage_reduction`), senza modificatori.

### F-20 Precisione (Accuracy Rating)
`AR = floor((L_style + combat.acc_level_offset) × (accuracy_bonus + combat.acc_bonus_offset) × (1 + accuracy_pct/100))`
Parametri: `acc_level_offset = 8`, `acc_bonus_offset = 50`.
Esempi: (1, 0, 0) → **450**; (10, 20, 0) → **1.260**; (10, 20, 10) → **1.386**; (50, 60, 0) → **6.380**; (99, 150, 0) → **21.400**.
Test: `tests/systems/combat/test_combat_math.gd`.

### F-21 Evasione (Evasion Rating)
`ER = floor((L_def + acc_level_offset) × (evasion_bonus + acc_bonus_offset) × (1 + evasion_pct/100))`
Esempi: (1, 0, 0) → 450; (16, 18, 0) → 1.632; (24, 30, 0) → 2.560. Test: `test_combat_math.gd`.

### F-22 Danno massimo, minimo e tiro
`max_hit = floor((L_style + combat.maxhit_level_offset) × (power_bonus + combat.maxhit_bonus_offset) / maxhit_bonus_offset × (1 + power_pct/100))`
`min_hit = max(1, floor(max_hit × combat.min_hit_ratio))`; tiro = intero uniforme in `[min_hit, max_hit]`.
Parametri: `maxhit_level_offset = 10`, `maxhit_bonus_offset = 40`, `min_hit_ratio = 0.1`.
Esempi: (1, 0, 0) → max 11, min 1; (10, 20, 0) → 30 / 3; (50, 60, 0) → 150 / 15; (99, 150, 0) → 517 / 51;
(10, 20, 10) → floor(33,0) = 33 / 3. Test: `test_combat_math.gd`.

### F-23 Probabilità di colpire
`hit = clamp(AR / (AR + ER), combat.hit_chance_min, combat.hit_chance_max)`; `min = 0.05`, `max = 0.95`.
Esempi: 450 vs 450 → 0,50; 1.080 vs 450 → 0,7059; 450 vs 1.800 → 0,20; 100 vs 10.000 → 0,05; 10.000 vs 100 → 0,95.
Test: `test_combat_math.gd`.

### F-24 Triangolo
Relazione dal punto di vista dell'attaccante: `blade` batte `arcana`, `arcana` batte `marksmanship`,
`marksmanship` batte `blade`; stesso stile = neutro.
- vantaggio: danno × `triangle.advantage_damage_mult` (1,15) e riduzione del difensore × `triangle.defender_dr_mult` (0,75);
- svantaggio: danno × `triangle.disadvantage_damage_mult` (0,85);
- neutro: nessun cambio.
Il danno moltiplicato si tronca (`floor`) prima della riduzione. Esempi: `triangle(blade, arcana) = advantage`;
`triangle(blade, marksmanship) = disadvantage`; `triangle(arcana, arcana) = neutral`. Test: `test_combat_math.gd`.

### F-25 Riduzione del danno
`dr_eff = T(damage_reduction) (0..80 da stats.json) × (0,75 se il difensore è in svantaggio)`
`danno = max(1, floor(danno_dopo_triangolo × (1 − dr_eff/100)))`
Esempi: 20, DR 25 → **15**; 3, DR 80 → **1**; tiro 20, attaccante in vantaggio, DR del difensore 10 →
floor(20×1,15) = 23 → dr_eff 7,5 → floor(23 × 0,925) = **21**; tiro 20, svantaggio, DR 10 → floor(17) = 17 → floor(15,3) = **15**.
Test: `test_combat_math.gd`.

### F-26 Intervallo d'attacco
`interval = max(combat.min_attack_interval_ms, round(base_ms × (1 + T(attack_interval_pct)/100)))`; min 800 ms.
`base_ms` = `weapon.attack_interval_ms` o `combat.unarmed.attack_interval_ms` (2400). Mostro: `attack_interval_ms` dei dati.
Esempi: 2400, −10 → 2160; 1000, −50 → 500 → **800**. Test: `test_combat_math.gd`.

### F-27 Punti vita massimi
`max_hp = combat.hp_base + combat.hp_per_vitality × L_vitality + floor(T(max_hp_flat))`; `hp_base = 50`, `hp_per_vitality = 10`.
Esempi: Vitalità 1 → 60; Vitalità 10 e +20 → 170; Vitalità 99 → 1.040. Test: `test_combat_math.gd`.

### F-28 Esperienza di combattimento
`d` = danno effettivo, limitato ai PV rimasti del mostro. Valori base (poi F-02 per ogni skill):
- `offensive`: stile `combat.xp_per_damage_style × d` (4);
- `balanced`: stile `2 × d`, Guardia `2 × d` (metà di 4 ciascuno, `floor`);
- `defensive`: Guardia `4 × d`;
- sempre: Vitalità `combat.xp_per_damage_vitality × d` (1).
Esempi: d 15 `offensive` con Lama → Lama 60, Vitalità 15; d 15 `balanced` → Lama 30, Guardia 30, Vitalità 15; mostro con
6 PV e tiro 15 → d = 6 → Lama 24, Vitalità 6. Test: `test_combat_math.gd`.

### F-29 Cura del cibo
`heal = floor(food.heal × (1 + T(food_healing_pct)/100))`; `hp = min(max_hp, hp + heal)`.
Esempi: 30 e +20% → 36; 20 e 0 → 20. Test: `tests/systems/combat/test_auto_eat.gd`.

### F-30 Razioni da campo
`tier = clamp(floor(T(auto_eat_tier)), 0, 3)`; soglie in `combat.auto_eat_tiers[tier] = {threshold_pct, target_pct}`:
livello 1 = 30/60, 2 = 40/75, 3 = 50/90 (livello 0 = spento).
Dopo un colpo subito: se `hp ≤ floor(max_hp × threshold/100)`, ripete "mangia 1 pezzo" finché
`hp ≥ ceil(max_hp × target/100)` o il cibo finisce.
Esempio: max 170, livello 1 (soglia 51, obiettivo 102), cibo 36: hp 45 → 81 → 117 → si ferma (**2 pezzi**). Con hp 52: non mangia.
Test: `test_auto_eat.gd`.

### F-31 Oro dei mostri
`gold = floor(randi_range(gold_min, gold_max) × (1 + T(gold_drop_pct)/100))`. Esempio: tiro 10, +25% → 12.
Test: `test_combat_engine.gd`.

### F-32 Drop
Ogni voce `{item, chance_pct, qty_min, qty_max}` tira in modo indipendente `roll_pct(chance_pct)`; quantità uniforme.
Esempio: chance 100, qty 2-2 → sempre 2; chance 0 → mai. Test: `test_combat_engine.gd`.

### F-33 Capienza della borsa del bottino
`capacity = combat.loot_bag_base_slots (12) + floor(T(loot_bag_slots))`. Esempio: 2 tasche → 20. Test: `tests/systems/combat/test_loot_bag.gd`.

### F-34 Duello di riferimento (test di integrazione)
Giocatore: Lama 1, Guardia 1, Vitalità 1, a mani nude (AR 450, max 11, 2400 ms, 60 PV). Mostro `plains_boar`
(tabella 10.3: L 1, 20 PV, 0 bonus, 2800 ms, max 11). Probabilità di colpire per entrambi 0,5.
Danno medio per attacco del giocatore 3 → in 1.000 duelli simulati (seme fisso, senza respawn) il tempo medio per
uccisione deve stare tra **15 e 21 s** (simulazione di controllo in fase di design: 18,0 s). Test: `tests/integration/test_reference_duel.gd`.

## 6. Offline

### F-40 Tempo offline
`elapsed = clamp(now_unix_ms − saved_at_unix_ms, 0, offline_cap_ms)`; `offline_cap_ms = 43200000` (12 h),
`capped = (now − saved) > offline_cap_ms`.
Esempi: 5 h → 18.000.000, capped false; 20 h → 43.200.000, capped true; orologio indietro → 0. Con
`elapsed < offline_min_ms (60000)` nessuna schermata. Test: `tests/core/offline/test_offline_simulator.gd`.

### F-41 Blocchi della simulazione
`chunks = ceil(elapsed / offline_chunk_ms)`, `offline_chunk_ms = 60000`. Esempio: 12 h → 720 blocchi; 90 s → 2 (60 s + 30 s).
Equivalenza: simulare 600.000 ms in un blocco o in 10 blocchi dà lo stesso stato con lo stesso seme. Test: idem.

## 7. Fratture (M7) e corsie (M8)

### F-50 Fratture
Prossima apertura: `randi_range(fractures.interval_min_ms, fractures.interval_max_ms)` = 7.200.000-14.400.000 ms.
Durata: `round(fractures.duration_ms × (1 + T(fracture_duration_pct)/100))`; `duration_ms = 1800000`.
Esempio: +20% → 2.160.000. Test: `tests/systems/fractures/test_fracture_system.gd`.

### F-51 Penalità della corsia secondaria
`interval_secondary = round(F-03 × (1 + parallel.interval_penalty_pct/100))`; `interval_penalty_pct = 40`.
Esempio: 3000 → 4200. Corsie disponibili = `1 + clamp(floor(T(parallel_lanes)), 0, 1)`. Test: `test_action_runner.gd`.

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
| Forgiatura | Lingotto Tn | 2 × minerale Tn | 2000 | `floor(0,8 × XP raccolta Tn)` (8, 14, 22, 32, 46, 64, 86, 116) | 3 × valore minerale |
| Forgiatura | Arma a lama Tn | 3 × lingotto Tn | 3000 | `3 × XP lingotto × 1,2` | 12 × valore minerale |
| Forgiatura | Corpetto Tn / Gambali Tn / Elmo Tn / Stivali Tn / Guanti Tn / Scudo Tn | 5 / 4 / 3 / 2 / 2 / 4 lingotti | 3000 | `lingotti × XP lingotto × 1,2` | `lingotti × 4 ×` valore minerale |
| Forgiatura | Attrezzo Tn (ascia, piccone, canna) | 2 × lingotto Tn + 1 × legno Tn | 3000 | `2 × XP lingotto × 1,3` | 10 × valore minerale |
| Focolare | Pesce cotto Tn | 1 × pesce Tn | 2500 | `floor(0,9 × XP pesca Tn)` | 2 × valore pesce |
| Intaglio | Arco Tn / Bastone arcano Tn | 3 × legno Tn | 2400 | `3 × XP legno × 1,1` | 10 × valore legno |
| Intaglio | Impugnatura Tn (oggetto intermedio, opzionale) | 1 × legno Tn | 1600 | `XP legno × 0,8` | 2 × valore legno |
Livello richiesto della ricetta Tn = livello del grado Tn (8.1). Gli arrotondamenti delle XP sono `floor`.

### 8.3 Cibo (Focolare)
| Grado | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 |
|---|---|---|---|---|---|---|---|---|
| `heal` | 20 | 35 | 55 | 80 | 110 | 150 | 200 | 260 |

### 8.4 Equipaggiamento (grado n = 1..8)
| Pezzo | Stile | Modificatori | Intervallo | Requisito |
|---|---|---|---|---|
| Arma a lama | `blade`, una mano | `accuracy_bonus 8n`, `power_bonus 6n` | 2400 | Lama ≥ livello Tn |
| Arco | `marksmanship`, due mani | `accuracy_bonus 10n`, `power_bonus 7n` | 2800 | Mira ≥ livello Tn |
| Bastone arcano | `arcana`, due mani | `accuracy_bonus 9n`, `power_bonus 8n` | 3000 | Arcano ≥ livello Tn |
| Corpetto | — | `evasion_bonus 6n`, `damage_reduction n` | — | Guardia ≥ livello Tn |
| Gambali | — | `evasion_bonus 4n`, `damage_reduction ceil(n/2)` | — | Guardia |
| Elmo | — | `evasion_bonus 3n`, `damage_reduction ceil(n/2)` | — | Guardia |
| Stivali / Guanti | — | `evasion_bonus 2n` | — | Guardia |
| Scudo (offhand) | — | `evasion_bonus 4n`, `damage_reduction n` | — | Guardia |
| Attrezzo | — | `skill_interval_pct −(3 + 2n)` con scope `skill:<skill>` | — | skill dell'attrezzo ≥ livello Tn |
Esempio: set completo T8 con scudo → `damage_reduction` 8 + 4 + 4 + 8 = 24.

### 8.5 Mostri
| Area | Id | L (att = pot = dif) | PV | Stile | Interv. ms | acc / pot / eva | DR | Oro | Frammento % |
|---|---|---|---|---|---|---|---|---|---|
| Pianure di Roccarossa | `plains_boar` | 1 | 20 | blade | 2800 | 0 / 0 / 0 | 0 | 1-4 | 0,5 |
| | `ember_rat` | 4 | 32 | arcana | 2400 | 5 / 4 / 5 | 0 | 2-6 | 0,5 |
| | `redrock_raider` | 8 | 50 | marksmanship | 2600 | 10 / 8 / 8 | 2 | 4-10 | 0,75 |
| Bosco dei Sussurri | `whisper_wolf` | 16 | 110 | blade | 2600 | 20 / 15 / 18 | 4 | 8-18 | 1,0 |
| | `moss_troll` | 22 | 160 | arcana | 3000 | 25 / 22 / 30 | 8 | 12-25 | 1,0 |
| | `hollow_archer` | 30 | 210 | marksmanship | 2400 | 30 / 18 / 20 | 5 | 15-30 | 1,0 |
| Miniere Crepate | `crack_golem` | 38 | 320 | blade | 3200 | 45 / 35 / 50 | 12 | 25-50 | 1,5 |
| | `deep_crawler` | 46 | 400 | marksmanship | 2200 | 50 / 30 / 35 | 8 | 30-60 | 1,5 |
| | `vein_witch` | 55 | 520 | arcana | 2800 | 55 / 40 / 40 | 10 | 40-80 | 1,5 |
| Soglia del Rift | `shard_wraith` | 65 | 700 | arcana | 2600 | 70 / 55 / 60 | 15 | 60-120 | 2,0 |
| | `rift_knight` | 78 | 950 | blade | 2400 | 85 / 65 / 80 | 20 | 90-170 | 2,5 |
| | `riftborn_colossus` | 92 | 1300 | marksmanship | 3400 | 100 / 80 / 110 | 25 | 150-300 | 3,0 |
I drop di oggetti (pelli, ossa, materiali dell'area) li definisce il Data Designer: al massimo 4 voci per mostro,
probabilità tra 1% e 40%.

### 8.6 Shop
| Id | Nome | Costo | Max | Requisiti | Effetto |
|---|---|---|---|---|---|
| `bank_slot` | Casella della bank | F-17 | 150 | — | `bank_slots +1` |
| `auto_eat_1` | Razioni da campo I | 2.000 | 1 | — | `auto_eat_tier +1` |
| `auto_eat_2` | Razioni da campo II | 25.000 | 1 | `auto_eat_1`, Vitalità 25 | `auto_eat_tier +1` |
| `auto_eat_3` | Razioni da campo III | 250.000 | 1 | `auto_eat_2`, Vitalità 50 | `auto_eat_tier +1` |
| `auto_loot` | Raccolta automatica del bottino | 50.000 | 1 | — | `auto_loot +1` |
| `loot_pocket` | Tasca della borsa | 5.000 | 3 | — | `loot_bag_slots +4` |
| `novice_hatchet` / `novice_pick` / `novice_rod` | Attrezzi del novizio (T1) | 150 | ∞ | — | oggetto attrezzo T1 |
| `second_thought` (M8) | Secondo pensiero | 1.000.000 | 1 | somma dei livelli ≥ 300 | `parallel_lanes +1` |

### 8.7 Altare e infusioni (Legatura del Rift)
Prese sbloccate ai livelli `rift.sockets`: 1, 20, 40, 60, 80.
| Livello ricetta | Infusione (id) | Frammenti | Altri ingredienti | Modificatori (global) | XP | Intervallo |
|---|---|---|---|---|---|---|
| 1 | `inf_swift_hands` | 5 | 10 legno T1 | `skill_interval_pct −3` | 40 | 4000 |
| 15 | `inf_bountiful` | 8 | 10 minerale T2 | `double_item_chance +2` | 70 | 4000 |
| 25 | `inf_scholar` | 12 | 10 pesce cotto T3 | `skill_xp_pct +3` | 110 | 4500 |
| 35 | `inf_keen_edge` | 16 | 5 lingotto T4 | `accuracy_pct +4` | 150 | 4500 |
| 45 | `inf_stoneskin` | 20 | 5 lingotto T5 | `damage_reduction +2` | 200 | 5000 |
| 55 | `inf_deep_roots` | 25 | 20 legno T5 | `mastery_xp_pct +5` | 260 | 5000 |
| 65 | `inf_hearthfire` | 30 | 20 pesce cotto T6 | `food_healing_pct +10` | 330 | 5500 |
| 75 | `inf_riftsense` (unica) | 40 | 10 minerale T7 | `rift_shard_chance +0.5` | 420 | 5500 |
| 85 | `inf_bulwark` | 50 | 5 lingotto T8 | `max_hp_flat +60` | 520 | 6000 |

### 8.8 Nodi della maestria (esempio completo: Selvicoltura)
| Id | Costo % del tetto | Prerequisiti | Modificatori (scope `skill:forestry`) |
|---|---|---|---|
| `forestry_n1_quick_axe` | 5 | — | `skill_interval_pct −3` |
| `forestry_n2_keen_eye` | 7,5 | n1 | `double_item_chance +3` |
| `forestry_n3_lore` | 7,5 | n1 | `skill_xp_pct +4` |
| `forestry_n4_rift_bark` | 10 | n2 | `rift_shard_chance +0.25` |
| `forestry_n5_patience` | 10 | n3 | `mastery_xp_pct +5` |
| `forestry_n6_master` | 20 | n4, n5 | `skill_interval_pct −5`, `double_item_chance +5` |
Totale 60% del tetto. Le altre skill con maestria seguono lo stesso schema (6 nodi, totale 55-65%).

## 9. Valori di `balance.json` (specifica iniziale completa)

| Chiave | Valore | Usata da |
|---|---|---|
| `tick_ms` | 100 | GameClock |
| `max_catchup_ms` | 5000 | GameClock |
| `autosave_interval_ms` | 10000 | Game |
| `slots.count` | 4 | SaveStore, menu |
| `start.gold` | 50 | GameSession.new_game |
| `start.items` | `[]` | GameSession.new_game |
| `xp_curve.{base, growth, linear, max_level, xp_cap}` | 70, 1.1, 8, 99, 50000000 | F-01 |
| `mastery_curve.{base, growth, linear, max_level}` | 20, 1.1, 4, 99 | F-09 |
| `mastery.{base_factor, per_level, ratio_weight, pool_share_pct, pool_cap_per_item}` | 1.0, 0.1, 3.0, 20, 300000 | F-10..F-13 |
| `action.min_interval_ms` | 250 | F-03 |
| `gathering.rift_shard_base_chance_pct` | 0.5 | F-07 |
| `bank.{base_slots, slot_cost_base, slot_cost_growth, slot_cost_cap, max_purchasable}` | 24, 400, 1.09, 2000000, 150 | F-16, F-17 |
| `combat.{acc_level_offset, acc_bonus_offset}` | 8, 50 | F-20, F-21 |
| `combat.{maxhit_level_offset, maxhit_bonus_offset, min_hit_ratio}` | 10, 40, 0.1 | F-22 |
| `combat.{hit_chance_min, hit_chance_max}` | 0.05, 0.95 | F-23 |
| `combat.triangle.{advantage_damage_mult, disadvantage_damage_mult, defender_dr_mult}` | 1.15, 0.85, 0.75 | F-24 |
| `combat.triangle.beats` | `{"blade":"arcana","arcana":"marksmanship","marksmanship":"blade"}` | F-24 |
| `combat.min_attack_interval_ms` | 800 | F-26 |
| `combat.unarmed` | `{"style":"blade","attack_interval_ms":2400}` | F-26 |
| `combat.{hp_base, hp_per_vitality}` | 50, 10 | F-27 |
| `combat.{hp_skill, defence_skill}` | `"vitality"`, `"guard"` | F-21, F-27, F-28 |
| `combat.{xp_per_damage_style, xp_per_damage_vitality}` | 4, 1 | F-28 |
| `combat.auto_eat_tiers` | `[null, {30,60}, {40,75}, {50,90}]` | F-30 |
| `combat.{respawn_ms, loot_bag_base_slots}` | 1500, 12 | 10.1, F-33 |
| `rift.sockets` | `[{"level":1},{"level":20},{"level":40},{"level":60},{"level":80}]` | 11 |
| `offline.{cap_ms, min_ms, chunk_ms}` | 43200000, 60000, 60000 | F-40, F-41 |
| `fractures.{interval_min_ms, interval_max_ms, duration_ms}` (M7) | 7200000, 14400000, 1800000 | F-50 |
| `parallel.interval_penalty_pct` (M8) | 40 | F-51 |

I limiti delle stat (es. `damage_reduction` max 80, `preservation_chance` max 80, `skill_interval_pct` min −80) stanno
**solo** in `stats.json` (§11), non in `balance.json`.

## 10. Numeri della UI non di gioco
Durate di animazioni, dimensioni della finestra, toast (4 visibili, 1 s di raggruppamento, 2 s di banner) sono costanti
di presentazione: stanno in `res://ui/theme/ui_style.gd` (unica definizione), non in `balance.json`.

## 11. Registro delle stat (`stats.json`)

Ogni stat: effetto, limiti del **totale**, formula, test che ne verifica l'effetto. Nessuna stat senza riga qui.

| Stat | Min | Max | Effetto | Formula | Test dell'effetto |
|---|---|---|---|---|---|
| `skill_interval_pct` | −80 | 100 | riduce/aumenta l'intervallo delle azioni | F-03 | `test_action_math.gd::test_interval_uses_skill_interval_pct` |
| `skill_xp_pct` | 0 | 1000 | aumenta l'XP | F-02 | `test_skills_system.gd::test_add_xp_applies_skill_xp_pct` |
| `mastery_xp_pct` | 0 | 1000 | aumenta la maestria | F-10 | `test_mastery_math.gd::test_mastery_xp_pct` |
| `double_item_chance` | 0 | 100 | probabilità di prodotto doppio | F-06 | `test_gathering_resolver.gd::test_double_item_chance_100` |
| `preservation_chance` | 0 | 80 | probabilità di non consumare ingredienti | F-08 | `test_artisan_resolver.gd::test_preservation_cap` |
| `rift_shard_chance` | 0 | 100 | aumenta la probabilità di frammento | F-07 | `test_gathering_resolver.gd::test_rift_shard_chance` |
| `bank_slots` | 0 | 10000 | caselle extra della bank | F-16 | `test_bank.gd::test_capacity_uses_bank_slots` |
| `accuracy_bonus` | −1000 | 100000 | precisione piatta | F-20 | `test_combat_math.gd::test_accuracy_rating` |
| `accuracy_pct` | −90 | 1000 | precisione percentuale | F-20 | `test_combat_math.gd::test_accuracy_pct` |
| `power_bonus` | −1000 | 100000 | danno massimo piatto | F-22 | `test_combat_math.gd::test_max_hit` |
| `power_pct` | −90 | 1000 | danno massimo percentuale | F-22 | `test_combat_math.gd::test_power_pct` |
| `evasion_bonus` | −1000 | 100000 | evasione piatta | F-21 | `test_combat_math.gd::test_evasion_rating` |
| `evasion_pct` | −90 | 1000 | evasione percentuale | F-21 | `test_combat_math.gd::test_evasion_pct` |
| `damage_reduction` | 0 | 80 | riduzione del danno subito | F-25 | `test_combat_math.gd::test_damage_reduction_cap` |
| `attack_interval_pct` | −90 | 200 | velocità d'attacco | F-26 | `test_combat_math.gd::test_attack_interval_min` |
| `max_hp_flat` | 0 | 100000 | PV massimi piatti | F-27 | `test_combat_math.gd::test_max_hp` |
| `food_healing_pct` | 0 | 500 | cura del cibo | F-29 | `test_auto_eat.gd::test_food_healing_pct` |
| `gold_drop_pct` | 0 | 1000 | oro dai mostri | F-31 | `test_combat_engine.gd::test_gold_drop_pct` |
| `loot_bag_slots` | 0 | 100 | caselle della borsa | F-33 | `test_loot_bag.gd::test_capacity_uses_loot_bag_slots` |
| `auto_loot` | 0 | 1 | bottino direttamente nella bank | 10.6 | `test_loot_bag.gd::test_auto_loot_to_bank` |
| `auto_eat_tier` | 0 | 3 | livello delle razioni da campo | F-30 | `test_auto_eat.gd::test_tier_thresholds` |
| `fracture_duration_pct` (M7) | 0 | 300 | durata delle Fratture | F-50 | `test_fracture_system.gd::test_duration_pct` |
| `parallel_lanes` (M8) | 0 | 1 | corsie extra | F-51 | `test_action_runner.gd::test_secondary_lane_unlock` |
