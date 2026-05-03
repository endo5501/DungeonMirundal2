extends GutTest


# --- StepTransition enum ---

func test_step_transition_has_stay():
	assert_true(CharacterCreationStep.StepTransition.has("STAY"))


func test_step_transition_has_advance():
	assert_true(CharacterCreationStep.StepTransition.has("ADVANCE"))


func test_step_transition_has_back():
	assert_true(CharacterCreationStep.StepTransition.has("BACK"))


func test_step_transition_has_cancel():
	assert_true(CharacterCreationStep.StepTransition.has("CANCEL"))


func test_step_transition_values_are_distinct():
	var values := [
		CharacterCreationStep.StepTransition.STAY,
		CharacterCreationStep.StepTransition.ADVANCE,
		CharacterCreationStep.StepTransition.BACK,
		CharacterCreationStep.StepTransition.CANCEL,
	]
	var unique := {}
	for v in values:
		unique[v] = true
	assert_eq(unique.size(), 4, "all enum values should be distinct")


# --- default implementations ---

func test_default_get_title_returns_empty_string():
	var step := CharacterCreationStep.new()
	assert_eq(step.get_title(), "")


func test_default_build_is_noop():
	var step := CharacterCreationStep.new()
	var content := VBoxContainer.new()
	add_child_autofree(content)
	var initial_children := content.get_child_count()
	step.build(content, null)
	assert_eq(content.get_child_count(), initial_children, "default build should add nothing")


func test_default_handle_input_returns_stay():
	var step := CharacterCreationStep.new()
	var event := TestHelpers.make_action_event(&"ui_accept")
	var result := step.handle_input(event, null)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)
