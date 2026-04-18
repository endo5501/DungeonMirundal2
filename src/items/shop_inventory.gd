class_name ShopInventory
extends RefCounted

var _items: Array[Item] = []


static func from_repository(repository: ItemRepository) -> ShopInventory:
	var shop := ShopInventory.new()
	if repository == null:
		return shop
	for item in repository.all():
		if item.equip_slot != Item.EquipSlot.NONE:
			shop._items.append(item)
	shop._items.sort_custom(func(a: Item, b: Item) -> bool: return a.price < b.price)
	return shop


func add(item: Item) -> void:
	if item == null:
		return
	_items.append(item)


func list() -> Array[Item]:
	return _items.duplicate()


func size() -> int:
	return _items.size()


func purchase(item: Item) -> ItemInstance:
	if item == null:
		return null
	return ItemInstance.new(item, true)
