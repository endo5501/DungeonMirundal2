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

func before_each():
	_renderer = FullMapRenderer.new()


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
	# Cell (2, 5): floor x=[21..29], y=[51..59]
	var found = false
	for x in range(21, 30):
		for y in range(51, 60):
			if img.get_pixel(x, y) == FullMapRenderer.COLOR_START:
				found = true
	assert_true(found, "START marker should appear on explored START tile")


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


func test_player_drawn_even_if_cell_not_in_explored_map():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	# Player cell NOT in explored_map (renderer should still draw player)
	var ps = PlayerState.new(Vector2i(4, 4), Direction.NORTH)
	var img = _renderer.render(wm, em, ps, Vector2i(80, 80))
	# Cell (4, 4): floor center (45, 45)
	assert_eq(img.get_pixel(45, 45), FullMapRenderer.COLOR_PLAYER)
