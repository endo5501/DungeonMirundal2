extends GutTest


# Integration: dilto (EVA -0.2 / 4 turns) lowers an enemy's evasion modifier so
# the attacker's hit_chance increases by +0.2 (evasion is subtracted in the
# hit_chance formula).

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


func test_dilto_loads_and_lowers_evasion_modifier_to_minus_zero_point_two():
	var dilto := load("res://data/spells/dilto.tres") as SpellData
	assert_not_null(dilto)
	var slime := _StubActor.new(0, 0, 5)
	dilto.effect.apply(null, [slime], null)
	assert_almost_eq(float(slime.modifier_stack.sum(&"evasion")), -0.2, 0.0001)
	assert_almost_eq(slime.get_evasion_modifier_total(), -0.2, 0.0001)


func test_dilto_raises_attacker_hit_chance_by_zero_point_two():
	var dilto := load("res://data/spells/dilto.tres") as SpellData
	# DamageCalculator.hit_chance clamps at 0.99. BASE_HIT (0.85) + a +0.2 boost
	# from dropping evasion by 0.2 would saturate at 0.99 (visible delta 0.14).
	# Pre-applying -0.2 to the attacker's HIT modifier lowers the unmodified
	# hit_chance to 0.65 so the full +0.2 delta lands in-range.
	var fighter := _StubActor.new(10, 0, 5)
	fighter.modifier_stack.add(&"hit", -0.2, 99)
	var slime_a := _StubActor.new(0, 0, 5)
	var slime_b := _StubActor.new(0, 0, 5)
	var hit_no_debuff := DamageCalculator.hit_chance(fighter, slime_a)
	dilto.effect.apply(null, [slime_b], null)
	var hit_debuffed := DamageCalculator.hit_chance(fighter, slime_b)
	assert_almost_eq(hit_debuffed - hit_no_debuff, 0.2, 0.0001,
		"dilto (-0.2 EVA on target) should raise attacker hit_chance by exactly 0.2")
