class_name ExploredMap
extends RefCounted

var _visited: Dictionary  # { Vector2i: true }

func _init() -> void:
	_visited = {}

func mark_visited(pos: Vector2i) -> void:
	_visited[pos] = true

func mark_visible(cells: Array) -> void:
	for cell in cells:
		mark_visited(cell)

func is_visited(pos: Vector2i) -> bool:
	return _visited.has(pos)

func get_visited_cells() -> Array:
	return _visited.keys()

func clear() -> void:
	_visited.clear()
