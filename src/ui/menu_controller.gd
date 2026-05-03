class_name MenuController
extends RefCounted

# Routes the four standard menu input actions (ui_up / ui_down / ui_accept /
# ui_cancel) onto a CursorMenu. Returns true if the event was consumed.
# The caller decides whether to call get_viewport().set_input_as_handled().
static func route(
	event: InputEvent,
	menu: CursorMenu,
	rows: Array[CursorMenuRow],
	on_accept: Callable,
	on_back: Callable = Callable(),
	on_cursor_changed: Callable = Callable(),
) -> bool:
	if event.is_action_pressed("ui_down"):
		menu.move_cursor(1)
		menu.update_rows(rows)
		if on_cursor_changed.is_valid():
			on_cursor_changed.call()
		return true
	if event.is_action_pressed("ui_up"):
		menu.move_cursor(-1)
		menu.update_rows(rows)
		if on_cursor_changed.is_valid():
			on_cursor_changed.call()
		return true
	if event.is_action_pressed("ui_accept"):
		if on_accept.is_valid():
			on_accept.call()
		return true
	if event.is_action_pressed("ui_cancel"):
		if on_back.is_valid():
			on_back.call()
			return true
		return false
	return false
