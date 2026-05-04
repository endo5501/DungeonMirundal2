class_name StatModSpellEffect
extends SpellEffect

# stat is one of &"attack" / &"defense" / &"agility" / &"hit" / &"evasion".
# delta is int for attack/defense/agility, float for hit/evasion.
@export var stat: StringName = &""
@export var delta: Variant = 0
@export var turns: int = 0


func apply(_caster: CombatActor, targets: Array, _spell_rng: SpellRng) -> SpellResolution:
	var resolution := SpellResolution.new()
	for target in targets:
		if target == null:
			continue
		target.modifier_stack.add(stat, delta, turns)
		var entry := resolution.add_entry(target, 0)
		(entry["events"] as Array).append({
			"type": "stat_mod",
			"stat": stat,
			"delta": delta,
			"turns": turns,
		})
	return resolution
