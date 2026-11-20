# 02. Formule, §5o: Abilità e tratti v2 (F-185…F-194; M28, V35-V36)

Estensione di `02_FORMULAS.md` (che supera le 400 righe): vale come la sua sezione **§5o**, con le chiavi §9f. Regole in `01_GDD_M28.md` (§40), dati in `04_DATA_SCHEMA_M28.md` (§33),
contratto in `05_INTERFACES_M28.md`. Gli esempi sono **casi di test**. Convenzioni di §5/§5a: `floor` dopo ogni prodotto indicato (con `CombatMath.EPSILON`), `roll_pct` e tiri solo
dove scritto. **Nessuna stat nuova** in `stats.json`; nessuna sorgente nuova in `ModifierService` (i buff restano `ability:<id>`, i modificatori dei tratti `trait:<id>`).
**Invariate**: F-20…F-34, F-70…F-80 e F-81/F-120 per i tipi esistenti; ogni regola qui sotto con i soli contenuti di M27 dà **gli stessi numeri e gli stessi tiri** di oggi (vincolo
di non regressione, test in M28-03).

Tipi di colpo del giocatore: **B** = colpo base (anche i bersagli in più di `every_nth_attack_all`; **non** il colpo in più di `double_hit_pct`, che resta come in F-120), **A** = colpo di
un'abilità `strike`/`cleave`, **C** = contrattacco (`riposte`), **T** = scatto di Sanguinamento.

---

## Condizioni

### F-185 Condizioni: regole comuni
- Condizioni dei nemici: `bleed`, `weaken`, `expose`, `stagger` (con la sua immunità); del giocatore: `ward`. Ogni nemico ha al massimo **un** esemplare di ciascuna.
- **Applicazione**: solo dopo un colpo **a segno** (B, A o C con danno > 0, già applicato) su un nemico che resta vivo; in ordine di lista (`apply` dell'abilità) o di slot (tratti).
- **Rinnovo** (`weaken`, `expose`): `pct = max(pct_attuale, pct_nuova)`, `ms = max(ms_attuali, ms_nuovi)`. `bleed`: F-186. `stagger`: F-188. `ward`: F-189.
- **Tempo**: le durate dei nemici scendono di `ms` in ogni tratto di tempo consumato negli stati `encounter`/`riftstone` (`_consume`); quelle a 0 si tolgono. Una condizione vale in un istante
  se ha `ms > 0` **dopo** il consumo del tempo fino a quell'istante: scadenza e uso nello stesso istante = scaduta. La fine non è un evento (nessun istante nuovo nel motore).
- **Fine**: le condizioni dei nemici spariscono con l'incontro (nuovo `Encounter`); il Riparo con `reset`, `stop`, la morte.
- **Save** (additivo, F-193 per le chiavi): lettura tollerante; valori non numerici o chiavi sconosciute scartati con `Log.warn`; `pct` limitate agli intervalli dello schema §33, `ms` a
  `[0, 60000]`, `ticks` a `[0, 60]`, `left` a `≥ 0`; condizione con `ms = 0` (o `left = 0`) scartata.
Esempio: Fiacchezza 25% con 3.000 ms rimasti, nuova 15% per 6.000 ms → **25% per 6.000 ms**. Breccia con 400 ms rimasti, attacco del giocatore 400 ms dopo → la Breccia **non** vale.
Test: `tests/systems/combat/conditions/test_enemy_conditions.gd`.

### F-186 Sanguinamento (`bleed`)
- Parametri: `pct` (della condizione), `ms` (durata). Su un colpo con danno `D` (il danno del colpo dopo F-25, prima dell'eventuale scudo del boss):
  `total = floor(D × pct / 100)`; se `total = 0` nulla. `ticks_new = ceil(ms / combat.conditions.tick_ms)`.
- Cumulo: `left = left + total`; `ticks = max(ticks, ticks_new)`.
- **Orologio** dell'incontro `clock` (uno solo): se è spento quando un nemico inizia a sanguinare, `clock = tick_ms`; scende come i timer; quando arriva a 0, **per ogni nemico vivo che
  sanguina, in ordine di posizione**: `d = ceil(left / ticks)`, `left −= d`, `ticks −= 1`, segnale `combat_condition_damage(i, d, &"bleed")`, poi `d` come danno del giocatore (T) sul
  nemico (`_hurt_enemy`: scudo del boss F-112, morte, ricompense, `on_kill`). Se l'incontro finisce si smette. Poi, se qualcuno sanguina ancora, `clock = tick_ms`, altrimenti spento.
- T: nessun tiro, nessun triangolo, nessuna riduzione, nessun `on_hit` (né rubavita, né accumuli "a colpo", né combo), nessuna parata.
Esempi (`tick_ms` 1.000): `D` 37, `pct` 50, 4.000 ms → total 18, ticks 4 → scatti **5, 5, 4, 4**. Dopo 2 scatti (left 8, ticks 2) un nuovo colpo `D` 20, 50%, 4.000 ms → left 18, ticks 4 →
**5, 5, 4, 4**. `D` 1, 50% → total 0: nessun Sanguinamento. Nemico con 7 PV e scatti 5, 5 → muore al secondo scatto (`on_kill`). Primo Sanguinamento a t = 2.300 → scatti a 3.300, 4.300,
5.300, 6.300; un secondo nemico inizia a sanguinare a t = 3.800 → il suo primo scatto è a **4.300**. Boss con scudo 3 e scatto 5 → scudo 0, PV −2.
Test: `tests/systems/combat/conditions/test_bleed.gd`.

### F-187 Fiacchezza (`weaken`) e Breccia (`expose`)
- **Fiacchezza** `{pct, ms}` (`pct` in (0, 90]): il danno che **quel nemico** infligge al giocatore (attacco base e abilità del boss) entra in F-193 con il fattore `(1 − pct/100)`.
  I Monoliti sono immuni (il loro impulso è fisso, F-125); l'impulso della Frattura non ha sorgente e non ne risente.
- **Breccia** `{pct, ms}` (`pct` in (0, 100]): i colpi B, A e C del giocatore su quel nemico hanno il fattore `(1 + pct/100)` in `M` (F-190). Non vale per T.
Esempi: tiro 20, neutro, Breccia 15, DR 10 → floor(20 × 1,15) = 23 → floor(23 × 0,9) = **20**; abilità ×1,2, tiro 30, Breccia 15, DR 10 → floor(36) = 36 → floor(41,4) = 41 → **36**;
Fiacchezza: vedi F-193. Test: `tests/systems/combat/conditions/test_enemy_conditions.gd`.

### F-188 Sbilanciamento (`stagger`)
- Parametro `ms`. Se il nemico **non** è immune (`immune_ms = 0`) e non è un boss di Frattura o di dungeon (`BossDef`, o il nemico della tappa del boss) né un Monolito:
  `timer_ms += ms`, `stagger_ms = ms` (finestra "sbilanciato", per `status_damage_mult`), `immune_ms = combat.conditions.stagger_immunity_ms`. Altrimenti nulla.
- `stagger_ms` e `immune_ms` scendono con il tempo (F-185). Il timer dell'abilità di un boss (F-112) non cambia mai.
Esempi (immunità 4.000): timer 1.200, Sbilanciamento 1.500 → timer **2.700**, sbilanciato per 1.500 ms, immune per 4.000 ms; un secondo Sbilanciamento 1.000 ms dopo → **ignorato**
(immunità 3.000); 4.000 ms dopo il primo → vale di nuovo. Nemico con il timer a 0 nello stesso istante in cui il giocatore lo Sbilancia di 1.000 → timer 1.000, **non attacca** in quell'istante
(F-193). Monolito o boss → nessun effetto. Test: `tests/systems/combat/conditions/test_stagger.gd`.

### F-189 Riparo (`ward`)
- Importo: `amount = floor(max_hp × pct / 100 × A)` (`A` = fattore di `ability_mult` per il tipo `ward`, F-192; 1 per i tratti `ward_on`), durata `ms`.
- Concessione: `amount = max(amount_attuale, nuovo)`, `ms = max(ms_attuali, ms_nuovi)`. Il Riparo scende con il tempo in **ogni** stato del combattimento (come i buff, F-79) e si toglie a 0.
- Assorbimento: F-193 (dopo `hit_cap_pct`).
Esempi: PV max 400, 15% → **60**; con `ability_mult` 25 su `ward` → floor(400 × 0,15 × 1,25) = **75**; Riparo 20 (2.000 ms) + nuovo 60 (6.000 ms) → **60 per 6.000 ms**; Riparo 60 (1.000 ms) +
nuovo 32 (5.000 ms) → **60 per 5.000 ms**. Test: `tests/systems/combat/conditions/test_ward.gd`.

## Colpi e abilità

### F-190 Danno del giocatore: il moltiplicatore unico `M`
Un solo prodotto `M` per colpo, un solo `floor`, dopo F-24 e prima di F-25 (come oggi `low_hp_damage_mult` ed `execute_mult`):
- **B**: `damage = floor(F-24(tiro) × M)`; **A** e **C**: `damage = floor(F-24(floor(tiro × power_mult)) × M)` (C usa `mult` del `riposte` al posto di `power_mult`); poi F-25 con
  `dr_mult` di `armor_pierce_pct` (solo B, F-120).
- Fattori di `M` (letti **al momento dei tiri**, F-191):

| Fattore | Vale per | Fonte |
|---|---|---|
| `low_hp_damage_mult`, `execute_mult`, `after_ability_mult`, `focus_combo` | B | tratti (F-81, F-120, F-192) |
| Breccia del bersaglio, `status_damage_mult`, `stack_damage`, `damage_trade` (`dealt_pct`), `lone_target_mult` | B, A, C | condizione, tratti |
| `execute` dell'abilità, `ability_mult` (`strike`, `cleave`) | A | abilità, tratti |

Con tutti i fattori a 1 il risultato è quello di oggi (F-22, F-80). Esempi: tiro 40, neutro, DR 0, Slancio a 3 accumuli (×1,15), `damage_trade` 25 (×1,25), Breccia 15 (×1,15) →
`M` = 1,653125 → floor(66,125) = **66**; abilità ×1,3 sul bersaglio con 25/100 PV ed `execute` 30% ×2,5, tiro 40, DR 10 → floor(52) = 52 → floor(130) = 130 → **117**; stesso colpo
con 31/100 PV → 52 → floor(46,8) = **46**. Test: `tests/systems/combat/test_player_damage_mult.gd`.

### F-191 Abilità: parametri nuovi e tipo `ward` (estende F-79 e F-80)
- **`ward`**: `amount` di F-189 con `ward_pct`; si usa (F-79) solo in un incontro e se `amount > ` Riparo attuale; poi F-189.
- **`heal`** con `ability_mult`: `floor(max_hp × heal_pct / 100 × A)` (con `A` = 1 è F-80).
- **`hits`** (solo `strike`, default 1): `hits` coppie di tiri (F-23, poi F-22 se a segno) sullo stesso bersaglio, **tutte prima** (F-80); applicate in ordine; quando il bersaglio è morto i
  colpi rimasti si scartano **senza evento**.
- **`target`** (`first`, `lowest_hp`, `highest_hp`; default: la regola dei tratti, F-76): sceglie il bersaglio di `strike`.
- **`execute`** `{hp_pct, mult}`: fattore `mult` in `M` se, al momento dei tiri, `hp × 100 ≤ max_hp × hp_pct` del bersaglio.
- **`apply`**: lista di condizioni `{condition, pct?, ms}` (F-185) applicate dopo ogni colpo a segno sul bersaglio ancora vivo; `bleed` usa il danno `D` di quel colpo.
- **`drain_pct`**: dopo ogni colpo con danno `D` > 0, cura `floor(D × drain_pct / 100)` (insieme al rubavita, stesso passo, non oltre i PV massimi).
- Ordine di un uso: `ability_used(id, bersagli senza ripetizioni)` → per ogni colpo in ordine: `combat_hit` → danno → condizioni (`apply`) → `on_hit` (rubavita, accumuli) e `drain_pct` →
  poi cura o Riparo dell'abilità → `on_ability` (F-192). Le uccisioni a metà chiamano `on_kill` come oggi.
Esempi: Pioggia di tagli 5 × 0,5, DR 0, nemico con 20 PV, tiri [20, mancato, 14, 30, 8] → 10, —, 7, 15, — : PV 20 → 10 → 3 → 0; **4 eventi** `combat_hit` (il mancato compreso), il quinto colpo
scartato. Tagli incrociati 3 × 0,5 con `bleed` 30% in 4.000 ms, danni 10, mancato, 12 → total 3 e 3 → left **6**, ticks 4 → scatti **2, 2, 1, 1**. Lama assetata ×1,8, danno 54, `drain_pct` 30 →
cura **16** (più 2 con Linfa vitale 5%). Guardia alta con PV max 400 e Riparo attuale 70 → **non** si usa (60 ≤ 70); con Riparo 20 → si usa, Riparo 60.
Test: `tests/systems/combat/test_abilities_m28.gd`.

### F-192 Tipi di effetto dei tratti di M28 (estende F-81)
Agganci nuovi: `on_evade` (un attacco nemico manca: F-23 fallito; mai per impulsi e Monoliti), `on_ability` (dopo un uso, F-191). Gli agganci esistenti ricevono anche il bersaglio, il
tipo di colpo e la sorgente (contratto). Stato salvato solo per i tipi indicati (al massimo **un** effetto con stato per tratto).

| Tipo | Parametri | Aggancio | Regola | Stato | Esempio |
|---|---|---|---|---|---|
| `stack_damage` | `gain` (`kill`, `hit`, `block`, `evade`), `pct`, `max`, `lose` (`damaged`, `encounter`, `none`) | gain, `on_damaged`, `on_encounter_start` | `s = min(max, s+1)` a ogni evento `gain` (`hit` = colpo B/A/C a segno); `s = 0` a `lose` (`damaged` = PV persi > 0 dopo il Riparo); fattore `1 + s × pct/100` in `M` (B, A, C) | `{"stacks"}` | Slancio: 3 uccisioni → ×1,15; colpo subito di 12 → 0; colpo parato o tutto nel Riparo → resta 3 |
| `stack_haste` | come sopra | come sopra | dopo ogni colpo base il nuovo timer è `max(combat.min_attack_interval_ms, floor(intervallo × Π(1 − s × pct/100)))` (con `s` prima dei colpi di quell'attacco) | `{"stacks"}` | intervallo 2.000, pct 3: s 4 → **1.760**; s 8 → **1.520**; intervallo 900, s 8 → 684 → **800** |
| `focus_combo` | `pct`, `max` | `on_hit` (B), `on_encounter_start` | sul bersaglio principale dell'attacco base: fattore `1 + c × pct/100` (B) con `c` = colpi base a segno consecutivi già dati a quel bersaglio, massimo `max`; cambio di bersaglio principale → `c = 0`; i bersagli in più di `every_nth_attack_all` non contano | `{"target", "count"}` | pct 6, max 5, sempre lo stesso: ×1,00, 1,06, 1,12, 1,18, 1,24, 1,30, 1,30; altro bersaglio → ×1,00 |
| `riposte` | `on` (`block`, `evade`), `mult` | `on_block`, `on_evade` | contrattacco **C** subito sulla sorgente viva (nessuno per l'impulso): F-23 e F-22 della mano principale, `floor(tiro × mult)` → F-24 → `M` → F-25; non parabile; chiama `on_hit`; un solo contrattacco per attacco nemico (il `mult` più alto) | — | parata, tiro 30, ×0,8, neutro, DR 10 → 24 → **21** |
| `damage_trade` | `dealt_pct` > 0, `taken_pct` > 0 | `modify` del danno | fattore `1 + dealt_pct/100` in `M` (B, A, C); `1 + taken_pct/100` sul danno subito (F-193) | — | vedi F-190, F-193 |
| `apply_on_hit` | `every` (1..20), `condition`, `pct`, `ms` | `on_hit` (B) | conta i colpi base a segno; a ogni multiplo di `every` applica la condizione al bersaglio di quel colpo se vivo (F-185; `bleed` con il suo `D`) | `{"count"}` | every 3, bleed 40%, 4.000: 3° colpo con D 30 → total 12 → 3, 3, 3, 3 |
| `status_damage_mult` | `condition`, `pct` | `M` | fattore `1 + pct/100` (B, A, C) se il bersaglio ha la condizione (`stagger` = finestra "sbilanciato") | — | contro chi sanguina, 20 → ×1,2 |
| `kill_cooldown_cut` | `ms` | `on_kill` | ogni ricarica attiva `t = max(0, t − Σ ms)` (le durate dei buff non cambiano) | — | 1.500: 4.000 e 800 → **2.500** e **0** |
| `after_ability_mult` | `mult` | `on_ability`, attacco base | dopo un uso di un'abilità qualsiasi è "carico"; il colpo base successivo ha il fattore `mult` (B, tutti i suoi bersagli), poi si scarica (anche se manca) | `{"armed"}` | ×1,5, tiro 20, DR 0 → **30** |
| `ward_on` | `on` (`kill`, `block`, `encounter_start`), `pct`, `ms` | l'aggancio indicato | Riparo `floor(max_hp × pct/100)` per `ms` (F-189); più effetti sullo stesso evento: il più grande | — | uccisione, max 500, 8% → **40** per 6.000 ms |
| `ability_mult` | `kinds` (sottoinsieme di `strike`, `cleave`, `heal`, `ward`), `pct` | `M`, importi | fattore `1 + pct/100`: in `M` per A dei tipi indicati; sulla cura (F-191) e sul Riparo (F-189) se indicati | — | cura 20% di 170 PV, 25 → floor(42,5) = **42** |
| `lone_target_mult` | `pct` | `M` | fattore `1 + pct/100` (B, A, C) se al momento dei tiri c'è un solo nemico vivo (Monoliti ed evocati compresi) | — | 1 vivo → ×1,25; 2 vivi → ×1 |

Più effetti dello stesso tipo si **moltiplicano** (fattori) o si **sommano** (`kill_cooldown_cut`), salvo dove è scritto "il più alto/grande". Tipi di F-120 ammessi nei tratti: `execute_mult`,
`hit_cap_pct`, `armor_pierce_pct`, `kill_heal_pct`, `block_heal_pct`, `stat_convert`, `double_hit_pct`, con le regole di F-120.
Test: `tests/systems/combat/effects/test_<tipo>.gd` (uno per tipo).

### F-193 Ordine di risoluzione (estende F-76) e danno subito
**Istante** (dopo il consumo del tempo, F-185): (1) colpo base del giocatore: `before_attack`, tiri (con `M`), mano e nuovo timer (`stack_haste`), colpi in ordine: `combat_hit` → danno →
`on_hit` (rubavita, accumuli, combo, `apply_on_hit`) → colpo in più di F-120; `after_ability_mult` si scarica; (2) abilità pronte in ordine di slot (F-191); (3) nemici per posizione:
attacco → mancato: `on_evade` (contrattacco, accumuli `evade`) / parato: `on_block` (cura, Riparo, contrattacco, accumuli `block`) / a segno: danno subito (sotto); abilità del boss;
(4) impulso della Frattura; (5) scatto del Sanguinamento se `clock = 0` (F-186). Ogni uccisione: `on_kill` (F-81, F-120, `kill_cooldown_cut`, `ward_on`, accumuli `kill`) come oggi.
**Danno subito** con `d0` > 0 (dopo F-25, l'impulso del Monolito o della Frattura, il colpo pesante del boss):
`d1 = max(1, floor(d0 × (1 − w/100) × Π(1 + taken_pct/100)))` (`w` = Fiacchezza della sorgente, 0 senza) → `hit_cap_pct` (F-120) → `d2` → Riparo: `a = min(ward, d2)`, `ward −= a`,
`d3 = d2 − a`. Se `d3 = 0` fine (nessun PV perso, nessun `on_damaged`, niente cibo, accumuli `damaged` intatti). Altrimenti PV −`d3`, morte, `on_damaged(d3)` (riflesso su `d3`,
accumuli persi), cibo automatico (F-30). Con `w = 0`, nessun `damage_trade` e Riparo 0 è il percorso di oggi.
Esempi: `d0` 25 (F-25: tiro 40, Armatura 100), Fiacchezza 25 → floor(18,75) = **18**; con `taken_pct` 20 → floor(22,5) = **22**; solo `taken_pct` 20 → **30**; `d0` 1, Fiacchezza 25 → **1**.
Riparo 60, `d1` 25 → Riparo 35, nessun danno; poi `d1` 50 → Riparo 0, PV −**15**, `on_damaged(15)`. PV max 400, `hit_cap_pct` 25, Riparo 60, `d1` 180 → 100 → PV −**40**.
Test: `tests/systems/combat/test_damage_taken_m28.gd`, `tests/systems/combat/test_resolution_order_m28.gd`.

### F-194 Equilibrio: nessun tratto né abilità domina (`tools/sim_combat.gd`)
Misura di M28-08 sui dati veri, seme 1234 (più un secondo seme per i casi al limite), `hours=1`, `scope=all`, `grade=auto`, livello fisso `L` ∈ {25, 50, 80, 95} nell'area il cui intervallo
contiene `L`, per ogni assetto (`greatsword`, `sword_shield`, `dual`, `sword`). Metriche: uccisioni/h `K`, morti/h `D`, cibo/h `F`.
- **Gruppi**: (a) **abilità**: nessun tratto, una sola abilità alla volta (ognuna sbloccata a `≤ L` e ammessa dall'assetto) più il caso "nessuna"; (b) **tratti**: nessuna abilità, un solo tratto
  alla volta più "nessuno".
- **(1) Nessuno domina**: in ogni gruppo nessuna voce `x` ha insieme `K_x ≥ 1,10 × max K` delle altre, `D_x ≤` e `F_x ≤` di tutte le altre.
- **(2) Nessuno è inutile**: ogni voce, in almeno un gruppo in cui è disponibile, ha `K ≥ 0,85 ×` mediana del gruppo **oppure** il `D` o l'`F` più basso del gruppo (ruolo difensivo);
  una voce di sola utilità (`target_rule`, `opening_strike`) è esente.
- **(3) Nessuna corsa alla potenza**: per ogni assetto e `L`, il migliore di tre equipaggiamenti completi con i contenuti di M28 (offensivo, difensivo, sinergia: elencati nel report di M28-08)
  ha `K ≤ 1,15 ×` quello di `loadout=auto` (i contenuti di M27, che restano primi nel file) e `D` non più alto.
- **(4) Nessuna regressione**: `loadout=auto` dà gli stessi numeri di `main` prima di M28 (stessi tiri).
Se (1)-(3) falliscono si ritoccano **solo** i valori dei contenuti nuovi (M28-09), mai quelli esistenti né l'economia (Q122, Q178).

---

## 9f. Chiavi di `balance.json` (M28)
| Chiave | Valore | Formula |
|---|---|---|
| `combat.conditions.tick_ms` | 1000 | F-186 |
| `combat.conditions.stagger_immunity_ms` | 4000 | F-188 |
Invariati: `traits.slot_levels` `[1, 10, 25, 50]`, `abilities.slot_levels` `[1, 1, 30]` (F-78, Q171).
