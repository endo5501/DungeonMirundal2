class_name SpellResolution
extends RefCounted

# Each entry is a Dictionary with keys:
#   actor (CombatActor), hp_delta (int), actor_name (String), events (Array).
# Negative hp_delta = damage, positive = heal.
# `events` holds zero or more event Dictionaries; producers append per-target
# events such as {"type": "damage", "amount": int} or {"type": "inflict", ...}.
# `hp_delta` MUST be kept consistent with the sum of HP-affecting events.
var entries: Array = []


# Returns the appended Dictionary so callers can mutate `events` directly.
func add_entry(actor: CombatActor, hp_delta: int) -> Dictionary:
	var entry := {
		"actor": actor,
		"hp_delta": hp_delta,
		"actor_name": actor.actor_name if actor != null else "",
		"events": [],
	}
	entries.append(entry)
	return entry


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
