extends GutTest

const TEST_SEED: int = 12345


func _make_group(id: StringName, min_count: int, max_count: int) -> MonsterGroupSpec:
	var spec := MonsterGroupSpec.new()
	spec.monster_id = id
	spec.count_min = min_count
	spec.count_max = max_count
	return spec


func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- MonsterGroupSpec ---

func test_group_spec_is_resource():
	var spec := MonsterGroupSpec.new()
	assert_true(spec is Resource)


func test_group_spec_fields_readable():
	var spec := _make_group(&"slime", 2, 4)
	assert_eq(spec.monster_id, &"slime")
	assert_eq(spec.count_min, 2)
	assert_eq(spec.count_max, 4)


func test_group_spec_is_valid_with_normal_range():
	var spec := _make_group(&"slime", 2, 4)
	assert_true(spec.is_valid())


func test_group_spec_is_valid_when_min_equals_max():
	var spec := _make_group(&"boss", 1, 1)
	assert_true(spec.is_valid())


func test_group_spec_rejects_empty_id():
	var spec := _make_group(&"", 1, 1)
	assert_false(spec.is_valid())


func test_group_spec_rejects_min_greater_than_max():
	var spec := _make_group(&"slime", 5, 2)
	assert_false(spec.is_valid())


func test_group_spec_rejects_zero_or_negative_min():
	var spec := _make_group(&"slime", 0, 4)
	assert_false(spec.is_valid())


func test_group_spec_roll_count_within_range():
	var spec := _make_group(&"slime", 2, 4)
	for i in range(50):
		var rng := _make_rng(TEST_SEED + i)
		var count := spec.roll_count(rng)
		assert_between(count, 2, 4)


func test_group_spec_fixed_count_is_deterministic():
	var spec := _make_group(&"boss", 1, 1)
	assert_eq(spec.roll_count(_make_rng(TEST_SEED)), 1)


# --- EncounterPattern ---

func test_encounter_pattern_is_resource():
	var pattern := EncounterPattern.new()
	assert_true(pattern is Resource)


func test_encounter_pattern_exposes_groups():
	var pattern := EncounterPattern.new()
	pattern.groups = [_make_group(&"slime", 2, 4), _make_group(&"goblin", 1, 1)]
	assert_eq(pattern.groups.size(), 2)


func test_encounter_pattern_total_count_within_bounds():
	var pattern := EncounterPattern.new()
	pattern.groups = [_make_group(&"slime", 2, 4), _make_group(&"goblin", 1, 1)]
	for i in range(50):
		var rng := _make_rng(TEST_SEED + i)
		var rolled := pattern.roll_counts(rng)
		assert_eq(rolled.size(), 2)
		var total := rolled[0] + rolled[1]
		assert_between(total, 3, 5)


func test_encounter_pattern_same_seed_same_result():
	var pattern := EncounterPattern.new()
	pattern.groups = [_make_group(&"slime", 2, 4), _make_group(&"goblin", 1, 3)]
	var a := pattern.roll_counts(_make_rng(TEST_SEED))
	var b := pattern.roll_counts(_make_rng(TEST_SEED))
	assert_eq(a, b)


func test_encounter_pattern_is_valid_with_valid_groups():
	var pattern := EncounterPattern.new()
	pattern.groups = [_make_group(&"slime", 2, 4)]
	assert_true(pattern.is_valid())


func test_encounter_pattern_rejects_empty_groups():
	var pattern := EncounterPattern.new()
	pattern.groups = []
	assert_false(pattern.is_valid())


func test_encounter_pattern_rejects_invalid_group():
	var pattern := EncounterPattern.new()
	pattern.groups = [_make_group(&"", 1, 1)]
	assert_false(pattern.is_valid())
