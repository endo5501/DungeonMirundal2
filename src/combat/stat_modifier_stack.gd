class_name StatModifierStack
extends RefCounted

# Stack of active stat modifiers attached to a CombatActor.
#
# Recognized stat keys (Decision 4 of add-stat-modifier-and-hit-evasion):
#   &"attack" / &"defense" / &"agility"  → int delta
#   &"hit" / &"evasion"                  → float delta
#
# β rule for `add(stat, delta, duration)` when an entry for the same stat
# already exists:
#   - stronger (abs(new) > abs(existing)) → replace delta and duration
#   - equal magnitude                      → keep existing delta, take max(duration)
#   - weaker                               → no-op
#
# scope is BATTLE_ONLY for every modifier this change adds; the field is kept
# so a later change can introduce non-battle-only scopes without reshaping the
# storage.

const SCOPE_BATTLE_ONLY: int = 0

var _entries: Array = []


func is_empty() -> bool:
	return _entries.is_empty()


func add(stat: StringName, delta, duration: int) -> void:
	var existing: Dictionary = _find(stat)
	if existing.is_empty():
		_entries.append({
			"stat": stat,
			"delta": delta,
			"duration": duration,
			"scope": SCOPE_BATTLE_ONLY,
		})
		return
	var new_abs: float = abs(float(delta))
	var existing_abs: float = abs(float(existing["delta"]))
	if new_abs > existing_abs:
		existing["delta"] = delta
		existing["duration"] = duration
		return
	if new_abs == existing_abs:
		existing["duration"] = max(int(existing["duration"]), duration)
		return
	# weaker incoming: keep existing as-is


func sum(stat: StringName):
	var total = 0
	var seen_float := false
	for e in _entries:
		if e["stat"] != stat:
			continue
		var d = e["delta"]
		if typeof(d) == TYPE_FLOAT:
			seen_float = true
		total += d
	if seen_float:
		return float(total)
	return total


func tick_battle_turn() -> void:
	var keep: Array = []
	for e in _entries:
		if int(e["scope"]) == SCOPE_BATTLE_ONLY:
			e["duration"] = int(e["duration"]) - 1
			if int(e["duration"]) <= 0:
				continue
		keep.append(e)
	_entries = keep


func clear_battle_only() -> void:
	var keep: Array = []
	for e in _entries:
		if int(e["scope"]) != SCOPE_BATTLE_ONLY:
			keep.append(e)
	_entries = keep


func _find(stat: StringName) -> Dictionary:
	for e in _entries:
		if e["stat"] == stat:
			return e
	return {}
