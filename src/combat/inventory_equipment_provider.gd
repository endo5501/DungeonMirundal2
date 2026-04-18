class_name InventoryEquipmentProvider
extends EquipmentProvider


func get_attack(character: Character) -> int:
	if character == null:
		return 0
	var base: int = int(character.base_stats.get(&"STR", 0)) / 2
	return base + _sum_bonus(character, &"attack_bonus")


func get_defense(character: Character) -> int:
	if character == null:
		return 0
	var base: int = int(character.base_stats.get(&"VIT", 0)) / 3
	return base + _sum_bonus(character, &"defense_bonus")


func get_agility(character: Character) -> int:
	if character == null:
		return 0
	var base: int = int(character.base_stats.get(&"AGI", 0))
	return base + _sum_bonus(character, &"agility_bonus")


func _sum_bonus(character: Character, field: StringName) -> int:
	if character.equipment == null:
		return 0
	var total: int = 0
	for inst in character.equipment.all_equipped():
		if inst != null and inst.item != null:
			total += int(inst.item.get(field))
	return total
