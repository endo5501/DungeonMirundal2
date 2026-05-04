class_name DamageSpellEffect
extends SpellEffect

@export var base_damage: int = 0
@export var spread: int = 0


func apply(_caster: CombatActor, targets: Array, spell_rng: SpellRng) -> SpellResolution:
	var resolution := SpellResolution.new()
	for target in targets:
		if target == null:
			continue
		roll_and_apply(target, base_damage, spread, spell_rng, resolution)
	return resolution


# Shared damage routine used by both DamageSpellEffect and
# DamageWithStatusSpellEffect. Returns the mutated entry so callers can append
# additional events (e.g. inflict/resist after damage).
static func roll_and_apply(
	target,
	base: int,
	spread_amount: int,
	spell_rng: SpellRng,
	resolution: SpellResolution
) -> Dictionary:
	var roll := 0
	if spell_rng != null and spread_amount != 0:
		roll = spell_rng.roll(-spread_amount, spread_amount)
	var damage: int = maxi(base + roll, 1)
	var before: int = target.current_hp
	target.take_damage(damage)
	var after: int = target.current_hp
	var entry := resolution.add_entry(target, after - before)
	(entry["events"] as Array).append({"type": "damage", "amount": before - after})
	return entry
