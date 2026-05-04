extends GutTest

const TEST_SEED: int = 12345


class _StubActor extends CombatActor:
	var _attack: int
	var _defense: int
	var _agility: int
	var _hit_mod: float
	var _eva_mod: float
	var _blind: bool

	func _init(
		p_attack: int = 0,
		p_defense: int = 0,
		p_agility: int = 0,
		p_hit: float = 0.0,
		p_eva: float = 0.0,
		p_blind: bool = false,
	) -> void:
		_attack = p_attack
		_defense = p_defense
		_agility = p_agility
		_hit_mod = p_hit
		_eva_mod = p_eva
		_blind = p_blind

	func _get_base_attack() -> int:
		return _attack

	func _get_base_defense() -> int:
		return _defense

	func _get_base_agility() -> int:
		return _agility

	func get_hit_modifier_total() -> float:
		return _hit_mod

	func get_evasion_modifier_total() -> float:
		return _eva_mod

	func has_blind_flag() -> bool:
		return _blind


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


# --- formula (unchanged) ---

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


# --- roll_hit (pure: strict less-than) ---

func test_roll_hit_strictly_less_than_returns_true():
	assert_true(DamageCalculator.roll_hit(0.85, 0.84))


func test_roll_hit_equal_returns_false():
	assert_false(DamageCalculator.roll_hit(0.85, 0.85))


func test_roll_hit_above_returns_false():
	assert_false(DamageCalculator.roll_hit(0.85, 0.90))


# --- hit_chance (pure) ---

func test_hit_chance_equal_stats_no_modifiers_returns_base():
	var attacker := _StubActor.new(0, 0, 5)
	var target := _StubActor.new(0, 0, 5)
	assert_almost_eq(DamageCalculator.hit_chance(attacker, target), 0.85, 0.0001)


func test_hit_chance_agi_advantage_plus_five_yields_plus_010():
	var attacker := _StubActor.new(0, 0, 10)
	var target := _StubActor.new(0, 0, 5)
	# AGI diff +5 → +0.10 (cap 0.30 not hit)
	assert_almost_eq(DamageCalculator.hit_chance(attacker, target), 0.95, 0.0001)


func test_hit_chance_agi_advantage_caps_at_plus_030():
	var attacker := _StubActor.new(0, 0, 25)
	var target := _StubActor.new(0, 0, 5)
	# AGI diff +20 × 0.02 = +0.40 → capped at +0.30 → raw 1.15 → final clamp 0.99
	assert_almost_eq(DamageCalculator.hit_chance(attacker, target), 0.99, 0.0001)


func test_hit_chance_agi_disadvantage_caps_at_minus_030():
	var attacker := _StubActor.new(0, 0, 5)
	var target := _StubActor.new(0, 0, 30)
	# AGI diff -25 × 0.02 = -0.50 → capped at -0.30 → 0.85 - 0.30 = 0.55
	assert_almost_eq(DamageCalculator.hit_chance(attacker, target), 0.55, 0.0001)


func test_hit_chance_hit_modifier_caps_at_plus_04():
	var attacker := _StubActor.new(0, 0, 5, 0.7, 0.0, false)
	var target := _StubActor.new(0, 0, 5)
	# attacker.hit clamped to +0.4 → 0.85 + 0.4 = 1.25 → clamp to 0.99
	assert_almost_eq(DamageCalculator.hit_chance(attacker, target), 0.99, 0.0001)


func test_hit_chance_evasion_modifier_caps_at_plus_04():
	var attacker := _StubActor.new(0, 0, 5)
	var target := _StubActor.new(0, 0, 5, 0.0, 0.6, false)
	# target.evasion clamped to +0.4 → 0.85 - 0.4 = 0.45
	assert_almost_eq(DamageCalculator.hit_chance(attacker, target), 0.45, 0.0001)


func test_hit_chance_hit_and_evasion_each_at_cap_cancels():
	# attacker hit_mod 0.7, target eva 0.6 → both clamp to 0.4 → +0.4 - 0.4 = 0
	var attacker := _StubActor.new(0, 0, 5, 0.7, 0.0, false)
	var target := _StubActor.new(0, 0, 5, 0.0, 0.6, false)
	assert_almost_eq(DamageCalculator.hit_chance(attacker, target), 0.85, 0.0001)


func test_hit_chance_clamps_at_upper_bound_099():
	# Massive attacker hit + AGI advantage + low target evasion → raw > 1.20
	var attacker := _StubActor.new(0, 0, 30, 0.4, 0.0, false)
	var target := _StubActor.new(0, 0, 5, 0.0, -0.4, false)
	# raw = 0.85 + 0.4 - (-0.4) + 0.30 = 1.95 → clamp 0.99
	assert_almost_eq(DamageCalculator.hit_chance(attacker, target), 0.99, 0.0001)


func test_hit_chance_clamps_at_lower_bound_005():
	# Penalty stack to push raw below 0.05.
	var attacker := _StubActor.new(0, 0, 5, -0.4, 0.0, false)
	var target := _StubActor.new(0, 0, 30, 0.0, 0.4, false)
	# raw = 0.85 + (-0.4) - 0.4 + (-0.30) = -0.25 → clamp 0.05
	assert_almost_eq(DamageCalculator.hit_chance(attacker, target), 0.05, 0.0001)


# BLIND_PENALTY is 0.0 today; status-effect change will wire the real value.
func test_hit_chance_blind_flag_currently_no_effect():
	var attacker := _StubActor.new(0, 0, 5, 0.0, 0.0, true)
	var target := _StubActor.new(0, 0, 5)
	assert_almost_eq(DamageCalculator.hit_chance(attacker, target), 0.85, 0.0001)


# --- calculate(actor, actor, rng) → DamageResult (orchestrator integration) ---

func test_calculate_returns_damage_result_instance():
	var attacker := _StubActor.new(10, 0, 5)
	var target := _StubActor.new(0, 4, 5)
	var rng := _make_rng()
	var result := DamageCalculator.calculate(attacker, target, rng)
	assert_is(result, DamageResult)


func test_calculate_with_overwhelming_advantage_hits_consistently():
	# AGI gap pushes hit_chance to clamp 0.99; over 20 trials we expect mostly hits.
	var attacker := _StubActor.new(10, 0, 30, 0.4, 0.0, false)
	var target := _StubActor.new(0, 4, 1, 0.0, -0.4, false)
	var rng := _make_rng()
	var hits := 0
	for i in range(20):
		var r := DamageCalculator.calculate(attacker, target, rng)
		if r.hit:
			hits += 1
			assert_true(r.amount >= 1)
		else:
			assert_eq(r.amount, 0)
	# At chance 0.99 the expected misses over 20 trials are 0.2; allow up to 2.
	assert_gte(hits, 18)


func test_calculate_with_overwhelming_disadvantage_misses_mostly():
	# Pin hit_chance at the floor 0.05.
	var attacker := _StubActor.new(10, 0, 1, -0.4, 0.0, false)
	var target := _StubActor.new(0, 4, 30, 0.0, 0.4, false)
	var rng := _make_rng()
	var hits := 0
	for i in range(50):
		var r := DamageCalculator.calculate(attacker, target, rng)
		if r.hit:
			hits += 1
	# At chance 0.05 the expected hits over 50 trials are 2.5; allow up to 7.
	assert_lt(hits, 8)


func test_calculate_returns_zero_when_attacker_is_null():
	var target := _StubActor.new(0, 4, 5)
	var rng := _make_rng()
	var r := DamageCalculator.calculate(null, target, rng)
	assert_false(r.hit)
	assert_eq(r.amount, 0)
