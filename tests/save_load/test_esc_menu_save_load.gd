extends GutTest

const TEST_SAVE_DIR := "user://test_saves_esc/"

var _save_manager: SaveManager

func before_each():
	_clean_test_dir()
	_save_manager = SaveManager.new(TEST_SAVE_DIR)
	GameState.new_game()
	GameState.save_manager = _save_manager

func after_each():
	_clean_test_dir()

func _clean_test_dir():
	var dir := DirAccess.open("user://")
	if dir and dir.dir_exists("test_saves_esc"):
		var saves_dir := DirAccess.open(TEST_SAVE_DIR)
		if saves_dir:
			saves_dir.list_dir_begin()
			var file_name := saves_dir.get_next()
			while file_name != "":
				saves_dir.remove(file_name)
				file_name = saves_dir.get_next()
			saves_dir.list_dir_end()
		dir.remove("test_saves_esc")

func _make_key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

# --- Save/Load enabled ---

func test_save_is_enabled():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	assert_false(menu.get_main_menu().is_disabled(EscMenu.MAIN_IDX_SAVE))

func test_load_is_enabled():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	assert_false(menu.get_main_menu().is_disabled(EscMenu.MAIN_IDX_LOAD))

# --- Save integration ---

func test_select_save_emits_save_requested():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	watch_signals(menu)
	menu.show_menu()
	# Navigate to "ゲームを保存" (index 1)
	menu.get_main_menu().selected_index = EscMenu.MAIN_IDX_SAVE
	menu.select_current_item()
	assert_signal_emitted(menu, "save_requested")

# --- Load integration ---

func test_select_load_emits_load_requested():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	watch_signals(menu)
	menu.show_menu()
	menu.get_main_menu().selected_index = EscMenu.MAIN_IDX_LOAD
	menu.select_current_item()
	assert_signal_emitted(menu, "load_requested")

# --- Save completed returns to menu ---

func test_save_completed_hides_menu():
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.on_save_completed()
	assert_false(menu.is_menu_visible())
