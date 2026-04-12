class_name DungeonView
extends RefCounted

const VIEW_DEPTH := 4

func get_visible_cells(wiz_map: WizMap, pos: Vector2i, facing: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = [pos]
	var forward := Direction.offset(facing)
	var left_dir := Direction.turn_left(facing)
	var right_dir := Direction.turn_right(facing)
	var left_offset := Direction.offset(left_dir)
	var right_offset := Direction.offset(right_dir)

	var center := pos
	var left_visible := true
	var right_visible := true

	for depth in range(1, VIEW_DEPTH + 1):
		var prev_center := center
		if not wiz_map.can_move(prev_center.x, prev_center.y, facing):
			break
		center = prev_center + forward
		if not wiz_map.in_bounds(center.x, center.y):
			break
		result.append(center)
		# left
		if left_visible and wiz_map.can_move(center.x, center.y, left_dir):
			var left_cell := center + left_offset
			if wiz_map.in_bounds(left_cell.x, left_cell.y):
				result.append(left_cell)
		else:
			left_visible = false
		# right
		if right_visible and wiz_map.can_move(center.x, center.y, right_dir):
			var right_cell := center + right_offset
			if wiz_map.in_bounds(right_cell.x, right_cell.y):
				result.append(right_cell)
		else:
			right_visible = false
	return result
