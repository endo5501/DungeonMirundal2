class_name ItemCommand
extends RefCounted

var actor: CombatActor
var item_instance: ItemInstance
var target: CombatActor
var cancelled: bool = false


func _init(p_actor: CombatActor = null, p_instance: ItemInstance = null, p_target: CombatActor = null) -> void:
	actor = p_actor
	item_instance = p_instance
	target = p_target
