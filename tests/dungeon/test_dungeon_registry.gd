extends GutTest

var _registry: DungeonRegistry

func before_each():
	_registry = DungeonRegistry.new()

# --- Initial state ---

func test_initially_empty():
	assert_eq(_registry.size(), 0)
	assert_eq(_registry.get_all().size(), 0)

# --- Create ---

func test_create_adds_dungeon():
	_registry.create("テスト迷宮", DungeonRegistry.SIZE_MEDIUM)
	assert_eq(_registry.size(), 1)

func test_create_returns_dungeon_data():
	var dd := _registry.create("迷宮", DungeonRegistry.SIZE_SMALL)
	assert_eq(dd.dungeon_name, "迷宮")

func test_create_multiple():
	_registry.create("A", DungeonRegistry.SIZE_SMALL)
	_registry.create("B", DungeonRegistry.SIZE_MEDIUM)
	_registry.create("C", DungeonRegistry.SIZE_LARGE)
	assert_eq(_registry.size(), 3)

# --- Size categories ---

func test_small_size_range():
	var dd := _registry.create("S", DungeonRegistry.SIZE_SMALL)
	assert_gte(dd.map_size, 8)
	assert_lte(dd.map_size, 12)

func test_medium_size_range():
	var dd := _registry.create("M", DungeonRegistry.SIZE_MEDIUM)
	assert_gte(dd.map_size, 13)
	assert_lte(dd.map_size, 20)

func test_large_size_range():
	var dd := _registry.create("L", DungeonRegistry.SIZE_LARGE)
	assert_gte(dd.map_size, 21)
	assert_lte(dd.map_size, 30)

# --- Get ---

func test_get_by_index():
	_registry.create("A", DungeonRegistry.SIZE_SMALL)
	_registry.create("B", DungeonRegistry.SIZE_MEDIUM)
	var dd := _registry.get_dungeon(1)
	assert_eq(dd.dungeon_name, "B")

func test_get_all_returns_all():
	_registry.create("A", DungeonRegistry.SIZE_SMALL)
	_registry.create("B", DungeonRegistry.SIZE_MEDIUM)
	var all := _registry.get_all()
	assert_eq(all.size(), 2)

# --- Remove ---

func test_remove_by_index():
	_registry.create("A", DungeonRegistry.SIZE_SMALL)
	_registry.create("B", DungeonRegistry.SIZE_MEDIUM)
	_registry.remove(0)
	assert_eq(_registry.size(), 1)
	assert_eq(_registry.get_dungeon(0).dungeon_name, "B")

func test_remove_last():
	_registry.create("A", DungeonRegistry.SIZE_SMALL)
	_registry.remove(0)
	assert_eq(_registry.size(), 0)
