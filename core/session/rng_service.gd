class_name RngService
extends RefCounted
## The session's only source of randomness: a RandomNumberGenerator whose seed and state are saved in the slot,
## so a loaded game continues the same sequence it would have produced without the reload.
##
## The seed is always passed in from outside (a new seed from the clock is chosen by Game).
## `roll_pct` with a certain outcome (<= 0 or >= 100) does not consume a number, so adding a 0% or 100% check
## never shifts the rest of the sequence.

const LOG_CATEGORY: String = "rng"
const SEED_KEY: String = "seed"
const STATE_KEY: String = "state"
# Largest integer a JSON number (double) holds exactly: larger states are saved as strings.
const MAX_EXACT_JSON_INT: int = 9007199254740992

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_rng.seed = seed_value


## Uniform float in [0, 1].
func randf() -> float:
	return _rng.randf()


## Uniform integer in [from, to], both included.
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## True with probability chance_pct / 100. Certain outcomes consume nothing.
func roll_pct(chance_pct: float) -> bool:
	if chance_pct <= 0.0:
		return false
	if chance_pct >= 100.0:
		return true
	return _rng.randf() * 100.0 < chance_pct


## Index chosen with probability weight / sum of weights. Weights must be >= 0 with a positive sum:
## otherwise it is a programming error and the result is -1 (nothing consumed).
func pick_weighted(weights: Array[int]) -> int:
	var total: int = 0
	for weight: int in weights:
		if weight < 0:
			push_error("RngService.pick_weighted: negative weight %d" % weight)
			assert(false, "negative weight")
			return -1
		total += weight
	if total <= 0:
		push_error("RngService.pick_weighted: weights without a positive sum")
		assert(false, "no positive weight")
		return -1
	var roll: int = _rng.randi_range(0, total - 1)
	for i: int in weights.size():
		if roll < weights[i]:
			return i
		roll -= weights[i]
	return weights.size() - 1


## {"seed": int, "state": int}; the state becomes a decimal string when JSON could not hold it exactly.
func to_save() -> Dictionary:
	var state: int = _rng.state
	var saved_state: Variant = state
	if absi(state) > MAX_EXACT_JSON_INT:
		saved_state = str(state)
	return {SEED_KEY: _rng.seed, STATE_KEY: saved_state}


## Restores seed and state (numbers may arrive as float or string). Malformed values are reported and the
## current generator is left untouched.
func from_save(d: Dictionary) -> void:
	var seed_value: Variant = _to_int(d.get(SEED_KEY))
	var state: Variant = _to_int(d.get(STATE_KEY))
	if seed_value == null or state == null:
		Log.warn(LOG_CATEGORY, "invalid rng block %s: generator kept" % str(d))
		return
	_rng.seed = seed_value
	_rng.state = state


# int from an int, an integral float or a decimal string; null otherwise.
func _to_int(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			var f: float = v
			if f != floorf(f):
				return null
			return int(f)
		TYPE_STRING:
			var s: String = v
			if not s.is_valid_int():
				return null
			return s.to_int()
	return null
