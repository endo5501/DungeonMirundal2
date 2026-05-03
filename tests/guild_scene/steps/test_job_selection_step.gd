extends GutTest

class FakeContext:
	extends RefCounted
	var _jobs: Array[JobData]
	var _qualified: Dictionary
	var selected_job_index: int = -1
	var cursor_index: int = 0

	func _init(p_jobs: Array[JobData], p_qualified: Dictionary) -> void:
		_jobs = p_jobs
		_qualified = p_qualified

	func get_available_jobs() -> Array[JobData]:
		return _jobs

	func get_qualified_jobs() -> Dictionary:
		return _qualified

	func get_selected_job_index() -> int:
		return selected_job_index

	func select_job(i: int) -> void:
		selected_job_index = i

	func get_cursor_index() -> int:
		return cursor_index

	func set_cursor_index(i: int) -> void:
		cursor_index = i


func _make_job(name_: String, with_magic: bool = false) -> JobData:
	var j := JobData.new()
	j.job_name = name_
	j.base_hp = 10
	j.has_magic = with_magic
	j.base_mp = 5 if with_magic else 0
	return j


var _step: JobSelectionStep
var _ctx: FakeContext
var _content: VBoxContainer


func before_each():
	_step = JobSelectionStep.new()
	var jobs: Array[JobData] = [_make_job("Fighter"), _make_job("Mage", true)]
	_ctx = FakeContext.new(jobs, {0: true, 1: false})
	_content = VBoxContainer.new()
	add_child_autofree(_content)


func _build():
	_step.build(_content, _ctx)


func _rows() -> Array:
	var rs: Array = []
	for c in _content.get_children():
		if c is CursorMenuRow:
			rs.append(c)
	return rs


# --- title ---

func test_title_includes_job_keyword():
	assert_string_contains(_step.get_title(), "職業")


# --- build ---

func test_build_creates_one_row_per_job():
	_build()
	assert_eq(_rows().size(), 2)


func test_build_disables_unqualified_jobs():
	_build()
	var rs := _rows()
	# qualified
	assert_false((rs[0] as CursorMenuRow)._disabled, "qualified Fighter row should be enabled")
	# unqualified
	assert_true((rs[1] as CursorMenuRow)._disabled, "unqualified Mage row should be disabled")


# --- handle_input: cursor and accept ---

func test_ui_down_moves_cursor():
	_build()
	var ev := TestHelpers.make_action_event(&"ui_down")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)
	assert_eq(_ctx.get_cursor_index(), 1)


func test_ui_accept_on_qualified_returns_advance_and_selects():
	_build()
	_ctx.set_cursor_index(0)  # Fighter (qualified)
	var ev := TestHelpers.make_action_event(&"ui_accept")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.ADVANCE)
	assert_eq(_ctx.get_selected_job_index(), 0)


func test_ui_accept_on_unqualified_returns_stay_and_does_not_select():
	_build()
	_ctx.set_cursor_index(1)  # Mage (unqualified)
	var ev := TestHelpers.make_action_event(&"ui_accept")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)
	assert_eq(_ctx.get_selected_job_index(), -1)


# --- back / cancel ---

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
