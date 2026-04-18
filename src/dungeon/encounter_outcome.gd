class_name EncounterOutcome
extends RefCounted

enum Result {
	ESCAPED,
	CLEARED,
	WIPED,
}

var result: Result
var gained_experience: int = 0
var gained_gold: int = 0
var drops: Array = []


func _init(initial_result: Result = Result.CLEARED) -> void:
	result = initial_result
