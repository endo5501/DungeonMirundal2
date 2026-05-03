extends GutTest


var _menu: CursorMenu
var _rows: Array[CursorMenuRow]
var _vbox: VBoxContainer

var _accept_count: int
var _back_count: int
var _cursor_changed_count: int
var _cursor_changed_index_at_call: int


func before_each():
	_menu = CursorMenu.new(["A", "B", "C"], [])
	_vbox = VBoxContainer.new()
	add_child_autofree(_vbox)
	_rows = []
	for i in range(3):
		_rows.append(CursorMenuRow.create(_vbox, "row_%d" % i, 16))
	_menu.update_rows(_rows)
	_accept_count = 0
	_back_count = 0
	_cursor_changed_count = 0
	_cursor_changed_index_at_call = -1


func _on_accept() -> void:
	_accept_count += 1


func _on_back() -> void:
	_back_count += 1


func _on_cursor_changed() -> void:
	_cursor_changed_count += 1
	_cursor_changed_index_at_call = _menu.selected_index


# --- Sanity check for design assumption (task 1.2) ---

func test_default_callable_is_invalid():
	# MenuController relies on Callable().is_valid() == false to detect
	# "no callback registered". Verify this assumption holds in Godot 4.x.
	assert_false(Callable().is_valid())


# --- ui_down ---

func test_ui_down_moves_cursor_forward_and_returns_true():
	var ev := TestHelpers.make_action_event(&"ui_down")
	var consumed := MenuController.route(ev, _menu, _rows, _on_accept)
	assert_true(consumed)
	assert_eq(_menu.selected_index, 1)


func test_ui_down_updates_rows():
	var ev := TestHelpers.make_action_event(&"ui_down")
	MenuController.route(ev, _menu, _rows, _on_accept)
	assert_false(_rows[0].is_selected())
	assert_true(_rows[1].is_selected())


# --- ui_up ---

func test_ui_up_moves_cursor_backward_and_returns_true():
	_menu.selected_index = 1
	var ev := TestHelpers.make_action_event(&"ui_up")
	var consumed := MenuController.route(ev, _menu, _rows, _on_accept)
	assert_true(consumed)
	assert_eq(_menu.selected_index, 0)


# --- ui_accept ---

func test_ui_accept_invokes_on_accept_and_returns_true():
	var ev := TestHelpers.make_action_event(&"ui_accept")
	var consumed := MenuController.route(ev, _menu, _rows, _on_accept)
	assert_true(consumed)
	assert_eq(_accept_count, 1)


# --- ui_cancel with on_back ---

func test_ui_cancel_invokes_on_back_when_registered():
	var ev := TestHelpers.make_action_event(&"ui_cancel")
	var consumed := MenuController.route(ev, _menu, _rows, _on_accept, _on_back)
	assert_true(consumed)
	assert_eq(_back_count, 1)


# --- ui_cancel without on_back ---

func test_ui_cancel_returns_false_when_on_back_not_registered():
	var ev := TestHelpers.make_action_event(&"ui_cancel")
	var consumed := MenuController.route(ev, _menu, _rows, _on_accept)
	assert_false(consumed)
	assert_eq(_back_count, 0)


# --- on_cursor_changed ---

func test_on_cursor_changed_fires_after_update_rows():
	var ev := TestHelpers.make_action_event(&"ui_down")
	var consumed := MenuController.route(
		ev, _menu, _rows, _on_accept, Callable(), _on_cursor_changed
	)
	assert_true(consumed)
	assert_eq(_cursor_changed_count, 1)
	# At the time on_cursor_changed fires, the cursor has already moved.
	assert_eq(_cursor_changed_index_at_call, 1)


# --- unrecognized event ---

func test_unrecognized_event_returns_false_and_leaves_state():
	var ev := TestHelpers.make_action_event(&"ui_left")
	var initial_index := _menu.selected_index
	var consumed := MenuController.route(ev, _menu, _rows, _on_accept)
	assert_false(consumed)
	assert_eq(_menu.selected_index, initial_index)
	assert_eq(_accept_count, 0)
	assert_eq(_back_count, 0)
