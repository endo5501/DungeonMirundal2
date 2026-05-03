extends GutTest

class FakeContext:
	extends RefCounted
	var _summary: Dictionary
	var confirm_calls: int = 0

	func _init(p_summary: Dictionary) -> void:
		_summary = p_summary

	func get_summary() -> Dictionary:
		return _summary

	func confirm_creation() -> void:
		confirm_calls += 1


var _step: ConfirmationStep
var _ctx: FakeContext
var _content: VBoxContainer


func _make_summary() -> Dictionary:
	# Use lightweight dummy resources instead of touching the full pipeline.
	var race := RaceData.new()
	race.race_name = "Human"
	var job := JobData.new()
	job.job_name = "Fighter"
	return {
		"name": "Hero",
		"race": race,
		"job": job,
		"level": 1,
		"hp": 12,
		"mp": 0,
		"stats": {&"STR": 9, &"INT": 8, &"PIE": 8, &"VIT": 9, &"AGI": 8, &"LUC": 8},
	}


func before_each():
	_step = ConfirmationStep.new()
	_ctx = FakeContext.new(_make_summary())
	_content = VBoxContainer.new()
	add_child_autofree(_content)


func _build():
	_step.build(_content, _ctx)


func _label_texts() -> Array[String]:
	var out: Array[String] = []
	for c in _content.get_children():
		if c is Label:
			out.append((c as Label).text)
	return out


# --- title ---

func test_title_includes_confirmation_keyword():
	assert_string_contains(_step.get_title(), "確認")


# --- build ---

func test_build_renders_summary_fields():
	_build()
	var texts := _label_texts()
	var combined := "\n".join(texts)
	assert_string_contains(combined, "Hero")
	assert_string_contains(combined, "Human")
	assert_string_contains(combined, "Fighter")


func test_build_with_empty_summary_shows_error():
	_ctx = FakeContext.new({})
	_build()
	var combined := "\n".join(_label_texts())
	assert_string_contains(combined, "エラー")


# --- handle_input ---

func test_ui_accept_returns_advance_and_calls_confirm():
	_build()
	var ev := TestHelpers.make_action_event(&"ui_accept")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.ADVANCE)
	assert_eq(_ctx.confirm_calls, 1)


func test_step_back_returns_back():
	_build()
	var ev := TestHelpers.make_action_event(&"step_back")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.BACK)


func test_ui_cancel_returns_cancel():
	_build()
	var ev := TestHelpers.make_action_event(&"ui_cancel")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.CANCEL)
