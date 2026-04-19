class_name InDungeonOnly
extends ContextCondition


func is_satisfied(context: ItemUseContext) -> bool:
	if context == null:
		return false
	return context.is_in_dungeon


func reason() -> String:
	return "ダンジョン内でのみ使用できる"
