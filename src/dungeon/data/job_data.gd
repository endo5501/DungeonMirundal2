class_name JobData
extends Resource

@export var id: StringName
@export var job_name: String
@export var base_hp: int
@export var has_magic: bool
@export var base_mp: int
@export var hp_per_level: int
@export var mp_per_level: int
@export var exp_table: PackedInt64Array
@export var required_str: int
@export var required_int: int
@export var required_pie: int
@export var required_vit: int
@export var required_agi: int
@export var required_luc: int

func can_qualify(stats: Dictionary) -> bool:
	return (
		stats.get(&"STR", 0) >= required_str
		and stats.get(&"INT", 0) >= required_int
		and stats.get(&"PIE", 0) >= required_pie
		and stats.get(&"VIT", 0) >= required_vit
		and stats.get(&"AGI", 0) >= required_agi
		and stats.get(&"LUC", 0) >= required_luc
	)

func exp_to_reach_level(target_level: int) -> int:
	if target_level <= 1:
		return 0
	var idx := target_level - 2
	if exp_table.size() == 0:
		return 0
	if idx >= exp_table.size():
		return exp_table[exp_table.size() - 1]
	return exp_table[idx]
