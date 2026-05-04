class_name FloorRole
extends RefCounted

enum { SINGLE, FIRST, MIDDLE, LAST }

static func for_index(index: int, total: int) -> int:
	if total <= 1:
		return SINGLE
	if index == 0:
		return FIRST
	if index == total - 1:
		return LAST
	return MIDDLE
