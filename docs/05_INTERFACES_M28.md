# 05. Interfacce, M28: Abilità e tratti v2 (§3f, §4e, §5.10b, §5.10c, §6f, §7.aa)

Estensione di `05_INTERFACES.md` (che supera le 400 righe): **è contratto** con le stesse regole (lo modifica solo il Reviewer; un task che ha bisogno di una firma nuova si ferma e la
chiede). Dove contraddice `05_INTERFACES.md` (§5.10 Combattimento, §6 save) o `_M24`…`_M27` vale questo file. Design `01_GDD_M28.md` (§40), formule `02_FORMULAS_M28.md`
(F-185…F-194), dati `04_DATA_SCHEMA_M28.md` (§33). Accanto a ogni firma il task che la scrive. Nessun motivo nuovo in `reasons.gd`; nessuna sorgente nuova in `ModifierService`.

## 3f. Segnali (`core/autoload/event_bus.gd`, M28-03)
```gdscript
signal combat_condition_damage(target: int, damage: int, condition: StringName)   # F-186: uno per scatto e nemico, emesso prima del danno (come combat_hit)
```
Invariati: `combat_hit` (anche per i colpi delle abilità a più colpi e per i contrattacchi: `attacker` = -1), `ability_used(ability_id, targets)` (`targets` **senza ripetizioni**, nell'ordine
del primo colpo), `trait_triggered(trait_id)` (anche per i tipi nuovi, a ogni scatto dell'effetto). Le condizioni e il Riparo **non** hanno segnali propri: la UI li legge da `get_state()` (§5.10b).

## 4e. Dati (`core/data/`)
```gdscript
# M28-03: core/data/defs/condition_apply.gd
class_name ConditionApply extends RefCounted
const BLEED: StringName = &"bleed"; const WEAKEN: StringName = &"weaken"; const EXPOSE: StringName = &"expose"; const STAGGER: StringName = &"stagger"
const ALL: Array[StringName] = [BLEED, WEAKEN, EXPOSE, STAGGER]
var condition: StringName; var pct: float = 0.0; var ms: int = 0
static func from_dict(d: Dictionary) -> ConditionApply      # null (con log, DefReader) se malformata

# M28-03: core/data/defs/condition_params.gd + GameData.conditions() -> ConditionParams
class_name ConditionParams extends RefCounted
var tick_ms: int; var stagger_immunity_ms: int                # combat.conditions (§33.1)

# M28-04: AbilityDef (core/data/defs/ability_def.gd), campi aggiunti (default = comportamento di oggi)
const KIND_WARD: StringName = &"ward"
var hits: int = 1; var target_rule: StringName = &""          # &"" = la regola dei tratti (F-76)
var execute_hp_pct: float = 0.0; var execute_mult: float = 1.0 # execute assente = 0 / 1
var applies: Array[ConditionApply] = []; var drain_pct: float = 0.0; var ward_pct: float = 0.0
```
`TraitEffectDef` invariato (`type`, `params`). Validatori: `DataValidatorAbilities` (nuovo file, `core/data/data_validator_abilities.gd`, estratto in M28-02 da `DataValidatorTraits` senza
cambiare regole; M28-04 aggiunge §33.3), `DataValidatorTraits` (M28-05 aggiunge §33.4), chiavi `combat.conditions` nel validatore di `balance.json` (M28-03).

## 5.10b Combattimento: condizioni e cablaggio del motore (M28-02, M28-03)
**Refactor senza cambi di comportamento (M28-02)**: `combat_fight.gd` (397 righe) si divide: le funzioni del ciclo (viaggio, nodo, `_cleared`, `_dungeon_cleared`, `_arrive`,
`_resolve_node`, `_finish_node`, `_start_travel`, `_announce_travel`) vanno in `systems/combat/combat_cycle.gd`, `class_name CombatCycle extends CombatState`, e `CombatFight extends CombatCycle`.
API pubblica di `CombatEngine` invariata. Obiettivo: `combat_fight.gd` ≤ 300 righe dopo M28-02 e ≤ 380 dopo M28-03 (altrimenti un helper `PlayerStrikes` statico per i colpi).
```gdscript
# M28-03: systems/combat/conditions/enemy_conditions.gd
class_name EnemyConditions extends RefCounted
var bleed_left: int = 0; var bleed_ticks: int = 0
var weaken_pct: float = 0.0; var weaken_ms: int = 0; var expose_pct: float = 0.0; var expose_ms: int = 0
var stagger_ms: int = 0; var immune_ms: int = 0
func has(condition: StringName) -> bool                        # stagger = finestra "sbilanciato" (F-188)
## F-185…F-188. `damage` = D del colpo (solo per bleed); `stagger_ok` = false per boss e Monoliti; `timer_ms` del nemico allungato da stagger.
## Ritorna il nuovo timer del nemico (invariato se non è stagger o è ignorato).
func apply(app: ConditionApply, damage: int, timer_ms: int, stagger_ok: bool, params: ConditionParams) -> int
func elapse(ms: int) -> void                                   # durate e immunità; mai bleed (scatti)
func bleeds() -> bool
func take_tick() -> int                                        # F-186: d = ceil(left / ticks), aggiorna left e ticks
func is_empty() -> bool
func to_save() -> Dictionary                                   # §6f; {} se vuote
static func from_save(d: Variant) -> EnemyConditions           # tollerante (F-185), mai null
func view() -> Dictionary                                      # §5.10b get_state

# M28-03: systems/combat/conditions/player_ward.gd
class_name PlayerWard extends RefCounted
var amount: int = 0; var ms: int = 0
func grant(new_amount: int, new_ms: int) -> void               # F-189 (max e max)
func absorb(damage: int) -> int                                # F-193: ritorna il danno che resta
func elapse(ms: int) -> void; func clear() -> void; func active() -> bool
func to_save() -> Dictionary; static func from_save(d: Variant) -> PlayerWard

# M28-03: systems/combat/conditions/bleed_clock.gd
class_name BleedClock extends RefCounted
var ms: int = -1                                               # -1 = spento
func start_if_idle(params: ConditionParams) -> void; func elapse(ms: int) -> void
func due() -> bool; func next_ms() -> int                      # AbilityRunner.NO_TIMER se spento
func rearm(any_bleeding: bool, params: ConditionParams) -> void
```
- `Encounter.Enemy` (M28-03): `var conditions: EnemyConditions` (nuovo a ogni nemico); `func stagger_immune() -> bool` (boss di Frattura o dungeon, Monolito). `Encounter.to_save` scrive
  `"cond"` solo se non vuote; `from_save` lo legge (tollerante). Nuovo statico (usato da abilità e contrattacchi, F-190):
  `static func roll_power_attack(attacker: CombatantStats, defender: CombatantStats, power_mult: float, damage_mult: float, rng: RngService, data: GameData, dr_mult: float = 1.0) -> Dictionary`
  (stessi tiri e stesso risultato di `AbilityRunner._roll` di oggi quando `damage_mult` = 1). `roll_attack` invariato.
- **Motore** (`CombatFight`, M28-03): chiama tutti gli agganci di F-193 (anche quelli che con i tipi di oggi non fanno nulla): `_next_timer` include `BleedClock.next_ms()`; `_consume` fa
  `elapse` di condizioni, Riparo e orologio; `_hurt_player` segue F-193; `_enemy_attack` chiama `on_evade`/`on_block` con `source_index` e il contrattacco; `_apply_hits` scarta i colpi su
  bersagli morti (nessun evento), applica le condizioni dei colpi, il `drain` e chiama `on_hit` con il contesto del colpo; `_use_abilities` passa a `AbilityRunner` il calcolo di `M` e chiama
  `on_ability`; `_kill` applica `cooldown_cut_ms` e `ward_on`. **Vincolo**: con i soli contenuti di M27 stessi eventi, stessi tiri, stessi numeri (test di non regressione).
- `CombatEngine.get_state()` (§5.10, `CombatView`), chiavi aggiunte: in ogni voce di `enemies` `"conditions": {"bleed": {"left", "ticks"}, "weaken": {"pct", "ms"}, "expose": {"pct", "ms"},
  "stagger": {"ms"}, "immune_ms"?}` (solo quelle attive; `{}` se nessuna); in testa `"ward": {"amount": int, "ms": int}` (`{}` se nessuno).

## 5.10c Effetti dei tratti e abilità (M28-03 interfaccia, M28-04 abilità, M28-05 tipi)
```gdscript
# EffectContext (systems/combat/effects/effect_context.gd), M28-03. Input aggiunti:
var target_index: int = -1; var primary_index: int = -1        # bersaglio del colpo; bersaglio principale dell'attacco base
var target_hp: int = 0; var target_max_hp: int = 0; var target_conditions: EnemyConditions = null
var alive_count: int = 0; var source_index: int = -1           # sorgente di on_block / on_evade / on_damaged (-1 = nessuna)
var hit_kind: StringName = &""                                 # &"base", &"ability", &"counter" (costanti HIT_BASE, HIT_ABILITY, HIT_COUNTER)
var ability_kind: StringName = &""                             # tipo dell'abilità (on_ability, ability_mult)
var damage: int = 0                                            # D del colpo (on_hit)
# Uscite aggiunte:
var counter_mult: float = 0.0                                  # riposte: il più alto (0 = nessun contrattacco)
var ward_pct: float = 0.0; var ward_ms: int = 0                # ward_on: il più grande
var cooldown_cut_ms: int = 0                                   # kill_cooldown_cut: somma
var applies: Array[ConditionApply] = []                        # apply_on_hit
var timer_mult: float = 1.0                                    # stack_haste: prodotto

# TraitEffect (base, default neutri), M28-03:
func on_evade(_ctx: EffectContext) -> void
func on_ability(_ctx: EffectContext) -> void
func hit_mult(_ctx: EffectContext) -> float                    # fattore di M (F-190) per B/A/C; usa hit_kind e target_*; default 1.0
func incoming_mult(_ctx: EffectContext) -> float               # damage_trade.taken (F-193); default 1.0
func amount_mult(_ctx: EffectContext) -> float                 # ability_mult su heal/ward (ability_kind); default 1.0
func base_timer_mult(_ctx: EffectContext) -> float             # stack_haste (F-192); default 1.0
func has_state() -> bool                                       # true per i tipi con stato (validatore e EffectSet)
# Agganci esistenti invariati nella firma; on_hit / on_block / on_damaged / on_kill / on_encounter_start ricevono i nuovi input.

# EffectSet, M28-03 (composizione in ordine di slot; prodotti / somme / massimi come F-192):
func evade(ctx: EffectContext) -> void
func ability(ctx: EffectContext) -> void
func hit_mult(ctx: EffectContext) -> float
func incoming_mult(ctx: EffectContext) -> float
func amount_mult(ctx: EffectContext) -> float
func base_timer_mult(ctx: EffectContext) -> float
# M28-05: create_typed riconosce i 12 tipi di F-192 (un file ciascuno in systems/combat/effects/)
```
- **Tipi nuovi** (M28-05), un file e una classe ciascuno: `stack_damage.gd` (`StackDamage`), `stack_haste.gd` (`StackHaste`), `focus_combo.gd` (`FocusCombo`), `riposte.gd` (`Riposte`),
  `damage_trade.gd` (`DamageTrade`), `apply_on_hit.gd` (`ApplyOnHit`), `status_damage_mult.gd` (`StatusDamageMult`), `kill_cooldown_cut.gd` (`KillCooldownCut`),
  `after_ability_mult.gd` (`AfterAbilityMult`), `ward_on.gd` (`WardOn`), `ability_mult.gd` (`AbilityMult`), `lone_target_mult.gd` (`LoneTargetMult`). Gli effetti non toccano mai
  motore né sessione (regola di `EffectContext`); lo stato (`to_save`) come oggi, chiave = id del tratto.
- **AbilityRunner** (M28-03 firma, M28-04 regole):
```gdscript
## `mult_of(def: AbilityDef, target_index: int) -> float`: M di F-190 per un colpo A (target_index ≥ 0) o il fattore
## dell'importo di heal/ward (target_index = -1). Callable vuoto = 1.0. `ward_amount` = Riparo attuale (F-191).
func take_due(encounter: Encounter, hp: int, stats: CombatantStats, rule: StringName,
		mult_of: Callable = Callable(), ward_amount: int = 0) -> Use
func cut_cooldowns(ms: int) -> void                            # kill_cooldown_cut (F-192)
class Use: (aggiunti) var ward: int = 0; var ward_ms: int = 0; var kind: StringName = &""
#   attacks[k] aggiunge "drain": int e "applies": Array[ConditionApply]; targets allineato ad attacks (ripetuto con hits > 1)
```
  Con `mult_of` vuoto e `ward_amount` 0 `take_due` dà gli stessi tiri e risultati di oggi.
- **LoadoutDescribe** (`core/guide/loadout_describe.gd`, M28-07): testi per i tipi di F-192, per i tipi di F-120 ammessi nei tratti e per i parametri nuovi delle abilità (§33.3); le parti
  nuove in `core/guide/loadout_describe_effects.gd` (`class_name LoadoutDescribeEffects`, statico) per stare sotto le 400 righe. Firme pubbliche invariate (`trait_text`, `ability_text`).

## 6f. Salvataggio (v11 invariato, aggiunte **additive**, nessuna migrazione)
Nel modulo `combat` (solo se non vuote; assenti = nessuna condizione; nessuna è scritta con il combattimento fermo):
```json
"enemies": [{"monster": "plains_boar", "hp": 14, "timer_ms": 2700,
             "cond": {"bleed": {"left": 8, "ticks": 2}, "weaken": {"pct": 25, "ms": 3000}, "expose": {"pct": 15, "ms": 1200},
                      "stagger_ms": 900, "immune_ms": 3400}}],
"cond_clock_ms": 600,
"ward": {"amount": 35, "ms": 4200},
"effects": {"momentum": {"stacks": 3}, "fixed_gaze": {"target": 1, "count": 4}, "technique_echo": {"armed": true}, "open_wounds": {"count": 2}}
```
Lettura tollerante (F-185): valori fuori intervallo limitati, malformati scartati con `Log.warn`; `cond_clock_ms` senza nessun nemico che sanguina → spento; `ward` con `ms` 0 → nessuno.
Un save di M27 si carica identico (nessuna chiave nuova); un save di M28 caricato da M27 perderebbe solo condizioni e Riparo dell'incontro in corso (le chiavi in più sono ignorate).
`format_version` resta **11**. Test: `tests/systems/combat/test_combat_save_m28.gd` (salva → carica → salva identico con ogni condizione, Riparo, orologio e stato dei tipi nuovi).

## 7.aa UI di M28 (nessuno stato di gioco nella UI, solo letture e comandi; `01_GDD_M28.md` §40.9)
- **Scheda Tratti e abilità** (`ui/pages/character/loadout_panel.gd`, `loadout_card.gd`): interruttore "Solo assetto attuale" (predefinito acceso; stato di presentazione) e ordine per
  `unlock_level`; testo da `LoadoutDescribe`; comandi invariati (`Loadout.set_trait`, `set_ability`). Se `loadout_panel.gd` supera 300 righe, il filtro va in un file proprio.
- **Combattimento** (`ui/pages/combat/`): sui riquadri dei nemici le condizioni di `get_state().enemies[i].conditions` (icona e secondi; per `bleed` il danno rimasto); sul giocatore il Riparo
  (`get_state().ward`) come strato sopra la barra dei PV; numeri di `combat_condition_damage` con un colore del tema (nessun colore nuovo fuori da `ui/theme/`). Icone in
  `assets/icons/conditions/{bleed,weaken,expose,stagger,ward}.svg` (segnaposto).
- **Guida**: pagina `data/guide/condizioni.json` (≤ 160 parole, sezione `character`), collegata dalle pagine Tratti e Abilità.
- Smoke test: `tests/ui/test_loadout_panel_smoke.gd` (clic **veri** sull'interruttore e su una carta), `tests/ui/test_combat_conditions_smoke.gd` (stato con condizioni e Riparo disegnato).

## 8. Deviazioni dal contratto emerse in M28 (M28-10)
Il codice differisce in questi punti dal testo sopra; vale il codice, il contratto è allineato qui.
- **M28-03**: `DataValidatorM14` è agganciato a `DataValidatorConditions`; `game_data.gd` compattato (resta sotto le 400 righe).
- `AbilityRunner.next_ms(hp, max_hp, ward_amount, mult_of, ward_ms)`: parametri in più rispetto alla firma di §5.10c (la scadenza del Riparo è un evento per `next_ms`, M28-08b).
- `EffectContext.HIT_EXTRA`: costante nuova per i colpi aggiuntivi delle abilità `hits`.
- `Enemy.immune_to` e `stagger_immune` (Monolito e boss: immuni alle condizioni/Sbilanciamento, Q175).
- Il timer del nemico nel save è limitato a `interval + stagger_ms` (lettura tollerante).
- `cut_cooldowns(ms <= 0)` ritorna subito; Riparo e orologio del Sanguinamento sono azzerati a start, stop, morte e fine dell'incontro.
- `StackBase`: classe base comune degli accumuli dei tratti nuovi.
- **Da unificare**: la validazione delle condizioni è duplicata in `_effect_condition` e `DataValidatorAbilities.apply_entry`.
- F-194 (3) ridefinita (`02_FORMULAS_M28.md`, Q178): riferimento = miglior equipaggiamento M27 puro; `loadout=auto` non è più il riferimento M27.

## 9. Esito di Q171-Q182
Tutte con il default del design (vedi `OPEN_QUESTIONS.md`): slot invariati, critico e albero rimandati, "Sciame di tagli", immunità 4 s, un solo orologio, Fiacchezza sul danno del nemico,
filtro "Solo assetto attuale", `setup=sword`, niente tipi nuovi nei leggendari, tabelle approvate; Q178 con la ridefinizione di (3).
