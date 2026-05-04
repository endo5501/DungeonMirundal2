class_name StatModifierStack
extends RefCounted

# Stack of active stat modifiers attached to a CombatActor.
#
# β rule for `add(stat, delta, duration)` when an entry for the same stat
# already exists:
#   - stronger (abs(new) > abs(existing)) → replace delta and duration
#   - equal magnitude                      → keep existing delta, take max(duration)
#   - weaker                               → no-op

const STAT_ATTACK: StringName = &"attack"
const STAT_DEFENSE: StringName = &"defense"
const STAT_AGILITY: StringName = &"agility"
const STAT_HIT: StringName = &"hit"
const STAT_EVASION: StringName = &"evasion"

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
		})
		return
	var new_abs: float = absf(float(delta))
	var existing_abs: float = absf(float(existing["delta"]))
	if new_abs > existing_abs:
		existing["delta"] = delta
		existing["duration"] = duration
		return
	if new_abs == existing_abs:
		existing["duration"] = max(int(existing["duration"]), duration)


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
		e["duration"] = int(e["duration"]) - 1
		if int(e["duration"]) <= 0:
			continue
		keep.append(e)
	_entries = keep


func clear_battle_only() -> void:
	_entries.clear()


func _find(stat: StringName) -> Dictionary:
	for e in _entries:
		if e["stat"] == stat:
			return e
	return {}
