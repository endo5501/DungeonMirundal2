class_name DefendCommand
extends RefCounted


func apply_to(actor: CombatActor) -> void:
	if actor != null:
		actor.apply_defend()
