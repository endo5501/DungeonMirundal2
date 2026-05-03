class_name MenuController
extends RefCounted

# The caller — not route() — calls set_input_as_handled. Keeping it that way
# lets ui_cancel without on_back pass through to outer handlers.
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
