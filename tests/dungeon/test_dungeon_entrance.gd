extends GutTest

var _registry: DungeonRegistry

func before_each():
	_registry = DungeonRegistry.new()

func _make_entrance() -> DungeonEntrance:
	var entrance := DungeonEntrance.new()
	entrance.setup(_registry, false)
	return entrance

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
