class_name Monster
extends RefCounted

var data: MonsterData
var max_hp: int
var current_hp: int


func _init(source: MonsterData, rng: RandomNumberGenerator) -> void:
	data = source
	max_hp = rng.randi_range(source.max_hp_min, source.max_hp_max)
	current_hp = max_hp


var monster_id: StringName:
	get: return data.monster_id


var monster_name: String:
	get: return data.monster_name
