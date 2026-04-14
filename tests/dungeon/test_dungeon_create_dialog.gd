extends GutTest

# --- Size category ---

func test_default_size_is_medium():
	var dialog := DungeonCreateDialog.new()
	assert_eq(dialog.size_category, DungeonRegistry.SIZE_MEDIUM)

func test_size_cycle_forward():
	var dialog := DungeonCreateDialog.new()
	dialog.cycle_size(1)
	assert_eq(dialog.size_category, DungeonRegistry.SIZE_LARGE)

func test_size_cycle_backward():
	var dialog := DungeonCreateDialog.new()
	dialog.cycle_size(-1)
	assert_eq(dialog.size_category, DungeonRegistry.SIZE_SMALL)

func test_size_wraps_forward():
	var dialog := DungeonCreateDialog.new()
	dialog.size_category = DungeonRegistry.SIZE_LARGE
	dialog.cycle_size(1)
	assert_eq(dialog.size_category, DungeonRegistry.SIZE_SMALL)

func test_size_wraps_backward():
	var dialog := DungeonCreateDialog.new()
	dialog.size_category = DungeonRegistry.SIZE_SMALL
	dialog.cycle_size(-1)
	assert_eq(dialog.size_category, DungeonRegistry.SIZE_LARGE)

# --- Name ---

func test_initial_name_is_not_empty():
	var dialog := DungeonCreateDialog.new()
	assert_gt(dialog.dungeon_name.length(), 0)

# --- Size label ---

func test_size_label_small():
	var dialog := DungeonCreateDialog.new()
	dialog.size_category = DungeonRegistry.SIZE_SMALL
	assert_eq(dialog.get_size_label(), "小")

func test_size_label_medium():
	var dialog := DungeonCreateDialog.new()
	dialog.size_category = DungeonRegistry.SIZE_MEDIUM
	assert_eq(dialog.get_size_label(), "中")

func test_size_label_large():
	var dialog := DungeonCreateDialog.new()
	dialog.size_category = DungeonRegistry.SIZE_LARGE
	assert_eq(dialog.get_size_label(), "大")

# --- Signals ---

func test_confirm_emits_signal():
	var dialog := DungeonCreateDialog.new()
	watch_signals(dialog)
	dialog.do_confirm()
	assert_signal_emitted(dialog, "confirmed")

func test_cancel_emits_signal():
	var dialog := DungeonCreateDialog.new()
	watch_signals(dialog)
	dialog.do_cancel()
	assert_signal_emitted(dialog, "cancelled")

func test_confirm_passes_name_and_category():
	var dialog := DungeonCreateDialog.new()
	dialog.dungeon_name = "テスト迷宮"
	dialog.size_category = DungeonRegistry.SIZE_LARGE
	watch_signals(dialog)
	dialog.do_confirm()
	assert_signal_emitted_with_parameters(dialog, "confirmed", ["テスト迷宮", DungeonRegistry.SIZE_LARGE])
