class_name AttackCommand
extends RefCounted

var target: CombatActor


func _init(p_target: CombatActor = null) -> void:
	target = p_target
