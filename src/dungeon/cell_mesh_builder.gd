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

const STAIRS_COUNT := 3
const STAIRS_MAX_HEIGHT := CELL_HEIGHT * 0.5
const STAIRS_WIDTH_MARGIN := 0.5
const STAIRS_DEPTH := 0.3

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

	if cell.tile == TileType.START:
		_add_stairs_up(faces, x0, z0)

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

func _add_wall_face(faces: Array, cell: Cell, dir: int, dir_name: String,
		verts: Array[Vector3], normal: Vector3) -> void:
	var edge := cell.get_edge(dir)
	if edge == EdgeType.WALL:
		faces.append(Face.new("wall_" + dir_name, verts, normal, WALL_COLOR))
	elif edge == EdgeType.DOOR:
		faces.append(Face.new("door_" + dir_name, verts, normal, DOOR_COLOR))
