class_name StatusInflictSpellEffect
extends SpellEffect

@export var status_id: StringName = &""
@export var chance: float = 1.0       # 0..1 base chance
@export var duration: int = 3          # turns; ignored when scope == PERSISTENT

# Tests inject a StatusRepository to avoid disk-based lookups via DataLoader.
var _status_repo_override: StatusRepository = null


func set_status_repo_for_testing(repo: StatusRepository) -> void:
	_status_repo_override = repo


func apply(_caster: CombatActor, targets: Array, spell_rng: SpellRng) -> SpellResolution:
	var resolution := SpellResolution.new()
	var data: StatusData = StatusRepoLocator.resolve(_status_repo_override).find(status_id)
	if data == null:
		return resolution
	for target in targets:
		if target == null:
			continue
		var entry := resolution.add_entry(target, 0)
		StatusInflictHelper.try_inflict(target, data, chance, duration, spell_rng, entry)
	return resolution
