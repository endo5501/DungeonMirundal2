class_name Monster
extends RefCounted

var data: MonsterData
var max_hp: int
var current_hp: int
var max_mp: int
var current_mp: int


func _init(source: MonsterData, rng: RandomNumberGenerator) -> void:
	data = source
	max_hp = rng.randi_range(source.max_hp_min, source.max_hp_max)
	current_hp = max_hp
	max_mp = rng.randi_range(source.max_mp_min, source.max_mp_max)
	current_mp = max_mp
