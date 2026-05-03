class_name TurnReport
extends RefCounted

var actions: Array = []


func add_attack(
	attacker: CombatActor,
	target: CombatActor,
	damage: int,
	defended: bool = false,
	retargeted_from: String = ""
) -> void:
	actions.append({
		"type": "attack",
		"attacker_name": attacker.actor_name if attacker != null else "",
		"target_name": target.actor_name if target != null else "",
		"damage": damage,
		"defended": defended,
		"retargeted_from": retargeted_from,
	})


func add_defend(actor: CombatActor) -> void:
	actions.append({
		"type": "defend",
		"attacker_name": actor.actor_name if actor != null else "",
		"target_name": "",
		"damage": 0,
		"defended": false,
	})


func add_escape(success: bool) -> void:
	actions.append({
		"type": "escape",
		"attacker_name": "",
		"target_name": "",
		"damage": 0,
		"defended": false,
		"success": success,
	})


func add_defeated(actor: CombatActor) -> void:
	actions.append({
		"type": "defeated",
		"attacker_name": "",
		"target_name": actor.actor_name if actor != null else "",
		"damage": 0,
		"defended": false,
	})


func add_item_use(actor: CombatActor, item_name: String, target: CombatActor, message: String) -> void:
	actions.append({
		"type": "item_use",
		"attacker_name": actor.actor_name if actor != null else "",
		"target_name": target.actor_name if target != null else "",
		"item_name": item_name,
		"message": message,
		"damage": 0,
		"defended": false,
	})


func add_item_cancelled(actor: CombatActor, item_name: String) -> void:
	actions.append({
		"type": "item_cancelled",
		"attacker_name": actor.actor_name if actor != null else "",
		"target_name": "",
		"item_name": item_name,
		"damage": 0,
		"defended": false,
	})
