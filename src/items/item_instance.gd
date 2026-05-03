class_name ItemInstance
extends RefCounted

var item: Item
var identified: bool


func _init(p_item: Item = null, p_identified: bool = true) -> void:
	item = p_item
	identified = p_identified


func to_dict() -> Dictionary:
	return {
		"item_id": item.item_id if item != null else StringName(),
		"identified": identified,
	}


static func from_dict(data: Dictionary, repository: ItemRepository) -> ItemInstance:
	if repository == null:
		return null
	var id_raw: Variant = data.get("item_id", &"")
	var id := StringName(id_raw) if not (id_raw is StringName) else id_raw as StringName
	var resolved := repository.find(id)
	if resolved == null:
		return null
	return ItemInstance.new(resolved, bool(data.get("identified", true)))
