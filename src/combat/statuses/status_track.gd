class_name StatusTrack
extends RefCounted

# Per-actor container for active status effects.
#
# Backed by Dictionary[StringName, int] mapping status_id -> remaining duration.
# A duration value of PERSISTENT_DURATION (-1) marks an entry as PERSISTENT.
# Each id appears at most once; re-applying with a finite duration takes
# `max(existing, new)`. Re-applying onto a PERSISTENT entry with a finite value
# is rejected (PERSISTENT wins). A finite entry can be upgraded to PERSISTENT.

const PERSISTENT_DURATION := -1

var _entries: Dictionary = {}  # StringName -> int


func apply(status_id: StringName, duration: int) -> void:
	if _entries.has(status_id):
		var existing: int = _entries[status_id]
		if existing == PERSISTENT_DURATION:
			return  # PERSISTENT cannot be overwritten by a finite duration
		if duration == PERSISTENT_DURATION:
			_entries[status_id] = PERSISTENT_DURATION
			return
		_entries[status_id] = max(existing, duration)
	else:
		_entries[status_id] = duration


func has(status_id: StringName) -> bool:
	return _entries.has(status_id)


func cure(status_id: StringName) -> bool:
	return _entries.erase(status_id)


func active_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for sid in _entries.keys():
		result.append(sid)
	return result


# Short-circuits on the first active status whose StatusData has the given
# behavior flag set. Avoids the per-call array allocation that
# active_ids() would force on the caller.
func any_with_flag(repo: StatusRepository, flag: int) -> bool:
	if repo == null:
		return false
	for sid in _entries.keys():
		var data: StatusData = repo.find(sid)
		if data == null:
			continue
		match flag:
			StatusData.Flag.PREVENTS_ACTION:
				if data.prevents_action:
					return true
			StatusData.Flag.RANDOMIZES_TARGET:
				if data.randomizes_target:
					return true
			StatusData.Flag.BLOCKS_CAST:
				if data.blocks_cast:
					return true
	return false


# Removes every entry whose StatusData has scope == BATTLE_ONLY.
# Returns the cured ids (caller can route into TurnReport).
func cure_all_battle_only(repo: StatusRepository) -> Array[StringName]:
	var cured: Array[StringName] = []
	for sid in _entries.keys():
		var data: StatusData = repo.find(sid) if repo != null else null
		if data == null:
			continue
		if data.scope == StatusData.Scope.BATTLE_ONLY:
			cured.append(sid)
	for sid in cured:
		_entries.erase(sid)
	return cured


# At the head of a battle turn:
#   1. Apply battle-tick damage to actor for every entry whose tick_in_battle > 0.
#      Skipped if actor.is_alive() is false at that moment.
#   2. Decrement BATTLE_ONLY durations by 1; remove those that reach <= 0.
#   3. PERSISTENT entries are NOT decremented.
# Returns an Array of {status_id, hp_loss, killed_by_tick} entries.
func tick_battle_turn(actor, repo: StatusRepository) -> Array:
	var report: Array = []
	if repo == null:
		return report
	# Erasures are deferred via `to_remove`; in-place value writes during
	# Dictionary iteration are safe.
	var to_remove: Array[StringName] = []
	for sid in _entries:
		var data: StatusData = repo.find(sid)
		if data == null:
			continue
		if data.tick_in_battle > 0 and actor != null and actor.is_alive():
			var before: int = actor.current_hp
			actor.take_damage(data.tick_in_battle)
			var after: int = actor.current_hp
			report.append({
				"status_id": sid,
				"hp_loss": before - after,
				"killed_by_tick": not actor.is_alive(),
			})
		var dur: int = _entries[sid]
		if dur != PERSISTENT_DURATION:
			dur -= 1
			if dur <= 0:
				to_remove.append(sid)
			else:
				_entries[sid] = dur
	for sid in to_remove:
		_entries.erase(sid)
	return report


# Removes every entry whose StatusData has cures_on_damage == true.
# Returns the cured ids.
func handle_damage_taken(_actor, repo: StatusRepository) -> Array[StringName]:
	var cured: Array[StringName] = []
	if repo == null:
		return cured
	for sid in _entries.keys():
		var data: StatusData = repo.find(sid)
		if data == null:
			continue
		if data.cures_on_damage:
			cured.append(sid)
	for sid in cured:
		_entries.erase(sid)
	return cured
