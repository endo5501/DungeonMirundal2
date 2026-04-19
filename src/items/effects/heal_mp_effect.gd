class_name HealMpEffect
extends ItemEffect

@export var power: int = 0


func apply(targets: Array, _context) -> ItemEffectResult:
	if targets.is_empty():
		return ItemEffectResult.failure("対象がいません")
	var target = targets[0]
	if target == null:
		return ItemEffectResult.failure("対象が無効です")
	var before: int = target.current_mp
	var healed: int = mini(target.max_mp, before + power)
	target.current_mp = healed
	var delta: int = healed - before
	return ItemEffectResult.ok("MP が %d 回復した" % delta)
