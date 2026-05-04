class_name CureStatusItemEffect
extends ItemEffect

@export var status_id: StringName = &""


func apply(targets: Array, _context) -> ItemEffectResult:
	if targets.is_empty():
		return ItemEffectResult.failure("対象がいません")
	var any_cured := false
	var cured_names: Array[String] = []
	for target in targets:
		if target == null:
			continue
		# Skip dead targets defensively (matches HealHpEffect-style guard).
		if target.has_method("is_alive") and not target.is_alive():
			continue
		if target is CombatActor:
			var actor := target as CombatActor
			if actor.statuses.cure(status_id):
				any_cured = true
				cured_names.append(actor.actor_name)
		elif "persistent_statuses" in target:
			var arr: Array = target.persistent_statuses
			var idx: int = arr.find(status_id)
			if idx >= 0:
				arr.remove_at(idx)
				target.persistent_statuses = arr
				any_cured = true
				if "character_name" in target:
					cured_names.append(String(target.character_name))
	if not any_cured:
		return ItemEffectResult.failure("対象には効果がなかった")
	if cured_names.is_empty():
		return ItemEffectResult.ok("状態を治療した")
	return ItemEffectResult.ok("%s の状態を治療した" % ", ".join(cured_names))
