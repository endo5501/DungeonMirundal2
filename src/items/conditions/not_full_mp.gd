class_name NotFullMp
extends TargetCondition


func is_satisfied(target, _context: ItemUseContext) -> bool:
	if target == null:
		return false
	if target.max_mp <= 0:
		return false
	return target.current_mp < target.max_mp


func reason() -> String:
	return "MP が満タン"
