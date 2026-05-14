class_name EncounterTableData
extends Resource

@export var floor: int = 1
@export var probability_per_step: float = 0.1
# tier_weights maps tier (int in [1, 5]) to a positive integer weight.
# Godot's .tres serialization may coerce int dictionary keys to strings; use
# normalized_tier_weights() at runtime to get a guaranteed int-keyed copy.
@export var tier_weights: Dictionary = {}
@export var species_count_min: int = 1
@export var species_count_max: int = 2
@export var count_per_species_min: int = 1
@export var count_per_species_max: int = 4


func is_valid() -> bool:
	if floor < 1:
		return false
	if probability_per_step < 0.0 or probability_per_step > 1.0:
		return false
	if species_count_min < 1 or species_count_max < species_count_min:
		return false
	if count_per_species_min < 1 or count_per_species_max < count_per_species_min:
		return false
	if tier_weights.is_empty():
		return false
	var has_positive := false
	for key in tier_weights.keys():
		var tier_int: int = _coerce_to_int(key)
		if tier_int == -1:
			return false
		if tier_int < 1 or tier_int > 5:
			return false
		var weight: int = int(tier_weights[key])
		if weight < 0:
			return false
		if weight > 0:
			has_positive = true
	return has_positive


func normalized_tier_weights() -> Dictionary:
	# Returns a copy of tier_weights with all keys coerced to int. Skips entries
	# whose key cannot be parsed as an integer.
	var result: Dictionary = {}
	for key in tier_weights.keys():
		var tier_int: int = _coerce_to_int(key)
		if tier_int == -1:
			continue
		result[tier_int] = int(tier_weights[key])
	return result


func _coerce_to_int(key: Variant) -> int:
	# Returns -1 if the key cannot be parsed as an integer.
	if typeof(key) == TYPE_INT:
		return int(key)
	if typeof(key) == TYPE_STRING or typeof(key) == TYPE_STRING_NAME:
		var s := String(key)
		if s.is_valid_int():
			return s.to_int()
	return -1
