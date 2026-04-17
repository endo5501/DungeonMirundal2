extends GutTest


func _make_group(id: StringName, min_count: int, max_count: int) -> MonsterGroupSpec:
	var spec := MonsterGroupSpec.new()
	spec.monster_id = id
	spec.count_min = min_count
	spec.count_max = max_count
	return spec


func _make_pattern(groups: Array[MonsterGroupSpec]) -> EncounterPattern:
	var pattern := EncounterPattern.new()
	pattern.groups = groups
	return pattern


func _make_entry(pattern: EncounterPattern, weight: int) -> EncounterEntry:
	var entry := EncounterEntry.new()
	entry.pattern = pattern
	entry.weight = weight
	return entry


# --- EncounterEntry ---

func test_entry_is_resource():
	var entry := EncounterEntry.new()
	assert_true(entry is Resource)


func test_entry_exposes_pattern_and_weight():
	var pattern := _make_pattern([_make_group(&"slime", 2, 4)])
	var entry := _make_entry(pattern, 3)
	assert_eq(entry.pattern, pattern)
	assert_eq(entry.weight, 3)


func test_entry_is_valid_with_positive_weight():
	var entry := _make_entry(_make_pattern([_make_group(&"slime", 2, 4)]), 1)
	assert_true(entry.is_valid())


func test_entry_rejects_zero_weight():
	var entry := _make_entry(_make_pattern([_make_group(&"slime", 2, 4)]), 0)
	assert_false(entry.is_valid())


func test_entry_rejects_null_pattern():
	var entry := EncounterEntry.new()
	entry.pattern = null
	entry.weight = 1
	assert_false(entry.is_valid())


func test_entry_rejects_invalid_pattern():
	var entry := _make_entry(_make_pattern([]), 1)
	assert_false(entry.is_valid())


# --- EncounterTableData ---

func test_table_is_resource():
	var table := EncounterTableData.new()
	assert_true(table is Resource)


func test_table_exposes_floor_and_probability():
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 0.1
	assert_eq(table.floor, 1)
	assert_eq(table.probability_per_step, 0.1)


func test_table_computes_total_weight():
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 0.1
	table.entries = [
		_make_entry(_make_pattern([_make_group(&"slime", 2, 4)]), 2),
		_make_entry(_make_pattern([_make_group(&"goblin", 1, 1)]), 1),
		_make_entry(_make_pattern([_make_group(&"bat", 1, 3)]), 1),
	]
	assert_eq(table.total_weight(), 4)


func test_table_preserves_entry_order():
	var table := EncounterTableData.new()
	var first := _make_entry(_make_pattern([_make_group(&"slime", 1, 1)]), 1)
	var second := _make_entry(_make_pattern([_make_group(&"goblin", 1, 1)]), 1)
	table.entries = [first, second]
	assert_eq(table.entries[0], first)
	assert_eq(table.entries[1], second)


func test_table_is_valid_with_proper_fields():
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 0.1
	table.entries = [_make_entry(_make_pattern([_make_group(&"slime", 2, 4)]), 1)]
	assert_true(table.is_valid())


func test_table_rejects_probability_out_of_range():
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 1.5
	table.entries = [_make_entry(_make_pattern([_make_group(&"slime", 2, 4)]), 1)]
	assert_false(table.is_valid())


func test_table_rejects_negative_probability():
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = -0.1
	table.entries = [_make_entry(_make_pattern([_make_group(&"slime", 2, 4)]), 1)]
	assert_false(table.is_valid())


func test_table_rejects_empty_entries():
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 0.1
	table.entries = []
	assert_false(table.is_valid())


func test_table_rejects_invalid_floor():
	var table := EncounterTableData.new()
	table.floor = 0
	table.probability_per_step = 0.1
	table.entries = [_make_entry(_make_pattern([_make_group(&"slime", 2, 4)]), 1)]
	assert_false(table.is_valid())
