extends GutTest


# Integration: bamatu (ATK +2 / 4 turns) raises a target ally's effective attack
# and increases the resulting normal-attack damage by +2 against a defender of
# the same defense, with a fixed RNG.

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


func test_bamatu_loads_and_raises_attack_modifier_to_plus_two():
	var bamatu := load("res://data/spells/bamatu.tres") as SpellData
	assert_not_null(bamatu)
	var fighter := _StubActor.new(10, 0, 5)
	bamatu.effect.apply(null, [fighter], null)
	assert_eq(fighter.modifier_stack.sum(&"attack"), 2)
	assert_eq(fighter.get_attack(), 12)


func test_bamatu_damage_increases_by_exactly_two_with_same_rng():
	var bamatu := load("res://data/spells/bamatu.tres") as SpellData
	# Equal-AGI actors so the agility term in hit_chance is zero on both runs.
	var fighter_a := _StubActor.new(10, 0, 5)
	var slime_a := _StubActor.new(0, 0, 5, 30)
	var fighter_b := _StubActor.new(10, 0, 5)
	var slime_b := _StubActor.new(0, 0, 5, 30)
	bamatu.effect.apply(null, [fighter_b], null)
	# Two fresh RNGs at the same seed produce identical roll sequences.
	var dmg_no_buff := DamageCalculator.calculate(fighter_a, slime_a, _make_rng())
	var dmg_buffed := DamageCalculator.calculate(fighter_b, slime_b, _make_rng())
	assert_true(dmg_no_buff.hit, "baseline attack should hit at the chosen seed")
	assert_true(dmg_buffed.hit, "buffed attack should hit at the chosen seed")
	assert_eq(dmg_buffed.amount - dmg_no_buff.amount, 2,
		"bamatu (+2 ATK) should add exactly 2 to the calculated damage")
