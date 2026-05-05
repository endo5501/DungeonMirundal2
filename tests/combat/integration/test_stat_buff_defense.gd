extends GutTest


# Integration: porfic (DEF +2 / 4 turns) raises a target ally's effective defense
# and reduces the resulting normal-attack damage by +1 (defense / 2 in the
# damage formula), with a fixed RNG.

const TEST_SEED: int = 1234


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


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func test_porfic_loads_and_raises_defense_modifier_to_plus_two():
	var porfic := load("res://data/spells/porfic.tres") as SpellData
	assert_not_null(porfic)
	var fighter := _StubActor.new(0, 4, 5)
	porfic.effect.apply(null, [fighter], null)
	assert_eq(fighter.modifier_stack.sum(&"defense"), 2)
	assert_eq(fighter.get_defense(), 6)


func test_porfic_damage_decreases_by_one_with_same_rng():
	var porfic := load("res://data/spells/porfic.tres") as SpellData
	# Equal-AGI actors so the agility term in hit_chance is zero on both runs.
	# Fighter has high attack; defender starts with even defense so DEF/2 is integer.
	var slime_a := _StubActor.new(10, 0, 5)
	var fighter_a := _StubActor.new(0, 4, 5, 30)
	var slime_b := _StubActor.new(10, 0, 5)
	var fighter_b := _StubActor.new(0, 4, 5, 30)
	porfic.effect.apply(null, [fighter_b], null)
	var dmg_no_buff := DamageCalculator.calculate(slime_a, fighter_a, _make_rng())
	var dmg_buffed := DamageCalculator.calculate(slime_b, fighter_b, _make_rng())
	assert_true(dmg_no_buff.hit, "baseline attack should hit at the chosen seed")
	assert_true(dmg_buffed.hit, "buffed attack should hit at the chosen seed")
	# damage formula: attack - defense/2 + spread.
	# base def 4 → def/2 = 2; buffed def 6 → def/2 = 3; difference is -1.
	assert_eq(dmg_no_buff.amount - dmg_buffed.amount, 1,
		"porfic (+2 DEF) should subtract exactly 1 from the calculated damage")
