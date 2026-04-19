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


func use_item(instance: ItemInstance, targets: Array, context: ItemUseContext) -> ItemEffectResult:
	if instance == null:
		return ItemEffectResult.failure("アイテムが無効")
	if not contains(instance):
		return ItemEffectResult.failure("所持していない")
	var item: Item = instance.item
	if item == null:
		return ItemEffectResult.failure("アイテム定義が欠落")
	if item.effect == null:
		return ItemEffectResult.failure("このアイテムは使用できない")
	for ctx_cond in item.context_conditions:
		if not ctx_cond.is_satisfied(context):
			return ItemEffectResult.failure(ctx_cond.reason())
	for target in targets:
		for tgt_cond in item.target_conditions:
			if not tgt_cond.is_satisfied(target, context):
				return ItemEffectResult.failure(tgt_cond.reason())
	var result: ItemEffectResult = item.effect.apply(targets, context)
	if result != null and result.success:
		remove(instance)
	return result


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
