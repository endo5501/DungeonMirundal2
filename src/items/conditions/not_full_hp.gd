class_name NotFullHp
extends TargetCondition


func is_satisfied(target, _context: ItemUseContext) -> bool:
	if target == null:
		return false
	return target.current_hp < target.max_hp


func reason() -> String:
	return "HP が満タン"
