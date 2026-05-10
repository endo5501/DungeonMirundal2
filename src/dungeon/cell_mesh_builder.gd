class_name CellMeshBuilder
extends RefCounted

const CELL_SIZE := 2.0
const CELL_HEIGHT := 2.0
const WALL_THICKNESS := 0.20
const PILLAR_HALF_WIDTH := 0.125  # 0.25 m square cross-section

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
static var PILLAR_COLOR := Color(0.45, 0.43, 0.38, STONE_ALPHA)

const STAIRS_COUNT := 4
const STAIRS_MAX_HEIGHT := CELL_HEIGHT * 0.65
const STAIRS_WIDTH_MARGIN := 0.45
const STAIRS_DEPTH := 0.24

func build_meshes(visible_cells: Array[Vector2i], wiz_map: WizMap) -> Array:
	var faces: Array = []
	var visible_set: Dictionary = {}
	for c in visible_cells:
		visible_set[c] = true
	var seen_corners: Dictionary = {}
	for grid_pos in visible_cells:
		var cell := wiz_map.cell(grid_pos.x, grid_pos.y)
		# Floor, ceiling, and landmark geometry are per-cell (no dedup needed).
		faces.append_array(build_faces(cell, grid_pos))
		# Walls (and DOOR placeholders): each shared edge is rendered exactly
		# once. Rule: a cell always renders its NORTH and WEST edges; it
		# renders its SOUTH or EAST edges only if the neighboring cell is NOT
		# in the visible set (so an "outer" cell still draws the wall).
		for dir in Direction.ALL:
			var edge_type: int = cell.get_edge(dir)
			if edge_type == EdgeType.OPEN:
				continue
			if dir == Direction.SOUTH or dir == Direction.EAST:
				var neighbor: Vector2i = grid_pos + Direction.offset(dir)
				if visible_set.has(neighbor):
					continue
			_add_wall_box(faces, grid_pos, dir, edge_type)
		# Corner pillars: visit each of the 4 corners of this cell, dedup
		# across cells, and place a pillar where any of the 4 meeting edges
		# is WALL or DOOR (off-map sides are treated as WALL).
		var corners: Array[Vector2i] = [
			grid_pos,
			Vector2i(grid_pos.x + 1, grid_pos.y),
			Vector2i(grid_pos.x, grid_pos.y + 1),
			Vector2i(grid_pos.x + 1, grid_pos.y + 1),
		]
		for corner in corners:
			if seen_corners.has(corner):
				continue
			seen_corners[corner] = true
			if _corner_touches_wall(wiz_map, corner):
				_add_pillar(faces, corner)
	return faces

# Returns true if any of the 4 edges meeting at the given corner is WALL or DOOR.
# Off-map cells contribute WALL edges (boundary), so corners on the map's
# perimeter always receive a pillar.
func _corner_touches_wall(wiz_map: WizMap, corner: Vector2i) -> bool:
	# Edges meeting at corner (i, j) — listed as (cell_pos, dir):
	# - West side  : SOUTH edge of (i-1, j-1)  ↔ NORTH of (i-1, j)
	# - East side  : SOUTH edge of (i,   j-1)  ↔ NORTH of (i,   j)
	# - North side : EAST  edge of (i-1, j-1)  ↔ WEST  of (i,   j-1)
	# - South side : EAST  edge of (i-1, j  )  ↔ WEST  of (i,   j)
	var checks: Array = [
		[Vector2i(corner.x - 1, corner.y - 1), Direction.SOUTH],
		[Vector2i(corner.x,     corner.y - 1), Direction.SOUTH],
		[Vector2i(corner.x - 1, corner.y - 1), Direction.EAST],
		[Vector2i(corner.x - 1, corner.y    ), Direction.EAST],
	]
	for c in checks:
		var pos: Vector2i = c[0]
		var dir: int = c[1]
		if not wiz_map.in_bounds(pos.x, pos.y):
			# Off-map → boundary, treat as WALL
			return true
		var edge: int = wiz_map.get_edge(pos.x, pos.y, dir)
		if edge == EdgeType.WALL or edge == EdgeType.DOOR:
			return true
	return false

# Emits a 6-face box pillar at the given corner (i, j) in cell-grid line coords.
# The pillar is centered at (i*CS, *, j*CS) with a 0.25 m square cross-section.
func _add_pillar(faces: Array, corner: Vector2i) -> void:
	var cx := float(corner.x) * CELL_SIZE
	var cz := float(corner.y) * CELL_SIZE
	_add_box(faces, "pillar",
		Vector3(cx - PILLAR_HALF_WIDTH, 0.0, cz - PILLAR_HALF_WIDTH),
		Vector3(cx + PILLAR_HALF_WIDTH, CELL_HEIGHT, cz + PILLAR_HALF_WIDTH),
		PILLAR_COLOR)

# Emits a 6-face box for a wall on the given direction of grid_pos.
# Face naming: <wall|door>_<dir>_<inner|outer|top|bottom|cap_a|cap_b>
# where the cap names are east/west for N/S walls (along X axis) and
# north/south for E/W walls (along Z axis).
# DOOR edges share the same box geometry but with door_<dir>_* prefix and
# DOOR_COLOR; this is a Step 2 placeholder until Step 5 introduces the
# lintel/jamb/panel assembly.
func _add_wall_box(faces: Array, grid_pos: Vector2i, dir: int, edge_type: int) -> void:
	var color: Color = WALL_COLOR if edge_type == EdgeType.WALL else DOOR_COLOR
	var dir_names := ["north", "east", "south", "west"]
	var dir_name: String = dir_names[dir]
	var prefix: String = ("wall_" if edge_type == EdgeType.WALL else "door_") + dir_name
	var t_half := WALL_THICKNESS * 0.5
	var x0 := grid_pos.x * CELL_SIZE
	var x1 := x0 + CELL_SIZE
	var z0 := grid_pos.y * CELL_SIZE
	var z1 := z0 + CELL_SIZE
	if dir == Direction.NORTH:
		# Wall along X at z = z0. Inner face (+Z normal) faces into the cell.
		_emit_box_along_x(faces, prefix, x0, x1, z0 - t_half, z0 + t_half, true, "east", "west", color)
	elif dir == Direction.SOUTH:
		# Wall along X at z = z1. Inner face (-Z normal) faces into the cell.
		_emit_box_along_x(faces, prefix, x0, x1, z1 - t_half, z1 + t_half, false, "east", "west", color)
	elif dir == Direction.WEST:
		# Wall along Z at x = x0. Inner face (+X normal) faces into the cell.
		_emit_box_along_z(faces, prefix, x0 - t_half, x0 + t_half, z0, z1, true, "north", "south", color)
	else:  # EAST
		# Wall along Z at x = x1. Inner face (-X normal) faces into the cell.
		_emit_box_along_z(faces, prefix, x1 - t_half, x1 + t_half, z0, z1, false, "north", "south", color)

# Helper for walls running along the X axis (NORTH and SOUTH walls).
# inner_is_max_z=true → inner face is at z=z_max (NORTH wall, faces +Z).
# inner_is_max_z=false → inner face is at z=z_min (SOUTH wall, faces -Z).
func _emit_box_along_x(faces: Array, prefix: String, x_min: float, x_max: float,
		z_min: float, z_max: float, inner_is_max_z: bool,
		cap_pos_x_name: String, cap_neg_x_name: String, color: Color) -> void:
	var z_inner := z_max if inner_is_max_z else z_min
	var z_outer := z_min if inner_is_max_z else z_max
	var inner_n := Vector3(0, 0, 1.0) if inner_is_max_z else Vector3(0, 0, -1.0)
	var outer_n := Vector3(0, 0, -1.0) if inner_is_max_z else Vector3(0, 0, 1.0)
	var inner_verts: Array[Vector3]
	var outer_verts: Array[Vector3]
	if inner_is_max_z:
		inner_verts = [Vector3(x_max, 0.0, z_inner), Vector3(x_min, 0.0, z_inner),
			Vector3(x_min, CELL_HEIGHT, z_inner), Vector3(x_max, CELL_HEIGHT, z_inner)]
		outer_verts = [Vector3(x_min, 0.0, z_outer), Vector3(x_max, 0.0, z_outer),
			Vector3(x_max, CELL_HEIGHT, z_outer), Vector3(x_min, CELL_HEIGHT, z_outer)]
	else:
		inner_verts = [Vector3(x_min, 0.0, z_inner), Vector3(x_max, 0.0, z_inner),
			Vector3(x_max, CELL_HEIGHT, z_inner), Vector3(x_min, CELL_HEIGHT, z_inner)]
		outer_verts = [Vector3(x_max, 0.0, z_outer), Vector3(x_min, 0.0, z_outer),
			Vector3(x_min, CELL_HEIGHT, z_outer), Vector3(x_max, CELL_HEIGHT, z_outer)]
	faces.append(Face.new(prefix + "_inner", inner_verts, inner_n, color))
	faces.append(Face.new(prefix + "_outer", outer_verts, outer_n, color))
	var top_verts: Array[Vector3] = [Vector3(x_min, CELL_HEIGHT, z_max), Vector3(x_max, CELL_HEIGHT, z_max),
		Vector3(x_max, CELL_HEIGHT, z_min), Vector3(x_min, CELL_HEIGHT, z_min)]
	faces.append(Face.new(prefix + "_top", top_verts, Vector3(0, 1, 0), color))
	var bottom_verts: Array[Vector3] = [Vector3(x_min, 0.0, z_min), Vector3(x_max, 0.0, z_min),
		Vector3(x_max, 0.0, z_max), Vector3(x_min, 0.0, z_max)]
	faces.append(Face.new(prefix + "_bottom", bottom_verts, Vector3(0, -1, 0), color))
	# +X end cap
	var cap_pos_x_verts: Array[Vector3] = [Vector3(x_max, 0.0, z_min), Vector3(x_max, 0.0, z_max),
		Vector3(x_max, CELL_HEIGHT, z_max), Vector3(x_max, CELL_HEIGHT, z_min)]
	faces.append(Face.new(prefix + "_" + cap_pos_x_name, cap_pos_x_verts, Vector3(1, 0, 0), color))
	# -X end cap
	var cap_neg_x_verts: Array[Vector3] = [Vector3(x_min, 0.0, z_max), Vector3(x_min, 0.0, z_min),
		Vector3(x_min, CELL_HEIGHT, z_min), Vector3(x_min, CELL_HEIGHT, z_max)]
	faces.append(Face.new(prefix + "_" + cap_neg_x_name, cap_neg_x_verts, Vector3(-1, 0, 0), color))

# Helper for walls running along the Z axis (WEST and EAST walls).
# inner_is_max_x=true → inner face is at x=x_max (WEST wall, faces +X).
# inner_is_max_x=false → inner face is at x=x_min (EAST wall, faces -X).
func _emit_box_along_z(faces: Array, prefix: String, x_min: float, x_max: float,
		z_min: float, z_max: float, inner_is_max_x: bool,
		cap_neg_z_name: String, cap_pos_z_name: String, color: Color) -> void:
	var x_inner := x_max if inner_is_max_x else x_min
	var x_outer := x_min if inner_is_max_x else x_max
	var inner_n := Vector3(1.0, 0, 0) if inner_is_max_x else Vector3(-1.0, 0, 0)
	var outer_n := Vector3(-1.0, 0, 0) if inner_is_max_x else Vector3(1.0, 0, 0)
	var inner_verts: Array[Vector3]
	var outer_verts: Array[Vector3]
	if inner_is_max_x:
		inner_verts = [Vector3(x_inner, 0.0, z_min), Vector3(x_inner, 0.0, z_max),
			Vector3(x_inner, CELL_HEIGHT, z_max), Vector3(x_inner, CELL_HEIGHT, z_min)]
		outer_verts = [Vector3(x_outer, 0.0, z_max), Vector3(x_outer, 0.0, z_min),
			Vector3(x_outer, CELL_HEIGHT, z_min), Vector3(x_outer, CELL_HEIGHT, z_max)]
	else:
		inner_verts = [Vector3(x_inner, 0.0, z_max), Vector3(x_inner, 0.0, z_min),
			Vector3(x_inner, CELL_HEIGHT, z_min), Vector3(x_inner, CELL_HEIGHT, z_max)]
		outer_verts = [Vector3(x_outer, 0.0, z_min), Vector3(x_outer, 0.0, z_max),
			Vector3(x_outer, CELL_HEIGHT, z_max), Vector3(x_outer, CELL_HEIGHT, z_min)]
	faces.append(Face.new(prefix + "_inner", inner_verts, inner_n, color))
	faces.append(Face.new(prefix + "_outer", outer_verts, outer_n, color))
	var top_verts: Array[Vector3] = [Vector3(x_min, CELL_HEIGHT, z_max), Vector3(x_max, CELL_HEIGHT, z_max),
		Vector3(x_max, CELL_HEIGHT, z_min), Vector3(x_min, CELL_HEIGHT, z_min)]
	faces.append(Face.new(prefix + "_top", top_verts, Vector3(0, 1, 0), color))
	var bottom_verts: Array[Vector3] = [Vector3(x_min, 0.0, z_min), Vector3(x_max, 0.0, z_min),
		Vector3(x_max, 0.0, z_max), Vector3(x_min, 0.0, z_max)]
	faces.append(Face.new(prefix + "_bottom", bottom_verts, Vector3(0, -1, 0), color))
	# -Z end cap
	var cap_neg_z_verts: Array[Vector3] = [Vector3(x_min, 0.0, z_min), Vector3(x_max, 0.0, z_min),
		Vector3(x_max, CELL_HEIGHT, z_min), Vector3(x_min, CELL_HEIGHT, z_min)]
	faces.append(Face.new(prefix + "_" + cap_neg_z_name, cap_neg_z_verts, Vector3(0, 0, -1), color))
	# +Z end cap
	var cap_pos_z_verts: Array[Vector3] = [Vector3(x_max, 0.0, z_max), Vector3(x_min, 0.0, z_max),
		Vector3(x_min, CELL_HEIGHT, z_max), Vector3(x_max, CELL_HEIGHT, z_max)]
	faces.append(Face.new(prefix + "_" + cap_pos_z_name, cap_pos_z_verts, Vector3(0, 0, 1), color))

func build_faces(cell: Cell, grid_pos: Vector2i) -> Array:
	# Per-cell helper: emits floor, ceiling, and landmark geometry only.
	# Wall geometry is emitted by build_meshes via _add_wall_box, with cross-cell
	# deduplication.
	var faces: Array = []
	var x0 := grid_pos.x * CELL_SIZE
	var z0 := grid_pos.y * CELL_SIZE
	var x1 := x0 + CELL_SIZE
	var z1 := z0 + CELL_SIZE
	var y0 := 0.0
	var y1 := CELL_HEIGHT

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

