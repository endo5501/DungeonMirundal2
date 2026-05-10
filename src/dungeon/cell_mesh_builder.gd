class_name CellMeshBuilder
extends RefCounted

const CELL_SIZE := 2.0
const CELL_HEIGHT := 2.0

class Face:
	var type: String
	var vertices: Array[Vector3]
	var normal: Vector3
	var color: Color

	func _init(t: String, verts: Array[Vector3], n: Vector3, c: Color) -> void:
		type = t
		vertices = verts
		normal = n
		color = c

# Vertex color alpha carries a surface-kind flag for the dungeon shader:
# STONE_ALPHA (1.0) is the default stone / stairs / floor / ceiling path
# and WOOD_ALPHA (0.5) switches the shader to the wooden-plank pattern.
# The ShaderMaterial is opaque (no blending / transparency render_mode),
# so the alpha channel is data only and never affects the rendered alpha.
const STONE_ALPHA := 1.0
const WOOD_ALPHA := 0.5

static var WALL_COLOR := Color(0.55, 0.53, 0.48, STONE_ALPHA)
static var DOOR_COLOR := Color(0.45, 0.28, 0.12, WOOD_ALPHA)
static var FLOOR_COLOR := Color(0.28, 0.26, 0.24, STONE_ALPHA)
static var CEILING_COLOR := Color(0.20, 0.19, 0.22, STONE_ALPHA)
static var STAIRS_COLOR := Color(0.48, 0.42, 0.34, STONE_ALPHA)
static var ALTAR_CAP_COLOR := Color(0.80, 0.62, 0.25, STONE_ALPHA)
static var PIT_COLOR := Color(0.04, 0.04, 0.05, STONE_ALPHA)
static var ALTAR_COLOR := Color(0.55, 0.18, 0.18, STONE_ALPHA)

const STAIRS_COUNT := 4
const STAIRS_MAX_HEIGHT := CELL_HEIGHT * 0.65
const STAIRS_WIDTH_MARGIN := 0.45
const STAIRS_DEPTH := 0.24

func build_meshes(visible_cells: Array[Vector2i], wiz_map: WizMap) -> Array:
	var faces: Array = []
	for grid_pos in visible_cells:
		var cell := wiz_map.cell(grid_pos.x, grid_pos.y)
		faces.append_array(build_faces(cell, grid_pos))
	return faces

func build_faces(cell: Cell, grid_pos: Vector2i) -> Array:
	var faces: Array = []
	var x0 := grid_pos.x * CELL_SIZE
	var z0 := grid_pos.y * CELL_SIZE
	var x1 := x0 + CELL_SIZE
	var z1 := z0 + CELL_SIZE
	var y0 := 0.0
	var y1 := CELL_HEIGHT

	# walls
	_add_wall_face(faces, cell, Direction.NORTH, "north",
		[Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0)],
		Vector3(0, 0, 1))
	_add_wall_face(faces, cell, Direction.SOUTH, "south",
		[Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1)],
		Vector3(0, 0, -1))
	_add_wall_face(faces, cell, Direction.EAST, "east",
		[Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)],
		Vector3(-1, 0, 0))
	_add_wall_face(faces, cell, Direction.WEST, "west",
		[Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1)],
		Vector3(1, 0, 0))

	# floor (visible from above, CCW winding when viewed from +Y)
	var floor_verts: Array[Vector3] = [
		Vector3(x0, y0, z1), Vector3(x1, y0, z1),
		Vector3(x1, y0, z0), Vector3(x0, y0, z0)]
	faces.append(Face.new("floor", floor_verts, Vector3(0, 1, 0), FLOOR_COLOR))

	# ceiling (visible from below, CCW winding when viewed from -Y)
	var ceil_verts: Array[Vector3] = [
		Vector3(x0, y1, z0), Vector3(x1, y1, z0),
		Vector3(x1, y1, z1), Vector3(x0, y1, z1)]
	faces.append(Face.new("ceiling", ceil_verts, Vector3(0, -1, 0), CEILING_COLOR))

	match cell.tile:
		TileType.START:
			_add_stairs_up(faces, x0, z0)
		TileType.STAIRS_UP:
			_add_stairs_up(faces, x0, z0)
		TileType.STAIRS_DOWN:
			_add_stairs_down(faces, x0, z0)
		TileType.GOAL:
			_add_goal_altar(faces, x0, z0)

	return faces

func _add_stairs_up(faces: Array, x0: float, z0: float) -> void:
	var x_lo := x0 + STAIRS_WIDTH_MARGIN
	var x_hi := x0 + CELL_SIZE - STAIRS_WIDTH_MARGIN
	# Stairs occupy the northern half of the cell; front (closest to the player
	# approaching from the south) is step 0 at the cell's midline.
	var z_mid := z0 + CELL_SIZE * 0.5
	for i in range(STAIRS_COUNT):
		var y_top := STAIRS_MAX_HEIGHT * float(i + 1) / float(STAIRS_COUNT)
		var y_prev := STAIRS_MAX_HEIGHT * float(i) / float(STAIRS_COUNT)
		var z_front := z_mid - float(i) * STAIRS_DEPTH
		var z_back := z_mid - float(i + 1) * STAIRS_DEPTH
		faces.append(Face.new("stairs_up_top_%d" % i,
			[Vector3(x_lo, y_top, z_front), Vector3(x_hi, y_top, z_front),
				Vector3(x_hi, y_top, z_back), Vector3(x_lo, y_top, z_back)],
			Vector3(0, 1, 0), STAIRS_COLOR))
		faces.append(Face.new("stairs_up_riser_%d" % i,
			[Vector3(x_lo, y_prev, z_front), Vector3(x_hi, y_prev, z_front),
				Vector3(x_hi, y_top, z_front), Vector3(x_lo, y_top, z_front)],
			Vector3(0, 0, 1), STAIRS_COLOR))
		faces.append(Face.new("stairs_up_east_%d" % i,
			[Vector3(x_hi, y_prev, z_front), Vector3(x_hi, y_prev, z_back),
				Vector3(x_hi, y_top, z_back), Vector3(x_hi, y_top, z_front)],
			Vector3(1, 0, 0), STAIRS_COLOR))
		faces.append(Face.new("stairs_up_west_%d" % i,
			[Vector3(x_lo, y_prev, z_back), Vector3(x_lo, y_prev, z_front),
				Vector3(x_lo, y_top, z_front), Vector3(x_lo, y_top, z_back)],
			Vector3(-1, 0, 0), STAIRS_COLOR))

func _add_stairs_down(faces: Array, x0: float, z0: float) -> void:
	var x_lo := x0 + 0.36
	var x_hi := x0 + CELL_SIZE - 0.36
	var z_lo := z0 + 0.28
	var z_hi := z0 + CELL_SIZE - 0.30
	var pit_y := 0.03
	faces.append(Face.new("pit_dark_floor",
		[Vector3(x_lo, pit_y, z_hi), Vector3(x_hi, pit_y, z_hi),
			Vector3(x_hi, pit_y, z_lo), Vector3(x_lo, pit_y, z_lo)],
		Vector3(0, 1, 0), PIT_COLOR))
	_add_box(faces, "pit_north_rim", Vector3(x_lo, 0.04, z_lo), Vector3(x_hi, 0.13, z_lo + 0.10), STAIRS_COLOR)
	_add_box(faces, "pit_south_rim", Vector3(x_lo, 0.04, z_hi - 0.10), Vector3(x_hi, 0.13, z_hi), STAIRS_COLOR)
	_add_box(faces, "pit_west_rim", Vector3(x_lo, 0.04, z_lo), Vector3(x_lo + 0.10, 0.13, z_hi), STAIRS_COLOR)
	_add_box(faces, "pit_east_rim", Vector3(x_hi - 0.10, 0.04, z_lo), Vector3(x_hi, 0.13, z_hi), STAIRS_COLOR)

	var step_x_lo := x0 + 0.56
	var step_x_hi := x0 + CELL_SIZE - 0.56
	var step_z_front := z0 + CELL_SIZE * 0.70
	for i in range(STAIRS_COUNT):
		var y_top := 0.42 - 0.08 * float(i)
		var y_prev := maxf(0.08, y_top - 0.10)
		var z_front := step_z_front - float(i) * 0.24
		var z_back := z_front - 0.18
		faces.append(Face.new("stairs_down_top_%d" % i,
			[Vector3(step_x_lo, y_top, z_front), Vector3(step_x_hi, y_top, z_front),
				Vector3(step_x_hi, y_top, z_back), Vector3(step_x_lo, y_top, z_back)],
			Vector3(0, 1, 0), STAIRS_COLOR))
		faces.append(Face.new("stairs_down_riser_%d" % i,
			[Vector3(step_x_lo, y_prev, z_back), Vector3(step_x_hi, y_prev, z_back),
				Vector3(step_x_hi, y_top, z_back), Vector3(step_x_lo, y_top, z_back)],
			Vector3(0, 0, -1), STAIRS_COLOR))

func _add_goal_altar(faces: Array, x0: float, z0: float) -> void:
	var x_mid := x0 + CELL_SIZE * 0.5
	var z_mid := z0 + CELL_SIZE * 0.5
	_add_box(faces, "altar_base",
		Vector3(x_mid - 0.46, 0.02, z_mid - 0.36),
		Vector3(x_mid + 0.46, 0.24, z_mid + 0.36), ALTAR_COLOR)
	_add_box(faces, "altar_stone",
		Vector3(x_mid - 0.24, 0.24, z_mid - 0.18),
		Vector3(x_mid + 0.24, 0.92, z_mid + 0.18), ALTAR_COLOR)
	_add_box(faces, "altar_cap",
		Vector3(x_mid - 0.34, 0.92, z_mid - 0.24),
		Vector3(x_mid + 0.34, 1.06, z_mid + 0.24), ALTAR_CAP_COLOR)

func _add_box(faces: Array, prefix: String, min_corner: Vector3, max_corner: Vector3, color: Color) -> void:
	var x0 := min_corner.x
	var y0 := min_corner.y
	var z0 := min_corner.z
	var x1 := max_corner.x
	var y1 := max_corner.y
	var z1 := max_corner.z
	faces.append(Face.new(prefix + "_top",
		[Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0)],
		Vector3(0, 1, 0), color))
	faces.append(Face.new(prefix + "_bottom",
		[Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)],
		Vector3(0, -1, 0), color))
	faces.append(Face.new(prefix + "_north",
		[Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0)],
		Vector3(0, 0, 1), color))
	faces.append(Face.new(prefix + "_south",
		[Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1)],
		Vector3(0, 0, -1), color))
	faces.append(Face.new(prefix + "_east",
		[Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)],
		Vector3(-1, 0, 0), color))
	faces.append(Face.new(prefix + "_west",
		[Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1)],
		Vector3(1, 0, 0), color))

func _add_wall_face(faces: Array, cell: Cell, dir: int, dir_name: String,
		verts: Array[Vector3], normal: Vector3) -> void:
	var edge := cell.get_edge(dir)
	if edge == EdgeType.WALL:
		faces.append(Face.new("wall_" + dir_name, verts, normal, WALL_COLOR))
	elif edge == EdgeType.DOOR:
		faces.append(Face.new("door_" + dir_name, verts, normal, DOOR_COLOR))
