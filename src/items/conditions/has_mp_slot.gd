class_name HasMpSlot
extends TargetCondition


func is_satisfied(target, _context: ItemUseContext) -> bool:
	if target == null:
		return false
	if "max_mp" in target:
		return target.max_mp > 0
	return false


func reason() -> String:
	return "MP を持たない職業"
