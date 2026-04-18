extends GutTest


var _sword: Item
var _shield: Item
var _repo: ItemRepository


func _make_item(id: StringName, name: String, category: Item.ItemCategory, slot: Item.EquipSlot) -> Item:
	var item := Item.new()
	item.item_id = id
	item.item_name = name
	item.unidentified_name = name + "?"
	item.category = category
	item.equip_slot = slot
	return item


func before_each():
	_sword = _make_item(&"long_sword", "Long Sword", Item.ItemCategory.WEAPON, Item.EquipSlot.WEAPON)
	_shield = _make_item(&"wooden_shield", "Wooden Shield", Item.ItemCategory.SHIELD, Item.EquipSlot.SHIELD)
	_repo = ItemRepository.new()
	_repo.register(_sword)
	_repo.register(_shield)


func test_instance_wraps_item_and_identified_flag():
	var inst := ItemInstance.new(_sword, true)
	assert_eq(inst.item, _sword)
	assert_true(inst.identified)


func test_instance_unidentified_flag():
	var inst := ItemInstance.new(_sword, false)
	assert_false(inst.identified)


func test_two_instances_from_same_item_are_distinct():
	var a := ItemInstance.new(_sword, true)
	var b := ItemInstance.new(_sword, true)
	assert_ne(a, b)
	assert_eq(a.item, b.item)


func test_to_dict_contains_item_id_and_identified():
	var inst := ItemInstance.new(_sword, true)
	var d := inst.to_dict()
	assert_eq(d.get("item_id"), &"long_sword")
	assert_eq(d.get("identified"), true)


func test_from_dict_resolves_item_from_repository():
	var inst := ItemInstance.from_dict({"item_id": &"long_sword", "identified": true}, _repo)
	assert_not_null(inst)
	assert_eq(inst.item, _sword)
	assert_true(inst.identified)


func test_from_dict_preserves_unidentified_flag():
	var inst := ItemInstance.from_dict({"item_id": &"long_sword", "identified": false}, _repo)
	assert_not_null(inst)
	assert_false(inst.identified)


func test_from_dict_returns_null_for_missing_item_id():
	var inst := ItemInstance.from_dict({"item_id": &"unknown", "identified": true}, _repo)
	assert_null(inst)


func test_roundtrip_preserves_fields():
	var original := ItemInstance.new(_shield, false)
	var restored := ItemInstance.from_dict(original.to_dict(), _repo)
	assert_not_null(restored)
	assert_eq(restored.item, _shield)
	assert_eq(restored.identified, original.identified)
