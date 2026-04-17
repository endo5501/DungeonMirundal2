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


func size() -> int:
	return _by_id.size()
