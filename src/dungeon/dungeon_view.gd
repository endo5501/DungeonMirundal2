class_name DungeonView
extends RefCounted

const VIEW_DEPTH := 4

func get_render_cells(wiz_map: WizMap, pos: Vector2i, facing: int) -> Array[Vector2i]:
	return get_visible_cells(wiz_map, pos, facing, false, true)

func get_explored_cells(wiz_map: WizMap, pos: Vector2i, facing: int) -> Array[Vector2i]:
	return get_visible_cells(wiz_map, pos, facing, true, false)

func get_visible_cells(wiz_map: WizMap, pos: Vector2i, facing: int, block_doors: bool = false, fill_openings: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = [pos]
	var forward := Direction.offset(facing)
	var left_dir := Direction.turn_left(facing)
	var right_dir := Direction.turn_right(facing)
	var left_offset := Direction.offset(left_dir)
	var right_offset := Direction.offset(right_dir)

	_add_lateral(result, wiz_map, pos, left_dir, left_offset, block_doors)
	_add_lateral(result, wiz_map, pos, right_dir, right_offset, block_doors)

	var center := pos
	for depth in range(1, VIEW_DEPTH + 1):
		var prev_center := center
		if not _can_see(wiz_map, prev_center.x, prev_center.y, facing, block_doors):
			break
		center = prev_center + forward
		if not wiz_map.in_bounds(center.x, center.y):
			break
		result.append(center)
		# Per-depth lateral checks: a wall on the side at depth N does not
		# propagate to deeper openings. The z-buffer still hides anything
		# geometrically occluded by the nearer wall.
		_add_lateral(result, wiz_map, center, left_dir, left_offset, block_doors)
		_add_lateral(result, wiz_map, center, right_dir, right_offset, block_doors)

	if fill_openings:
		_flood_through_openings(result, wiz_map)
	return result

func _add_lateral(result: Array[Vector2i], wiz_map: WizMap, from: Vector2i, dir: int, offset: Vector2i, block_doors: bool) -> void:
	if not _can_see(wiz_map, from.x, from.y, dir, block_doors):
		return
	var cell: Vector2i = from + offset
	if not wiz_map.in_bounds(cell.x, cell.y):
		return
	result.append(cell)

func _flood_through_openings(result: Array[Vector2i], wiz_map: WizMap) -> void:
	# Widens the renderer's view set one hop through OPEN edges so that a
	# visible opening never reveals un-meshed space behind it. Reuses
	# _can_see with block_doors=true (which is the strict "edge is OPEN"
	# check) for consistent semantics with the cone sweep.
	var seen := {}
	for c in result:
		seen[c] = true
	var original_size := result.size()
	for i in range(original_size):
		var cell_pos: Vector2i = result[i]
		for d in Direction.ALL:
			if not _can_see(wiz_map, cell_pos.x, cell_pos.y, d, true):
				continue
			var neighbor: Vector2i = cell_pos + Direction.offset(d)
			if seen.has(neighbor):
				continue
			seen[neighbor] = true
			result.append(neighbor)

func _can_see(wiz_map: WizMap, x: int, y: int, dir: int, block_doors: bool) -> bool:
	if block_doors:
		var n := Vector2i(x, y) + Direction.offset(dir)
		if not wiz_map.in_bounds(n.x, n.y):
			return false
		return wiz_map.get_edge(x, y, dir) == EdgeType.OPEN
	return wiz_map.can_move(x, y, dir)
