extends GutTest

# Layout:
#   CELL_PX=3, WALL_PX=1, STRIDE=4, VIEW_SIZE=7, IMAGE_SIZE=29
#   Cell at view pos (vx,vy):
#     floor: x=[vx*4+1..vx*4+3], y=[vy*4+1..vy*4+3]
#     north edge line: y=vy*4, x=[vx*4+1..vx*4+3]
#     east edge line: x=(vx+1)*4, y=[vy*4+1..vy*4+3]
#   Player center cell: vx=3, vy=3 -> floor center pixel (14, 14)

var _renderer: MinimapRenderer

func before_each():
	_renderer = MinimapRenderer.new()

# --- Image size ---

func test_image_size_is_29x29():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	assert_eq(img.get_width(), 29)
	assert_eq(img.get_height(), 29)

# --- Player at center ---

func test_player_always_at_center():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(5, 5))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# Center cell vx=3,vy=3: floor center pixel (14, 14)
	assert_eq(img.get_pixel(14, 14), MinimapRenderer.COLOR_PLAYER)

func test_player_center_at_different_position():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(10, 12))
	var ps = PlayerState.new(Vector2i(10, 12), Direction.SOUTH)
	var img = _renderer.render(wm, em, ps)
	assert_eq(img.get_pixel(14, 14), MinimapRenderer.COLOR_PLAYER)

# --- Player direction indicator ---

func test_player_direction_north():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(5, 5))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# North gap of center cell: y=3*4=12, x=[13..15]
	assert_eq(img.get_pixel(14, 12), MinimapRenderer.COLOR_PLAYER)

func test_player_direction_east():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(5, 5))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.EAST)
	var img = _renderer.render(wm, em, ps)
	# East gap of center cell: x=4*4=16, y=[13..15]
	assert_eq(img.get_pixel(16, 14), MinimapRenderer.COLOR_PLAYER)

# --- Unexplored / Explored floor ---
# Player at (5,5), view covers (2,2) to (8,8)
# Cell (3,4) -> view pos (1,2) -> floor area x=[5..7], y=[9..11]

func test_unexplored_cell_is_black():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# cell (3,4) -> view (1,2) -> floor center (6, 10)
	assert_eq(img.get_pixel(6, 10), MinimapRenderer.COLOR_BG)

func test_explored_cell_floor_is_drawn():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 4))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# cell (3,4) -> view (1,2) -> floor center (6, 10)
	assert_eq(img.get_pixel(6, 10), MinimapRenderer.COLOR_FLOOR)

func test_explored_cell_fills_3x3_floor():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(3, 4))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# cell (3,4) -> view (1,2) -> floor x=[5,7], y=[9,11]
	for x in range(5, 8):
		for y in range(9, 12):
			assert_eq(img.get_pixel(x, y), MinimapRenderer.COLOR_FLOOR,
				"floor pixel (%d,%d)" % [x, y])

# --- Out of bounds ---

func test_cells_outside_map_are_background():
	var wm = WizMap.new(8)
	var em = ExploredMap.new()
	var ps = PlayerState.new(Vector2i(0, 0), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# (-3,-3) -> view (0,0) -> floor center (2, 2)
	assert_eq(img.get_pixel(2, 2), MinimapRenderer.COLOR_BG)

# --- Edge rendering (lines) ---
# Player at (5,5), cell (4,4) -> view pos (2,2)
# floor: x=[9..11], y=[9..11]
# north edge line: y=8, x=[9..11]
# east edge line: x=12, y=[9..11]

func test_wall_edge_renders_as_line():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 4))
	# All edges WALL by default
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# North edge line: y=8, x=[9,10,11]
	assert_eq(img.get_pixel(9, 8), MinimapRenderer.COLOR_WALL)
	assert_eq(img.get_pixel(10, 8), MinimapRenderer.COLOR_WALL)
	assert_eq(img.get_pixel(11, 8), MinimapRenderer.COLOR_WALL)

func test_door_edge_renders_as_line():
	var wm = WizMap.new(16)
	wm.set_edge(4, 4, Direction.EAST, EdgeType.DOOR)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 4))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# East edge line: x=12, y=[9,10,11]
	assert_eq(img.get_pixel(12, 9), MinimapRenderer.COLOR_DOOR)
	assert_eq(img.get_pixel(12, 10), MinimapRenderer.COLOR_DOOR)
	assert_eq(img.get_pixel(12, 11), MinimapRenderer.COLOR_DOOR)

func test_open_edge_between_explored_cells_renders_floor():
	var wm = WizMap.new(16)
	wm.set_edge(4, 4, Direction.NORTH, EdgeType.OPEN)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 4))
	em.mark_visited(Vector2i(4, 3))
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# North edge gap: y=8, x=[9,10,11] should be floor color
	assert_eq(img.get_pixel(10, 8), MinimapRenderer.COLOR_FLOOR)

func test_open_edge_to_unexplored_not_floor():
	var wm = WizMap.new(16)
	wm.set_edge(4, 4, Direction.NORTH, EdgeType.OPEN)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 4))
	# (4,3) NOT explored
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# North edge gap should NOT be floor color
	assert_ne(img.get_pixel(10, 8), MinimapRenderer.COLOR_FLOOR)

# --- No corner pillars ---

func test_no_corner_pillars_in_open_room():
	var wm = WizMap.new(16)
	# Create a 3x3 open room: open all interior edges
	for y in range(3, 6):
		for x in range(3, 6):
			for dir in Direction.ALL:
				var nx = x + Direction.dx(dir)
				var ny = y + Direction.dy(dir)
				if nx >= 3 and nx <= 5 and ny >= 3 and ny <= 5:
					wm.set_edge(x, y, dir, EdgeType.OPEN)
	var em = ExploredMap.new()
	for y in range(3, 6):
		for x in range(3, 6):
			em.mark_visited(Vector2i(x, y))
	# Player at center of room (4,4) -> view center
	var ps = PlayerState.new(Vector2i(4, 4), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# Corner between (4,4) and (5,5) in view -> view corner at (vx=3+1, vy=3+1)
	# The corner pixel at (4*4, 4*4) = (16, 16) should NOT be wall color
	# Actually: cell (4,4)->view(3,3), cell (5,5)->view(4,4)
	# Corner between them is at pixel ((3+1)*4, (3+1)*4) = (16, 16)
	assert_ne(img.get_pixel(16, 16), MinimapRenderer.COLOR_WALL,
		"corner pixel in open room should not be wall color")

func test_corner_between_walls_is_filled():
	var wm = WizMap.new(16)
	var em = ExploredMap.new()
	em.mark_visited(Vector2i(4, 4))
	# All edges WALL by default
	var ps = PlayerState.new(Vector2i(5, 5), Direction.NORTH)
	var img = _renderer.render(wm, em, ps)
	# cell (4,4) -> view (2,2), NW corner pixel at (2*4, 2*4) = (8, 8)
	assert_eq(img.get_pixel(8, 8), MinimapRenderer.COLOR_WALL,
		"corner between walls should be wall color")

func test_corner_in_open_room_is_floor():
	var wm = WizMap.new(16)
	# Open room: cells (4,4), (5,4), (4,5), (5,5) all open between each other
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
	# Corner between (4,4)(5,4)(4,5)(5,5) in view:
	# (4,4)->view(2,2), (5,5)->view(3,3)
	# Corner at ((2+1)*4, (2+1)*4) = (12, 12)
	assert_eq(img.get_pixel(12, 12), MinimapRenderer.COLOR_FLOOR,
		"corner in open room should be floor color")
