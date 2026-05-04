class_name HealSpellEffect
extends SpellEffect

@export var base_heal: int = 0
@export var spread: int = 0


func apply(_caster: CombatActor, targets: Array, rng: RandomNumberGenerator) -> SpellResolution:
	var resolution := SpellResolution.new()
	for target in targets:
		if target == null:
			continue
		# v1 raise-dead is out of scope; skip dead targets so they don't get a resolution entry.
		if not target.is_alive():
			continue
		var roll := 0
		if rng != null and spread != 0:
			roll = rng.randi_range(-spread, spread)
		var heal: int = maxi(base_heal + roll, 1)
		var before: int = target.current_hp
		var max_value: int = target.max_hp
		var healed: int = mini(max_value, before + heal)
		target.current_hp = healed
		resolution.add_entry(target, healed - before)
	return resolution
