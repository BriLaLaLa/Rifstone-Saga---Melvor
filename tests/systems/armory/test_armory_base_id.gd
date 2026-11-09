extends GutTest
## Armory.base_id_of: the base of a piece without copying the instance (hot path of the combat loop, M14-11).


func test_base_id_of_a_stored_piece_and_of_an_unknown_uid() -> void:
	var s: GameSession = autofree(TestFactory.session(1, TestFactory.real_data()))
	var uid: int = TestFactory.give_piece(s, &"emberbronze_sword")
	assert_eq(s.armory.base_id_of(uid), &"emberbronze_sword")
	assert_eq(s.armory.base_id_of(0), &"")
	assert_eq(s.armory.base_id_of(987654), &"")
