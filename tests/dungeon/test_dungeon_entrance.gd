extends GutTest

var _registry: DungeonRegistry

func before_each():
	_registry = DungeonRegistry.new()

func _make_entrance() -> DungeonEntrance:
	var entrance := DungeonEntrance.new()
	entrance.setup(_registry, false)
	return entrance

func _make_key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

func _find_create_dialog(entrance: DungeonEntrance) -> DungeonCreateDialog:
	for child in entrance.get_children():
		if child is DungeonCreateDialog:
			return child as DungeonCreateDialog
	return null

# --- Empty list ---

func test_empty_registry_shows_no_items():
	var entrance := _make_entrance()
	assert_eq(entrance.get_dungeon_count(), 0)

# --- With dungeons ---

func test_shows_dungeons_from_registry():
	_registry.create("迷宮A", DungeonRegistry.SIZE_SMALL)
	_registry.create("迷宮B", DungeonRegistry.SIZE_MEDIUM)
	var entrance := _make_entrance()
	assert_eq(entrance.get_dungeon_count(), 2)

# --- Enter button state ---

func test_enter_disabled_when_no_dungeons():
	var entrance := _make_entrance()
	assert_true(entrance.is_enter_disabled())

func test_enter_disabled_when_no_party():
	_registry.create("迷宮", DungeonRegistry.SIZE_SMALL)
	var entrance := DungeonEntrance.new()
	entrance.setup(_registry, false)  # has_party = false
	assert_true(entrance.is_enter_disabled())

func test_enter_enabled_when_dungeon_selected_and_party_exists():
	_registry.create("迷宮", DungeonRegistry.SIZE_SMALL)
	var entrance := DungeonEntrance.new()
	entrance.setup(_registry, true)  # has_party = true
	entrance.selected_index = 0
	assert_false(entrance.is_enter_disabled())

# --- Delete button state ---

func test_delete_disabled_when_no_selection():
	var entrance := _make_entrance()
	assert_true(entrance.is_delete_disabled())

func test_delete_enabled_when_dungeon_selected():
	_registry.create("迷宮", DungeonRegistry.SIZE_SMALL)
	var entrance := _make_entrance()
	entrance.selected_index = 0
	assert_false(entrance.is_delete_disabled())

# --- Signals ---

func test_enter_emits_signal_with_index():
	_registry.create("迷宮", DungeonRegistry.SIZE_SMALL)
	var entrance := DungeonEntrance.new()
	entrance.setup(_registry, true)
	entrance.selected_index = 0
	watch_signals(entrance)
	entrance.do_enter()
	assert_signal_emitted_with_parameters(entrance, "enter_dungeon", [0])

func test_back_emits_signal():
	var entrance := _make_entrance()
	watch_signals(entrance)
	entrance.do_back()
	assert_signal_emitted(entrance, "back_requested")

# --- Cursor ---

func test_cursor_moves_in_dungeon_list():
	_registry.create("A", DungeonRegistry.SIZE_SMALL)
	_registry.create("B", DungeonRegistry.SIZE_MEDIUM)
	_registry.create("C", DungeonRegistry.SIZE_LARGE)
	var entrance := _make_entrance()
	entrance.selected_index = 0
	entrance.move_list_cursor(1)
	assert_eq(entrance.selected_index, 1)

func test_cursor_clamps_at_boundaries():
	_registry.create("A", DungeonRegistry.SIZE_SMALL)
	var entrance := _make_entrance()
	entrance.selected_index = 0
	entrance.move_list_cursor(-1)
	assert_eq(entrance.selected_index, 0)

# --- Initial focus on empty registry ---

func test_empty_registry_initial_focus_on_buttons():
	var entrance := _make_entrance()
	assert_eq(entrance._focus, DungeonEntrance.Focus.BUTTONS, "empty registry should start with BUTTONS focus")

func test_empty_registry_button_cursor_on_new_dungeon():
	var entrance := _make_entrance()
	assert_eq(entrance._button_menu.selected_index, 1, "cursor should start on 新規生成 (index 1)")

func test_empty_registry_enter_opens_create_dialog_with_one_press():
	var entrance := _make_entrance()
	add_child_autofree(entrance)
	entrance._unhandled_input(_make_key_event(KEY_ENTER))
	assert_not_null(_find_create_dialog(entrance), "create dialog should open after single Enter press")

func test_non_empty_registry_keeps_list_focus():
	_registry.create("A", DungeonRegistry.SIZE_SMALL)
	var entrance := _make_entrance()
	assert_eq(entrance._focus, DungeonEntrance.Focus.DUNGEON_LIST, "non-empty registry should keep list focus")

# --- Empty state guidance message ---

func test_empty_registry_shows_guidance_message():
	var entrance := _make_entrance()
	add_child_autofree(entrance)
	var found := false
	for child in entrance._vbox.get_children():
		if child is Label and (child as Label).text == "まず「新規生成」でダンジョンを作成してください":
			found = true
			break
	assert_true(found, "guidance message should be displayed when registry is empty")

func test_empty_registry_message_uses_enabled_color():
	var entrance := _make_entrance()
	add_child_autofree(entrance)
	for child in entrance._vbox.get_children():
		if child is Label and (child as Label).text == "まず「新規生成」でダンジョンを作成してください":
			var label := child as Label
			var has_disabled_override := label.has_theme_color_override("font_color") \
				and label.get_theme_color("font_color") == CursorMenu.DISABLED_COLOR
			assert_false(has_disabled_override, "guidance message should not use DISABLED_COLOR")
			return
	fail_test("guidance message label not found")
