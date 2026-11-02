class_name XpTable
extends RefCounted
## Precomputed experience table (02_FORMULAS.md F-01, reused for mastery F-09).
## delta(L) = floor(base * growth^(L - 1) + linear * (L - 1)) for L = 1..max_level - 1;
## xp_for_level(L) = sum of delta(k) for k = 1..L - 1 (level 1 = 0).
## The curve parameters are never hardcoded: callers pass them from balance.json
## (xp_curve / mastery_curve) through from_params. The xp cap is not part of the table:
## it is applied by whoever grants xp (F-02).

var max_level: int = 0

## _totals[L] = total xp needed to reach level L; index 0 is unused (kept at 0).
var _totals: PackedInt64Array = PackedInt64Array()


static func from_params(base: float, growth: float, linear: float, max_level: int) -> XpTable:
	assert(max_level >= 1, "XpTable: max_level must be >= 1")
	assert(base > 0.0 and growth > 0.0, "XpTable: base and growth must be > 0")
	if max_level < 1 or base <= 0.0 or growth <= 0.0:
		push_error("XpTable: invalid params base=%s growth=%s linear=%s max_level=%d"
				% [base, growth, linear, max_level])
	var table := XpTable.new()
	table._build(base, growth, linear, maxi(max_level, 1))
	return table


## Total xp needed to reach `level` (F-01). Level 1 (or lower) → 0; above max_level → total of max_level.
func xp_for_level(level: int) -> int:
	return _totals[clampi(level, 1, max_level)]


## delta(level): xp from `level` to `level + 1`; 0 at (or above) max_level.
func xp_to_next(level: int) -> int:
	var l: int = clampi(level, 1, max_level)
	if l >= max_level:
		return 0
	return _totals[l + 1] - _totals[l]


## Highest level L <= max_level with xp_for_level(L) <= xp (binary search). Negative xp → 1.
func level_for_xp(xp: int) -> int:
	var lo: int = 1
	var hi: int = max_level
	while lo < hi:
		@warning_ignore("integer_division")
		var mid: int = (lo + hi + 1) / 2
		if _totals[mid] <= xp:
			lo = mid
		else:
			hi = mid - 1
	return lo


## Fraction 0..1 of the way through the current level; 1.0 at max_level.
func progress(xp: int) -> float:
	var level: int = level_for_xp(xp)
	if level >= max_level:
		return 1.0
	var span: int = xp_to_next(level)
	if span <= 0:
		return 1.0
	return clampf(float(xp - _totals[level]) / float(span), 0.0, 1.0)


func _build(base: float, growth: float, linear: float, levels: int) -> void:
	max_level = levels
	_totals.resize(levels + 1)
	_totals[0] = 0
	_totals[1] = 0
	for level: int in range(1, levels):
		# pow per level (not a running product) keeps float error from accumulating.
		var delta: int = floori(base * pow(growth, level - 1) + linear * (level - 1))
		_totals[level + 1] = _totals[level] + delta
