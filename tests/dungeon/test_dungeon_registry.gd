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

# --- Floor count ranges ---

func test_small_floor_count_range():
	for _i in range(20):
		var dd := _registry.create("S", DungeonRegistry.SIZE_SMALL)
		assert_gte(dd.floors.size(), 2, "SMALL floor count >= 2")
		assert_lte(dd.floors.size(), 4, "SMALL floor count <= 4")

func test_medium_floor_count_range():
	for _i in range(20):
		var dd := _registry.create("M", DungeonRegistry.SIZE_MEDIUM)
		assert_gte(dd.floors.size(), 4, "MEDIUM floor count >= 4")
		assert_lte(dd.floors.size(), 7, "MEDIUM floor count <= 7")

func test_large_floor_count_range():
	for _i in range(20):
		var dd := _registry.create("L", DungeonRegistry.SIZE_LARGE)
		assert_gte(dd.floors.size(), 8, "LARGE floor count >= 8")
		assert_lte(dd.floors.size(), 12, "LARGE floor count <= 12")

# --- Per-floor map_size ranges ---

func test_small_floor_map_size_range():
	var dd := _registry.create("S", DungeonRegistry.SIZE_SMALL)
	for fd in dd.floors:
		assert_gte(fd.map_size, 8, "SMALL per-floor map_size >= 8")
		assert_lte(fd.map_size, 12, "SMALL per-floor map_size <= 12")

func test_medium_floor_map_size_range():
	var dd := _registry.create("M", DungeonRegistry.SIZE_MEDIUM)
	for fd in dd.floors:
		assert_gte(fd.map_size, 13, "MEDIUM per-floor map_size >= 13")
		assert_lte(fd.map_size, 20, "MEDIUM per-floor map_size <= 20")

func test_large_floor_map_size_range():
	var dd := _registry.create("L", DungeonRegistry.SIZE_LARGE)
	for fd in dd.floors:
		assert_gte(fd.map_size, 21, "LARGE per-floor map_size >= 21")
		assert_lte(fd.map_size, 30, "LARGE per-floor map_size <= 30")

func test_floors_have_independent_map_sizes():
	# A LARGE dungeon has 8-12 floors, each with map_size 21-30. With independent
	# per-floor randomization, the chance that all 8+ floors land on the same
	# size across a 20-trial run is astronomically small.
	var saw_variety := false
	for _i in range(20):
		var dd := _registry.create("L", DungeonRegistry.SIZE_LARGE)
		var first_size: int = dd.floors[0].map_size
		for fd in dd.floors:
			if fd.map_size != first_size:
				saw_variety = true
				break
		if saw_variety:
			break
	assert_true(saw_variety, "per-floor map_size should vary independently")

# --- Determinism with seeded RNG ---

func test_create_with_same_seed_is_deterministic():
	var reg_a := DungeonRegistry.new(42)
	var reg_b := DungeonRegistry.new(42)
	var dd_a := reg_a.create("X", DungeonRegistry.SIZE_MEDIUM)
	var dd_b := reg_b.create("X", DungeonRegistry.SIZE_MEDIUM)
	assert_eq(dd_a.floors.size(), dd_b.floors.size())
	for i in range(dd_a.floors.size()):
		assert_eq(dd_a.floors[i].seed_value, dd_b.floors[i].seed_value,
			"floor[%d] seed must match across same-seed registries" % i)
		assert_eq(dd_a.floors[i].map_size, dd_b.floors[i].map_size,
			"floor[%d] map_size must match across same-seed registries" % i)

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

# --- Round-trip serialization ---

func test_to_from_dict_round_trip_multi_floor():
	_registry.create("迷宮A", DungeonRegistry.SIZE_SMALL)
	_registry.create("迷宮B", DungeonRegistry.SIZE_MEDIUM)
	var d := _registry.to_dict()
	var restored := DungeonRegistry.from_dict(d)
	assert_eq(restored.size(), 2)
	for i in range(2):
		var src := _registry.get_dungeon(i)
		var dst := restored.get_dungeon(i)
		assert_eq(dst.dungeon_name, src.dungeon_name)
		assert_eq(dst.floors.size(), src.floors.size())
		for j in range(src.floors.size()):
			assert_eq(dst.floors[j].seed_value, src.floors[j].seed_value)
			assert_eq(dst.floors[j].map_size, src.floors[j].map_size)
