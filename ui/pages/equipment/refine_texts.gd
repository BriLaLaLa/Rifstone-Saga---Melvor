class_name RefineTexts
extends RefCounted
## Texts of the refinement and salvage boxes of the piece panel (docs/01_GDD.md §23-25). The cost, the success chance
## and the yields are read from `Upgrade` / `Salvage` (data in balance.json) and the session; no number is written
## here. No state.

const REFINE_TITLE: String = "Raffinazione +%d → +%d"
const CHANCE_TEXT: String = "Probabilità di successo: %s%%"
const COST_TITLE: String = "Costo del tentativo"
const GOLD_NAME: String = "Oro"
const COST_LINE: String = "%s: %s (ne hai %s)"
const FAIL_DOWN_TEXT: String = "In caso di fallimento i materiali sono persi e il pezzo scende a +%d."
const FAIL_PLAIN_TEXT: String = "In caso di fallimento i materiali sono persi."
const SEAL_TEXT: String = "Usa %s (ne hai %s): evita la discesa"
const MAX_TEXT: String = "Il pezzo è già al livello massimo di raffinazione."
const SALVAGE_TITLE: String = "Smantellare questo pezzo?"
const SALVAGE_YIELD_TEXT: String = "Il pezzo va distrutto e ottieni:"
const SALVAGE_NOTHING_TEXT: String = "Il pezzo va distrutto e non rende nulla."
const SALVAGE_LINE: String = "%s x%s"


## Everything the refine box shows for `uid`, read now: {"max": bool, "title", "chance", "cost_lines": PackedStringArray,
## "fail_text", "seal_possible": bool, "seal_name", "seal_have": int}.
static func refine_info(session: GameSession, uid: int) -> Dictionary:
	var inst: ItemInstance = session.armory.get_instance(uid)
	var data: GameData = session.data
	if inst == null or inst.upgrade >= Upgrade.max_level(data):
		return {"max": true}
	var grade: int = data.item(inst.base_id).equip.grade
	var cost: Dictionary = Upgrade.cost(inst.upgrade, grade, data)
	var chance: float = Upgrade.chance_pct(inst.upgrade, session.modifiers.total(Upgrade.STAT), data)
	var lines: PackedStringArray = PackedStringArray()
	if int(cost["gold"]) > 0:
		lines.append(COST_LINE % [GOLD_NAME, NumberFormat.format_int(int(cost["gold"])),
				NumberFormat.format_int(session.wallet.get_gold())])
	_append_item_line(lines, session, cost["ingot"], int(cost["ingots"]))
	_append_item_line(lines, session, Upgrade.SHARD_ITEM, int(cost["shards"]))
	var failed: int = Upgrade.failed_level(inst.upgrade, data)
	var seal: StringName = Upgrade.seal_item(data)
	var seal_def: ItemDef = data.item(seal) if data.has_item(seal) else null
	return {
		"max": false,
		"title": REFINE_TITLE % [inst.upgrade, inst.upgrade + 1],
		"chance": CHANCE_TEXT % String.num(chance, 1).replace(".", ","),
		"cost_lines": lines,
		"fail_text": FAIL_DOWN_TEXT % failed if failed < inst.upgrade else FAIL_PLAIN_TEXT,
		"seal_possible": failed < inst.upgrade and seal_def != null,
		"seal_name": seal_def.name if seal_def != null else String(seal),
		"seal_have": session.bank.get_count(seal),
	}


static func _append_item_line(lines: PackedStringArray, session: GameSession, item_id: StringName, qty: int) -> void:
	if qty <= 0:
		return
	var def: ItemDef = session.data.item(item_id) if session.data.has_item(item_id) else null
	lines.append(COST_LINE % [def.name if def != null else String(item_id), NumberFormat.format_int(qty),
			NumberFormat.format_int(session.bank.get_count(item_id))])


## Lines "Item xN" of what the salvage of `uid` pays (F-95, `Salvage.paid`); empty when it pays nothing.
static func salvage_lines(session: GameSession, uid: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var inst: ItemInstance = session.armory.get_instance(uid)
	if inst == null:
		return lines
	var yields: Dictionary[StringName, int] = Salvage.paid(inst, session.data)
	for item_id: StringName in yields:
		var def: ItemDef = session.data.item(item_id) if session.data.has_item(item_id) else null
		lines.append(SALVAGE_LINE % [def.name if def != null else String(item_id),
				NumberFormat.format_int(yields[item_id])])
	return lines
