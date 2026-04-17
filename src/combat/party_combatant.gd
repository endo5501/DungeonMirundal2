class_name PartyCombatant
extends CombatActor

var character: Character
var equipment_provider: EquipmentProvider


func _init(p_character: Character, p_provider: EquipmentProvider) -> void:
	character = p_character
	equipment_provider = p_provider
	if character != null:
		actor_name = character.character_name


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


func get_attack() -> int:
	if equipment_provider == null:
		return 0
	return equipment_provider.get_attack(character)


func get_defense() -> int:
	if equipment_provider == null:
		return 0
	return equipment_provider.get_defense(character)


func get_agility() -> int:
	if equipment_provider == null:
		return 0
	return equipment_provider.get_agility(character)
