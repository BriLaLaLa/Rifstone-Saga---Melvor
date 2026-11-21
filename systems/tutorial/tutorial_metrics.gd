class_name TutorialMetrics
extends RefCounted
## Measures read from the model for the tutorial conditions of type `metric` (docs/05_INTERFACES_M30.md §5.42). Pure reads:
## no state, no signal. `METRICS` maps each metric to the signals that make it worth reading again.

const METRICS: Dictionary[StringName, Array] = {
	&"character_level": [&"character_level_up"], &"kills_total": [&"monster_killed"], &"disciplines_learned": [&"discipline_changed"],
	&"page_visited": [], &"mail_collected": [&"mail_changed"], &"village_levels": [&"village_upgraded"], &"quests_completed": [&"quest_completed"]}


static func value(session: GameSession, metric: StringName, arg: StringName = &"") -> int:
	match metric:
		&"character_level":
			return session.character.get_level()
		&"kills_total":
			var total: int = 0
			for n: int in session.combat.total_kills().values():
				total += n
			return total
		&"disciplines_learned":
			if arg == &"":
				return session.disciplines.learned(&"gathering").size() + session.disciplines.learned(&"artisan").size()
			return session.disciplines.learned(arg).size()
		&"page_visited":
			return 1 if session.tutorial != null and session.tutorial.has_visited(arg) else 0
		&"mail_collected":
			return session.mail.collected_total()
		&"village_levels":
			if arg != &"":
				return session.village.level(arg)
			var levels: int = 0
			for b: VillageBuildingDef in session.data.village_buildings():
				levels += session.village.level(b.id)
			return levels
		&"quests_completed":
			return session.quests.completed_total()
	push_error("TutorialMetrics: unknown metric '%s'" % metric)
	return 0
