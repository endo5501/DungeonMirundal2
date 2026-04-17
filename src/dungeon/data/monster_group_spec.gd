class_name MonsterGroupSpec
extends Resource

@export var monster_id: StringName
@export var count_min: int = 1
@export var count_max: int = 1


func is_valid() -> bool:
	if monster_id == &"":
		return false
	if count_min < 1:
		return false
	if count_min > count_max:
		return false
	return true


func roll_count(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(count_min, count_max)
