extends GutTest

const TEST_SAVE_DIR := "user://test_saves_lscreen/"

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
	if dir and dir.dir_exists("test_saves_lscreen"):
		var saves_dir := DirAccess.open(TEST_SAVE_DIR)
		if saves_dir:
			saves_dir.list_dir_begin()
			var file_name := saves_dir.get_next()
			while file_name != "":
				saves_dir.remove(file_name)
				file_name = saves_dir.get_next()
			saves_dir.list_dir_end()
		dir.remove("test_saves_lscreen")

func _make_key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

# --- Display tests ---

func test_load_screen_shows_no_saves_message_when_empty():
	var screen := LoadScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	assert_true(screen.has_no_saves_message())
	assert_eq(screen.get_slot_count(), 0)

func test_load_screen_shows_slots():
	_save_manager.save(1)
	_save_manager.save(2)
	var screen := LoadScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	assert_false(screen.has_no_saves_message())
	assert_eq(screen.get_slot_count(), 2)

# --- Selection test ---

func test_select_slot_emits_load_requested():
	_save_manager.save(1)
	var screen := LoadScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	watch_signals(screen)
	screen._unhandled_input(_make_key_event(KEY_ENTER))
	assert_signal_emitted(screen, "load_requested")

# --- ESC to close ---

func test_esc_emits_back_requested():
	var screen := LoadScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	watch_signals(screen)
	screen._unhandled_input(_make_key_event(KEY_ESCAPE))
	assert_signal_emitted(screen, "back_requested")
