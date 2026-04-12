class_name MapRect
extends RefCounted

var x: int
var y: int
var w: int
var h: int

func _init(px: int, py: int, pw: int, ph: int) -> void:
	x = px
	y = py
	w = pw
	h = ph

func x2() -> int:
	return x + w - 1

func y2() -> int:
	return y + h - 1

func center() -> Vector2i:
	return Vector2i(x + w / 2, y + h / 2)

func intersects(other: MapRect, margin: int = 1) -> bool:
	return not (
		x2() + margin < other.x
		or other.x2() + margin < x
		or y2() + margin < other.y
		or other.y2() + margin < y
	)

func contains(px: int, py: int) -> bool:
	return x <= px and px <= x2() and y <= py and py <= y2()
