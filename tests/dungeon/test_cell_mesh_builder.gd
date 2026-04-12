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
