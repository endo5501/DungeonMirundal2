class_name PlayerState
extends RefCounted

var position: Vector2i
var facing: int

func _init(pos: Vector2i, dir: int) -> void:
	position = pos
	facing = dir

func turn_right() -> void:
	facing = (facing + 1) % 4

func turn_left() -> void:
	facing = (facing + 3) % 4

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
