class_name PartyCombatant
extends CombatActor

var character: Character
var equipment_provider: EquipmentProvider


func _init(p_character: Character, p_provider: EquipmentProvider) -> void:
	character = p_character
	equipment_provider = p_provider
	if character != null:
		actor_name = character.character_name
		# Seed persistent statuses from the wrapped Character into our StatusTrack
		# so battle code sees the same state Character.persistent_statuses describes.
		for sid in character.persistent_statuses:
			statuses.apply(sid, StatusTrack.PERSISTENT_DURATION)


func _read_current_hp() -> int:
	if character == null:
		return 0
	return character.current_hp


func _write_current_hp(value: int) -> void:
	if character != null:
		character.current_hp = value


func _read_max_hp() -> int:
	if character == null:
		return 0
	return character.max_hp


func _read_current_mp() -> int:
	if character == null:
		return 0
	return character.current_mp


func _write_current_mp(value: int) -> void:
	if character != null:
		character.current_mp = value


func _read_max_mp() -> int:
	if character == null:
		return 0
	return character.max_mp


func _get_base_attack() -> int:
	if equipment_provider == null:
		return 0
	return equipment_provider.get_attack(character)


func _get_base_defense() -> int:
	if equipment_provider == null:
		return 0
	return equipment_provider.get_defense(character)


func _get_base_agility() -> int:
	if equipment_provider == null:
		return 0
	return equipment_provider.get_agility(character)


# Player resistance is the sum of race and job resists, clamped to [0, 1].
# An empty resist_key disables resistance lookup entirely.
func get_resist(resist_key: StringName) -> float:
	if resist_key == &"" or character == null:
		return 0.0
	var sum := 0.0
	if character.race != null:
		sum += float(character.race.resists.get(resist_key, 0.0))
	if character.job != null:
		sum += float(character.job.resists.get(resist_key, 0.0))
	return clamp(sum, 0.0, 1.0)


# Writes back PERSISTENT statuses to character.persistent_statuses; BATTLE_ONLY
# entries are dropped (they should already have been cured by the engine, but
# we filter here defensively too).
func commit_persistent_to_character(repo: StatusRepository) -> void:
	if character == null:
		return
	var persistent: Array[StringName] = []
	if repo == null:
		character.persistent_statuses = persistent
		return
	for sid in statuses.active_ids():
		var data: StatusData = repo.find(sid)
		if data == null:
			continue
		if data.scope == StatusData.Scope.PERSISTENT:
			persistent.append(sid)
	character.persistent_statuses = persistent
