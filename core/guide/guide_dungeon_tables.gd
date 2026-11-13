class_name GuideDungeonTables
extends RefCounted
## The generated tables of the Guide page "Dungeon" (docs/04_DATA_SCHEMA.md §27): the room types (F-138), the boss stages (F-139)
## and the boss loot (F-143). Rows of text, the first one is the header; every number is read from the dungeons of GameData.
## The tables never say which exit leads to which room: the hidden map is not in the data of the player.

const ROOM_NAMES: Dictionary[StringName, String] = {
	&"pack": "Branco", &"horde": "Orda", &"elite": "Guardiano", &"miniboss": "Capobranco", &"trap": "Trappola", &"rest": "Riposo",
}
const RARITY_NAMES: Dictionary[StringName, String] = {&"common": "comune", &"magic": "magico", &"rare": "raro"}
const EVENT_TEXTS: Dictionary[StringName, String] = {
	&"trap": "Due scelte: attraversare di corsa (costa PV) o aggirare (imboscata)",
	&"rest": "Due scelte: riposare (cura PV) o frugare tra i rami (branco e scorta)",
}


static func rooms(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Dungeon", "Stanza", "Peso", "Dal bivio", "Mostri", "Premio"]]
	for def: DungeonDef in data.dungeons():
		for type: DungeonRoomType in def.room_types:
			rows.append([def.name, ROOM_NAMES.get(type.id, String(type.id)), str(type.weight), str(type.min_layer),
					EVENT_TEXTS.get(type.id, _composition(type, def)), _reward(type.reward)])
	return rows


static func stages(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Dungeon", "Atto", "Nemico", "PV", "Seguito", "Abilità"]]
	for def: DungeonDef in data.dungeons():
		for i: int in def.stages.size():
			var stage: DungeonStageDef = def.stages[i]
			var monster: MonsterDef = def.monster_def(stage.monster_id)
			rows.append([def.name, "%d: %s" % [i + 1, stage.title], monster.name if monster != null else String(stage.monster_id),
					GuideIndex.num(monster.hp) if monster != null else "", _names(stage.escorts, def),
					GuideFractureTables.ability_text(stage.ability, data)])
	return rows


static func loot(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Dungeon", "Premio del boss", "Quantità"]]
	for def: DungeonDef in data.dungeons():
		rows.append([def.name, "Oro", _range(def.boss_gold)])
		rows.append([def.name, "Polvere del Rift", _range(def.boss_dust)])
		var pieces: PackedStringArray = PackedStringArray()
		for piece: Dictionary in def.boss_pieces:
			if piece.has("rarity"):
				pieces.append("1 pezzo %s" % RARITY_NAMES.get(piece["rarity"], String(piece["rarity"])))
			else:
				pieces.append("1 pezzo almeno %s" % RARITY_NAMES.get(piece.get("min_rarity", &""), String(piece.get("min_rarity", ""))))
		rows.append([def.name, "Pezzi", ", ".join(pieces)])
		rows.append([def.name, "Cristalli", str(def.boss_crystals)])
		rows.append([def.name, "Carta della Frattura di grado %d" % def.boss_card_grade, "%s%%" % GuideIndex.num(def.boss_card_pct)])
	return rows


static func _composition(type: DungeonRoomType, def: DungeonDef) -> String:
	if not type.fixed.is_empty():
		return _names(type.fixed, def)
	if type.size_min == type.size_max:
		return "%d mostri" % type.size_min
	return "%d-%d mostri" % [type.size_min, type.size_max]


static func _names(ids: Array[StringName], def: DungeonDef) -> String:
	var counts: Dictionary[String, int] = {}
	for id: StringName in ids:
		var monster: MonsterDef = def.monster_def(id)
		var label: String = monster.name if monster != null else String(id)
		counts[label] = int(counts.get(label, 0)) + 1
	var parts: PackedStringArray = PackedStringArray()
	for label: String in counts:
		parts.append(label if counts[label] == 1 else "%d %s" % [counts[label], label])
	return ", ".join(parts)


static func _range(value: Vector2i) -> String:
	return "%d" % value.x if value.x == value.y else "%d - %d" % [value.x, value.y]


static func _reward(reward: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if reward.has("gold"):
		parts.append("oro %s" % _range(reward["gold"] as Vector2i))
	if reward.has("dust"):
		parts.append("Polvere %s" % _range(reward["dust"] as Vector2i))
	if reward.has("crystal_pct"):
		parts.append("Cristallo %s%%" % GuideIndex.num(float(reward["crystal_pct"])))
	if reward.has("piece_pct"):
		parts.append("pezzo %s%%" % GuideIndex.num(float(reward["piece_pct"])))
	return ", ".join(parts)
