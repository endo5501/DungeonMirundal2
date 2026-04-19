class_name AliveOnly
extends TargetCondition


func is_satisfied(target, _context: ItemUseContext) -> bool:
	if target == null:
		return false
	if target.has_method("is_dead"):
		return not target.is_dead()
	if "current_hp" in target:
		return target.current_hp > 0
	return false


func reason() -> String:
	return "対象が行動不能"
