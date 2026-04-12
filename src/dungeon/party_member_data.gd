class_name PartyMemberData
extends RefCounted

var member_name: String
var level: int
var current_hp: int
var max_hp: int
var current_mp: int
var max_mp: int

func _init(p_name: String, p_level: int, p_current_hp: int, p_max_hp: int, p_current_mp: int, p_max_mp: int) -> void:
	member_name = p_name
	level = p_level
	current_hp = p_current_hp
	max_hp = p_max_hp
	current_mp = p_current_mp
	max_mp = p_max_mp
