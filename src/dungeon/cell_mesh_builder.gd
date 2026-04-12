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

static var WALL_COLOR := Color(0.7, 0.7, 0.65)
static var DOOR_COLOR := Color(0.6, 0.35, 0.1)
static var FLOOR_COLOR := Color(0.15, 0.15, 0.2)
static var CEILING_COLOR := Color(0.1, 0.1, 0.15)

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

	return faces

func _add_wall_face(faces: Array, cell: Cell, dir: int, dir_name: String,
		verts: Array[Vector3], normal: Vector3) -> void:
	var edge := cell.get_edge(dir)
	if edge == EdgeType.WALL:
		faces.append(Face.new("wall_" + dir_name, verts, normal, WALL_COLOR))
	elif edge == EdgeType.DOOR:
		faces.append(Face.new("door_" + dir_name, verts, normal, DOOR_COLOR))
