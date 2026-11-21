extends GutTest
## Real tutorial data (M30-03; docs/01_GDD_M30.md §41.4, §41.7, docs/04_DATA_SCHEMA_M30.md §34): 22 steps, 20 starter quests, mail
## templates, the Guide page, and the reachability of every non-ack step (§34.6).

const REAL_ROOT: String = "res://data"
const CONFIG_ROOT: String = "res://data/config"
const STEP_IDS: Array[String] = ["welcome", "character", "equipment", "combat_start", "combat_kills", "combat_triangle", "combat_eat", "combat_food", "bank",
	"shop", "rift", "trainers", "skill", "nodes", "village", "noticeboard", "auction", "mail", "fractures", "dungeon", "guide", "finish"]
const QUEST_IDS: Array[String] = ["first_trait", "level_3", "level_10", "kills_25", "beat_arcane", "eat_once", "sell_first", "first_infusion",
	"learn_gathering", "learn_artisan", "campfire_meal", "first_craft", "mastery_node", "first_building", "noticeboard_claim", "auction_buy", "first_card",
	"fracture_won", "dungeon_won", "mail_two", "visit_guide"]
const GATHERING: Array[StringName] = [&"forestry", &"quarrying", &"angling", &"herbalism"]
const FORBIDDEN_CATEGORIES: Array[StringName] = [&"equipment", &"weapon", &"armor", &"offhand", &"tool", &"bag", &"map"]
const MELVOR_WORDS: Array[String] = ["melvor", "runecrafting", "thieving", "firemaking", "woodcutting", "mastery pool"]
const QUEST_MONEY_TOTAL: int = 40800

var _data: GameData = null


func before_all() -> void:
	_data = GameData.load_from_dirs(REAL_ROOT, CONFIG_ROOT)


func _step(id: String) -> TutorialStepDef:
	return _data.tutorial_step(StringName(id))


func test_real_data_loads_without_errors() -> void:
	assert_eq(_data.errors.size(), 0, "no load errors: %s" % str(_data.errors))


func test_22_steps_in_order_with_text_limits() -> void:
	var steps: Array[TutorialStepDef] = _data.tutorial_steps()
	assert_eq(steps.size(), 22)
	for i: int in steps.size():
		assert_eq(str(steps[i].id), STEP_IDS[i], "step %d" % i)
		assert_between(steps[i].title.length(), 1, 40, "title of %s" % steps[i].id)
		assert_between(steps[i].text.length(), 1, 280, "text of %s" % steps[i].id)
	assert_eq(steps[steps.size() - 1].done_when[0].type, &"ack", "the last step is Avanti")


func test_21_quests_in_order_with_limits_and_money_total() -> void:
	var quests: Array[StarterQuestDef] = _data.starter_quests()
	assert_eq(quests.size(), 21)
	var money: int = 0
	var items: Dictionary = {}
	for i: int in quests.size():
		var q: StarterQuestDef = quests[i]
		assert_eq(str(q.id), QUEST_IDS[i], "quest %d" % i)
		assert_between(q.name.length(), 1, 40, "name of %s" % q.id)
		assert_between(q.description.length(), 1, 140, "description of %s" % q.id)
		money += q.reward_money
		for iq: ItemQty in q.reward_items:
			items[iq.item_id] = int(items.get(iq.item_id, 0)) + iq.qty
	assert_eq(money, QUEST_MONEY_TOTAL, "starter quests pay 40800 copper in total (Q188, 01_GDD_M30.md §41.6): a change is a rebalance")
	assert_eq(items, {&"seared_brookfin": 10, &"rift_dust": 10, &"cooked_plains_haunch": 10})


func test_quest_rewards_are_sellable_and_not_gear() -> void:
	var xp: int = 0
	for q: StarterQuestDef in _data.starter_quests():
		xp += q.reward_character_xp
		for iq: ItemQty in q.reward_items:
			var def: ItemDef = _data.item(iq.item_id)
			assert_gt(def.value, 0, "%s is sellable" % iq.item_id)
			assert_false(FORBIDDEN_CATEGORIES.has(def.category), "%s is not gear" % iq.item_id)
	assert_eq(xp, 250, "total character XP of the quests")


func test_step_text_numbers_match_the_data() -> void:
	assert_eq(_step("combat_kills").done_when[0].count, 3, "the text says 'tre nemici'")
	assert_true(_step("combat_kills").text.contains("tre nemici"))


func test_start_kit_reaches_equipment_and_combat_steps() -> void:
	var armory: Array = _data.balance_value("start.armory") as Array
	var worn_weapon: bool = false
	var spare_weapon: bool = false
	for e: Dictionary in armory:
		var def: ItemDef = _data.item(StringName(e["base"] as String))
		if def.equip == null or def.equip.slot != &"weapon":
			continue
		for need: int in def.equip.requirements.values():
			assert_lte(need, 1, "%s is wearable at character level 1" % def.id)
		if (e["equip"] as String) == "weapon":
			worn_weapon = true
		elif (e["equip"] as String).is_empty():
			spare_weapon = true
	assert_true(worn_weapon and spare_weapon, "the start Armory has a weapon worn and another not worn")
	var level_one: bool = false
	for area: AreaDef in _data.areas():
		level_one = level_one or int(area.requirements.get(&"character", 0)) <= 1
	assert_true(level_one, "an area opens at character level 1")


func test_trainers_reach_the_discipline_step() -> void:
	assert_eq(_data.balance_value("trainer.learn_gold"), 0, "grade 1 is free")
	assert_eq(_data.trainer_grade(1).character_level, 1, "grade 1 needs level 1")
	for skill: StringName in GATHERING:
		assert_not_null(_data.trainer(skill), "trainer of %s" % skill)
	var allowed: Array = _step("trainers").done_when[0].args["skill_id"] as Array
	for skill: StringName in GATHERING:
		assert_true(allowed.has(str(skill)), "%s in the step filter" % skill)


func test_gift_comes_before_mail_collected() -> void:
	var steps: Array[TutorialStepDef] = _data.tutorial_steps()
	var gift_index: int = -1
	var collect_index: int = -1
	for i: int in steps.size():
		if steps[i].gift_money > 0 or not steps[i].gift_items.is_empty():
			gift_index = i if gift_index < 0 else gift_index
		for c: TutorialCondition in steps[i].done_when:
			if c.type == &"metric" and c.metric == &"mail_collected" and collect_index < 0:
				collect_index = i
	assert_gte(gift_index, 0, "a step has a gift")
	assert_lte(gift_index, collect_index, "the gift is delivered in or before the mail_collected step")
	assert_eq(_step("mail").gift_money, 3000)
	assert_gte(int(_data.balance_value("mail.capacity")), 1)


func test_quest_monster_and_items_exist_and_appear_in_packs() -> void:
	assert_not_null(_data.monster(&"ember_rat"))
	var found: bool = false
	for area: AreaDef in _data.areas():
		for pack: PackDef in area.packs:
			found = found or pack.monster_ids.has(&"ember_rat")
	assert_true(found, "ember_rat is in a pack of an area")
	assert_gt(_data.item(&"seared_brookfin").value, 0)
	assert_gt(_data.item(&"rift_dust").value, 0)


func test_mail_templates_two_per_kind_without_placeholders() -> void:
	for kind: StringName in [&"tutorial_gift", &"starter_reward"]:
		var list: Array[MailTemplateDef] = _data.mail_templates(kind)
		assert_gte(list.size(), 2, "templates of %s" % kind)
		for t: MailTemplateDef in list:
			assert_false(t.subject.contains("{") or t.body.contains("{"), "no placeholders in %s" % kind)
			assert_between(t.subject.length(), 1, 60)
			assert_between(t.body.length(), 1, 240)


func test_guide_page_exists_and_is_short() -> void:
	var page: GuidePageDef = _data.guide_page(&"guide_tutorial")
	assert_not_null(page)
	assert_eq(page.section, &"first_steps")
	assert_eq(page.title, "Tutorial e Primi passi")
	var words: int = 0
	for block: Dictionary in page.blocks:
		if block["type"] == "text":
			var raw: String = block["text"] as String
			while raw.contains("{"):
				var a: int = raw.find("{")
				raw = raw.substr(0, a) + " x " + raw.substr(raw.find("}", a) + 1)
			words += raw.split(" ", false).size()
	assert_lt(words, 160)


func test_no_melvor_names_in_texts() -> void:
	var texts: Array[String] = []
	for s: TutorialStepDef in _data.tutorial_steps():
		texts.append(s.title + " " + s.text)
	for q: StarterQuestDef in _data.starter_quests():
		texts.append(q.name + " " + q.description)
	for kind: StringName in [&"tutorial_gift", &"starter_reward"]:
		for t: MailTemplateDef in _data.mail_templates(kind):
			texts.append(t.sender + " " + t.subject + " " + t.body)
	for text: String in texts:
		for word: String in MELVOR_WORDS:
			assert_false(text.to_lower().contains(word), "'%s' in '%s'" % [word, text])


func test_m31_step_fields_and_final_reward() -> void:
	assert_eq(_step("combat_kills").progress_text, "Nemici sconfitti: %d su %d")
	assert_eq(_step("combat_eat").wound_hp_pct, 30)
	assert_false(_step("combat_eat").freeze_combat)
	assert_true(_step("combat_food").freeze_combat)
	assert_eq(_step("combat_food").ack_text, "Ok")
	assert_true(_step("nodes").force_node)
	assert_false(_step("combat_kills").freeze_combat)
	var final: StarterFinalDef = _data.starter_final()
	assert_not_null(final)
	assert_eq(final.reward_character_xp, 300)
	assert_eq(final.reward_money, 0)
	assert_eq(final.reward_items.size(), 2)
	assert_eq(final.reward_items[0].item_id, &"pioneer_emblem")
	assert_eq(final.reward_items[1].qty, 30)
	assert_eq(_data.item(&"pioneer_emblem").value, 5000)
	assert_between(final.name.length(), 1, 40)
	assert_between(final.description.length(), 1, 140)
	assert_eq(int((_data.balance_value("start.items") as Array)[0]["qty"]), 30)
