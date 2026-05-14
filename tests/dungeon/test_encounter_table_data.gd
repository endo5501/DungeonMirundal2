extends GutTest


func _make_table(p_floor: int = 1, prob: float = 0.1) -> EncounterTableData:
	return TestHelpers.make_encounter_table(p_floor, prob, {1: 1}, 1, 1, 1, 1)


# --- EncounterTableData ---

func test_table_is_resource():
	var table := EncounterTableData.new()
	assert_true(table is Resource)


func test_table_exposes_floor_and_probability():
	var table := _make_table()
	assert_eq(table.floor, 1)
	assert_eq(table.probability_per_step, 0.1)


func test_table_exposes_tier_weights():
	var table := _make_table()
	table.tier_weights = {1: 6, 2: 1}
	assert_eq(table.tier_weights[1], 6)
	assert_eq(table.tier_weights[2], 1)


func test_table_exposes_species_count_range():
	var table := _make_table()
	table.species_count_min = 1
	table.species_count_max = 3
	assert_eq(table.species_count_min, 1)
	assert_eq(table.species_count_max, 3)


func test_table_exposes_count_per_species_range():
	var table := _make_table()
	table.count_per_species_min = 2
	table.count_per_species_max = 5
	assert_eq(table.count_per_species_min, 2)
	assert_eq(table.count_per_species_max, 5)


func test_table_is_valid_with_proper_fields():
	var table := _make_table()
	table.tier_weights = {1: 6, 2: 1}
	table.species_count_max = 2
	table.count_per_species_max = 4
	assert_true(table.is_valid())


func test_table_rejects_empty_tier_weights():
	var table := _make_table()
	table.tier_weights = {}
	assert_false(table.is_valid())


func test_table_rejects_all_zero_tier_weights():
	var table := _make_table()
	table.tier_weights = {1: 0, 2: 0}
	assert_false(table.is_valid())


func test_table_rejects_negative_weight():
	var table := _make_table()
	table.tier_weights = {1: -1}
	assert_false(table.is_valid())


func test_table_rejects_tier_key_above_5():
	var table := _make_table()
	table.tier_weights = {6: 1}
	assert_false(table.is_valid())


func test_table_rejects_tier_key_below_1():
	var table := _make_table()
	table.tier_weights = {0: 1}
	assert_false(table.is_valid())


func test_table_rejects_probability_out_of_range():
	var table := _make_table(1, 1.5)
	assert_false(table.is_valid())


func test_table_rejects_negative_probability():
	var table := _make_table(1, -0.1)
	assert_false(table.is_valid())


func test_table_rejects_invalid_floor():
	var table := _make_table(0)
	assert_false(table.is_valid())


func test_table_rejects_inverted_species_count():
	var table := _make_table()
	table.species_count_min = 3
	table.species_count_max = 1
	assert_false(table.is_valid())


func test_table_rejects_zero_species_count_min():
	var table := _make_table()
	table.species_count_min = 0
	table.species_count_max = 1
	assert_false(table.is_valid())


func test_table_rejects_inverted_count_per_species():
	var table := _make_table()
	table.count_per_species_min = 5
	table.count_per_species_max = 2
	assert_false(table.is_valid())


func test_table_rejects_zero_count_per_species_min():
	var table := _make_table()
	table.count_per_species_min = 0
	table.count_per_species_max = 4
	assert_false(table.is_valid())


# --- key normalization (Godot dict serialization may coerce int keys to string) ---

func test_table_normalizes_string_tier_keys():
	var table := _make_table()
	# Simulate a .tres save/load that coerced "3" to string key
	table.tier_weights = {"3": 5}
	assert_true(table.is_valid())
	# normalized_tier_weights() returns int keys
	var normalized := table.normalized_tier_weights()
	assert_true(normalized.has(3))
	assert_eq(normalized[3], 5)


func test_table_rejects_non_integer_string_tier_keys():
	var table := _make_table()
	table.tier_weights = {"abc": 1}
	assert_false(table.is_valid())


func test_normalized_tier_weights_returns_int_keys_for_int_input():
	var table := _make_table()
	table.tier_weights = {1: 4, 2: 3}
	var normalized := table.normalized_tier_weights()
	assert_true(normalized.has(1))
	assert_true(normalized.has(2))
	assert_eq(normalized[1], 4)
	assert_eq(normalized[2], 3)
