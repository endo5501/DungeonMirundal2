class_name MonsterRepository
extends RefCounted

var _by_id: Dictionary = {}


func register(data: MonsterData) -> bool:
	if data == null or not data.is_valid():
		return false
	_by_id[data.monster_id] = data
	return true


func register_all(entries: Array) -> int:
	var count := 0
	for entry in entries:
		if register(entry):
			count += 1
	return count


func find(monster_id: StringName) -> MonsterData:
	return _by_id.get(monster_id, null)


func find_by_tier(tier: int) -> Array[MonsterData]:
	# Deterministic iteration: Godot Dictionary preserves insertion order, so
	# callers seeded with the same RNG against the same repository state get
	# reproducible encounter generation.
	var results: Array[MonsterData] = []
	for id in _by_id.keys():
		var monster: MonsterData = _by_id[id]
		if monster.tier == tier:
			results.append(monster)
	return results


func size() -> int:
	return _by_id.size()
