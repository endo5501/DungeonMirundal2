class_name ItemRepository
extends RefCounted

var _by_id: Dictionary = {}


static func from_array(items: Array) -> ItemRepository:
	var repo := ItemRepository.new()
	for item in items:
		repo.register(item)
	return repo


func register(item: Item) -> void:
	if item == null:
		return
	_by_id[item.item_id] = item


func find(item_id: StringName) -> Item:
	return _by_id.get(item_id, null)


func all() -> Array[Item]:
	var results: Array[Item] = []
	for id in _by_id.keys():
		results.append(_by_id[id])
	return results
