class_name DamageSpellEffect
extends SpellEffect

@export var base_damage: int = 0
@export var spread: int = 0


func apply(_caster: CombatActor, targets: Array, spell_rng: SpellRng) -> SpellResolution:
	var resolution := SpellResolution.new()
	for target in targets:
		if target == null:
			continue
		var roll := 0
		if spell_rng != null and spread != 0:
			roll = spell_rng.roll(-spread, spread)
		var damage: int = maxi(base_damage + roll, 1)
		var before: int = target.current_hp
		target.take_damage(damage)
		var after: int = target.current_hp
		resolution.add_entry(target, after - before)
	return resolution
