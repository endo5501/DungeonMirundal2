class_name ExploredMap
extends RefCounted

var _visited: Dictionary  # { Vector2i: true }

func _init() -> void:
	_visited = {}

func mark_visited(pos: Vector2i) -> void:
	_visited[pos] = true

func mark_visible(cells: Array[Vector2i]) -> void:
	for cell in cells:
		mark_visited(cell)

func is_visited(pos: Vector2i) -> bool:
	return _visited.has(pos)

func get_visited_count() -> int:
	return _visited.size()

func get_visited_cells() -> Array:
	return _visited.keys()

func clear() -> void:
	_visited.clear()

func to_dict() -> Dictionary:
	var visited_arr: Array = []
	for pos in _visited.keys():
		visited_arr.append([pos.x, pos.y])
	return {"visited": visited_arr}

static func from_dict(data: Dictionary) -> ExploredMap:
	var em := ExploredMap.new()
	var visited_arr: Array = data.get("visited", [])
	for pair in visited_arr:
		em.mark_visited(Vector2i(int(pair[0]), int(pair[1])))
	return em
