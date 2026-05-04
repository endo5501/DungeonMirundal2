class_name CureStatusSpellEffect
extends SpellEffect

@export var status_id: StringName = &""


func apply(_caster: CombatActor, targets: Array, _spell_rng: SpellRng) -> SpellResolution:
	var resolution := SpellResolution.new()
	for target in targets:
		if target == null:
			continue
		var entry := resolution.add_entry(target, 0)
		var was_present: bool = target.statuses.cure(status_id)
		if was_present:
			(entry["events"] as Array).append({
				"type": "cure",
				"status_id": status_id,
			})
	return resolution
