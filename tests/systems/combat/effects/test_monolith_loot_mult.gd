extends GutTest
## F-120 `monolith_loot_mult` (hook `on_monolith`): the quantity of every stack of the loot of a Rift Monolith x `mult` (round):
## x2, Dust 30 -> 60. The Monolith fight with the ring is in tests/systems/combat/test_monolith_effects.gd.


class RecordingSink extends LootSink:
	var stacks: Dictionary[StringName, int] = {}
	var pieces: int = 0

	func add(item_id: StringName, qty: int) -> bool:
		stacks[item_id] = stacks.get(item_id, 0) + qty
		return true

	func add_piece(_inst: ItemInstance) -> void:
		pieces += 1


func test_the_effect_multiplies_the_context() -> void:
	var ctx := EffectContext.new()
	MonolithLootMult.new(&"equipment:ring", {"mult": 2.0}).on_monolith(ctx)
	assert_eq(ctx.loot_mult, 2.0)
	assert_eq(ctx.triggered, [&"equipment:ring"] as Array[StringName])
	MonolithLootMult.new(&"t", {"mult": 1.5}).on_monolith(ctx)
	assert_eq(ctx.loot_mult, 3.0, "several multiply")


func test_the_scaled_sink_doubles_the_stacks_and_leaves_the_pieces() -> void:
	var inner := RecordingSink.new()
	var sink := ScaledSink.new(inner, 2.0)
	sink.add(&"rift_dust", 30)
	sink.add(&"test_log", 2)
	sink.add_piece(ItemInstance.new())
	assert_eq(inner.stacks[&"rift_dust"], 60)
	assert_eq(inner.stacks[&"test_log"], 4)
	assert_eq(inner.pieces, 1, "a piece is a piece")


func test_the_quantity_is_rounded() -> void:
	var inner := RecordingSink.new()
	var sink := ScaledSink.new(inner, 1.5)
	sink.add(&"a", 3)
	sink.add(&"b", 5)
	assert_eq(inner.stacks[&"a"], 5, "round(4.5)")
	assert_eq(inner.stacks[&"b"], 8, "round(7.5)")
