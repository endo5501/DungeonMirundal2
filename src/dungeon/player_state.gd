class_name PlayerState
extends RefCounted

var position: Vector2i
var facing: int

func _init(pos: Vector2i, dir: int) -> void:
	position = pos
	facing = dir

func turn_right() -> void:
	facing = Direction.turn_right(facing)

func turn_left() -> void:
	facing = Direction.turn_left(facing)

func move_forward(wiz_map: WizMap) -> bool:
	if not wiz_map.can_move(position.x, position.y, facing):
		return false
	position += Direction.offset(facing)
	return true

func move_backward(wiz_map: WizMap) -> bool:
	var back_dir := Direction.opposite(facing)
	if not wiz_map.can_move(position.x, position.y, back_dir):
		return false
	position += Direction.offset(back_dir)
	return true

func to_dict() -> Dictionary:
	return {
		"position": [position.x, position.y],
		"facing": facing,
	}

static func from_dict(data: Dictionary) -> PlayerState:
	var pos_arr: Array = data.get("position", [0, 0])
	var pos := Vector2i(int(pos_arr[0]), int(pos_arr[1]))
	var dir: int = data.get("facing", Direction.NORTH)
	return PlayerState.new(pos, dir)
