extends GutTest


func test_outcome_is_refcounted():
	var outcome := EncounterOutcome.new()
	assert_true(outcome is RefCounted)


func test_default_result_is_cleared():
	var outcome := EncounterOutcome.new()
	assert_eq(outcome.result, EncounterOutcome.Result.CLEARED)


func test_result_enum_has_three_values():
	assert_eq(EncounterOutcome.Result.size(), 3)


func test_can_construct_with_result():
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.ESCAPED)
	assert_eq(outcome.result, EncounterOutcome.Result.ESCAPED)


func test_wiped_result():
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.WIPED)
	assert_eq(outcome.result, EncounterOutcome.Result.WIPED)


func test_default_gained_experience_is_zero():
	var outcome := EncounterOutcome.new()
	assert_eq(outcome.gained_experience, 0)


func test_default_drops_is_empty():
	var outcome := EncounterOutcome.new()
	assert_eq(outcome.drops.size(), 0)
