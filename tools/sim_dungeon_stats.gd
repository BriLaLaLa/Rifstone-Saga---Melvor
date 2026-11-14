extends RefCounted
## Thresholds and statistics of tools/sim_dungeon.gd (docs/02_FORMULAS.md F-144): the bands, the summary of a batch of runs and the checks.

const DUNGEON_ID: StringName = &"monkey_den"
const HOUR_MS: int = 3_600_000
const RECOMMENDED: int = 45
## Win rate by character level (policy random). Calibrated on the engine (M22-07): the heroes of level 35 and 40 meet a cliff
## (the grade of the set jumps), so their bands are low; see F-144.
const WIN_BANDS: Dictionary = {35: [0.0, 0.10], 40: [0.10, 0.40], 45: [0.85, 0.97], 55: [0.98, 1.0]}
## Food of the hero with the tier-1 rations: mean pieces per run (measured 33-45, see F-144).
const FOOD_MEAN_MAX: int = 55
## Gross hp lost per room (% of the max hp of a level-45 hero with tier-1 rations): ceilings, F-144.
const ROOM_CEILING: Dictionary = {"pack": 220.0, "horde": 190.0, "elite": 100.0, "miniboss": 350.0}
const BOSS_LOSS_MAX: float = 2600.0


static func check_level(level: int, s: Dictionary) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var band: Array = WIN_BANDS.get(level, [])
	if not band.is_empty() and (s["won"] < float(band[0]) or s["won"] > float(band[1])):
		failures.append("level %d wins %.1f%% not in %d-%d%%" % [level, s["won"] * 100.0, roundi(float(band[0]) * 100.0), roundi(float(band[1]) * 100.0)])
	if level != RECOMMENDED:
		return failures
	check_range(failures, "duration (min, mean)", s["min_mean"], 12.0, 20.0)
	if s["min_p90"] >= 30.0:
		failures.append("duration p90 %.1f min >= 30" % s["min_p90"])
	if s["food_runs"] < 0.70:
		failures.append("food used in %.0f%% of the runs (< 70)" % (s["food_runs"] * 100.0))
	if s["food_mean"] > FOOD_MEAN_MAX:
		failures.append("food %.0f pieces per run on average (> %d)" % [s["food_mean"], FOOD_MEAN_MAX])
	check_range(failures, "pieces per won run", s["pieces"], 4.0, 7.0)
	if s["rare"] < 1.2:
		failures.append("rare or better per won run %.2f < 1.2" % s["rare"])
	check_range(failures, "dust per won run", s["dust"], 70.0, 130.0)
	check_range(failures, "crystals per won run", s["crystals"], 3.0, 6.0)
	check_range(failures, "gold per won run", s["gold"], 6000.0, 12000.0)
	check_range(failures, "legendaries per won run (sampled, loose)", s["legend_win"], 0.08, 0.40)
	return failures


static func check_rooms(s: Dictionary) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var rooms: Dictionary = s["rooms"]
	for kind: String in ROOM_CEILING:
		if rooms.has(kind) and rooms[kind][0] > float(ROOM_CEILING[kind]):
			failures.append("%s rooms cost %.1f%% hp (> %.0f)" % [kind, rooms[kind][0], float(ROOM_CEILING[kind])])
	if float(s["boss_loss"]) > BOSS_LOSS_MAX:
		failures.append("boss costs %.0f%% hp (> %.0f)" % [s["boss_loss"], BOSS_LOSS_MAX])
	for kind: String in ["pack", "horde", "elite", "miniboss"]:
		if rooms.has(kind) and float(s["boss_loss"]) < float(rooms[kind][0]):
			failures.append("the boss (%.0f%%) must cost more than a %s room (%.0f%%)" % [s["boss_loss"], kind, rooms[kind][0]])
	return failures


## Expected legendaries per won run: the sum of the chances of the legendaries of the Monkey Den (F-143 point 7).
static func legend_expected(data: Object) -> float:
	var total: float = 0.0
	for item: Object in data.call("items"):
		if item.equip != null and item.equip.legendary != null and item.equip.legendary.source_type == &"dungeon" \
				and item.equip.legendary.source_id == DUNGEON_ID:
			total += float(item.equip.legendary.chance_pct) / 100.0
	return total


static func check_range(failures: PackedStringArray, label: String, value: float, low: float, high: float) -> void:
	if value < low or value > high:
		failures.append("%s %.2f not in %.2f-%.2f" % [label, value, low, high])


static func summarize(runs: Array[Dictionary]) -> Dictionary:
	var n: float = maxf(float(runs.size()), 1.0)
	var won: Array[Dictionary] = runs.filter(func(r: Dictionary) -> bool: return r["outcome"] == "won")
	var w: float = maxf(float(won.size()), 1.0)
	var mins: Array[float] = []
	var food_runs: int = 0
	var food_max: int = 0
	var food_total: int = 0
	var rooms: Dictionary = {}
	var boss_loss: float = 0.0
	var boss_runs: int = 0
	var deaths: Dictionary = {}
	for r: Dictionary in runs:
		mins.append(float(r["ms"]) / 60000.0)
		food_runs += 1 if int(r["food"]) > 0 else 0
		food_max = maxi(food_max, int(r["food"]))
		food_total += int(r["food"])
		if r["died_in"] != "":
			deaths[r["died_in"]] = int(deaths.get(r["died_in"], 0)) + 1
		if r["boss_loss"] >= 0.0:
			boss_loss += float(r["boss_loss"])
			boss_runs += 1
		for kind: String in r["room_loss"]:
			var entry: Array = rooms.get(kind, [0.0, 0])
			entry[0] = float(entry[0]) + float(r["room_loss"][kind][0])
			entry[1] = int(entry[1]) + int(r["room_loss"][kind][1])
			rooms[kind] = entry
	for kind: String in rooms:
		rooms[kind][0] = float(rooms[kind][0]) / maxf(float(rooms[kind][1]), 1.0)
	mins.sort()
	var sums: Dictionary = {"pieces": 0.0, "rare": 0.0, "dust": 0.0, "crystals": 0.0, "gold": 0.0, "cards": 0.0, "legend": 0.0}
	for r: Dictionary in won:
		sums["pieces"] += r["pieces"]
		sums["rare"] += r["rare"]
		sums["dust"] += r["dust"]
		sums["crystals"] += r["crystals"]
		sums["gold"] += r["gold"]
		sums["cards"] += r["cards"]
		sums["legend"] += r["legend"]
	var ms_total: float = 0.0
	for r: Dictionary in runs:
		ms_total += float(r["ms"])
	var won_ms: float = 0.0
	for r: Dictionary in won:
		won_ms += float(r["ms"])
	return {
		"won": float(won.size()) / n, "min_mean": ms_total / n / 60000.0, "min_p90": mins[mini(mins.size() - 1, int(mins.size() * 0.9))] if not mins.is_empty() else 0.0,
		"food_runs": food_runs / n, "food_max": food_max, "food_mean": food_total / n, "pieces": sums["pieces"] / w, "rare": sums["rare"] / w, "dust": sums["dust"] / w,
		"crystals": sums["crystals"] / w, "gold": sums["gold"] / w, "cards": sums["cards"] / w, "legend_win": sums["legend"] / w,
		"legend_run": sums["legend"] / n, "rooms": rooms, "boss_loss": boss_loss / maxf(float(boss_runs), 1.0),
		"hours_per_won": won_ms / w / HOUR_MS, "runs": runs.size(), "deaths": deaths,
	}

