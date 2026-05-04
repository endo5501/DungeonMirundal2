class_name DamageWithStatusSpellEffect
extends SpellEffect

@export var base_damage: int = 0
@export var spread: int = 0
@export var status_id: StringName = &""
@export var inflict_chance: float = 0.0    # 0..1
@export var status_duration: int = 3        # turns; ignored when scope == PERSISTENT

var _status_repo_override: StatusRepository = null


func set_status_repo_for_testing(repo: StatusRepository) -> void:
	_status_repo_override = repo


func apply(_caster: CombatActor, targets: Array, spell_rng: SpellRng) -> SpellResolution:
	var resolution := SpellResolution.new()
	var data: StatusData = StatusRepoLocator.resolve(_status_repo_override).find(status_id)
	for target in targets:
		if target == null:
			continue
		var entry := DamageSpellEffect.roll_and_apply(target, base_damage, spread, spell_rng, resolution)
		# Skip inflict when target died from damage or status data missing.
		if data == null or not target.is_alive():
			continue
		StatusInflictHelper.try_inflict(target, data, inflict_chance, status_duration, spell_rng, entry)
	return resolution
