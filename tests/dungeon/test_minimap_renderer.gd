extends GutTest

var _renderer: MinimapRenderer

const STAIRS_DOWN_ICON_PATH := "res://assets/images/map_icons/stairs_down.png"

func before_each():
	_renderer = MinimapRenderer.new()

func _floor_origin(vx: int, vy: int) -> Vector2i:
	return Vector2i(
		vx * MinimapRenderer.STRIDE + MinimapRenderer.WALL_PX,
		vy * MinimapRenderer.STRIDE + MinimapRenderer.WALL_PX)

func _floor_center(vx: int, vy: int) -> Vector2i:
	var origin := _floor_origin(vx, vy)
	return origin + Vector2i(MinimapRenderer.CELL_PX / 2, MinimapRenderer.CELL_PX / 2)

func _render_basic(player_pos: Vector2i = Vector2i(5, 5), facing: int = Direction.NORTH) -> Image:
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(player_pos)
	var ps = PlayerState.new(player_pos, facing)
	return _renderer.render(wm, em, ps)

func _render_landmark_tile(tile: int) -> Image:
	var wm = WizMap.new(16)
	wm.cell(4, 4).tile = tile
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 4))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	return _renderer.render(wm, em, ps)

func _landmark_pattern(img: Image, vx: int = 2, vy: int = 2) -> String:
	var parts: Array[String] = []
	var origin := _floor_origin(vx, vy)
	for y in range(origin.y, origin.y + MinimapRenderer.CELL_PX):
		for x in range(origin.x, origin.x + MinimapRenderer.CELL_PX):
			var c := img.get_pixel(x, y)
			if c == MinimapRenderer.COLOR_FLOOR:
				parts.append(".")
			elif c == MinimapRenderer.COLOR_PLAYER:
				parts.append("P")
			elif c == MinimapRenderer.COLOR_GOAL \
					or c == MinimapRenderer.COLOR_START \
					or c == MinimapRenderer.COLOR_STAIRS_UP \
					or c == MinimapRenderer.COLOR_STAIRS_DOWN:
				parts.append("#")
			elif c.get_luminance() < 0.35:
				parts.append("S")
			elif c.get_luminance() > 0.55:
				parts.append("#")
			else:
				parts.append(".")
	return "".join(parts)

func _column_heights(pattern: String, floor_px: int, marker_char: String = "#") -> Array[int]:
	var heights: Array[int] = []
	for x in range(floor_px):
		var height := 0
		for y in range(floor_px):
			if pattern.substr(y * floor_px + x, 1) == marker_char:
				height += 1
		heights.append(height)
	return heights

func _row_widths(pattern: String, floor_px: int, marker_char: String = "#") -> Array[int]:
	var widths: Array[int] = []
	for y in range(floor_px):
		var width := 0
		for x in range(floor_px):
			if pattern.substr(y * floor_px + x, 1) == marker_char:
				width += 1
		widths.append(width)
	return widths

func _count_segments(counts: Array[int], min_pixels: int) -> int:
	var total := 0
	for count in counts:
		if count >= min_pixels:
			total += 1
	return total

func _assert_monotonic(heights: Array[int], increasing: bool, message: String) -> void:
	var distinct := {}
	for h in heights:
		distinct[h] = true
	for i in range(1, heights.size()):
		if increasing:
			assert_true(heights[i - 1] <= heights[i], message)
		else:
			assert_true(heights[i - 1] >= heights[i], message)
	assert_true(distinct.size() >= 4, "%s should have multiple step heights" % message)

# --- Image size / high resolution ---

func test_image_size_uses_high_resolution_cells():
	var img := _render_basic()
	assert_eq(MinimapRenderer.CELL_PX, 9)
	assert_eq(MinimapRenderer.WALL_PX, 3)
	assert_eq(img.get_width(), 87)
	assert_eq(img.get_height(), 87)

func test_high_resolution_floor_has_enough_pixels_for_detailed_icons():
	assert_true(MinimapRenderer.CELL_PX >= 9,
		"minimap floor area should be high enough resolution for detailed icons")

# --- Player ---

func test_player_always_at_center():
	var img := _render_basic()
	assert_eq(img.get_pixelv(_floor_center(3, 3)), MinimapRenderer.COLOR_PLAYER)

func test_player_center_at_different_position():
	var img := _render_basic(Vector2i(10, 12), Direction.SOUTH)
	assert_eq(img.get_pixelv(_floor_center(3, 3)), MinimapRenderer.COLOR_PLAYER)

func test_player_direction_north():
	var img := _render_basic(Vector2i(5, 5), Direction.NORTH)
	var origin := _floor_origin(3, 3)
	assert_eq(img.get_pixel(origin.x + MinimapRenderer.CELL_PX / 2, origin.y - 1),
		MinimapRenderer.COLOR_PLAYER)

func test_player_direction_east():
	var img := _render_basic(Vector2i(5, 5), Direction.EAST)
	var origin := _floor_origin(3, 3)
	assert_eq(img.get_pixel(origin.x + MinimapRenderer.CELL_PX, origin.y + MinimapRenderer.CELL_PX / 2),
		MinimapRenderer.COLOR_PLAYER)

# --- Explored / unexplored ---

func test_unexplored_cell_is_black():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	assert_eq(img.get_pixelv(_floor_center(1, 2)), MinimapRenderer.COLOR_BG)

func test_explored_cell_floor_is_drawn():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 4))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	assert_eq(img.get_pixelv(_floor_center(1, 2)), MinimapRenderer.COLOR_FLOOR)

func test_explored_cell_fills_floor():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 4))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	var origin := _floor_origin(1, 2)
	for x in range(origin.x, origin.x + MinimapRenderer.CELL_PX):
		for y in range(origin.y, origin.y + MinimapRenderer.CELL_PX):
			assert_eq(img.get_pixel(x, y), MinimapRenderer.COLOR_FLOOR,
				"floor pixel (%d,%d)" % [x, y])

func test_cells_outside_map_are_background():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	assert_eq(img.get_pixelv(_floor_center(0, 0)), MinimapRenderer.COLOR_BG)

# --- Edge rendering ---

func test_wall_edge_renders_as_line():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 4))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	var origin := _floor_origin(2, 2)
	for x in range(origin.x, origin.x + MinimapRenderer.CELL_PX):
		assert_eq(img.get_pixel(x, origin.y - 1), MinimapRenderer.COLOR_WALL)

func test_door_edge_renders_as_line():
	var wm = WizMap.new(16)
	wm.set_edge(4, 4, Direction.EAST, EdgeType.DOOR)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 4))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	var origin := _floor_origin(2, 2)
	for y in range(origin.y, origin.y + MinimapRenderer.CELL_PX):
		assert_eq(img.get_pixel(origin.x + MinimapRenderer.CELL_PX, y), MinimapRenderer.COLOR_DOOR)

func test_open_edge_between_explored_cells_renders_floor():
	var wm = WizMap.new(16)
	wm.set_edge(4, 4, Direction.NORTH, EdgeType.OPEN)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 4))
	em.mark_visited(Vector2i(4, 3))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	var origin := _floor_origin(2, 2)
	assert_eq(img.get_pixel(origin.x + MinimapRenderer.CELL_PX / 2, origin.y - 1),
		MinimapRenderer.COLOR_FLOOR)

func test_open_edge_to_unexplored_not_floor():
	var wm = WizMap.new(16)
	wm.set_edge(4, 4, Direction.NORTH, EdgeType.OPEN)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 4))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	var origin := _floor_origin(2, 2)
	assert_ne(img.get_pixel(origin.x + MinimapRenderer.CELL_PX / 2, origin.y - 1),
		MinimapRenderer.COLOR_FLOOR)

func test_corner_between_walls_is_filled():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 4))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	assert_eq(img.get_pixel(2 * MinimapRenderer.STRIDE, 2 * MinimapRenderer.STRIDE),
		MinimapRenderer.COLOR_WALL)

func test_corner_in_open_room_is_floor():
	var wm = WizMap.new(16)
	for y in range(4, 6):
		for x in range(4, 6):
			if x < 5:
				wm.set_edge(x, y, Direction.EAST, EdgeType.OPEN)
			if y < 5:
				wm.set_edge(x, y, Direction.SOUTH, EdgeType.OPEN)
	var em = ExploredMap.new()
	for y in range(4, 6):
		for x in range(4, 6):
			em.mark_visited(Vector2i(x, y))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	assert_eq(img.get_pixel(3 * MinimapRenderer.STRIDE, 3 * MinimapRenderer.STRIDE),
		MinimapRenderer.COLOR_FLOOR)

# --- Landmark icons ---

func test_start_tile_marker_drawn_on_explored_start():
	var img := _render_landmark_tile(TileType.START)
	assert_true(_landmark_pattern(img).contains("#"), "START marker pixel should be drawn")

func test_start_marker_color_distinct_from_floor_and_player():
	assert_ne(MinimapRenderer.COLOR_START, MinimapRenderer.COLOR_FLOOR)
	assert_ne(MinimapRenderer.COLOR_START, MinimapRenderer.COLOR_PLAYER)

func test_unexplored_start_tile_has_no_marker():
	var wm = WizMap.new(16)
	wm.cell(4, 4).tile = TileType.START
	var em = ExploredMap.new()
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	var origin := _floor_origin(2, 2)
	for x in range(origin.x, origin.x + MinimapRenderer.CELL_PX):
		for y in range(origin.y, origin.y + MinimapRenderer.CELL_PX):
			assert_ne(img.get_pixel(x, y), MinimapRenderer.COLOR_START)

func test_player_on_start_tile_center_shows_player_color():
	var wm = WizMap.new(16)
	wm.cell(5, 5).tile = TileType.START
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(5, 5))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	assert_eq(img.get_pixelv(_floor_center(3, 3)), MinimapRenderer.COLOR_PLAYER)

func test_start_and_stairs_up_use_same_stair_shape():
	var start_img := _render_landmark_tile(TileType.START)
	var up_img := _render_landmark_tile(TileType.STAIRS_UP)
	assert_eq(_landmark_pattern(start_img), _landmark_pattern(up_img),
		"START should use the same ordinary stair shape as STAIRS_UP")

func test_stairs_up_icon_uses_detailed_ascending_steps():
	var up_img := _render_landmark_tile(TileType.STAIRS_UP)
	var pattern := _landmark_pattern(up_img)
	assert_true(_count_segments(_row_widths(pattern, MinimapRenderer.CELL_PX), 1) >= 3,
		"STAIRS_UP should include multiple horizontal step lines")
	assert_true(_count_segments(_column_heights(pattern, MinimapRenderer.CELL_PX), 1) >= 3,
		"STAIRS_UP should include multiple vertical riser lines")

func test_stairs_down_icon_uses_dark_opening_and_descending_steps():
	var down_img := _render_landmark_tile(TileType.STAIRS_DOWN)
	var pattern := _landmark_pattern(down_img)
	assert_true(pattern.contains("S"), "STAIRS_DOWN should include a dark shadowed stairwell")
	assert_true(_count_segments(_row_widths(pattern, MinimapRenderer.CELL_PX), 1) >= 3,
		"STAIRS_DOWN should include multiple horizontal step lines")
	assert_true(_count_segments(_column_heights(pattern, MinimapRenderer.CELL_PX), 1) >= 3,
		"STAIRS_DOWN should include multiple vertical riser lines")

func test_stairs_down_icon_asset_exists_for_minimap_rendering():
	assert_true(FileAccess.file_exists(STAIRS_DOWN_ICON_PATH),
		"STAIRS_DOWN minimap icon should be generated as a PNG asset")

func test_stairs_down_icon_does_not_use_blue_marker_color():
	assert_eq(MinimapRenderer.COLOR_STAIRS_DOWN, Color8(238, 238, 230),
		"stair icons should be readable as white, not cyan")

func test_stairs_up_and_down_icons_are_distinct():
	var up_img := _render_landmark_tile(TileType.STAIRS_UP)
	var down_img := _render_landmark_tile(TileType.STAIRS_DOWN)
	assert_ne(_landmark_pattern(up_img), _landmark_pattern(down_img),
		"STAIRS_UP and STAIRS_DOWN minimap icons should differ")

func test_goal_tile_icon_present_on_explored_goal():
	var img := _render_landmark_tile(TileType.GOAL)
	assert_true(_landmark_pattern(img).contains("#"), "GOAL should draw goal icon pixels")

func test_landmark_icons_stay_within_floor_area():
	for tile in [TileType.START, TileType.STAIRS_UP, TileType.STAIRS_DOWN, TileType.GOAL]:
		var img := _render_landmark_tile(tile)
		var origin := _floor_origin(2, 2)
		for x in range(origin.x, origin.x + MinimapRenderer.CELL_PX):
			assert_eq(img.get_pixel(x, origin.y - 1), MinimapRenderer.COLOR_WALL)
			assert_eq(img.get_pixel(x, origin.y + MinimapRenderer.CELL_PX), MinimapRenderer.COLOR_WALL)
		for y in range(origin.y, origin.y + MinimapRenderer.CELL_PX):
			assert_eq(img.get_pixel(origin.x - 1, y), MinimapRenderer.COLOR_WALL)
			assert_eq(img.get_pixel(origin.x + MinimapRenderer.CELL_PX, y), MinimapRenderer.COLOR_WALL)

func test_player_on_any_landmark_tile_center_shows_player_color():
	for tile in [TileType.START, TileType.STAIRS_UP, TileType.STAIRS_DOWN, TileType.GOAL]:
		var wm = WizMap.new(16)
		wm.cell(5, 5).tile = tile
		var em = ExploredMap.new()
		em.mark_visited(Vector2i(5, 5))
		var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
		var img = _renderer.render(wm, em, ps)
		assert_eq(img.get_pixelv(_floor_center(3, 3)), MinimapRenderer.COLOR_PLAYER,
			"player color takes precedence on landmark tile %d" % tile)
