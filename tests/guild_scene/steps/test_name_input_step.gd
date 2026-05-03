extends GutTest

# Minimal context double for NameInputStep. Records calls so tests can assert
# the step delegates name updates back to the wizard.
class FakeContext:
	extends RefCounted
	var name_input: String = ""
	var advance_calls: int = 0
	var current_step: int = 1
	var total_steps: int = 5

	func get_name_input() -> String:
		return name_input

	func set_name_input(value: String) -> void:
		name_input = value

	func advance() -> void:
		advance_calls += 1


var _step
var _ctx: FakeContext
var _content: VBoxContainer


func before_each():
	_step = NameInputStep.new()
	_ctx = FakeContext.new()
	_content = VBoxContainer.new()
	add_child_autofree(_content)


func _build():
	_step.build(_content, _ctx)


func _find_line_edit() -> LineEdit:
	for c in _content.get_children():
		if c is LineEdit:
			return c as LineEdit
	return null


# --- title ---

func test_title_is_name_input():
	assert_string_contains(_step.get_title(), "名前")


# --- build ---

func test_build_creates_line_edit():
	_build()
	assert_not_null(_find_line_edit(), "build should add a LineEdit to content")


func test_build_initial_text_matches_context_name():
	_ctx.name_input = "Hero"
	_build()
	var edit := _find_line_edit()
	assert_eq(edit.text, "Hero")


# --- handle_input ---

func test_ui_cancel_returns_cancel():
	_build()
	var ev := TestHelpers.make_action_event(&"ui_cancel")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.CANCEL)


func test_ui_accept_when_line_edit_unfocused_returns_stay_and_grabs_focus():
	_build()
	var edit := _find_line_edit()
	# Force unfocused state by releasing focus
	edit.release_focus()
	var ev := TestHelpers.make_action_event(&"ui_accept")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY,
		"unfocused ui_accept should grab focus, not advance")


func test_unrecognized_event_returns_stay():
	_build()
	var ev := TestHelpers.make_action_event(&"ui_down")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)


# --- text submission via line edit ---

func test_text_submitted_updates_context_name_and_advances():
	_build()
	var edit := _find_line_edit()
	edit.text = "Alice"
	edit.text_submitted.emit("Alice")
	assert_eq(_ctx.name_input, "Alice")
	assert_eq(_ctx.advance_calls, 1)


func test_text_changed_updates_context_name():
	_build()
	var edit := _find_line_edit()
	edit.text_changed.emit("Bob")
	assert_eq(_ctx.name_input, "Bob")
