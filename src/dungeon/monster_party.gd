class_name MonsterParty
extends RefCounted

var members: Array[Monster] = []


func add(monster: Monster) -> void:
	members.append(monster)


func size() -> int:
	return members.size()


func is_empty() -> bool:
	return members.is_empty()


func counts_by_species() -> Dictionary:
	var counts: Dictionary = {}
	for member in members:
		var id := member.monster_id
		counts[id] = counts.get(id, 0) + 1
	return counts
