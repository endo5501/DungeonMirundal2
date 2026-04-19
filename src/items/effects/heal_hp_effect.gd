class_name HealHpEffect
extends ItemEffect

@export var power: int = 0


func apply(targets: Array, _context) -> ItemEffectResult:
	if targets.is_empty():
		return ItemEffectResult.failure("対象がいません")
	var target = targets[0]
	if target == null:
		return ItemEffectResult.failure("対象が無効です")
	var before: int = target.current_hp
	var healed: int = mini(target.max_hp, before + power)
	target.current_hp = healed
	var delta: int = healed - before
	return ItemEffectResult.ok("HP が %d 回復した" % delta)
