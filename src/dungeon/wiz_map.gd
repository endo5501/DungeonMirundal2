class_name WizMap
extends RefCounted

var map_size: int
var _grid: Array  # Array[Array[Cell]]
var rooms: Array[MapRect]

func _init(size: int) -> void:
	assert(size >= 8, "WizMap size must be >= 8, got %d" % size)
	map_size = size
	rooms = []
	_init_all_walls()

func _init_all_walls() -> void:
	_grid = []
	_grid.resize(map_size)
	for y in range(map_size):
		var row: Array[Cell] = []
		row.resize(map_size)
		for x in range(map_size):
			row[x] = Cell.new()
		_grid[y] = row

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < map_size and y >= 0 and y < map_size

func cell(x: int, y: int) -> Cell:
	return _grid[y][x]

func get_edge(x: int, y: int, dir: int) -> int:
	return cell(x, y).get_edge(dir)

func set_edge(x: int, y: int, dir: int, edge: int) -> void:
	if not in_bounds(x, y):
		return
	cell(x, y).set_edge(dir, edge)
	var n := Vector2i(x, y) + Direction.offset(dir)
	if in_bounds(n.x, n.y):
		cell(n.x, n.y).set_edge(Direction.opposite(dir), edge)

func open_between(x1: int, y1: int, x2: int, y2: int, edge: int = EdgeType.OPEN) -> void:
	var dx := x2 - x1
	var dy := y2 - y1
	if abs(dx) + abs(dy) != 1:
		push_error("adjacent cells only")
		return
	if dx == 1:
		set_edge(x1, y1, Direction.EAST, edge)
	elif dx == -1:
		set_edge(x1, y1, Direction.WEST, edge)
	elif dy == 1:
		set_edge(x1, y1, Direction.SOUTH, edge)
	else:
		set_edge(x1, y1, Direction.NORTH, edge)

func carve_perfect_maze(rng: RandomNumberGenerator) -> void:
	var visited := {}
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	visited[Vector2i(0, 0)] = true

	while stack.size() > 0:
		var pos := stack[-1]
		var neighbors: Array = []

		for dir in Direction.ALL:
			var npos := pos + Direction.offset(dir)
			if in_bounds(npos.x, npos.y) and not visited.has(npos):
				neighbors.append([dir, npos])

		if neighbors.is_empty():
			stack.pop_back()
			continue

		var choice: Array = neighbors[rng.randi_range(0, neighbors.size() - 1)]
		var dir: int = choice[0]
		var npos: Vector2i = choice[1]
		open_between(pos.x, pos.y, npos.x, npos.y, EdgeType.OPEN)
		visited[npos] = true
		stack.append(npos)

func generate_rooms(rng: RandomNumberGenerator, room_attempts: int, min_room_size: int, max_room_size: int) -> void:
	rooms = []
	for _i in range(room_attempts):
		var w := rng.randi_range(min_room_size, max_room_size)
		var h := rng.randi_range(min_room_size, max_room_size)
		if w >= map_size - 2 or h >= map_size - 2:
			continue
		var rx := rng.randi_range(1, map_size - w - 1)
		var ry := rng.randi_range(1, map_size - h - 1)
		var room := MapRect.new(rx, ry, w, h)
		var overlaps := false
		for existing in rooms:
			if room.intersects(existing, 1):
				overlaps = true
				break
		if not overlaps:
			rooms.append(room)

func carve_room(room: MapRect) -> void:
	for y in range(room.y, room.y + room.h):
		for x in range(room.x, room.x + room.w):
			if x < room.x2():
				set_edge(x, y, Direction.EAST, EdgeType.OPEN)
			if y < room.y2():
				set_edge(x, y, Direction.SOUTH, EdgeType.OPEN)

func carve_rooms() -> void:
	for room in rooms:
		carve_room(room)

func add_extra_links(rng: RandomNumberGenerator, count: int) -> void:
	var candidates: Array = []
	for y in range(map_size):
		for x in range(map_size):
			if x < map_size - 1 and get_edge(x, y, Direction.EAST) == EdgeType.WALL:
				candidates.append([x, y, Direction.EAST])
			if y < map_size - 1 and get_edge(x, y, Direction.SOUTH) == EdgeType.WALL:
				candidates.append([x, y, Direction.SOUTH])
	# Partial Fisher-Yates: only shuffle the first `limit` elements
	# (Array.shuffle() uses a separate RNG, breaking seed reproducibility)
	var limit := mini(count, candidates.size())
	for i in range(limit):
		var j := rng.randi_range(i, candidates.size() - 1)
		var tmp: Array = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	for i in range(limit):
		var c: Array = candidates[i]
		set_edge(c[0], c[1], c[2], EdgeType.OPEN)

func add_doors_between_room_and_nonroom(rng: RandomNumberGenerator, door_chance: float = 0.25) -> void:
	for y in range(map_size):
		for x in range(map_size):
			for dir in [Direction.EAST, Direction.SOUTH]:
				var n := Vector2i(x, y) + Direction.offset(dir)
				if not in_bounds(n.x, n.y):
					continue
				var a_in := in_any_room(x, y)
				var b_in := in_any_room(n.x, n.y)
				if a_in != b_in and get_edge(x, y, dir) == EdgeType.OPEN:
					if rng.randf() < door_chance:
						set_edge(x, y, dir, EdgeType.DOOR)

func in_any_room(x: int, y: int) -> bool:
	for room in rooms:
		if room.contains(x, y):
			return true
	return false

func can_move(x: int, y: int, dir: int) -> bool:
	var n := Vector2i(x, y) + Direction.offset(dir)
	if not in_bounds(n.x, n.y):
		return false
	var edge := get_edge(x, y, dir)
	return edge == EdgeType.OPEN or edge == EdgeType.DOOR

func bfs(start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var head := 0
	var dist := {start: 0}
	while head < queue.size():
		var pos: Vector2i = queue[head]
		head += 1
		for dir in Direction.ALL:
			if not can_move(pos.x, pos.y, dir):
				continue
			var next := pos + Direction.offset(dir)
			if not dist.has(next):
				dist[next] = dist[pos] + 1
				queue.append(next)
	return dist

func is_fully_connected() -> bool:
	return bfs(Vector2i(0, 0)).size() == map_size * map_size

func place_start_and_goal(rng: RandomNumberGenerator) -> void:
	for y in range(map_size):
		for x in range(map_size):
			cell(x, y).tile = TileType.FLOOR
	var sx: int
	var sy: int
	if rooms.size() > 0:
		var room: MapRect = rooms[rng.randi_range(0, rooms.size() - 1)]
		var c := room.center()
		sx = c.x
		sy = c.y
	else:
		sx = 0
		sy = 0
	var dist := bfs(Vector2i(sx, sy))
	var max_dist := -1
	var gx := 0
	var gy := 0
	for pos in dist:
		if dist[pos] > max_dist:
			max_dist = dist[pos]
			gx = pos.x
			gy = pos.y
	cell(sx, sy).tile = TileType.START
	cell(gx, gy).tile = TileType.GOAL

func generate(
	seed_val: int = 0,
	room_attempts: int = -1,
	min_room_size: int = 4,
	max_room_size: int = -1,
	extra_links: int = -1,
	door_chance: float = 0.25,
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	_init_all_walls()
	rooms = []

	if room_attempts < 0:
		room_attempts = maxi(20, map_size * 3)
	if max_room_size < 0:
		max_room_size = maxi(5, mini(8, map_size / 3 + 1) as int)
	if extra_links < 0:
		extra_links = maxi(2, (map_size / 4) as int)

	carve_perfect_maze(rng)
	generate_rooms(rng, room_attempts, min_room_size, max_room_size)
	carve_rooms()
	add_extra_links(rng, extra_links)
	add_doors_between_room_and_nonroom(rng, door_chance)
	place_start_and_goal(rng)
