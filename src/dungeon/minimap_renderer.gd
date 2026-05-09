class_name MinimapRenderer
extends RefCounted

const VIEW_RADIUS := 3
const VIEW_SIZE := VIEW_RADIUS * 2 + 1  # 7
const CELL_PX := 9
const WALL_PX := 3
const STRIDE := CELL_PX + WALL_PX  # 12
const IMAGE_SIZE := STRIDE * VIEW_SIZE + WALL_PX  # 87
const STAIRS_UP_ICON_PATH := "res://assets/images/map_icons/stairs_up.png"
const STAIRS_DOWN_ICON_PATH := "res://assets/images/map_icons/stairs_down.png"

static var COLOR_FLOOR := Color8(102, 102, 89)
static var COLOR_WALL := Color8(178, 178, 178)
static var COLOR_DOOR := Color8(153, 102, 51)
static var COLOR_PLAYER := Color8(51, 204, 51)
static var COLOR_START := Color8(238, 238, 230)
static var COLOR_STAIRS_UP := Color8(238, 238, 230)
static var COLOR_STAIRS_DOWN := Color8(238, 238, 230)
static var COLOR_PIT := Color8(32, 28, 36)
static var COLOR_GOAL := Color8(220, 70, 70)
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

	var tile: int = wiz_map.cell(cx, cy).tile
	_draw_landmark_icon(img, tile, vx, vy)

func _draw_landmark_icon(img: Image, tile: int, vx: int, vy: int) -> void:
	match tile:
		TileType.START:
			if not _draw_icon_image(img, vx, vy, STAIRS_UP_ICON_PATH):
				_draw_stairs_up_fallback(img, vx, vy, COLOR_START)
		TileType.STAIRS_UP:
			if not _draw_icon_image(img, vx, vy, STAIRS_UP_ICON_PATH):
				_draw_stairs_up_fallback(img, vx, vy, COLOR_STAIRS_UP)
		TileType.STAIRS_DOWN:
			if not _draw_icon_image(img, vx, vy, STAIRS_DOWN_ICON_PATH):
				_draw_stairs_down_fallback(img, vx, vy)
		TileType.GOAL:
			_draw_icon_pattern(img, vx, vy, [
				"#.......#",
				".#.....#.",
				"..#...#..",
				"...#.#...",
				"....#....",
				"...#.#...",
				"..#...#..",
				".#.....#.",
				"#.......#",
			], COLOR_GOAL)

func _draw_icon_pattern(img: Image, vx: int, vy: int, pattern: Array[String], color: Color) -> void:
	var fx := vx * STRIDE + WALL_PX
	var fy := vy * STRIDE + WALL_PX
	for dy in range(CELL_PX):
		for dx in range(CELL_PX):
			if pattern[dy].substr(dx, 1) == "#":
				img.set_pixel(fx + dx, fy + dy, color)

func _draw_icon_image(img: Image, vx: int, vy: int, path: String) -> bool:
	var fx := vx * STRIDE + WALL_PX
	var fy := vy * STRIDE + WALL_PX
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		return false
	var icon := texture.get_image()
	if icon == null:
		return false
	for dy in range(CELL_PX):
		for dx in range(CELL_PX):
			var sx := mini(icon.get_width() - 1, int(float(dx) * float(icon.get_width()) / float(CELL_PX)))
			var sy := mini(icon.get_height() - 1, int(float(dy) * float(icon.get_height()) / float(CELL_PX)))
			var color := icon.get_pixel(sx, sy)
			if color.a > 0.0:
				img.set_pixel(fx + dx, fy + dy, color)
	return true

func _draw_stairs_up_fallback(img: Image, vx: int, vy: int, color: Color) -> void:
	_draw_icon_pattern(img, vx, vy, [
		"........#",
		".......##",
		"......###",
		".....####",
		"....#####",
		"...######",
		"..#######",
		".########",
		"#########",
	], color)

func _draw_stairs_down_fallback(img: Image, vx: int, vy: int) -> void:
	var fx := vx * STRIDE + WALL_PX
	var fy := vy * STRIDE + WALL_PX
	var pattern: Array[String] = [
		"SSSSSSSSS",
		"S#######S",
		"S#.....#S",
		"S###...#S",
		"S..#...#S",
		"S..###.#S",
		"S....#.#S",
		"S....###S",
		"SSSSSSSSS",
	]
	for dy in range(CELL_PX):
		for dx in range(CELL_PX):
			var marker := pattern[dy].substr(dx, 1)
			if marker == "#":
				img.set_pixel(fx + dx, fy + dy, COLOR_STAIRS_DOWN)
			elif marker == "S":
				img.set_pixel(fx + dx, fy + dy, COLOR_PIT)

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
			for wy in range(WALL_PX):
				var ey := fy - WALL_PX + wy
				if ey < 0:
					continue
				for dx in range(CELL_PX):
					img.set_pixel(fx + dx, ey, color)
		Direction.SOUTH:
			for wy in range(WALL_PX):
				var ey := fy + CELL_PX + wy
				if ey >= IMAGE_SIZE:
					continue
				for dx in range(CELL_PX):
					img.set_pixel(fx + dx, ey, color)
		Direction.WEST:
			for wx in range(WALL_PX):
				var ex := fx - WALL_PX + wx
				if ex < 0:
					continue
				for dy in range(CELL_PX):
					img.set_pixel(ex, fy + dy, color)
		Direction.EAST:
			for wx in range(WALL_PX):
				var ex := fx + CELL_PX + wx
				if ex >= IMAGE_SIZE:
					continue
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
				for dy in range(WALL_PX):
					for dx in range(WALL_PX):
						var x := px + dx
						var y := py + dy
						if x < IMAGE_SIZE and y < IMAGE_SIZE:
							img.set_pixel(x, y, color)

func _corner_color_from_neighbors(img: Image, px: int, py: int) -> Color:
	var has_wall := false
	var has_door := false
	var has_floor := false
	var non_bg_count := 0
	var offsets: Array[Vector2i] = []
	for i in range(WALL_PX):
		offsets.append(Vector2i(-1, i))
		offsets.append(Vector2i(WALL_PX, i))
		offsets.append(Vector2i(i, -1))
		offsets.append(Vector2i(i, WALL_PX))
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
