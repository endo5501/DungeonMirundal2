extends GutTest


func _make_dialog() -> ConfirmDialog:
	var dialog := ConfirmDialog.new()
	add_child_autofree(dialog)
	return dialog


# --- 1. setup ---

func test_setup_makes_dialog_visible():
	var dialog := _make_dialog()
	dialog.setup("削除しますか？")
	assert_true(dialog.visible)


func test_setup_displays_message():
	var dialog := _make_dialog()
	dialog.setup("削除しますか？")
	assert_eq(dialog.get_message(), "削除しますか？")


func test_setup_default_index_defaults_to_no():
	var dialog := _make_dialog()
	dialog.setup("確認")
	assert_eq(dialog.get_selected_index(), 1)


func test_setup_default_index_can_be_yes():
	var dialog := _make_dialog()
	dialog.setup("確認", 0)
	assert_eq(dialog.get_selected_index(), 0)


# --- 2. confirmed signal ---

func test_yes_then_accept_emits_confirmed():
	var dialog := _make_dialog()
	dialog.setup("確認", 0)  # default = はい
	watch_signals(dialog)
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_signal_emitted(dialog, "confirmed")
	assert_signal_not_emitted(dialog, "cancelled")


func test_yes_then_accept_hides_dialog():
	var dialog := _make_dialog()
	dialog.setup("確認", 0)
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_false(dialog.visible)


# --- 3. cancelled signal ---

func test_no_then_accept_emits_cancelled():
	var dialog := _make_dialog()
	dialog.setup("確認", 1)  # default = いいえ
	watch_signals(dialog)
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_signal_emitted(dialog, "cancelled")
	assert_signal_not_emitted(dialog, "confirmed")


func test_no_then_accept_hides_dialog():
	var dialog := _make_dialog()
	dialog.setup("確認", 1)
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_false(dialog.visible)


# --- 4. ui_cancel always emits cancelled ---

func test_ui_cancel_with_yes_selected_emits_cancelled():
	var dialog := _make_dialog()
	dialog.setup("確認", 0)  # default = はい
	watch_signals(dialog)
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_signal_emitted(dialog, "cancelled")
	assert_signal_not_emitted(dialog, "confirmed")


func test_ui_cancel_with_no_selected_emits_cancelled():
	var dialog := _make_dialog()
	dialog.setup("確認", 1)  # default = いいえ
	watch_signals(dialog)
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_signal_emitted(dialog, "cancelled")


func test_ui_cancel_hides_dialog():
	var dialog := _make_dialog()
	dialog.setup("確認", 0)
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_false(dialog.visible)


# --- 5. setup re-displays ---

func test_setup_again_redisplays_with_new_message():
	var dialog := _make_dialog()
	dialog.setup("最初", 0)
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_false(dialog.visible)
	dialog.setup("二回目", 1)
	assert_true(dialog.visible)
	assert_eq(dialog.get_message(), "二回目")
	assert_eq(dialog.get_selected_index(), 1)


# --- 6. Hidden dialog ignores input ---

func test_hidden_dialog_ignores_accept():
	var dialog := _make_dialog()
	# Never call setup(); dialog stays hidden
	watch_signals(dialog)
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_signal_not_emitted(dialog, "confirmed")
	assert_signal_not_emitted(dialog, "cancelled")


func test_hidden_dialog_ignores_cancel():
	var dialog := _make_dialog()
	watch_signals(dialog)
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_signal_not_emitted(dialog, "cancelled")


# --- 7. Cursor navigation ---

func test_ui_down_moves_selection_to_no():
	var dialog := _make_dialog()
	dialog.setup("確認", 0)  # start on はい
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_down"))
	assert_eq(dialog.get_selected_index(), 1)


func test_ui_up_moves_selection_to_yes():
	var dialog := _make_dialog()
	dialog.setup("確認", 1)  # start on いいえ
	dialog._unhandled_input(TestHelpers.make_action_event(&"ui_up"))
	assert_eq(dialog.get_selected_index(), 0)
