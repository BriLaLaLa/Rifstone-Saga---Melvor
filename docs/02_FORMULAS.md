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
Test: `tests/systems/mastery/test_mastery_nodes.gd` (`test_f15_examples`, `test_node_cost_uses_the_pool_cap_of_the_skill`, `test_f15_real_forestry_nodes`).

## 4. Bank, oro, shop

### F-16 Capienza della bank
`capacity = bank.base_slots + floor(T(bank_slots, global))`; `bank.base_slots = 24`.
Esempio: 3 caselle comprate → 27. Test: `tests/systems/bank/test_bank.gd`.

### F-17 Prezzo della prossima casella
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

### F-22 Danno massimo, minimo e tiro
`max_hit = floor((L + combat.maxhit_level_offset) × (power_bonus + combat.maxhit_bonus_offset) / maxhit_bonus_offset × (1 + power_pct/100))`;
`L` = `L_char` o `power_level`.
`min_hit = max(1, floor(max_hit × combat.min_hit_ratio))`; tiro = intero uniforme in `[min_hit, max_hit]`.
Parametri: `maxhit_level_offset = 10`, `maxhit_bonus_offset = 40`, `min_hit_ratio = 0.1`.
Esempi: (1, 0, 0) → max 11, min 1; (10, 20, 0) → 30 / 3; (50, 60, 0) → 150 / 15; (99, 150, 0) → 517 / 51;
(10, 20, 10) → floor(33,0) = 33 / 3. Test: `test_combat_math.gd`.

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

### F-25 Riduzione del danno
`dr_eff = T(damage_reduction) (0..80 da stats.json) × (0,75 se il difensore è in svantaggio)`
`danno = max(1, floor(danno_dopo_triangolo × (1 − dr_eff/100)))`
Esempi: 20, DR 25 → **15**; 3, DR 80 → **1**; tiro 20, attaccante in vantaggio, DR del difensore 10 →
floor(20×1,15) = 23 → dr_eff 7,5 → floor(23 × 0,925) = **21**; tiro 20, svantaggio, DR 10 → floor(17) = 17 → floor(15,3) = **15**.
Test: `test_combat_math.gd`.

### F-26 Intervallo d'attacco
`interval = max(combat.min_attack_interval_ms, round(base_ms × (1 + T(attack_interval_pct)/100)))`; min 800 ms.
`base_ms` = `weapon.attack_interval_ms`, F-73 con due spade, o `combat.unarmed.attack_interval_ms` (2400).
Mostro: `attack_interval_ms` dei dati.
Esempi: 2400, −10 → 2160; 1000, −50 → 500 → **800**; due spade 1800, −10 → 1620. Test: `test_combat_math.gd`.

### F-27 Punti vita massimi
`max_hp = combat.hp_base + combat.hp_per_level × L_char + floor(T(max_hp_flat))`; `hp_base = 50`, `hp_per_level = 10`.
Esempi: livello 1 → 60; livello 10 e +20 → 170; livello 99 → 1.040. Test: `test_combat_math.gd`.

### F-28 Esperienza di combattimento (per uccisione)
Ogni nemico ucciso dà al personaggio il campo `xp` del mostro (`04_DATA_SCHEMA.md` §8), che passa da F-71. Nessuna XP
per danno, nessuna stance (D3). Una Pietra del Rift (F-87) dà il suo `xp`. Valori: tabella §8.5 (`xp = 4 × PV`).
Esempi: `plains_boar` (xp 80), +0% → 80; +25% → 100; gruppo di 3 `plains_boar` → 240. Test:
`tests/systems/combat/test_combat_engine.gd::test_kill_grants_character_xp`.

### F-29 Cura del cibo
`heal = floor(food.heal × (1 + T(food_healing_pct)/100))`; `hp = min(max_hp, hp + heal)`.
Esempi: 30 e +20% → 36; 20 e 0 → 20. Test: `tests/systems/combat/test_auto_eat.gd`.

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
pot 18; offhand acc 13, pot 6. Test: `tests/systems/combat/test_combatant_stats.gd::test_dual_wield_hand_stats`.

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

### F-80 Effetto delle abilità (M6)
- `strike` / `cleave`: per ogni bersaglio (uno; `targets` = N primi vivi; 0 = tutti) tiro F-23, poi
  `danno = floor(tiro F-22 × power_mult)` → F-24 → F-25.
- `heal`: `hp = min(max_hp, hp + floor(max_hp × heal_pct/100))`.
- `buff`: i `modifiers` dell'abilità valgono come sorgente `ability:<id>` per `duration_ms`, poi spariscono (anche a
  fine combattimento o alla morte).
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

## 5b. Armeria e bottino (F-82…F-89)

### F-82 Capienza dell'Armeria e prezzo delle caselle
`capacity = armory.base_slots + floor(T(armory_slots, global))`; `armory.base_slots = 40` (Q33). Contano solo i pezzi
**non indossati**. Prezzo della prossima casella (voce `armory_slot` dello shop, `cost.formula = "armory_slot"`):
`price(n) = min(armory.slot_cost_cap, floor(armory.slot_cost_base × armory.slot_cost_growth^n))`, con 1000, 1.12, 2000000.
Esempi: 10 caselle comprate → capienza 50; prezzo n 0 → 1.000; 1 → 1.120; 2 → 1.254; 5 → 1.762; 10 → 3.105; 20 → 9.646;
30 → 29.959. Test: `tests/systems/armory/test_armory.gd`, `tests/systems/shop/test_shop.gd::test_armory_slot_price`.

### F-83 Rarità nell'artigianato
`M` = livello di maestria della ricetta (1-99, F-09: una ricetta senza XP di maestria è al livello 1; `M 0` negli esempi
è solo il caso limite della funzione pura), `k = 1 + T(item_rarity_pct, ctx)/100` con `ctx` = contesto dell'azione
(i modificatori globali valgono sempre; uno con scope di skill o azione vale solo lì).
`p_magic = (rarity.craft.magic_base_pct + rarity.craft.magic_per_mastery_level × M) × k`;
`p_rare = (rarity.craft.rare_base_pct + rarity.craft.rare_per_mastery_level × M) × k`; valori 10, 0.4, 1, 0.1.
Se `p_rare > 100` → 100; se `p_magic + p_rare > 100` → `p_magic = 100 − p_rare`.
Tiro: `r = rng.randf() × 100`; `r < p_rare` → `rare`; `r < p_rare + p_magic` → `magic`; altrimenti `common`.
Esempi: M 0, +0% → 10 / 1; M 50, +20% → 36,0 / 7,2; M 99, +0% → 49,6 / 10,9; con (36, 7,2): r 5,0 → raro; r 20 →
magico; r 50 → comune. Test: `tests/systems/items/test_item_roller.gd::test_craft_rarity`.

### F-84 Rarità nei drop (M7)
`p_magic = rarity.drop.magic_pct × k`, `p_rare = rarity.drop.rare_pct × k` (stesso `k` e stesso tiro di F-83); valori
20, 3 per i mostri, `rarity.rift_stone.magic_pct` 40 e `rare_pct` 12 per le Pietre del Rift. Esempio: mostro con +50% →
30 / 4,5. Test: `test_item_roller.gd::test_drop_rarity`.

### F-85 Affissi
Numero: `randi_range(a, b)` con `rarity.affix_count.magic = [1, 2]`, `rarity.affix_count.rare = [3, 4]`, comune 0.
Per ogni affisso, in ordine: candidati = affissi di `data/affixes/affixes.json` ammessi dallo slot del pezzo, non già
presenti sul pezzo, con almeno un grado `min_ilvl ≤ ilvl`; `pick_weighted(weight)`; grado = uniforme tra i gradi
sbloccati; valore = `min + randi_range(0, floor((max − min) / step)) × step` (`step` di default 1). Senza candidati si
smette (il pezzo ha meno affissi). `ilvl` = livello della ricetta (artigianato) o del mostro (drop, M7).
Esempi: gradi con `min_ilvl` 1, 20, 45 e ilvl 25 → 2 gradi sbloccati; grado `{min 3, max 6}` → 3..6; `{min 0.5, max 1.5,
step 0.25}` → 0,5, 0,75 … 1,5; slot con 2 soli affissi ammessi e raro da 4 → 2 affissi.
Test: `test_item_roller.gd::test_affix_rolls`.

### F-86 Raffinazione (M7)
Tentativo da `+N` a `+N+1` (N 0..8, Q28): costo `upgrade.levels[N] = {success_pct, gold_per_grade, ingots, shards}`:
oro `gold_per_grade × grado`, `ingots` lingotti del grado del pezzo, `shards` frammenti del Rift.
`chance = min(100, success_pct × (1 + T(upgrade_success_pct)/100))`. Successo → `+N+1`. Fallimento: materiali persi;
se `N ≥ upgrade.downgrade_from` (4) il pezzo scende a `+N−1`, salvo il Sigillo di salvaguardia (`upgrade.seal_item`,
consumato); mai distrutto (Q27). Modificatori base del pezzo × `(1 + upgrade.mod_pct_per_level × N / 100)` (10); gli
affissi non cambiano.
| N → N+1 | 0→1 | 1→2 | 2→3 | 3→4 | 4→5 | 5→6 | 6→7 | 7→8 | 8→9 |
|---|---|---|---|---|---|---|---|---|---|
| `success_pct` | 95 | 90 | 85 | 75 | 65 | 55 | 45 | 35 | 25 |
| `gold_per_grade` | 50 | 100 | 200 | 400 | 800 | 1600 | 3200 | 6400 | 12800 |
| `ingots` | 1 | 1 | 2 | 2 | 3 | 3 | 4 | 4 | 5 |
| `shards` | 0 | 0 | 0 | 0 | 0 | 5 | 10 | 15 | 20 |
Esempi: +5 → +6 con +10% → 60,5%; fallimento da +5 → +4; fallimento da +3 → resta +3; `power_bonus` 48 a +3 → 62,4;
spada T4, +5 → +6: 6.400 oro, 3 lingotti T4, 5 frammenti. Test: `tests/systems/armory/test_upgrade.gd`.

### F-87 Pietre del Rift (M7)
Dopo ogni uccisione (non di una Pietra): `since += 1`; appare una Pietra se `since ≥ rift_stone.pity_kills` (300)
oppure `roll_pct(rift_stone.chance_pct)` (0.5); quando appare `since = 0` e il prossimo incontro (dopo `BETWEEN`) è la
Pietra dell'area. La Pietra non attacca: ogni `pulse_ms` infligge `pulse_damage` al giocatore (senza tiro, ridotto da
F-25, parabile con F-75). Esempi: `since` 299 → uccisione → Pietra garantita; chance 100 → sempre. Test:
`tests/systems/combat/test_rift_stone.gd`.

### F-88 Smantellamento (M7)
Lingotti restituiti: `floor(ingots_ricetta × salvage.ingot_ratio)` (0.4) del grado del pezzo (0 per i pezzi senza
ricetta); frammenti: `salvage.shards_by_rarity[rarity] × grado` (comune 0, magico 1, raro 3) + `N` della raffinazione.
Esempi: corpetto T3 (5 lingotti) magico +0 → 2 lingotti T3 e 3 frammenti; spada T8 rara +2 → 1 lingotto T8 e 26
frammenti; anello T5 raro → 0 lingotti, 15 frammenti. Test: `tests/systems/armory/test_salvage.gd`.

### F-89 Castoni (M8)
`sockets = sockets.by_rarity[rarity] + (1 se upgrade ≥ sockets.bonus_at_upgrade)`; comune 0, magico 1, raro 2, bonus a
+7. Esempi: raro +7 → 3; comune +9 → 1; magico +6 → 1. Test: `tests/systems/armory/test_sockets.gd`.

## 6. Offline

### F-40 Tempo offline
`elapsed = clamp(now_unix_ms − saved_at_unix_ms, 0, offline_cap_ms)`; `offline_cap_ms = 43200000` (12 h),
`capped = (now − saved) > offline_cap_ms`.
Esempi: 5 h → 18.000.000, capped false; 20 h → 43.200.000, capped true; orologio indietro → 0. Con
`elapsed < offline_min_ms (60000)` nessuna schermata. Test: `tests/core/offline/test_offline_simulator.gd`.

### F-41 Blocchi della simulazione
`chunks = ceil(elapsed / offline_chunk_ms)`, `offline_chunk_ms = 60000`. Esempio: 12 h → 720 blocchi; 90 s → 2 (60 s + 30 s).
Equivalenza: simulare 600.000 ms in un blocco o in 10 blocchi dà lo stesso stato con lo stesso seme. Test: idem.

## 7. Fratture (M10) e corsie (M11)

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
| Forgiatura | Spada Tn | 3 × lingotto Tn + 1 × impugnatura Tn | 3000 | `3 × XP lingotto × 1,2` | 12 × valore minerale + valore impugnatura |
| Forgiatura | Spadone Tn | 5 × lingotto Tn + 1 × impugnatura Tn | 3500 | `5 × XP lingotto × 1,2` | 20 × valore minerale + valore impugnatura |
| Forgiatura | Scudo Tn | 4 × lingotto Tn + 1 × anima dello scudo Tn | 3000 | `4 × XP lingotto × 1,2` | 16 × valore minerale + valore anima |
| Forgiatura | Corpetto Tn / Gambali Tn / Elmo Tn / Stivali Tn / Guanti Tn | 5 / 4 / 3 / 2 / 2 lingotti | 3000 | `lingotti × XP lingotto × 1,2` | `lingotti × 4 ×` valore minerale |
| Forgiatura | Attrezzo Tn (ascia, piccone, canna) | 2 × lingotto Tn + 1 × manico Tn | 3000 | `2 × XP lingotto × 1,3` | 10 × valore minerale |
| Focolare | Pesce cotto Tn | 1 × pesce Tn | 2500 | `floor(0,9 × XP pesca Tn)` | 2 × valore pesce |
| Intaglio | Impugnatura Tn (ingrediente di spade e spadoni) | 1 × legno Tn | 1600 | `XP legno × 0,8` | 2 × valore legno |
| Intaglio | Anima dello scudo Tn (ingrediente degli scudi) | 2 × legno Tn | 2000 | `2 × XP legno × 0,9` | 4 × valore legno |
| Intaglio | Manico Tn (ingrediente degli attrezzi) | 1 × legno Tn | 1600 | `XP legno × 0,8` | 2 × valore legno |
Livello richiesto della ricetta Tn = livello del grado Tn (8.1). Gli arrotondamenti delle XP sono `floor`. Archi e
bastoni arcani non sono nell'MVP (Q37): tornano con le loro classi. I pezzi `equipment`/`tool` prodotti sono istanze
dell'Armeria con rarità F-83 e affissi F-85 (`ilvl` = livello della ricetta).

### 8.3 Cibo (Focolare)
| Grado | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 |
|---|---|---|---|---|---|---|---|---|
| `heal` | 20 | 35 | 55 | 80 | 110 | 150 | 200 | 260 |

### 8.4 Equipaggiamento (grado n = 1..8)
| Pezzo | `kind` / stile | Modificatori | Intervallo | Requisito |
|---|---|---|---|---|
| Spada | `sword`, `blade`, una mano (`weapon` o `offhand`) | `accuracy_bonus 8n`, `power_bonus 6n` | 2400 | `{"character": livello Tn}` |
| Spadone | `greatsword`, `blade`, due mani | `accuracy_bonus 9n`, `power_bonus 11n` | 3200 | personaggio |
| Scudo (offhand) | `shield` | `evasion_bonus 4n`, `damage_reduction n`, `block_chance 5 + floor(10 × (n − 1) / 7)` | — | personaggio |
| Corpetto | — | `evasion_bonus 6n`, `damage_reduction n` | — | personaggio |
| Gambali | — | `evasion_bonus 4n`, `damage_reduction ceil(n/2)` | — | personaggio |
| Elmo | — | `evasion_bonus 3n`, `damage_reduction ceil(n/2)` | — | personaggio |
| Stivali / Guanti | — | `evasion_bonus 2n` | — | personaggio |
| Anello / Amuleto (M7, solo drop, Q30) | — | `accuracy_bonus 3n` / `max_hp_flat 10n` | — | personaggio |
| Attrezzo | — | `skill_interval_pct −(3 + 2n)` con scope `skill:<skill>` | — | skill dell'attrezzo ≥ livello Tn |
Esempio: set completo T8 con scudo → `damage_reduction` 8 + 4 + 4 + 8 = 24, `block_chance` 15. Ogni pezzo ha `grado` n
(`equip.grade`). Identità degli assetti (D6): spadone lento e forte, spada e scudo difensivo, due spade rapide (F-73).
Modificatori degli assetti (`data/classes/rift_blade.json`): solo `dual_swords` con `accuracy_pct −10` (Q39, provvisorio); gli altri nessuno.

### 8.5 Mostri
| Area | Id | L (att = pot = dif) | PV | Stile | Interv. ms | acc / pot / eva | DR | Oro | Frammento % | XP |
|---|---|---|---|---|---|---|---|---|---|---|
| Pianure di Roccarossa | `plains_boar` | 1 | 20 | blade | 2800 | 0 / 0 / 0 | 0 | 1-4 | 0,5 | 80 |
| | `ember_rat` | 4 | 32 | arcana | 2400 | 5 / 4 / 5 | 0 | 2-6 | 0,5 | 128 |
| | `redrock_raider` | 8 | 50 | marksmanship | 2600 | 10 / 8 / 8 | 2 | 4-10 | 0,75 | 200 |
| Bosco dei Sussurri | `whisper_wolf` | 16 | 110 | blade | 2600 | 20 / 15 / 18 | 4 | 8-18 | 1,0 | 440 |
| | `moss_troll` | 22 | 160 | arcana | 3000 | 25 / 22 / 30 | 8 | 12-25 | 1,0 | 640 |
| | `hollow_archer` | 30 | 210 | marksmanship | 2400 | 30 / 18 / 20 | 5 | 15-30 | 1,0 | 840 |
| Miniere Crepate | `crack_golem` | 38 | 320 | blade | 3200 | 45 / 35 / 50 | 12 | 25-50 | 1,5 | 1280 |
| | `deep_crawler` | 46 | 400 | marksmanship | 2200 | 50 / 30 / 35 | 8 | 30-60 | 1,5 | 1600 |
| | `vein_witch` | 55 | 520 | arcana | 2800 | 55 / 40 / 40 | 10 | 40-80 | 1,5 | 2080 |
| Soglia del Rift | `shard_wraith` | 65 | 700 | arcana | 2600 | 70 / 55 / 60 | 15 | 60-120 | 2,0 | 2800 |
| | `rift_knight` | 78 | 950 | blade | 2400 | 85 / 65 / 80 | 20 | 90-170 | 2,5 | 3800 |
| | `riftborn_colossus` | 92 | 1300 | marksmanship | 3400 | 100 / 80 / 110 | 25 | 150-300 | 3,0 | 5200 |
I drop di oggetti (pelli, ossa, materiali dell'area) li definisce il Data Designer: al massimo 4 voci per mostro,
probabilità tra 1% e 40%. Requisito di ogni area: `{"character": n}` con n = livello del primo mostro dell'area (1, 16, 38, 65).

**Gruppi** (`packs`, D5, Q38): ogni area ha 3-6 gruppi pesati di 1..`combat.max_pack_size` (6) mostri della stessa
area; dimensione massima per area: Pianure 2, Bosco 3, Miniere 4, Soglia 6. Almeno un gruppo per area è di un solo
mostro (il più debole). Esempio (Pianure): `[plains_boar]` peso 4, `[plains_boar, plains_boar]` peso 2,
`[ember_rat]` peso 3, `[ember_rat, plains_boar]` peso 2, `[redrock_raider]` peso 1. I numeri dei gruppi si
confermano con `tools/sim_combat.gd` (M5): un personaggio con il set forgiato del grado dell'area e il cibo del grado
deve avere 0 morti in 1 ora simulata nel gruppo più facile e tenere almeno 60 uccisioni/ora nell'area.

### 8.6 Shop
| Id | Nome | Costo | Max | Requisiti | Effetto |
|---|---|---|---|---|---|
| `bank_slot` | Casella della bank | F-17 | 150 | — | `bank_slots +1` |
| `auto_eat_1` | Razioni da campo I | 2.000 | 1 | — | `auto_eat_tier +1` |
| `armory_slot` | Casella dell'Armeria | F-82 | 60 | — | `armory_slots +1` |
| `auto_eat_2` | Razioni da campo II | 25.000 | 1 | `auto_eat_1`, personaggio 25 | `auto_eat_tier +1` |
| `auto_eat_3` | Razioni da campo III | 250.000 | 1 | `auto_eat_2`, personaggio 50 | `auto_eat_tier +1` |
| `auto_loot` | Raccolta automatica del bottino | 50.000 | 1 | — | `auto_loot +1` |
| `loot_pocket` | Tasca della borsa | 5.000 | 3 | — | `loot_bag_slots +4` |
| `novice_hatchet` / `novice_pick` / `novice_rod` | Attrezzi del novizio (T1) | 150 | ∞ | — | istanza comune dell'attrezzo T1 nell'Armeria |
| `second_thought` (M11) | Secondo pensiero | 1.000.000 | 1 | somma dei livelli ≥ 300 | `parallel_lanes +1` |

### 8.7 Altare e infusioni (Legatura del Rift, M8)
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
Cavatura (`quarrying_n1_steady_pick` … `quarrying_n6_master`) e Lenza (`angling_n1_quick_cast` … `angling_n6_master`)
hanno oggi gli stessi costi, prerequisiti, stat e valori di Selvicoltura con scope della propria skill (M2-02,
`OPEN_QUESTIONS.md` Q26). Disposizione (`pos` = `[col, row]`) comune ai tre alberi: n1 `[1,0]`, n2 `[0,1]`, n3 `[2,1]`,
n4 `[0,2]`, n5 `[2,2]`, n6 `[1,3]`.

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
| `warded` | `damage_reduction` | head, body, legs, offhand | 1..1 | 1..2 | 2..3 | 3..4 | 6 |
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
| `start.items` | `[]` | GameSession.new_game |
| `xp_curve.{base, growth, linear, max_level, xp_cap}` | 70, 1.1, 8, 99, 50000000 | F-01 |
| `mastery_curve.{base, growth, linear, max_level}` | 20, 1.1, 4, 99 | F-09 |
| `mastery.{base_factor, per_level, ratio_weight, pool_share_pct, pool_cap_per_item}` | 1.0, 0.1, 3.0, 20, 300000 | F-10..F-13 |
| `mastery.pool_warning_pct` | 95 | MasteryPanel: avviso del pool quasi pieno (`01_GDD.md` §6.2); > 0 e ≤ 100 |
| `action.min_interval_ms` | 250 | F-03 |
| `gathering.rift_shard_base_chance_pct` | 0.5 | F-07 |
| `bank.{base_slots, slot_cost_base, slot_cost_growth, slot_cost_cap}` | 24, 400, 1.09, 2000000 | F-16, F-17 (il massimo di caselle comprabili è `max_purchases` di `bank_slot`, §8.6) |
| `combat.{acc_level_offset, acc_bonus_offset}` | 8, 50 | F-20, F-21 |
| `combat.{maxhit_level_offset, maxhit_bonus_offset, min_hit_ratio}` | 10, 40, 0.1 | F-22 |
| `combat.{hit_chance_min, hit_chance_max}` | 0.05, 0.95 | F-23 |
| `combat.triangle.{advantage_damage_mult, disadvantage_damage_mult, defender_dr_mult}` | 1.15, 0.85, 0.75 | F-24 |
| `combat.triangle.beats` | `{"blade":"arcana","arcana":"marksmanship","marksmanship":"blade"}` | F-24 |
| `combat.min_attack_interval_ms` | 800 | F-26 |
| `combat.unarmed` | `{"style":"blade","attack_interval_ms":2400}` | F-26, F-72 |
| `combat.{hp_base, hp_per_level}` | 50, 10 | F-27 (sostituisce `hp_per_vitality`) |
| `combat.dual_wield.interval_mult` | 0.75 | F-73 (Q39) |
| `combat.max_pack_size` | 6 | `01_GDD.md` §10.1, §8.5 (Q38) |
| `combat.auto_eat_tiers` | `[null, {30,60}, {40,75}, {50,90}]` | F-30 |
| `combat.{respawn_ms, loot_bag_base_slots}` | 1500, 12 | 10.1 (attesa `BETWEEN`), F-33 |
| `character_curve.{base, growth, linear, max_level, xp_cap}` | 70, 1.1, 8, 99, 50000000 | F-71 (Q34) |
| `character.start_class` | `"rift_blade"` | GameSession.new_game (`01_GDD.md` §19) |
| `armory.{base_slots, slot_cost_base, slot_cost_growth, slot_cost_cap}` | 40, 1000, 1.12, 2000000 | F-82 (il massimo comprabile è `max_purchases` di `armory_slot`, 60) |
| `rarity.craft.{magic_base_pct, magic_per_mastery_level, rare_base_pct, rare_per_mastery_level}` | 10, 0.4, 1, 0.1 | F-83 |
| `rarity.affix_count.{magic, rare}` | `[1, 2]`, `[3, 4]` | F-85 |
| `traits.slot_levels` (M6) | `[1, 10, 25, 50]` | F-78 (Q35) |
| `abilities.slot_levels` (M6) | `[1, 1, 30]` | F-78 (Q36) |
| `rarity.drop.{magic_pct, rare_pct}`, `rarity.rift_stone.{magic_pct, rare_pct}` (M7) | 20, 3; 40, 12 | F-84 |
| `upgrade.{levels, downgrade_from, mod_pct_per_level, seal_item, ingot_items}` (M7) | tabella F-86, 4, 10, id del Sigillo, 8 id dei lingotti T1-T8 | F-86 |
| `rift_stone.{chance_pct, pity_kills}` (M7) | 0.5, 300 | F-87 |
| `salvage.{ingot_ratio, shards_by_rarity}` (M7) | 0.4, `{"common":0,"magic":1,"rare":3}` | F-88 |
| `sockets.{by_rarity, bonus_at_upgrade}` (M8) | `{"common":0,"magic":1,"rare":2}`, 7 | F-89 |
| `rift.sockets` (già presente, usata in M8) | `[{"level":1},{"level":20},{"level":40},{"level":60},{"level":80}]` | 11 |
| `offline.{cap_ms, min_ms, chunk_ms}` | 43200000, 60000, 60000 | F-40, F-41 |
| `fractures.{interval_min_ms, interval_max_ms, duration_ms}` (M10) | 7200000, 14400000, 1800000 | F-50 |
| `parallel.interval_penalty_pct` (M11) | 40 | F-51 |

Chiavi tolte con la riforma (M4-01, D3): `combat.hp_per_vitality`, `combat.hp_skill`, `combat.defence_skill`,
`combat.xp_per_damage_style`, `combat.xp_per_damage_vitality`. Le chiavi segnate (M6)…(M11) le aggiunge il task che
le usa, insieme alla regola del validatore.

I limiti delle stat (es. `damage_reduction` max 80, `preservation_chance` max 80, `skill_interval_pct` min −80) stanno
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
| `bank_slots` | 0 | 10000 | caselle extra della bank | F-16 | `tests/systems/bank/test_bank.gd::test_capacity_uses_bank_slots` |
| `accuracy_bonus` | −1000 | 100000 | precisione piatta | F-20 | `tests/systems/combat/test_combat_math.gd::test_accuracy_rating` |
| `accuracy_pct` | −90 | 1000 | precisione percentuale | F-20 | `tests/systems/combat/test_combat_math.gd::test_accuracy_pct` |
| `power_bonus` | −1000 | 100000 | danno massimo piatto | F-22 | `tests/systems/combat/test_combat_math.gd::test_max_hit` |
| `power_pct` | −90 | 1000 | danno massimo percentuale | F-22 | `tests/systems/combat/test_combat_math.gd::test_power_pct` |
| `evasion_bonus` | −1000 | 100000 | evasione piatta | F-21 | `tests/systems/combat/test_combat_math.gd::test_evasion_rating` |
| `evasion_pct` | −90 | 1000 | evasione percentuale | F-21 | `tests/systems/combat/test_combat_math.gd::test_evasion_pct` |
| `damage_reduction` | 0 | 80 | riduzione del danno subito | F-25 | `tests/systems/combat/test_combat_math.gd::test_damage_reduction_cap` |
| `attack_interval_pct` | −90 | 200 | velocità d'attacco | F-26 | `tests/systems/combat/test_combat_math.gd::test_attack_interval_min` |
| `max_hp_flat` | 0 | 100000 | PV massimi piatti | F-27 | `tests/systems/combat/test_combat_math.gd::test_max_hp` |
| `food_healing_pct` | 0 | 500 | cura del cibo | F-29 | `tests/systems/combat/test_auto_eat.gd::test_food_healing_pct` |
| `gold_drop_pct` | 0 | 1000 | oro dai mostri | F-31 | `tests/systems/combat/test_combat_engine.gd::test_gold_drop_pct` |
| `loot_bag_slots` | 0 | 100 | caselle della borsa | F-33 | `tests/systems/combat/test_loot_bag.gd::test_capacity_uses_loot_bag_slots` |
| `auto_loot` | 0 | 1 | bottino direttamente nella bank | 01_GDD §10.6 | `tests/systems/combat/test_loot_bag.gd::test_auto_loot_to_bank` |
| `auto_eat_tier` | 0 | 3 | livello delle razioni da campo | F-30 | `tests/systems/combat/test_auto_eat.gd::test_tier_thresholds` |
| `armory_slots` (M4) | 0 | 10000 | caselle extra dell'Armeria | F-82 | `tests/systems/armory/test_armory.gd::test_capacity_uses_armory_slots` |
| `item_rarity_pct` (M4) | 0 | 1000 | probabilità di pezzi magici e rari | F-83, F-84 | `tests/systems/items/test_item_roller.gd::test_item_rarity_pct` |
| `block_chance` (M5) | 0 | 50 | probabilità di parare un colpo con lo scudo (Q40) | F-75 | `tests/systems/combat/test_combat_engine.gd::test_block_chance` |
| `upgrade_success_pct` (M7) | 0 | 300 | probabilità di riuscita della raffinazione | F-86 | `tests/systems/armory/test_upgrade.gd::test_upgrade_success_pct` |
| `fracture_duration_pct` (M10) | 0 | 300 | durata delle Fratture | F-50 | `tests/systems/fractures/test_fracture_system.gd::test_duration_pct` |
| `parallel_lanes` (M11) | 0 | 1 | corsie extra | F-51 | `tests/systems/actions/test_action_runner.gd::test_secondary_lane_unlock` |
