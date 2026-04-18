class_name MonsterData
extends Resource

@export var monster_id: StringName
@export var monster_name: String
@export var max_hp_min: int
@export var max_hp_max: int
@export var attack: int
@export var defense: int
@export var agility: int
@export var experience: int
@export var gold_min: int = 0
@export var gold_max: int = 0


func is_valid() -> bool:
	if monster_id == &"":
		return false
	if max_hp_min < 0:
		return false
	if max_hp_min > max_hp_max:
		return false
	if gold_min < 0:
		return false
	if gold_min > gold_max:
		return false
	return true
