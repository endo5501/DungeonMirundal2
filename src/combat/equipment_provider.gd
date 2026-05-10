class_name EquipmentProvider
extends RefCounted


func get_attack(_character: Character) -> int:
	return 0


func get_defense(_character: Character) -> int:
	return 0


func get_agility(_character: Character) -> int:
	return 0


# MELEE default keeps legacy stub providers working.
func get_weapon_range(_character: Character) -> int:
	return WeaponRange.MELEE
