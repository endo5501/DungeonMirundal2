class_name SpellResolution
extends RefCounted

# Each entry is a Dictionary with keys: actor (CombatActor), hp_delta (int), actor_name (String).
# Negative hp_delta = damage, positive = heal.
var entries: Array = []


func add_entry(actor: CombatActor, hp_delta: int) -> void:
	entries.append({
		"actor": actor,
		"hp_delta": hp_delta,
		"actor_name": actor.actor_name if actor != null else "",
	})


func size() -> int:
	return entries.size()


func is_empty() -> bool:
	return entries.is_empty()


# Render per-target entries as one line each. Used by both the in-battle
# CombatLog and the out-of-battle SpellUseFlow result view.
static func format_entries(entries_array: Array) -> Array[String]:
	var lines: Array[String] = []
	for e in entries_array:
		var name: String = e.get("actor_name", "")
		var delta: int = int(e.get("hp_delta", 0))
		if delta < 0:
			lines.append("  %s に %d ダメージ" % [name, -delta])
		elif delta > 0:
			lines.append("  %s の HP +%d" % [name, delta])
		else:
			lines.append("  %s への効果はなかった" % name)
	return lines
