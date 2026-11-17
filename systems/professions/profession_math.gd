class_name ProfessionMath
extends RefCounted
## Colored recipes (docs/02_FORMULAS_M26.md F-167, F-168): pure integer logic, no state, no random numbers.
## Thresholds come from the data (`ActionDef.colors`: yellow, green, grey; F-166); nothing about them lives here.

const PPM: int = 1000000
const LOG_CATEGORY: String = "professions"
const KEY_YELLOW: StringName = &"yellow"
const KEY_GREEN: StringName = &"green"
const KEY_GREY: StringName = &"grey"
const COLOR_ORANGE: StringName = &"orange"


## F-167: &"orange" below the yellow threshold, &"yellow" below green, &"green" below grey, else &"grey". &"" without colors.
static func color_id(colors: Dictionary, level: int) -> StringName:
	if colors.is_empty():
		return &""
	if level < int(colors[KEY_YELLOW]):
		return COLOR_ORANGE
	if level < int(colors[KEY_GREEN]):
		return KEY_YELLOW
	if level < int(colors[KEY_GREY]):
		return KEY_GREEN
	return KEY_GREY


## F-167: skill-up probability in ppm: PPM below yellow, 0 from grey, linear in between. PPM without colors.
static func chance_ppm(colors: Dictionary, level: int) -> int:
	if colors.is_empty():
		return PPM
	var yellow: int = int(colors[KEY_YELLOW])
	var grey: int = int(colors[KEY_GREY])
	if level < yellow:
		return PPM
	if level >= grey:
		return 0
	return (grey - level) * PPM / (grey - yellow)


## F-168: t = frac + xp x chance; returns (base = t / PPM, new frac = t mod PPM). Invalid input: error and (0, 0).
static func split_xp(xp: int, chance: int, frac: int) -> Vector2i:
	if xp < 0 or chance < 0 or chance > PPM or frac < 0 or frac >= PPM:
		Log.error(LOG_CATEGORY, "split_xp: invalid xp %d, chance %d or frac %d" % [xp, chance, frac])
		return Vector2i.ZERO
	var total: int = frac + xp * chance
	return Vector2i(total / PPM, total % PPM)
