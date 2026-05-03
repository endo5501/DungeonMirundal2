extends GutTest

const STAT_KEYS: Array[StringName] = [&"STR", &"INT", &"PIE", &"VIT", &"AGI", &"LUC"]


# Records every mutation so tests can assert.
class FakeContext:
	extends RefCounted
	var bonus_total: int = 10
	var remaining: int = 10
	var stat_values := {&"STR": 8, &"INT": 8, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	var increment_calls: Array[StringName] = []
	var decrement_calls: Array[StringName] = []
	var reroll_calls: int = 0
	var cursor_index: int = 0

	func get_bonus_total() -> int:
		return bonus_total

	func get_remaining_points() -> int:
		return remaining

	func get_stat_value(key: StringName) -> int:
		return stat_values.get(key, 0)

	func increment_stat(key: StringName) -> void:
		increment_calls.append(key)

	func decrement_stat(key: StringName) -> void:
		decrement_calls.append(key)

	func reroll_bonus() -> void:
		reroll_calls += 1

	func get_cursor_index() -> int:
		return cursor_index

	func set_cursor_index(i: int) -> void:
		cursor_index = i


var _step: BonusAllocationStep
var _ctx: FakeContext
var _content: VBoxContainer


func before_each():
	_step = BonusAllocationStep.new()
	_ctx = FakeContext.new()
	_content = VBoxContainer.new()
	add_child_autofree(_content)


func _build():
	_step.build(_content, _ctx)


# --- title ---

func test_title_includes_bonus_keyword():
	assert_string_contains(_step.get_title(), "ボーナス")


# --- build ---

func test_build_creates_one_row_per_stat():
	_build()
	var rows := 0
	for c in _content.get_children():
		if c is CursorMenuRow:
			rows += 1
	assert_eq(rows, STAT_KEYS.size())


func test_build_resets_cursor_to_zero():
	_ctx.cursor_index = 5
	_build()
	assert_eq(_ctx.get_cursor_index(), 0)


# --- cursor movement ---

func test_ui_down_moves_cursor():
	_build()
	var ev := TestHelpers.make_action_event(&"ui_down")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)
	assert_eq(_ctx.get_cursor_index(), 1)


func test_ui_up_wraps_to_last():
	_build()
	var ev := TestHelpers.make_action_event(&"ui_up")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)
	assert_eq(_ctx.get_cursor_index(), STAT_KEYS.size() - 1)


# --- stat increment / decrement ---

func test_ui_right_increments_current_stat():
	_build()
	_ctx.set_cursor_index(2)  # PIE
	var ev := TestHelpers.make_action_event(&"ui_right")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)
	assert_eq(_ctx.increment_calls.size(), 1)
	assert_eq(_ctx.increment_calls[0], &"PIE")


func test_ui_left_decrements_current_stat():
	_build()
	_ctx.set_cursor_index(0)  # STR
	var ev := TestHelpers.make_action_event(&"ui_left")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)
	assert_eq(_ctx.decrement_calls.size(), 1)
	assert_eq(_ctx.decrement_calls[0], &"STR")


# --- reroll ---

func test_reroll_stats_calls_reroll_bonus():
	_build()
	var ev := TestHelpers.make_action_event(&"reroll_stats")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)
	assert_eq(_ctx.reroll_calls, 1)


# --- accept depends on remaining points ---

func test_ui_accept_returns_advance_when_no_points_remain():
	_ctx.remaining = 0
	_build()
	var ev := TestHelpers.make_action_event(&"ui_accept")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.ADVANCE)


func test_ui_accept_returns_stay_when_points_remain():
	_ctx.remaining = 3
	_build()
	var ev := TestHelpers.make_action_event(&"ui_accept")
	var result := _step.handle_input(ev, _ctx)
	assert_eq(result, CharacterCreationStep.StepTransition.STAY)


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
