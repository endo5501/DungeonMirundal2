class_name DummyEquipmentProvider
extends EquipmentProvider

const WEAPON_BONUS: Dictionary = {
	"Fighter": 5,
	"Mage": 1,
	"Priest": 2,
	"Thief": 3,
	"Bishop": 2,
	"Samurai": 5,
	"Lord": 5,
	"Ninja": 4,
}

const ARMOR_BONUS: Dictionary = {
	"Fighter": 3,
	"Mage": 1,
	"Priest": 3,
	"Thief": 2,
	"Bishop": 2,
	"Samurai": 4,
	"Lord": 5,
	"Ninja": 3,
}


func get_attack(character: Character) -> int:
	if character == null or character.job == null:
		return 0
	var str_contribution: int = int(character.base_stats.get(&"STR", 0)) / 2
	var bonus: int = WEAPON_BONUS.get(character.job.job_name, 0)
	return str_contribution + bonus


func get_defense(character: Character) -> int:
	if character == null or character.job == null:
		return 0
	var vit_contribution: int = int(character.base_stats.get(&"VIT", 0)) / 3
	var bonus: int = ARMOR_BONUS.get(character.job.job_name, 0)
	return vit_contribution + bonus


func get_agility(character: Character) -> int:
	if character == null:
		return 0
	return int(character.base_stats.get(&"AGI", 0))
