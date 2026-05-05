extends GutTest


# Integration: a turns=4 stat modifier survives exactly 3 tick_battle_turn()
# calls (decrementing 4 → 3 → 2 → 1) and is dropped on the 4th tick when its
# duration reaches 0. This mirrors how TurnEngine._end_turn_cleanup ticks the
# stack at the end of each turn.

class _StubActor extends CombatActor:
	var _hp: int = 30
	var _max: int = 30

	func _init() -> void:
		actor_name = "Stub"

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


func test_bamatu_buff_decays_to_zero_after_four_ticks():
	var bamatu := load("res://data/spells/bamatu.tres") as SpellData
	var fighter := _StubActor.new()
	bamatu.effect.apply(null, [fighter], null)
	assert_eq(fighter.modifier_stack.sum(&"attack"), 2,
		"sanity: bamatu installs an attack modifier")
	# After 3 ticks, the duration is 1 and the modifier is still active.
	for i in range(3):
		fighter.modifier_stack.tick_battle_turn()
		assert_eq(fighter.modifier_stack.sum(&"attack"), 2,
			"tick %d: modifier should still be active" % i)
	# The 4th tick reduces duration to 0 and drops the entry.
	fighter.modifier_stack.tick_battle_turn()
	assert_eq(fighter.modifier_stack.sum(&"attack"), 0,
		"after the 4th tick the +2 attack modifier should have decayed to 0")
	assert_true(fighter.modifier_stack.is_empty(),
		"stack should be empty once the only modifier expired")


func test_porfic_buff_decays_to_zero_after_four_ticks():
	var porfic := load("res://data/spells/porfic.tres") as SpellData
	var fighter := _StubActor.new()
	porfic.effect.apply(null, [fighter], null)
	assert_eq(fighter.modifier_stack.sum(&"defense"), 2)
	for i in range(4):
		fighter.modifier_stack.tick_battle_turn()
	assert_eq(fighter.modifier_stack.sum(&"defense"), 0,
		"porfic (+2 DEF / 4 turns) should be cleared after 4 ticks")
