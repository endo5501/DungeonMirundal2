class_name PlayerState
extends RefCounted

var position: Vector2i
var facing: int
var current_floor: int = 0

func _init(pos: Vector2i, dir: int) -> void:
	position = pos
	facing = dir

func turn_right() -> void:
	facing = Direction.turn_right(facing)

func turn_left() -> void:
	facing = Direction.turn_left(facing)

func move_forward(wiz_map: WizMap) -> bool:
	return _try_step(wiz_map, facing)

func move_backward(wiz_map: WizMap) -> bool:
	return _try_step(wiz_map, Direction.opposite(facing))

func strafe_left(wiz_map: WizMap) -> bool:
	return _try_step(wiz_map, Direction.turn_left(facing))

func strafe_right(wiz_map: WizMap) -> bool:
	return _try_step(wiz_map, Direction.turn_right(facing))

func _try_step(wiz_map: WizMap, dir: int) -> bool:
	if not wiz_map.can_move(position.x, position.y, dir):
		return false
	position += Direction.offset(dir)
	return true

func to_dict() -> Dictionary:
	return {
		"position": [position.x, position.y],
		"facing": facing,
		"current_floor": current_floor,
	}

static func from_dict(data: Dictionary) -> PlayerState:
	var pos_arr: Array = data.get("position", [0, 0])
	var pos := Vector2i(int(pos_arr[0]), int(pos_arr[1]))
	var dir: int = data.get("facing", Direction.NORTH)
	var ps := PlayerState.new(pos, dir)
	ps.current_floor = int(data.get("current_floor", 0))
	return ps
