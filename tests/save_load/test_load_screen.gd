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
	screen._unhandled_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_signal_emitted(screen, "load_requested")

# --- ESC to close ---

func test_esc_emits_back_requested():
	var screen := LoadScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	watch_signals(screen)
	screen._unhandled_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_signal_emitted(screen, "back_requested")

# --- Failure UI ---

func test_show_load_failure_file_not_found():
	_save_manager.save(1)
	var screen := LoadScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	screen.show_load_failure(SaveManager.LoadResult.FILE_NOT_FOUND)
	assert_eq(screen.get_status_text(), "セーブファイルが見つかりません")

func test_show_load_failure_parse_error():
	_save_manager.save(1)
	var screen := LoadScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	screen.show_load_failure(SaveManager.LoadResult.PARSE_ERROR)
	assert_eq(screen.get_status_text(), "セーブデータが破損しています")

func test_show_load_failure_version_too_new():
	_save_manager.save(1)
	var screen := LoadScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	screen.show_load_failure(SaveManager.LoadResult.VERSION_TOO_NEW)
	assert_eq(screen.get_status_text(), "未対応のセーブデータです(新しいバージョン)")

func test_show_load_failure_restore_failed():
	_save_manager.save(1)
	var screen := LoadScreen.new()
	add_child_autofree(screen)
	screen.setup(_save_manager)
	screen.show_load_failure(SaveManager.LoadResult.RESTORE_FAILED)
	assert_eq(screen.get_status_text(), "ロードに失敗しました")
