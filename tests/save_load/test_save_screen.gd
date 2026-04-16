extends GutTest

const TEST_SAVE_DIR := "user://test_saves_screen/"

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
	if dir and dir.dir_exists("test_saves_screen"):
		var saves_dir := DirAccess.open(TEST_SAVE_DIR)
		if saves_dir:
			saves_dir.list_dir_begin()
			var file_name := saves_dir.get_next()
			while file_name != "":
				saves_dir.remove(file_name)
				file_name = saves_dir.get_next()
			saves_dir.list_dir_end()
		dir.remove("test_saves_screen")

func _make_key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

# --- Slot display tests ---

func test_save_screen_shows_new_save_only_when_no_saves():
	var screen := SaveScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	assert_eq(screen.get_slot_count(), 1)

func test_save_screen_shows_saves_plus_new_save():
	_save_manager.save(1)
	_save_manager.save(2)
	var screen := SaveScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	assert_eq(screen.get_slot_count(), 3)

# --- New save test ---

func test_new_save_creates_file():
	var screen := SaveScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	watch_signals(screen)
	screen._unhandled_input(_make_key_event(KEY_ENTER))
	assert_signal_emitted(screen, "save_completed")
	assert_true(FileAccess.file_exists(TEST_SAVE_DIR + "save_001.json"))

# --- Overwrite confirm test ---

func test_overwrite_shows_confirm_dialog():
	_save_manager.save(1)
	var screen := SaveScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	screen._unhandled_input(_make_key_event(KEY_DOWN))
	screen._unhandled_input(_make_key_event(KEY_ENTER))
	assert_true(screen.is_overwrite_dialog_visible())

func test_overwrite_confirm_saves():
	_save_manager.save(1)
	var screen := SaveScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	watch_signals(screen)
	screen._unhandled_input(_make_key_event(KEY_DOWN))
	screen._unhandled_input(_make_key_event(KEY_ENTER))
	# Confirm overwrite (select "はい" which is first)
	screen._unhandled_input(_make_key_event(KEY_UP))
	screen._unhandled_input(_make_key_event(KEY_ENTER))
	assert_signal_emitted(screen, "save_completed")

func test_overwrite_cancel_returns_to_list():
	_save_manager.save(1)
	var screen := SaveScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	screen._unhandled_input(_make_key_event(KEY_DOWN))
	screen._unhandled_input(_make_key_event(KEY_ENTER))
	screen._unhandled_input(_make_key_event(KEY_ESCAPE))
	assert_false(screen.is_overwrite_dialog_visible())

# --- ESC to close ---

func test_esc_emits_back_requested():
	var screen := SaveScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	watch_signals(screen)
	screen._unhandled_input(_make_key_event(KEY_ESCAPE))
	assert_signal_emitted(screen, "back_requested")
