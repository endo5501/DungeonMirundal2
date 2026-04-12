class_name Cell
extends RefCounted

var tile: int = TileType.FLOOR
var _edges: Array[int] = []

func _init() -> void:
	_edges.resize(4)
	_edges.fill(EdgeType.WALL)

func get_edge(dir: int) -> int:
	return _edges[dir]

func set_edge(dir: int, edge: int) -> void:
	_edges[dir] = edge
