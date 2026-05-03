class_name RaceData
extends Resource

@export var id: StringName
@export var race_name: String
@export var base_str: int
@export var base_int: int
@export var base_pie: int
@export var base_vit: int
@export var base_agi: int
@export var base_luc: int

func get_base_stats() -> Dictionary:
	return {
		&"STR": base_str,
		&"INT": base_int,
		&"PIE": base_pie,
		&"VIT": base_vit,
		&"AGI": base_agi,
		&"LUC": base_luc,
	}
