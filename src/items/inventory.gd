class_name Inventory
extends RefCounted

var _items: Array[ItemInstance] = []
var gold: int = 0


func add(instance: ItemInstance) -> void:
	if instance == null:
		return
	_items.append(instance)


func remove(instance: ItemInstance) -> bool:
	var idx := _items.find(instance)
	if idx < 0:
		return false
	_items.remove_at(idx)
	return true


func contains(instance: ItemInstance) -> bool:
	return _items.find(instance) >= 0


func list() -> Array[ItemInstance]:
	return _items.duplicate()


func index_of(instance: ItemInstance) -> int:
	return _items.find(instance)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount


func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	if amount > gold:
		return false
	gold -= amount
	return true


func to_dict() -> Dictionary:
	var items_data: Array = []
	for inst in _items:
		items_data.append(inst.to_dict())
	return {
		"gold": gold,
		"items": items_data,
	}


static func from_dict(data: Dictionary, repository: ItemRepository) -> Inventory:
	var inv := Inventory.new()
	inv.gold = int(data.get("gold", 0))
	var items_data: Array = data.get("items", [])
	for item_data in items_data:
		var inst := ItemInstance.from_dict(item_data, repository)
		if inst != null:
			inv._items.append(inst)
	return inv
