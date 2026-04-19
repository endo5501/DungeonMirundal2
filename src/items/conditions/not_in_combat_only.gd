class_name NotInCombatOnly
extends ContextCondition


func is_satisfied(context: ItemUseContext) -> bool:
	if context == null:
		return true
	return not context.is_in_combat


func reason() -> String:
	return "戦闘中は使用できない"
