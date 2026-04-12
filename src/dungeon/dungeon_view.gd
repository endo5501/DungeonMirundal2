class_name DungeonView
extends RefCounted

const VIEW_DEPTH := 4

func get_visible_cells(wiz_map: WizMap, pos: Vector2i, facing: int, block_doors: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = [pos]
	var forward := Direction.offset(facing)
	var left_dir := Direction.turn_left(facing)
	var right_dir := Direction.turn_right(facing)
	var left_offset := Direction.offset(left_dir)
	var right_offset := Direction.offset(right_dir)

	# lateral cells at player position (depth 0)
	if _can_see(wiz_map, pos.x, pos.y, left_dir, block_doors):
		var left_cell := pos + left_offset
		if wiz_map.in_bounds(left_cell.x, left_cell.y):
			result.append(left_cell)
	if _can_see(wiz_map, pos.x, pos.y, right_dir, block_doors):
		var right_cell := pos + right_offset
		if wiz_map.in_bounds(right_cell.x, right_cell.y):
			result.append(right_cell)

	var center := pos
	var left_visible := true
	var right_visible := true

	for depth in range(1, VIEW_DEPTH + 1):
		var prev_center := center
		if not _can_see(wiz_map, prev_center.x, prev_center.y, facing, block_doors):
			break
		center = prev_center + forward
		if not wiz_map.in_bounds(center.x, center.y):
			break
		result.append(center)
		# left
		if left_visible and _can_see(wiz_map, center.x, center.y, left_dir, block_doors):
			var left_cell := center + left_offset
			if wiz_map.in_bounds(left_cell.x, left_cell.y):
				result.append(left_cell)
		else:
			left_visible = false
		# right
		if right_visible and _can_see(wiz_map, center.x, center.y, right_dir, block_doors):
			var right_cell := center + right_offset
			if wiz_map.in_bounds(right_cell.x, right_cell.y):
				result.append(right_cell)
		else:
			right_visible = false
	return result

func _can_see(wiz_map: WizMap, x: int, y: int, dir: int, block_doors: bool) -> bool:
	if block_doors:
		var n := Vector2i(x, y) + Direction.offset(dir)
		if not wiz_map.in_bounds(n.x, n.y):
			return false
		return wiz_map.get_edge(x, y, dir) == EdgeType.OPEN
	return wiz_map.can_move(x, y, dir)
