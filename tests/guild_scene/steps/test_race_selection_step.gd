extends GutTest

class FakeContext:
	extends RefCounted
	var _races: Array[RaceData]
	var selected_race_index: int = -1
	var cursor_index: int = 0
	var advance_calls: int = 0

	func _init(p_races: Array[RaceData]) -> void:
		_races = p_races

	func get_available_races() -> Array[RaceData]:
		return _races

	func get_selected_race_index() -> int:
		return selected_race_index

	func select_race(i: int) -> void:
		selected_race_index = i

	func get_cursor_index() -> int:
		return cursor_index

	func set_cursor_index(i: int) -> void:
		cursor_index = i

	func advance() -> void:
		advance_calls += 1


func _make_race(name_: String) -> RaceData:
	var r := RaceData.new()
	r.race_name = name_
	r.base_str = 8
	r.base_int = 8
	r.base_pie = 8
	r.base_vit = 8
	r.base_agi = 8
	r.base_luc = 8
	return r


var _step: RaceSelectionStep
var _ctx: FakeContext
var _content: VBoxContainer


func before_each():
	_step = RaceSelectionStep.new()
	_ctx = FakeContext.new([_make_race("Human"), _make_race("Elf"), _make_race("Dwarf")])
	_content = VBoxContainer.new()
	add_child_autofree(_content)


func _build():
	_step.build(_content, _ctx)


func _row_count() -> int:
	var count := 0
	for c in _content.get_children():
		if c is CursorMenuRow:
			count += 1
	return count


# --- title ---

func test_title_includes_race_selection():
	assert_string_contains(_step.get_title(), "種族")


# --- build ---

func test_build_creates_one_row_per_race():
	_build()
	assert_eq(_row_count(), 3)


func test_build_starts_cursor_at_zero():
	_ctx.cursor_index = 7  # garbage
	_build()
	assert_eq(_ctx.get_cursor_index(), 0)


# --- handle_input: cursor movement ---

func test_ui_down_moves_cursor_forward_and_returns_stay():
	_build()
	var ev := TestHelpers.make_action_event(&"ui_down")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)
	assert_eq(_ctx.get_cursor_index(), 1)


func test_ui_up_wraps_around_when_at_zero():
	_build()
	var ev := TestHelpers.make_action_event(&"ui_up")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)
	assert_eq(_ctx.get_cursor_index(), 2)


# --- handle_input: accept / back / cancel ---

func test_ui_accept_selects_race_and_returns_advance():
	_build()
	_ctx.set_cursor_index(1)
	var ev := TestHelpers.make_action_event(&"ui_accept")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.ADVANCE)
	assert_eq(_ctx.get_selected_race_index(), 1)


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


func test_unrecognized_event_returns_stay():
	_build()
	var ev := TestHelpers.make_action_event(&"ui_left")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)
