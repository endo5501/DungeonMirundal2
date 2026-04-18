class_name InventoryEquipmentProvider
extends EquipmentProvider


func get_attack(character: Character) -> int:
	if character == null:
		return 0
	var total: int = int(character.base_stats.get(&"STR", 0)) / 2
	for inst in _equipped(character):
		total += inst.item.attack_bonus
	return total


func get_defense(character: Character) -> int:
	if character == null:
		return 0
	var total: int = int(character.base_stats.get(&"VIT", 0)) / 3
	for inst in _equipped(character):
		total += inst.item.defense_bonus
	return total


func get_agility(character: Character) -> int:
	if character == null:
		return 0
	var total: int = int(character.base_stats.get(&"AGI", 0))
	for inst in _equipped(character):
		total += inst.item.agility_bonus
	return total


func _equipped(character: Character) -> Array[ItemInstance]:
	if character.equipment == null:
		return []
	return character.equipment.all_equipped()
