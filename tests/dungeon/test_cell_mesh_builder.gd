extends GutTest

const CELL_SIZE := 2.0

func test_wall_north_generates_quad():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	# all edges are WALL by default
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var north_faces = faces.filter(func(f): return f.type == "wall_north")
	assert_eq(north_faces.size(), 1, "one north wall face")

func test_open_north_no_wall():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	cell.set_edge(Direction.NORTH, EdgeType.OPEN)
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var north_faces = faces.filter(func(f): return f.type == "wall_north")
	assert_eq(north_faces.size(), 0, "no north wall face when OPEN")

func test_door_generates_door_face():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	cell.set_edge(Direction.NORTH, EdgeType.DOOR)
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var north_faces = faces.filter(func(f): return f.type == "door_north")
	assert_eq(north_faces.size(), 1, "door face generated")

func test_floor_always_generated():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var floor_faces = faces.filter(func(f): return f.type == "floor")
	assert_eq(floor_faces.size(), 1, "floor always present")

func test_ceiling_always_generated():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var ceiling_faces = faces.filter(func(f): return f.type == "ceiling")
	assert_eq(ceiling_faces.size(), 1, "ceiling always present")

func test_wall_vertices_at_correct_position():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	var faces = builder.build_faces(cell, Vector2i(3, 2))
	var north_faces = faces.filter(func(f): return f.type == "wall_north")
	assert_eq(north_faces.size(), 1)
	var verts: Array[Vector3] = north_faces[0].vertices
	# north wall at z = grid_y * CELL_SIZE = 2 * 2.0 = 4.0
	# x from grid_x * CELL_SIZE to (grid_x + 1) * CELL_SIZE = 6.0 to 8.0
	for v in verts:
		assert_almost_eq(v.z, 4.0, 0.01, "north wall z = 4.0")
	var min_x = verts[0].x
	var max_x = verts[0].x
	for v in verts:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
	assert_almost_eq(min_x, 6.0, 0.01, "wall min_x")
	assert_almost_eq(max_x, 8.0, 0.01, "wall max_x")

func test_floor_vertices_at_y_zero():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var floor_faces = faces.filter(func(f): return f.type == "floor")
	for v in floor_faces[0].vertices:
		assert_almost_eq(v.y, 0.0, 0.01, "floor at y=0")

func test_ceiling_vertices_at_y_two():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var ceiling_faces = faces.filter(func(f): return f.type == "ceiling")
	for v in ceiling_faces[0].vertices:
		assert_almost_eq(v.y, 2.0, 0.01, "ceiling at y=2.0")

func test_all_four_walls_default():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var wall_faces = faces.filter(func(f): return f.type.begins_with("wall_"))
	assert_eq(wall_faces.size(), 4, "4 walls when all edges WALL")

# --- Landmark tile meshes ---

func _faces_with_prefix(faces: Array, prefix: String) -> Array:
	return faces.filter(func(f): return f.type.begins_with(prefix))

func _assert_floor_and_ceiling_present(faces: Array, message_prefix: String) -> void:
	var floor_faces = faces.filter(func(f): return f.type == "floor")
	var ceiling_faces = faces.filter(func(f): return f.type == "ceiling")
	assert_eq(floor_faces.size(), 1, "%s floor face" % message_prefix)
	assert_eq(ceiling_faces.size(), 1, "%s ceiling face" % message_prefix)

func _assert_landmark_vertices_within_cell(faces: Array, prefixes: Array,
		grid: Vector2i, message_prefix: String) -> void:
	var x0 := grid.x * CELL_SIZE
	var z0 := grid.y * CELL_SIZE
	var x1 := x0 + CELL_SIZE
	var z1 := z0 + CELL_SIZE
	var ceiling_height := CellMeshBuilder.CELL_HEIGHT
	var landmark_faces: Array = []
	for prefix in prefixes:
		landmark_faces.append_array(_faces_with_prefix(faces, prefix))
	assert_true(landmark_faces.size() > 0, "%s preconditions: landmark faces exist" % message_prefix)
	for f in landmark_faces:
		for v in f.vertices:
			assert_true(v.x >= x0 - 0.01 and v.x <= x1 + 0.01,
				"%s vertex x (%f) within [%f, %f]" % [message_prefix, v.x, x0, x1])
			assert_true(v.z >= z0 - 0.01 and v.z <= z1 + 0.01,
				"%s vertex z (%f) within [%f, %f]" % [message_prefix, v.z, z0, z1])
			assert_true(v.y >= -0.01 and v.y <= ceiling_height + 0.01,
				"%s vertex y (%f) within [0, %f]" % [message_prefix, v.y, ceiling_height])

func test_start_tile_generates_normal_upward_stair_faces_without_return_landmark():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	cell.tile = TileType.START
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var return_faces = _faces_with_prefix(faces, "return_")
	var stairs_up_faces = _faces_with_prefix(faces, "stairs_up_")
	var stairs_down_faces = _faces_with_prefix(faces, "stairs_down_")
	assert_eq(return_faces.size(), 0, "START cell should not generate special return_* faces")
	assert_true(stairs_up_faces.size() > 0, "START cell should generate normal stairs_up_* faces")
	assert_eq(stairs_down_faces.size(), 0, "START cell should not generate stairs_down_* faces")

func test_stairs_up_tile_generates_upward_stair_faces():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	cell.tile = TileType.STAIRS_UP
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var stairs_faces = _faces_with_prefix(faces, "stairs_up_")
	assert_true(stairs_faces.size() > 0, "STAIRS_UP cell should generate stairs_up_* faces")
	_assert_floor_and_ceiling_present(faces, "STAIRS_UP")

func test_stairs_down_tile_generates_pit_and_descending_stair_faces():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	cell.tile = TileType.STAIRS_DOWN
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var pit_faces = _faces_with_prefix(faces, "pit_")
	var stairs_faces = _faces_with_prefix(faces, "stairs_down_")
	assert_true(pit_faces.size() > 0, "STAIRS_DOWN cell should generate pit_* faces")
	assert_true(stairs_faces.size() > 0, "STAIRS_DOWN cell should generate stairs_down_* faces")

func test_goal_tile_generates_altar_faces():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	cell.tile = TileType.GOAL
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	var altar_faces = _faces_with_prefix(faces, "altar_")
	assert_true(altar_faces.size() > 0, "GOAL cell should generate altar_* faces")

func test_floor_tile_has_no_landmark_faces():
	var builder = CellMeshBuilder.new()
	var cell = Cell.new()
	# default tile is FLOOR
	var faces = builder.build_faces(cell, Vector2i(0, 0))
	assert_eq(_faces_with_prefix(faces, "return_").size(), 0, "FLOOR cell should not generate return faces")
	assert_eq(_faces_with_prefix(faces, "stairs_up_").size(), 0, "FLOOR cell should not generate stairs_up faces")
	assert_eq(_faces_with_prefix(faces, "stairs_down_").size(), 0, "FLOOR cell should not generate stairs_down faces")
	assert_eq(_faces_with_prefix(faces, "pit_").size(), 0, "FLOOR cell should not generate pit faces")
	assert_eq(_faces_with_prefix(faces, "altar_").size(), 0, "FLOOR cell should not generate altar faces")

func test_landmark_vertices_within_cell_volume():
	var builder = CellMeshBuilder.new()
	var grid := Vector2i(3, 2)
	var cases := [
		{"tile": TileType.START, "prefixes": ["stairs_up_"], "message": "START"},
		{"tile": TileType.STAIRS_UP, "prefixes": ["stairs_up_"], "message": "STAIRS_UP"},
		{"tile": TileType.STAIRS_DOWN, "prefixes": ["pit_", "stairs_down_"], "message": "STAIRS_DOWN"},
		{"tile": TileType.GOAL, "prefixes": ["altar_"], "message": "GOAL"},
	]
	for case in cases:
		var cell = Cell.new()
		cell.tile = case["tile"]
		var faces = builder.build_faces(cell, grid)
		_assert_landmark_vertices_within_cell(faces, case["prefixes"], grid, case["message"])

func test_landmark_tiles_still_have_floor_and_ceiling():
	var builder = CellMeshBuilder.new()
	for tile in [TileType.START, TileType.STAIRS_UP, TileType.STAIRS_DOWN, TileType.GOAL]:
		var cell = Cell.new()
		cell.tile = tile
		var faces = builder.build_faces(cell, Vector2i(0, 0))
		_assert_floor_and_ceiling_present(faces, "tile %d" % tile)
