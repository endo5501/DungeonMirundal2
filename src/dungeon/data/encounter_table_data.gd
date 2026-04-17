class_name EncounterTableData
extends Resource

@export var floor: int = 1
@export var probability_per_step: float = 0.1
@export var entries: Array[EncounterEntry] = []


func is_valid() -> bool:
	if floor < 1:
		return false
	if probability_per_step < 0.0 or probability_per_step > 1.0:
		return false
	if entries.is_empty():
		return false
	for entry in entries:
		if entry == null or not entry.is_valid():
			return false
	return true


func total_weight() -> int:
	var sum := 0
	for entry in entries:
		sum += entry.weight
	return sum
