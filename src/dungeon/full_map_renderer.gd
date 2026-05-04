class_name FullMapRenderer
extends RefCounted

const MIN_CELL_PX := 4
const WALL_PX := 1

static var COLOR_FLOOR := Color8(102, 102, 89)
static var COLOR_WALL := Color8(178, 178, 178)
static var COLOR_DOOR := Color8(153, 102, 51)
static var COLOR_PLAYER := Color8(51, 204, 51)
static var COLOR_START := Color8(230, 204, 51)
static var COLOR_GOAL := Color8(220, 70, 70)
static var COLOR_STAIRS_DOWN := Color8(120, 180, 220)
static var COLOR_STAIRS_UP := Color8(180, 120, 220)
static var COLOR_BG := Color8(0, 0, 0)


func render(wiz_map: WizMap, explored_map: ExploredMap, player_state: PlayerState, target_size: Vector2i) -> Image:
	var cell_px := _calc_cell_px(target_size, wiz_map.map_size)
	var floor_px := cell_px - WALL_PX
	var image_size := cell_px * wiz_map.map_size + WALL_PX
	var img := Image.create(image_size, image_size, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_BG)

	for cell_pos in explored_map.get_visited_cells():
		_draw_cell(img, wiz_map, explored_map, cell_pos.x, cell_pos.y, cell_px, floor_px)

	_draw_player(img, player_state, cell_px, floor_px)
	return img


static func _calc_cell_px(target_size: Vector2i, map_size: int) -> int:
	var smaller := mini(target_size.x, target_size.y)
	var px := int(smaller / map_size)
	return maxi(MIN_CELL_PX, px)


func _draw_cell(img: Image, wiz_map: WizMap, explored_map: ExploredMap,
		cx: int, cy: int, cell_px: int, floor_px: int) -> void:
	var fx := cx * cell_px + WALL_PX
	var fy := cy * cell_px + WALL_PX
	for dy in range(floor_px):
		for dx in range(floor_px):
			img.set_pixel(fx + dx, fy + dy, COLOR_FLOOR)

	for dir in Direction.ALL:
		var edge := wiz_map.get_edge(cx, cy, dir)
		var color := _edge_color(edge, cx, cy, dir, explored_map)
		_draw_edge_line(img, cx, cy, dir, color, cell_px, floor_px)

	var tile: int = wiz_map.cell(cx, cy).tile
	if tile == TileType.START:
		_draw_marker(img, cx, cy, cell_px, floor_px, COLOR_START)
	elif tile == TileType.GOAL:
		_draw_marker(img, cx, cy, cell_px, floor_px, COLOR_GOAL)
	elif tile == TileType.STAIRS_DOWN:
		_draw_marker(img, cx, cy, cell_px, floor_px, COLOR_STAIRS_DOWN)
	elif tile == TileType.STAIRS_UP:
		_draw_marker(img, cx, cy, cell_px, floor_px, COLOR_STAIRS_UP)


func _edge_color(edge: int, cx: int, cy: int, dir: int, explored_map: ExploredMap) -> Color:
	if edge == EdgeType.WALL:
		return COLOR_WALL
	if edge == EdgeType.DOOR:
		return COLOR_DOOR
	var neighbor := Vector2i(cx, cy) + Direction.offset(dir)
	if explored_map.is_visited(neighbor):
		return COLOR_FLOOR
	return COLOR_BG


func _draw_edge_line(img: Image, cx: int, cy: int, dir: int, color: Color,
		cell_px: int, floor_px: int) -> void:
	var fx := cx * cell_px + WALL_PX
	var fy := cy * cell_px + WALL_PX
	var image_size := img.get_width()

	match dir:
		Direction.NORTH:
			var ey := fy - WALL_PX
			if ey < 0:
				return
			for dx in range(floor_px):
				img.set_pixel(fx + dx, ey, color)
		Direction.SOUTH:
			var ey := fy + floor_px
			if ey >= image_size:
				return
			for dx in range(floor_px):
				img.set_pixel(fx + dx, ey, color)
		Direction.WEST:
			var ex := fx - WALL_PX
			if ex < 0:
				return
			for dy in range(floor_px):
				img.set_pixel(ex, fy + dy, color)
		Direction.EAST:
			var ex := fx + floor_px
			if ex >= image_size:
				return
			for dy in range(floor_px):
				img.set_pixel(ex, fy + dy, color)


func _draw_marker(img: Image, cx: int, cy: int, cell_px: int, floor_px: int, color: Color) -> void:
	var fx := cx * cell_px + WALL_PX
	var fy := cy * cell_px + WALL_PX
	var mx := fx + int(floor_px / 2)
	for dy in range(floor_px):
		img.set_pixel(mx, fy + dy, color)


func _draw_player(img: Image, player_state: PlayerState, cell_px: int, floor_px: int) -> void:
	var cx := player_state.position.x
	var cy := player_state.position.y
	var fx := cx * cell_px + WALL_PX
	var fy := cy * cell_px + WALL_PX
	for dy in range(floor_px):
		for dx in range(floor_px):
			img.set_pixel(fx + dx, fy + dy, COLOR_PLAYER)
	_draw_edge_line(img, cx, cy, player_state.facing, COLOR_PLAYER, cell_px, floor_px)
