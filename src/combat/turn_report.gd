class_name TurnReport
extends RefCounted

var actions: Array = []


func add_attack(
	attacker: CombatActor,
	target: CombatActor,
	damage: int,
	defended: bool = false,
	retargeted_from: String = "",
	confusion_swap: bool = false
) -> void:
	actions.append({
		"type": "attack",
		"attacker_name": attacker.actor_name if attacker != null else "",
		"target_name": target.actor_name if target != null else "",
		"damage": damage,
		"defended": defended,
		"retargeted_from": retargeted_from,
		"confusion_swap": confusion_swap,
	})


func add_miss(attacker: CombatActor, target: CombatActor, confusion_swap: bool = false) -> void:
	actions.append({
		"type": "miss",
		"attacker_name": attacker.actor_name if attacker != null else "",
		"target_name": target.actor_name if target != null else "",
		"confusion_swap": confusion_swap,
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


func add_cast(
	caster: CombatActor,
	spell: SpellData,
	resolution: SpellResolution,
	retargeted_from: String = ""
) -> void:
	var entries: Array = []
	if resolution != null:
		for e in resolution.entries:
			# Status-only entries (hp_delta=0 + events) are rendered as
			# top-level inflict/resist/cure actions; including them here would
			# double-up as "効果はなかった".
			var hp_delta: int = int(e.get("hp_delta", 0))
			var events: Array = e.get("events", [])
			if hp_delta == 0 and not events.is_empty():
				continue
			entries.append({
				"actor_name": e.get("actor_name", ""),
				"hp_delta": hp_delta,
			})
	actions.append({
		"type": "cast",
		"caster_name": caster.actor_name if caster != null else "",
		"spell_id": spell.id if spell != null else &"",
		"spell_display_name": spell.display_name if spell != null else "",
		"entries": entries,
		"retargeted_from": retargeted_from,
	})


func add_cast_skipped_no_mp(caster: CombatActor, spell: SpellData) -> void:
	actions.append({
		"type": "cast_skipped_no_mp",
		"caster_name": caster.actor_name if caster != null else "",
		"spell_id": spell.id if spell != null else &"",
		"spell_display_name": spell.display_name if spell != null else "",
	})


func add_cast_skipped_no_target(caster: CombatActor, spell: SpellData) -> void:
	actions.append({
		"type": "cast_skipped_no_target",
		"caster_name": caster.actor_name if caster != null else "",
		"spell_id": spell.id if spell != null else &"",
		"spell_display_name": spell.display_name if spell != null else "",
	})


# --- add-status-effect-infrastructure: status-related entries ---

func add_tick_damage(actor: CombatActor, status_id: StringName, amount: int, killed_by_tick: bool) -> void:
	actions.append({
		"type": "tick_damage",
		"actor_name": actor.actor_name if actor != null else "",
		"status_id": status_id,
		"amount": amount,
		"killed_by_tick": killed_by_tick,
	})


func add_wake(actor: CombatActor, status_id: StringName) -> void:
	actions.append({
		"type": "wake",
		"actor_name": actor.actor_name if actor != null else "",
		"status_id": status_id,
	})


func add_inflict(target: CombatActor, status_id: StringName, success: bool) -> void:
	actions.append({
		"type": "inflict",
		"target_name": target.actor_name if target != null else "",
		"status_id": status_id,
		"success": success,
	})


func add_cure(actor: CombatActor, status_id: StringName) -> void:
	actions.append({
		"type": "cure",
		"actor_name": actor.actor_name if actor != null else "",
		"status_id": status_id,
	})


func add_resist(target: CombatActor, status_id: StringName) -> void:
	actions.append({
		"type": "resist",
		"target_name": target.actor_name if target != null else "",
		"status_id": status_id,
	})


func add_stat_mod(target: CombatActor, stat: StringName, delta, turns: int) -> void:
	actions.append({
		"type": "stat_mod",
		"target_name": target.actor_name if target != null else "",
		"stat": stat,
		"delta": delta,
		"turns": turns,
	})


func add_action_locked(actor: CombatActor) -> void:
	actions.append({
		"type": "action_locked",
		"actor_name": actor.actor_name if actor != null else "",
	})


func add_cast_silenced(caster: CombatActor, spell_id: StringName) -> void:
	actions.append({
		"type": "cast_silenced",
		"caster_name": caster.actor_name if caster != null else "",
		"spell_id": spell_id,
	})


# --- add-row-based-combat: row-based reach action types ---

func add_wait(actor: CombatActor) -> void:
	actions.append({
		"type": "wait",
		"actor_name": actor.actor_name if actor != null else "",
	})


func add_attack_unreachable(attacker: CombatActor, target: CombatActor) -> void:
	actions.append({
		"type": "attack_unreachable",
		"attacker_name": attacker.actor_name if attacker != null else "",
		"target_name": target.actor_name if target != null else "",
	})
