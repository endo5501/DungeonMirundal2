extends GutTest


# Integration: sopic (HIT -0.2 / 4 turns) lowers an enemy group's hit modifier
# so each affected attacker's hit_chance against any defender drops by 0.2.

class _StubActor extends CombatActor:
	var _base_atk: int
	var _base_def: int
	var _base_agi: int
	var _hp: int
	var _max: int

	func _init(p_atk: int, p_def: int, p_agi: int, p_hp: int = 30) -> void:
		_base_atk = p_atk
		_base_def = p_def
		_base_agi = p_agi
		_hp = p_hp
		_max = p_hp
		actor_name = "Stub"

	func _get_base_attack() -> int:
		return _base_atk

	func _get_base_defense() -> int:
		return _base_def

	func _get_base_agility() -> int:
		return _base_agi

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


func test_sopic_loads_and_applies_hit_minus_zero_point_two_to_every_group_member():
	var sopic := load("res://data/spells/sopic.tres") as SpellData
	assert_not_null(sopic)
	var slimes: Array = [
		_StubActor.new(5, 0, 5),
		_StubActor.new(5, 0, 5),
		_StubActor.new(5, 0, 5),
	]
	var resolution := sopic.effect.apply(null, slimes, null)
	assert_eq(resolution.entries.size(), 3, "sopic should record one entry per group member")
	for s in slimes:
		assert_almost_eq(float(s.modifier_stack.sum(&"hit")), -0.2, 0.0001)
		assert_almost_eq(s.get_hit_modifier_total(), -0.2, 0.0001)


func test_sopic_drops_each_affected_attacker_hit_chance_by_zero_point_two():
	var sopic := load("res://data/spells/sopic.tres") as SpellData
	var fighter := _StubActor.new(10, 0, 5)
	var slime_a := _StubActor.new(5, 0, 5)
	var slime_b := _StubActor.new(5, 0, 5)
	var hit_no_debuff := DamageCalculator.hit_chance(slime_a, fighter)
	sopic.effect.apply(null, [slime_b], null)
	var hit_debuffed := DamageCalculator.hit_chance(slime_b, fighter)
	assert_almost_eq(hit_no_debuff - hit_debuffed, 0.2, 0.0001,
		"sopic (-0.2 HIT on attacker) should drop attacker hit_chance by exactly 0.2")
