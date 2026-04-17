class_name EncounterEntry
extends Resource

@export var pattern: EncounterPattern
@export var weight: int = 1


func is_valid() -> bool:
	if weight <= 0:
		return false
	if pattern == null or not pattern.is_valid():
		return false
	return true
