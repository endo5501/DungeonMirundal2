class_name EquipmentProvider
extends RefCounted


func get_attack(_character: Character) -> int:
	return 0


func get_defense(_character: Character) -> int:
	return 0


func get_agility(_character: Character) -> int:
	return 0


# Resolve the equipped weapon's reach. Default is MELEE so subclasses that
# don't care about row-based combat (e.g. legacy stubs) keep working.
func get_weapon_range(_character: Character) -> int:
	return WeaponRange.MELEE
