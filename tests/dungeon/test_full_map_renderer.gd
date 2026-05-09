extends GutTest

# Layout (with cell_px as full stride):
#   cell_px = max(MIN_CELL_PX, floor(min(W,H) / map_size))
#   floor_px = cell_px - WALL_PX  (WALL_PX = 1)
#   image_size = cell_px * map_size + WALL_PX
#   Cell (cx, cy):
#     floor area: x=[cx*cell_px+1 .. cx*cell_px+floor_px], y similarly
#     north edge line: y = cy*cell_px, x=[cx*cell_px+1 .. cx*cell_px+floor_px]
#     east edge line:  x = (cx+1)*cell_px, y=[cy*cell_px+1 .. cy*cell_px+floor_px]
#
# Standard test setup: map_size=8, target=(80,80) -> cell_px=10, image_size=81, floor_px=9

var _renderer: FullMapRenderer

const STAIRS_UP_ICON_PATH := "res://assets/images/map_icons/stairs_up.png"
const STAIRS_DOWN_ICON_PATH := "res://assets/images/map_icons/stairs_down.png"

func before_each():
	_renderer = FullMapRenderer.new()

func _render_landmark_tile(tile: int, target_size: Vector2i = Vector2i(80, 80)) -> Image:
	var wm = WizMap.new(8)
	wm.cell(2, 5).tile = tile
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(2, 5))
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	return _renderer.render(wm, em, ps, target_size)

func _cell_non_floor_pattern(img: Image, cx: int, cy: int, cell_px: int) -> String:
	var parts: Array[String] = []
	var floor_px := cell_px - FullMapRenderer.WALL_PX
	var fx := cx * cell_px + FullMapRenderer.WALL_PX
	var fy := cy * cell_px + FullMapRenderer.WALL_PX
	for y in range(fy, fy + floor_px):
		for x in range(fx, fx + floor_px):
			var c := img.get_pixel(x, y)
			if c == FullMapRenderer.COLOR_FLOOR:
				parts.append(".")
			elif c == FullMapRenderer.COLOR_PLAYER:
				parts.append("P")
			elif c == FullMapRenderer.COLOR_GOAL \
					or c == FullMapRenderer.COLOR_START \
					or c == FullMapRenderer.COLOR_STAIRS_UP \
					or c == FullMapRenderer.COLOR_STAIRS_DOWN:
				parts.append("#")
			elif c.get_luminance() < 0.35:
				parts.append("S")
			elif c.get_luminance() > 0.55:
				parts.append("#")
			else:
				parts.append(".")
	return "".join(parts)

func _cell_icon_pattern(img: Image, cx: int, cy: int, cell_px: int) -> String:
	var parts: Array[String] = []
	var floor_px := cell_px - FullMapRenderer.WALL_PX
	var fx := cx * cell_px + FullMapRenderer.WALL_PX
	var fy := cy * cell_px + FullMapRenderer.WALL_PX
	for y in range(fy, fy + floor_px):
		for x in range(fx, fx + floor_px):
			var c := img.get_pixel(x, y)
			if c == FullMapRenderer.COLOR_FLOOR:
				parts.append(".")
			elif c.get_luminance() < 0.35:
				parts.append("S")
			elif c.get_luminance() > 0.55:
				parts.append("#")
			else:
				parts.append(".")
	return "".join(parts)

func _vertical_line_pattern(cell_px: int) -> String:
	var parts: Array[String] = []
	var floor_px := cell_px - FullMapRenderer.WALL_PX
	var center := int(floor_px / 2)
	for y in range(floor_px):
		for x in range(floor_px):
			parts.append("#" if x == center else ".")
	return "".join(parts)

func _assert_landmark_icon_present(tile: int, message: String) -> void:
	var img := _render_landmark_tile(tile)
	var pattern := _cell_non_floor_pattern(img, 2, 5, 10)
	assert_true(pattern.contains("#"), message)

func _column_heights(pattern: String, floor_px: int) -> Array[int]:
	var heights: Array[int] = []
	for x in range(floor_px):
		var height := 0
		for y in range(floor_px):
			if pattern.substr(y * floor_px + x, 1) == "#":
				height += 1
		heights.append(height)
	return heights

func _row_widths(pattern: String, floor_px: int) -> Array[int]:
	var widths: Array[int] = []
	for y in range(floor_px):
		var width := 0
		for x in range(floor_px):
			if pattern.substr(y * floor_px + x, 1) == "#":
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
	var distinct: Dictionary = {}
	for h in heights:
		distinct[h] = true
	for i in range(1, heights.size()):
		if increasing:
			assert_true(heights[i - 1] <= heights[i], message)
		else:
			assert_true(heights[i - 1] >= heights[i], message)
	assert_true(distinct.size() >= 3, "%s should have multiple visible step heights" % message)

func _is_landmark_color(color: Color) -> bool:
	return color == FullMapRenderer.COLOR_START \
		or color == FullMapRenderer.COLOR_STAIRS_UP \
		or color == FullMapRenderer.COLOR_STAIRS_DOWN \
		or color == FullMapRenderer.COLOR_GOAL


# --- Image size calculation ---

func test_image_size_for_typical_target():
	var wm = WizMap.new(20)
	var em = ExploredMap.new()
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(640, 480))
	# cell_px = floor(480/20) = 24, image_size = 24*20+1 = 481
	assert_eq(img.get_width(), 481)
	assert_eq(img.get_height(), 481)


func test_image_uses_smaller_dimension():
	var wm = WizMap.new(10)
	var em = ExploredMap.new()
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(1000, 500))
	# cell_px = floor(500/10) = 50, image_size = 50*10+1 = 501
	assert_eq(img.get_width(), 501)


func test_image_min_cell_px_clamped():
	var wm = WizMap.new(20)
	var em = ExploredMap.new()
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	# target so small that natural calc < MIN_CELL_PX (4)
	var img = _renderer.render(wm, em, ps, Vector2i(40, 40))
	# cell_px = max(4, floor(40/20)) = max(4, 2) = 4, image_size = 4*20+1 = 81
	assert_eq(img.get_width(), 81)


# --- Explored / unexplored ---

func test_unexplored_cell_is_background():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (5, 3) NOT explored; floor center pixel (5*10+5, 3*10+5) = (55, 35)
	assert_eq(img.get_pixel(55, 35), FullMapRenderer.COLOR_BG)


func test_explored_cell_floor_drawn():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(5, 3))
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (5, 3) explored; floor center at (55, 35)
	assert_eq(img.get_pixel(55, 35), FullMapRenderer.COLOR_FLOOR)


func test_explored_cell_fills_full_floor_area():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(2, 2))
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (2, 2): floor x=[21..29], y=[21..29]
	for x in range(21, 30):
		for y in range(21, 30):
			assert_eq(img.get_pixel(x, y), FullMapRenderer.COLOR_FLOOR,
				"floor pixel (%d,%d)" % [x, y])


# --- Edge rendering ---

func test_wall_edge_drawn():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 3))
	# All edges WALL by default
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (3, 3): north edge at y=30, x=[31..39]
	assert_eq(img.get_pixel(31, 30), FullMapRenderer.COLOR_WALL)
	assert_eq(img.get_pixel(35, 30), FullMapRenderer.COLOR_WALL)
	assert_eq(img.get_pixel(39, 30), FullMapRenderer.COLOR_WALL)


func test_door_edge_drawn():
	var wm = WizMap.new(8)
	wm.set_edge(3, 3, Direction.EAST, EdgeType.DOOR)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 3))
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (3, 3): east edge at x=40, y=[31..39]
	assert_eq(img.get_pixel(40, 31), FullMapRenderer.COLOR_DOOR)
	assert_eq(img.get_pixel(40, 35), FullMapRenderer.COLOR_DOOR)
	assert_eq(img.get_pixel(40, 39), FullMapRenderer.COLOR_DOOR)


func test_open_edge_between_explored_renders_floor():
	var wm = WizMap.new(8)
	wm.set_edge(3, 3, Direction.NORTH, EdgeType.OPEN)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 3))
	em.mark_visited(Vector2i(3, 2))  # north neighbor
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (3, 3) north edge at y=30, x=[31..39]
	assert_eq(img.get_pixel(35, 30), FullMapRenderer.COLOR_FLOOR)


func test_open_edge_to_unexplored_not_floor():
	var wm = WizMap.new(8)
	wm.set_edge(3, 3, Direction.NORTH, EdgeType.OPEN)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 3))
	# (3, 2) NOT explored
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	assert_ne(img.get_pixel(35, 30), FullMapRenderer.COLOR_FLOOR)


# --- START / GOAL markers ---

func test_marker_colors_distinct():
	assert_ne(FullMapRenderer.COLOR_START, FullMapRenderer.COLOR_GOAL)
	assert_ne(FullMapRenderer.COLOR_START, FullMapRenderer.COLOR_FLOOR)
	assert_ne(FullMapRenderer.COLOR_START, FullMapRenderer.COLOR_PLAYER)
	assert_ne(FullMapRenderer.COLOR_GOAL, FullMapRenderer.COLOR_FLOOR)
	assert_ne(FullMapRenderer.COLOR_GOAL, FullMapRenderer.COLOR_PLAYER)


func test_explored_start_tile_marker_drawn():
	var wm = WizMap.new(8)
	wm.cell(2, 5).tile = TileType.START
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(2, 5))
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	assert_true(_cell_non_floor_pattern(img, 2, 5, 10).contains("#"),
		"START stair icon should appear on explored START tile")


func test_explored_start_tile_uses_stair_icon_not_vertical_line():
	var img := _render_landmark_tile(TileType.START)
	var pattern := _cell_non_floor_pattern(img, 2, 5, 10)
	assert_true(pattern.contains("#"), "START icon should draw non-floor pixels")
	assert_ne(pattern, _vertical_line_pattern(10), "START should not use the legacy vertical line marker")


func test_explored_start_tile_uses_same_shape_as_stairs_up():
	var start_img := _render_landmark_tile(TileType.START)
	var up_img := _render_landmark_tile(TileType.STAIRS_UP)
	assert_eq(_cell_non_floor_pattern(start_img, 2, 5, 10),
		_cell_non_floor_pattern(up_img, 2, 5, 10),
		"START should use the same ordinary stair shape as STAIRS_UP")


func test_explored_goal_tile_marker_drawn():
	var wm = WizMap.new(8)
	wm.cell(4, 6).tile = TileType.GOAL
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 6))
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (4, 6): floor x=[41..49], y=[61..69]
	var found = false
	for x in range(41, 50):
		for y in range(61, 70):
			if img.get_pixel(x, y) == FullMapRenderer.COLOR_GOAL:
				found = true
	assert_true(found, "GOAL marker should appear on explored GOAL tile")


func test_explored_stairs_up_and_down_icons_are_distinct():
	var up_img := _render_landmark_tile(TileType.STAIRS_UP)
	var down_img := _render_landmark_tile(TileType.STAIRS_DOWN)
	var up_pattern := _cell_non_floor_pattern(up_img, 2, 5, 10)
	var down_pattern := _cell_non_floor_pattern(down_img, 2, 5, 10)
	assert_true(up_pattern.contains("#"), "STAIRS_UP should draw icon pixels")
	assert_true(down_pattern.contains("#"), "STAIRS_DOWN should draw icon pixels")
	assert_ne(up_pattern, down_pattern, "STAIRS_UP and STAIRS_DOWN full-map icons should differ")


func test_explored_stairs_up_icon_uses_b_style_ascending_steps():
	var up_img := _render_landmark_tile(TileType.STAIRS_UP)
	var up_pattern := _cell_non_floor_pattern(up_img, 2, 5, 10)
	assert_true(_count_segments(_row_widths(up_pattern, 9), 1) >= 3,
		"STAIRS_UP should include multiple horizontal step lines")
	assert_true(_count_segments(_column_heights(up_pattern, 9), 1) >= 3,
		"STAIRS_UP should include multiple vertical riser lines")


func test_explored_stairs_down_icon_uses_10_style_descending_steps():
	var down_img := _render_landmark_tile(TileType.STAIRS_DOWN)
	var down_pattern := _cell_icon_pattern(down_img, 2, 5, 10)
	assert_true(down_pattern.contains("S"),
		"STAIRS_DOWN should include a dark shadowed stairwell")
	assert_true(_count_segments(_row_widths(down_pattern, 9), 1) >= 3,
		"STAIRS_DOWN should include multiple horizontal step lines")
	assert_true(_count_segments(_column_heights(down_pattern, 9), 1) >= 3,
		"STAIRS_DOWN should include multiple vertical riser lines")


func test_stair_icons_are_white_not_blue():
	assert_eq(FullMapRenderer.COLOR_STAIRS_UP, Color8(238, 238, 230))
	assert_eq(FullMapRenderer.COLOR_STAIRS_DOWN, Color8(238, 238, 230))


func test_stair_icon_assets_exist_for_full_map_rendering():
	assert_true(FileAccess.file_exists(STAIRS_UP_ICON_PATH),
		"STAIRS_UP full-map icon should be generated as a PNG asset")
	assert_true(FileAccess.file_exists(STAIRS_DOWN_ICON_PATH),
		"STAIRS_DOWN full-map icon should be generated as a PNG asset")


func test_explored_goal_tile_uses_altar_icon_not_vertical_line():
	var img := _render_landmark_tile(TileType.GOAL)
	var pattern := _cell_non_floor_pattern(img, 2, 5, 10)
	assert_true(pattern.contains("#"), "GOAL icon should draw non-floor pixels")
	assert_ne(pattern, _vertical_line_pattern(10), "GOAL should not use the legacy vertical line marker")


func test_unexplored_start_no_marker():
	var wm = WizMap.new(8)
	wm.cell(2, 5).tile = TileType.START
	var em = ExploredMap.new()
	# (2, 5) NOT explored
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	for x in range(21, 30):
		for y in range(51, 60):
			assert_ne(img.get_pixel(x, y), FullMapRenderer.COLOR_START,
				"unexplored START tile should not draw marker at (%d,%d)" % [x, y])


func test_unexplored_goal_no_marker():
	var wm = WizMap.new(8)
	wm.cell(4, 6).tile = TileType.GOAL
	var em = ExploredMap.new()
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	for x in range(41, 50):
		for y in range(61, 70):
			assert_ne(img.get_pixel(x, y), FullMapRenderer.COLOR_GOAL,
				"unexplored GOAL tile should not draw marker")


func test_start_marker_stays_in_floor_area():
	var wm = WizMap.new(8)
	wm.cell(2, 5).tile = TileType.START
	# All edges WALL by default (so gaps are wall, not marker)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(2, 5))
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Floor area x=[21..29], y=[51..59]
	# Edge gaps: y=50 (north), y=60 (south), x=20 (west), x=30 (east)
	for x in range(20, 31):
		assert_ne(img.get_pixel(x, 50), FullMapRenderer.COLOR_START,
			"no marker pixel in north gap at (%d,50)" % x)
		assert_ne(img.get_pixel(x, 60), FullMapRenderer.COLOR_START,
			"no marker pixel in south gap at (%d,60)" % x)
	for y in range(50, 61):
		assert_ne(img.get_pixel(20, y), FullMapRenderer.COLOR_START,
			"no marker pixel in west gap at (20,%d)" % y)
		assert_ne(img.get_pixel(30, y), FullMapRenderer.COLOR_START,
			"no marker pixel in east gap at (30,%d)" % y)


func test_landmark_icons_stay_in_floor_area_at_typical_and_min_cell_sizes():
	for target_size in [Vector2i(80, 80), Vector2i(20, 20)]:
		var cell_px := FullMapRenderer._calc_cell_px(target_size, 8)
		var floor_px := cell_px - FullMapRenderer.WALL_PX
		for tile in [TileType.START, TileType.STAIRS_UP, TileType.STAIRS_DOWN, TileType.GOAL]:
			var img := _render_landmark_tile(tile, target_size)
			var fx := 2 * cell_px + FullMapRenderer.WALL_PX
			var fy := 5 * cell_px + FullMapRenderer.WALL_PX
			for x in range(fx - FullMapRenderer.WALL_PX, fx + floor_px + FullMapRenderer.WALL_PX + 1):
				assert_false(_is_landmark_color(img.get_pixel(x, fy - FullMapRenderer.WALL_PX)),
					"landmark color should not leak into north gap")
				assert_false(_is_landmark_color(img.get_pixel(x, fy + floor_px)),
					"landmark color should not leak into south gap")
			for y in range(fy - FullMapRenderer.WALL_PX, fy + floor_px + FullMapRenderer.WALL_PX + 1):
				assert_false(_is_landmark_color(img.get_pixel(fx - FullMapRenderer.WALL_PX, y)),
					"landmark color should not leak into west gap")
				assert_false(_is_landmark_color(img.get_pixel(fx + floor_px, y)),
					"landmark color should not leak into east gap")


# --- Player rendering ---

func test_player_drawn_at_grid_position():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(7, 3))
	var ps = PlayerState.new(Vector2i(7, 3), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (7, 3): floor center at (75, 35)
	assert_eq(img.get_pixel(75, 35), FullMapRenderer.COLOR_PLAYER)


func test_player_direction_north():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(5, 5))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (5, 5): north edge at y=50, x=[51..59]
	assert_eq(img.get_pixel(55, 50), FullMapRenderer.COLOR_PLAYER)


func test_player_direction_east():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(5, 5))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.EAST)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (5, 5): east edge at x=60, y=[51..59]
	assert_eq(img.get_pixel(60, 55), FullMapRenderer.COLOR_PLAYER)


func test_player_direction_south():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(5, 5))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.SOUTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (5, 5): south edge at y=60, x=[51..59]
	assert_eq(img.get_pixel(55, 60), FullMapRenderer.COLOR_PLAYER)


func test_player_direction_west():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(5, 5))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.WEST)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (5, 5): west edge at x=50, y=[51..59]
	assert_eq(img.get_pixel(50, 55), FullMapRenderer.COLOR_PLAYER)


func test_player_overrides_start_marker():
	var wm = WizMap.new(8)
	wm.cell(3, 3).tile = TileType.START
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 3))
	var ps = PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Floor center pixel (35, 35) should be PLAYER, not START
	assert_eq(img.get_pixel(35, 35), FullMapRenderer.COLOR_PLAYER)


func test_player_overrides_all_landmark_icons():
	for tile in [TileType.START, TileType.STAIRS_UP, TileType.STAIRS_DOWN, TileType.GOAL]:
		var wm = WizMap.new(8)
		wm.cell(3, 3).tile = tile
		var em = ExploredMap.new()
		em.mark_visited(Vector2i(3, 3))
		var ps = PlayerState.new(Vector2i(3, 3), Direction.NORTH)
		var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
		assert_eq(img.get_pixel(35, 35), FullMapRenderer.COLOR_PLAYER,
			"player should override landmark icon for tile %d" % tile)


func test_player_drawn_even_if_cell_not_in_explored_map():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	# Player cell NOT in explored_map (renderer should still draw player)
	var ps = PlayerState.new(Vector2i(4, 4), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (4, 4): floor center (45, 45)
	assert_eq(img.get_pixel(45, 45), FullMapRenderer.COLOR_PLAYER)
