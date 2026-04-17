class_name EncounterPattern
extends Resource

@export var groups: Array[MonsterGroupSpec] = []


func is_valid() -> bool:
	if groups.is_empty():
		return false
	for group in groups:
		if group == null or not group.is_valid():
			return false
	return true


func roll_counts(rng: RandomNumberGenerator) -> Array[int]:
	var results: Array[int] = []
	for group in groups:
		results.append(group.roll_count(rng))
	return results
