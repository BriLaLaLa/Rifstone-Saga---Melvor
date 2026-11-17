extends RefCounted
## v8 -> v9 (M25-11, docs/05_INTERFACES_M25.md §6c, docs/01_GDD_M25.md §37.2): the Incisore becomes a discipline of production.
## All in `modules`; nothing else changes (skills, mastery, actions, rift, combat, gold):
## 1. progress = `skills.riftbinding.xp` > 0, or a job of `actions.jobs` with `skill` = `riftbinding`;
## 2. with progress and the Incisore not learned: it is learned at the smallest grade whose cap covers its level (F-158, free);
##    if the other learned artisan disciplines are already `disciplines.max_per_category`, it takes an extra slot (`disciplines.extra`);
## 3. without progress nothing changes; `disciplines.extra` is always there (empty by default).
## The data come from res://data like migration_7_to_8.gd (whose helpers it uses).

const Frozen := preload("res://core/save/migrations/migration_7_to_8.gd")
const ENGRAVER: String = "riftbinding"
const ARTISAN: String = "artisan"


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var modules: Variant = out.get("modules")
	if not modules is Dictionary:
		return out
	var m: Dictionary = modules
	if not m.get("disciplines") is Dictionary:
		m["disciplines"] = {"learned": {}, "recipes": []}
	var disciplines: Dictionary = m["disciplines"]
	if not disciplines.get("learned") is Dictionary:
		disciplines["learned"] = {}
	if not disciplines.get("extra") is Array:
		disciplines["extra"] = []
	var learned: Dictionary = disciplines["learned"]
	if learned.has(ENGRAVER) or not _has_progress(m):
		return out
	var curve: XpTable = Frozen._xp_table()
	var level: int = curve.level_for_xp(Frozen._xp_of(m, ENGRAVER)) if curve != null else 1
	learned[ENGRAVER] = Frozen._grade_for(level, Frozen._grade_caps())
	if _learned_artisans(learned) >= Frozen._max_per_category():
		disciplines["extra"] = [ENGRAVER]
	return out


static func _has_progress(m: Dictionary) -> bool:
	if Frozen._xp_of(m, ENGRAVER) > 0:
		return true
	var actions: Variant = m.get("actions")
	if actions is Dictionary and (actions as Dictionary).get("jobs") is Array:
		for job: Variant in (actions as Dictionary)["jobs"] as Array:
			if job is Dictionary and str((job as Dictionary).get("skill", "")) == ENGRAVER:
				return true
	return false


# The learned artisan disciplines (the Incisore not counted: it is not learned yet).
static func _learned_artisans(learned: Dictionary) -> int:
	var count: int = 0
	for def: Dictionary in Frozen._skill_defs():
		var id: String = str(def.get("id", ""))
		if def.get("category") == ARTISAN and id != ENGRAVER and learned.has(id):
			count += 1
	return count
