extends GutTest

const TEST_SEED: int = 12345


class _StubActor extends CombatActor:
	var _attack: int
	var _defense: int

	func _init(p_attack: int, p_defense: int) -> void:
		_attack = p_attack
		_defense = p_defense

	func get_attack() -> int:
		return _attack

	func get_defense() -> int:
		return _defense


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


# --- formula ---

func test_apply_formula_basic_case():
	# max(1, 10 - 4/2 + 1) = max(1, 9) = 9
	assert_eq(DamageCalculator.apply_formula(10, 4, 1), 9)


func test_apply_formula_spread_zero():
	# max(1, 10 - 4/2 + 0) = 8
	assert_eq(DamageCalculator.apply_formula(10, 4, 0), 8)


func test_apply_formula_spread_two():
	# max(1, 10 - 4/2 + 2) = 10
	assert_eq(DamageCalculator.apply_formula(10, 4, 2), 10)


func test_apply_formula_minimum_one_when_attack_well_below_defense():
	# 3 - 20/2 + 0 = -7 -> floor to 1
	assert_eq(DamageCalculator.apply_formula(3, 20, 0), 1)


func test_apply_formula_minimum_one_when_zero_spread_and_equal_half():
	# 2 - 4/2 + 0 = 0 -> floor to 1
	assert_eq(DamageCalculator.apply_formula(2, 4, 0), 1)


# --- calculate_by_stats (rng) ---

func test_calculate_by_stats_within_expected_range():
	var rng := _make_rng()
	for i in range(20):
		var damage := DamageCalculator.calculate_by_stats(10, 4, rng)
		# Expected spread 0..2, so damage is 8..10
		assert_true(damage >= 8 and damage <= 10,
			"damage=%d should be in [8,10]" % damage)


func test_calculate_by_stats_is_deterministic_with_seeded_rng():
	var rng_a := _make_rng()
	var rng_b := _make_rng()
	for i in range(10):
		assert_eq(
			DamageCalculator.calculate_by_stats(12, 5, rng_a),
			DamageCalculator.calculate_by_stats(12, 5, rng_b)
		)


# --- calculate(actor, actor, rng) ---

func test_calculate_uses_actor_stats():
	var attacker := _StubActor.new(10, 0)
	var target := _StubActor.new(0, 4)
	var rng := _make_rng()
	var damage := DamageCalculator.calculate(attacker, target, rng)
	# Equivalent to calculate_by_stats(10, 4, rng_first_roll)
	assert_true(damage >= 8 and damage <= 10)
