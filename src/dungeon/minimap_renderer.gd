class_name MinimapRenderer
extends RefCounted

const VIEW_RADIUS := 3
const VIEW_SIZE := VIEW_RADIUS * 2 + 1  # 7
const CELL_PX := 3
const WALL_PX := 1
const STRIDE := CELL_PX + WALL_PX  # 4
const IMAGE_SIZE := STRIDE * VIEW_SIZE + WALL_PX  # 29

static var COLOR_FLOOR := Color8(102, 102, 89)
static var COLOR_WALL := Color8(178, 178, 178)
static var COLOR_DOOR := Color8(153, 102, 51)
static var COLOR_PLAYER := Color8(51, 204, 51)
static var COLOR_START := Color8(230, 204, 51)
static var COLOR_BG := Color8(0, 0, 0)

func render(wiz_map: WizMap, explored_map: ExploredMap, player_state: PlayerState) -> Image:
	var img := Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_BG)

	var px := player_state.position.x
	var py := player_state.position.y

	for vy in range(VIEW_SIZE):
		for vx in range(VIEW_SIZE):
			var cx := px - VIEW_RADIUS + vx
			var cy := py - VIEW_RADIUS + vy
			if not wiz_map.in_bounds(cx, cy):
				continue
			if not explored_map.is_visited(Vector2i(cx, cy)):
				continue
			_draw_cell(img, wiz_map, explored_map, cx, cy, vx, vy)

	_fill_corners(img)
	_draw_player(img, player_state)
	return img

func _draw_cell(img: Image, wiz_map: WizMap, explored_map: ExploredMap,
		cx: int, cy: int, vx: int, vy: int) -> void:
	var fx := vx * STRIDE + WALL_PX
	var fy := vy * STRIDE + WALL_PX
	for dy in range(CELL_PX):
		for dx in range(CELL_PX):
			img.set_pixel(fx + dx, fy + dy, COLOR_FLOOR)

	for dir in Direction.ALL:
		var edge := wiz_map.get_edge(cx, cy, dir)
		var color := _edge_color(edge, cx, cy, dir, explored_map)
		_draw_edge_line(img, vx, vy, dir, color)

	if wiz_map.cell(cx, cy).tile == TileType.START:
		_draw_start_marker(img, vx, vy)

func _draw_start_marker(img: Image, vx: int, vy: int) -> void:
	var mx := vx * STRIDE + WALL_PX + 1
	var fy := vy * STRIDE + WALL_PX
	for dy in range(CELL_PX):
		img.set_pixel(mx, fy + dy, COLOR_START)

func _edge_color(edge: int, cx: int, cy: int, dir: int, explored_map: ExploredMap) -> Color:
	if edge == EdgeType.WALL:
		return COLOR_WALL
	if edge == EdgeType.DOOR:
		return COLOR_DOOR
	# OPEN: connect with floor color only if neighbor is explored
	var neighbor := Vector2i(cx, cy) + Direction.offset(dir)
	if explored_map.is_visited(neighbor):
		return COLOR_FLOOR
	return COLOR_BG

func _draw_edge_line(img: Image, vx: int, vy: int, dir: int, color: Color) -> void:
	var fx := vx * STRIDE + WALL_PX
	var fy := vy * STRIDE + WALL_PX

	match dir:
		Direction.NORTH:
			var ey := fy - WALL_PX
			if ey < 0:
				return
			for dx in range(CELL_PX):
				img.set_pixel(fx + dx, ey, color)
		Direction.SOUTH:
			var ey := fy + CELL_PX
			if ey >= IMAGE_SIZE:
				return
			for dx in range(CELL_PX):
				img.set_pixel(fx + dx, ey, color)
		Direction.WEST:
			var ex := fx - WALL_PX
			if ex < 0:
				return
			for dy in range(CELL_PX):
				img.set_pixel(ex, fy + dy, color)
		Direction.EAST:
			var ex := fx + CELL_PX
			if ex >= IMAGE_SIZE:
				return
			for dy in range(CELL_PX):
				img.set_pixel(ex, fy + dy, color)

func _fill_corners(img: Image) -> void:
	for cy in range(VIEW_SIZE + 1):
		for cx in range(VIEW_SIZE + 1):
			var px := cx * STRIDE
			var py := cy * STRIDE
			if px >= IMAGE_SIZE or py >= IMAGE_SIZE:
				continue
			var color := _corner_color_from_neighbors(img, px, py)
			if color != COLOR_BG:
				img.set_pixel(px, py, color)

func _corner_color_from_neighbors(img: Image, px: int, py: int) -> Color:
	var has_wall := false
	var has_door := false
	var has_floor := false
	var non_bg_count := 0
	var offsets: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for ofs in offsets:
		var nx: int = px + ofs.x
		var ny: int = py + ofs.y
		if nx < 0 or nx >= IMAGE_SIZE or ny < 0 or ny >= IMAGE_SIZE:
			continue
		var c := img.get_pixel(nx, ny)
		if c == COLOR_WALL:
			has_wall = true
			non_bg_count += 1
		elif c == COLOR_DOOR:
			has_door = true
			non_bg_count += 1
		elif c == COLOR_FLOOR or c == COLOR_PLAYER:
			has_floor = true
			non_bg_count += 1
	if non_bg_count < 2:
		return COLOR_BG
	if has_wall:
		return COLOR_WALL
	if has_door:
		return COLOR_DOOR
	if has_floor:
		return COLOR_FLOOR
	return COLOR_BG

func _draw_player(img: Image, player_state: PlayerState) -> void:
	var fx := VIEW_RADIUS * STRIDE + WALL_PX
	var fy := VIEW_RADIUS * STRIDE + WALL_PX
	for dy in range(CELL_PX):
		for dx in range(CELL_PX):
			img.set_pixel(fx + dx, fy + dy, COLOR_PLAYER)

	_draw_edge_line(img, VIEW_RADIUS, VIEW_RADIUS, player_state.facing, COLOR_PLAYER)
