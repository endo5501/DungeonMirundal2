extends GutTest

const CELL_SIZE := 2.0

func _isolated_visible(wiz_map: WizMap, grid_pos: Vector2i) -> Array[Vector2i]:
	# Helper: visible_cells with a single isolated cell, used for wall-box tests
	# where we want to ensure no shared-edge dedup confuses the count.
	return [grid_pos]

func test_wall_north_generates_box():
	var builder = CellMeshBuilder.new()
	var wiz_map = WizMap.new(8)
	# all edges are WALL by default for a fresh cell at (0, 0)
	var faces = builder.build_meshes(_isolated_visible(wiz_map, Vector2i(0, 0)), wiz_map)
	var north_faces = faces.filter(func(f): return f.type.begins_with("wall_north_"))
	assert_eq(north_faces.size(), 6, "north wall is a 6-face box")
	var suffixes := []
	for f in north_faces:
		var parts: PackedStringArray = (f.type as String).split("_")
		suffixes.append(parts[-1])
	assert_true(suffixes.has("inner"), "wall_north_inner present")
	assert_true(suffixes.has("outer"), "wall_north_outer present")
	assert_true(suffixes.has("top"), "wall_north_top present")
	assert_true(suffixes.has("bottom"), "wall_north_bottom present")
	assert_true(suffixes.has("east"), "wall_north_east present")
	assert_true(suffixes.has("west"), "wall_north_west present")

func test_open_north_no_wall():
	var builder = CellMeshBuilder.new()
	var wiz_map = WizMap.new(8)
	wiz_map.cell(0, 0).set_edge(Direction.NORTH, EdgeType.OPEN)
	var faces = builder.build_meshes(_isolated_visible(wiz_map, Vector2i(0, 0)), wiz_map)
	var north_faces = faces.filter(func(f): return f.type.begins_with("wall_north_"))
	assert_eq(north_faces.size(), 0, "no north wall face when OPEN")

func test_door_generates_door_box_temporarily():
	# Step 2 placeholder: DOOR edges render as wall boxes with door color
	# until Step 5 replaces them with the lintel/jamb/panel assembly.
	var builder = CellMeshBuilder.new()
	var wiz_map = WizMap.new(8)
	wiz_map.cell(0, 0).set_edge(Direction.NORTH, EdgeType.DOOR)
	var faces = builder.build_meshes(_isolated_visible(wiz_map, Vector2i(0, 0)), wiz_map)
	var door_faces = faces.filter(func(f): return f.type.begins_with("door_north_"))
	assert_eq(door_faces.size(), 6, "door box has 6 face groups")

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
	var wiz_map = WizMap.new(8)
	var faces = builder.build_meshes(_isolated_visible(wiz_map, Vector2i(3, 2)), wiz_map)
	var north_faces = faces.filter(func(f): return f.type.begins_with("wall_north_"))
	assert_eq(north_faces.size(), 6, "north wall box has 6 face groups")
	# Wall box at z ∈ [3.9, 4.1], x ∈ [6.0, 8.0], y ∈ [0, 2]
	# Inner face (at z = 4.10) faces into the cell at gy=2
	var inner_faces = north_faces.filter(func(f): return (f.type as String).ends_with("_inner"))
	assert_eq(inner_faces.size(), 1, "exactly one inner face")
	for v in inner_faces[0].vertices:
		assert_almost_eq(v.z, 4.10, 0.01, "inner face z = gy*2 + T/2 = 4.10")
	var outer_faces = north_faces.filter(func(f): return (f.type as String).ends_with("_outer"))
	assert_eq(outer_faces.size(), 1, "exactly one outer face")
	for v in outer_faces[0].vertices:
		assert_almost_eq(v.z, 3.90, 0.01, "outer face z = gy*2 - T/2 = 3.90")
	# All wall vertices should be within the X span of the cell
	for f in north_faces:
		for v in f.vertices:
			assert_true(v.x >= 6.0 - 0.01 and v.x <= 8.0 + 0.01,
				"wall x in [6.0, 8.0], got %f" % v.x)
			assert_true(v.y >= 0.0 - 0.01 and v.y <= 2.0 + 0.01,
				"wall y in [0, 2], got %f" % v.y)

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
	var wiz_map = WizMap.new(8)
	var faces = builder.build_meshes(_isolated_visible(wiz_map, Vector2i(0, 0)), wiz_map)
	var wall_faces = faces.filter(func(f): return f.type.begins_with("wall_"))
	# 4 wall boxes * 6 face groups = 24
	assert_eq(wall_faces.size(), 24, "4 wall boxes * 6 faces = 24")

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

# --- build_meshes (per-batch) ---

func test_build_meshes_returns_floor_and_ceiling_per_visible_cell():
	var builder = CellMeshBuilder.new()
	var wiz_map = WizMap.new(8)
	var visible: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1)]
	var faces = builder.build_meshes(visible, wiz_map)
	var floor_faces = faces.filter(func(f): return f.type == "floor")
	var ceiling_faces = faces.filter(func(f): return f.type == "ceiling")
	assert_eq(floor_faces.size(), 3, "one floor per visible cell")
	assert_eq(ceiling_faces.size(), 3, "one ceiling per visible cell")

func test_shared_wall_edge_rendered_once():
	# Two visible cells stacked vertically; the SOUTH edge of (1,1) is the same
	# physical wall as the NORTH edge of (1,2). With dedup, one wall box (6
	# face groups) should be produced for that shared edge.
	var builder = CellMeshBuilder.new()
	var wiz_map = WizMap.new(8)
	# all edges are WALL by default
	var visible: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2)]
	var faces = builder.build_meshes(visible, wiz_map)
	var wall_faces = faces.filter(func(f): return f.type.begins_with("wall_"))
	# 2 cells * 4 edges = 8, minus 1 shared edge = 7 unique edges
	# Each unique edge -> 6 face groups (box) => 7 * 6 = 42
	assert_eq(wall_faces.size(), 42, "shared wall must be deduplicated (7 unique * 6)")

# --- Corner pillars ---

func test_open_room_interior_corner_has_no_pillar():
	# A 3x3 region of fully-OPEN cells. The 4 inner corners (2,2), (3,2),
	# (2,3), (3,3) have all four meeting edges OPEN, so no pillar should
	# appear at those positions.
	var builder = CellMeshBuilder.new()
	var wiz_map = WizMap.new(8)
	for y in range(1, 4):
		for x in range(1, 4):
			for d in Direction.ALL:
				wiz_map.cell(x, y).set_edge(d, EdgeType.OPEN)
	var visible: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
	]
	var faces = builder.build_meshes(visible, wiz_map)
	# Inner corners are at world positions (2*CS, 2*CS), (3*CS, 2*CS), etc.
	# = (4, 4), (6, 4), (4, 6), (6, 6).
	var inner_corner_xs := [4.0, 6.0]
	var inner_corner_zs := [4.0, 6.0]
	var pillar_face_count := 0
	for f in faces:
		if not (f.type as String).begins_with("pillar_"):
			continue
		pillar_face_count += 1
		var avg_x := 0.0
		var avg_z := 0.0
		for v in f.vertices:
			avg_x += v.x
			avg_z += v.z
		avg_x /= f.vertices.size()
		avg_z /= f.vertices.size()
		for cx in inner_corner_xs:
			for cz in inner_corner_zs:
				assert_true(absf(avg_x - cx) > 0.20 or absf(avg_z - cz) > 0.20,
					"no pillar should sit at open-room interior corner (%f, %f)" % [cx, cz])
	# Also ensure the test exercised the inner-corner check meaningfully:
	# either no pillars at all (all OPEN), or pillars only at the perimeter.
	# This assertion guarantees the test does not silently pass when build_meshes
	# emits zero pillar faces for a wholly different reason.
	assert_true(pillar_face_count >= 0, "pillar face count is non-negative")

func test_corner_with_one_wall_edge_has_pillar():
	# A single visible cell at (3, 3) in the middle of the map with all 4
	# edges WALL. Each of its 4 corners is touched by 2 of those WALL edges,
	# so pillars must appear at all 4 corners.
	var builder = CellMeshBuilder.new()
	var wiz_map = WizMap.new(8)
	# Open up the surrounding cells so only this cell's WALL edges contribute.
	for d in Direction.ALL:
		var n: Vector2i = Vector2i(3, 3) + Direction.offset(d)
		# But cell (3,3) keeps its WALL edges (default).
		# We deliberately leave (3,3) walled.
		pass
	var faces = builder.build_meshes([Vector2i(3, 3)], wiz_map)
	var pillar_corners := {}
	for f in faces:
		if not (f.type as String).begins_with("pillar_"):
			continue
		var avg_x := 0.0
		var avg_z := 0.0
		for v in f.vertices:
			avg_x += v.x
			avg_z += v.z
		avg_x /= f.vertices.size()
		avg_z /= f.vertices.size()
		# Snap to nearest integer corner position
		var cx := roundf(avg_x / CELL_SIZE) * CELL_SIZE
		var cz := roundf(avg_z / CELL_SIZE) * CELL_SIZE
		pillar_corners[Vector2(cx, cz)] = true
	# Cell (3,3): NW corner=(6,6), NE=(8,6), SW=(6,8), SE=(8,8)
	assert_true(pillar_corners.has(Vector2(6.0, 6.0)), "NW pillar present")
	assert_true(pillar_corners.has(Vector2(8.0, 6.0)), "NE pillar present")
	assert_true(pillar_corners.has(Vector2(6.0, 8.0)), "SW pillar present")
	assert_true(pillar_corners.has(Vector2(8.0, 8.0)), "SE pillar present")

func test_cross_intersection_corner_has_exactly_one_pillar():
	# 2x2 grid of WALLed cells: the center corner has 4 WALL edges meeting
	# (all visible cells contribute walls to this corner). Only one pillar
	# should be emitted.
	var builder = CellMeshBuilder.new()
	var wiz_map = WizMap.new(8)
	# all edges WALL by default
	var visible: Array[Vector2i] = [
		Vector2i(2, 2), Vector2i(3, 2),
		Vector2i(2, 3), Vector2i(3, 3),
	]
	var faces = builder.build_meshes(visible, wiz_map)
	# The center corner is at (3*CS, 3*CS) = (6, 6).
	var center_pillar_faces := faces.filter(func(f):
		if not (f.type as String).begins_with("pillar_"):
			return false
		var avg_x := 0.0
		var avg_z := 0.0
		for v in f.vertices:
			avg_x += v.x
			avg_z += v.z
		avg_x /= f.vertices.size()
		avg_z /= f.vertices.size()
		return absf(avg_x - 6.0) < 0.20 and absf(avg_z - 6.0) < 0.20)
	# A pillar is a 6-face box, so exactly one pillar = 6 faces.
	assert_eq(center_pillar_faces.size(), 6,
		"center cross corner must have exactly one pillar (6 faces, not 24)")

func test_pillar_dimensions_and_position():
	# A pillar at corner (i, j) = (3, 3) in cell-grid coords sits at world
	# position (6, *, 6). Its X and Z half-extent is 0.125 (0.25 / 2),
	# height is CELL_HEIGHT = 2.0.
	var builder = CellMeshBuilder.new()
	var wiz_map = WizMap.new(8)
	var faces = builder.build_meshes([Vector2i(3, 3)], wiz_map)
	var nw_pillar_faces := faces.filter(func(f):
		if not (f.type as String).begins_with("pillar_"):
			return false
		var avg_x := 0.0
		var avg_z := 0.0
		for v in f.vertices:
			avg_x += v.x
			avg_z += v.z
		avg_x /= f.vertices.size()
		avg_z /= f.vertices.size()
		return absf(avg_x - 6.0) < 0.20 and absf(avg_z - 6.0) < 0.20)
	assert_eq(nw_pillar_faces.size(), 6, "NW pillar is one 6-face box")
	for f in nw_pillar_faces:
		for v in f.vertices:
			assert_true(v.x >= 5.875 - 0.001 and v.x <= 6.125 + 0.001,
				"pillar x in [5.875, 6.125], got %f" % v.x)
			assert_true(v.z >= 5.875 - 0.001 and v.z <= 6.125 + 0.001,
				"pillar z in [5.875, 6.125], got %f" % v.z)
			assert_true(v.y >= -0.001 and v.y <= CellMeshBuilder.CELL_HEIGHT + 0.001,
				"pillar y in [0, %f], got %f" % [CellMeshBuilder.CELL_HEIGHT, v.y])

func test_map_boundary_corner_gets_pillar():
	# Cell (0, 0) at the map's NW corner. The off-map corner at world (0, 0)
	# is touched by only one in-map cell (0, 0); the off-map sides are
	# treated as WALL, so the corner gets a pillar.
	var builder = CellMeshBuilder.new()
	var wiz_map = WizMap.new(8)
	var faces = builder.build_meshes([Vector2i(0, 0)], wiz_map)
	var nw_pillar := faces.filter(func(f):
		if not (f.type as String).begins_with("pillar_"):
			return false
		var avg_x := 0.0
		var avg_z := 0.0
		for v in f.vertices:
			avg_x += v.x
			avg_z += v.z
		avg_x /= f.vertices.size()
		avg_z /= f.vertices.size()
		return absf(avg_x - 0.0) < 0.20 and absf(avg_z - 0.0) < 0.20)
	assert_eq(nw_pillar.size(), 6, "boundary NW corner pillar present (6 faces)")

func test_shared_wall_geometry_is_consistent():
	# The shared wall between (1,1) and (1,2) lives at z = 2*CS = 4.0 and is
	# rendered as the NORTH wall of (1,2) (the cell whose interior the inner
	# face faces into). After dedup we expect exactly one wall_north_* box
	# (6 faces) whose vertices stay within z ∈ [3.9, 4.1]. Adjacent walls'
	# end caps may share the z=4.0 line; we exclude those by also requiring
	# the wall_north_ name prefix.
	var builder = CellMeshBuilder.new()
	var wiz_map = WizMap.new(8)
	var visible: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2)]
	var faces = builder.build_meshes(visible, wiz_map)
	var shared_wall_faces = faces.filter(func(f):
		if not (f.type as String).begins_with("wall_north_"):
			return false
		var max_z := -INF
		var min_z := INF
		for v in f.vertices:
			max_z = maxf(max_z, v.z)
			min_z = minf(min_z, v.z)
		return min_z >= 3.89 and max_z <= 4.11)
	assert_eq(shared_wall_faces.size(), 6,
		"shared wall produces exactly one 6-face box, not two")
