extends GutTest


# Integration: morlis (DEF -2 / 4 turns) lowers an enemy's effective defense
# and increases the attacker's normal-attack damage by +1 (defense / 2 in the
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


func test_morlis_loads_and_lowers_defense_modifier_to_minus_two():
	var morlis := load("res://data/spells/morlis.tres") as SpellData
	assert_not_null(morlis)
	var slime := _StubActor.new(0, 4, 5)
	morlis.effect.apply(null, [slime], null)
	assert_eq(slime.modifier_stack.sum(&"defense"), -2)
	assert_eq(slime.get_defense(), 2)


func test_morlis_damage_increases_by_one_with_same_rng():
	var morlis := load("res://data/spells/morlis.tres") as SpellData
	var fighter_a := _StubActor.new(10, 0, 5)
	var slime_a := _StubActor.new(0, 4, 5, 30)
	var fighter_b := _StubActor.new(10, 0, 5)
	var slime_b := _StubActor.new(0, 4, 5, 30)
	morlis.effect.apply(null, [slime_b], null)
	var dmg_no_debuff := DamageCalculator.calculate(fighter_a, slime_a, _make_rng())
	var dmg_debuffed := DamageCalculator.calculate(fighter_b, slime_b, _make_rng())
	assert_true(dmg_no_debuff.hit, "baseline attack should hit at the chosen seed")
	assert_true(dmg_debuffed.hit, "debuffed-target attack should hit at the chosen seed")
	# damage formula: attack - defense/2 + spread.
	# base def 4 → def/2 = 2; debuffed def 2 → def/2 = 1; difference is +1.
	assert_eq(dmg_debuffed.amount - dmg_no_debuff.amount, 1,
		"morlis (-2 DEF) should add exactly 1 to the calculated damage")
