class_name Direction
extends RefCounted

enum { NORTH, EAST, SOUTH, WEST }

const ALL := [NORTH, EAST, SOUTH, WEST]

const _DX := [0, 1, 0, -1]
const _DY := [-1, 0, 1, 0]

static func dx(dir: int) -> int:
	return _DX[dir]

static func dy(dir: int) -> int:
	return _DY[dir]

static func offset(dir: int) -> Vector2i:
	return Vector2i(_DX[dir], _DY[dir])

static func opposite(dir: int) -> int:
	return (dir + 2) % 4

static func turn_right(dir: int) -> int:
	return (dir + 1) % 4

static func turn_left(dir: int) -> int:
	return (dir + 3) % 4
