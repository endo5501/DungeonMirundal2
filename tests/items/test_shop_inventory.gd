extends GutTest


var _repo: ItemRepository


func _make_item(id: StringName, slot: Item.EquipSlot, price: int) -> Item:
	var item := Item.new()
	item.item_id = id
	item.item_name = String(id)
	match slot:
		Item.EquipSlot.WEAPON: item.category = Item.ItemCategory.WEAPON
		Item.EquipSlot.ARMOR: item.category = Item.ItemCategory.ARMOR
		Item.EquipSlot.NONE: item.category = Item.ItemCategory.OTHER
	item.equip_slot = slot
	item.price = price
	return item


func _make_consumable(id: StringName, price: int) -> Item:
	var item := Item.new()
	item.item_id = id
	item.item_name = String(id)
	item.category = Item.ItemCategory.CONSUMABLE
	item.equip_slot = Item.EquipSlot.NONE
	item.price = price
	return item


func before_each():
	_repo = ItemRepository.new()
	_repo.register(_make_item(&"sword", Item.EquipSlot.WEAPON, 100))
	_repo.register(_make_item(&"armor", Item.EquipSlot.ARMOR, 80))
	_repo.register(_make_item(&"junk", Item.EquipSlot.NONE, 5))  # OTHER + NONE should be skipped
	_repo.register(_make_consumable(&"potion", 50))  # CONSUMABLE should be included


func test_from_repository_includes_equippable_items():
	var shop := ShopInventory.from_repository(_repo)
	var ids: Array = []
	for item in shop.list():
		ids.append(item.item_id)
	assert_true(ids.has(&"sword"))
	assert_true(ids.has(&"armor"))


func test_from_repository_skips_other_with_none_slot():
	var shop := ShopInventory.from_repository(_repo)
	for item in shop.list():
		# OTHER + NONE slot items (e.g. junk) should be excluded
		var is_equippable := item.equip_slot != Item.EquipSlot.NONE
		var is_consumable := item.category == Item.ItemCategory.CONSUMABLE
		assert_true(is_equippable or is_consumable)


func test_from_repository_includes_consumables():
	var shop := ShopInventory.from_repository(_repo)
	var ids: Array = []
	for item in shop.list():
		ids.append(item.item_id)
	assert_true(ids.has(&"potion"))


func test_from_repository_excludes_other_junk():
	var shop := ShopInventory.from_repository(_repo)
	for item in shop.list():
		assert_ne(item.item_id, &"junk")


func test_shop_list_is_stable_across_calls():
	var shop := ShopInventory.from_repository(_repo)
	var first := shop.list()
	var second := shop.list()
	assert_eq(first.size(), second.size())
	for i in range(first.size()):
		assert_eq(first[i].item_id, second[i].item_id)


func test_purchase_returns_fresh_identified_instance():
	var shop := ShopInventory.from_repository(_repo)
	var sword := _repo.find(&"sword")
	var inst := shop.purchase(sword)
	assert_not_null(inst)
	assert_eq(inst.item, sword)
	assert_true(inst.identified)


func test_purchase_returns_different_instances_for_same_item():
	var shop := ShopInventory.from_repository(_repo)
	var sword := _repo.find(&"sword")
	var a := shop.purchase(sword)
	var b := shop.purchase(sword)
	assert_ne(a, b)
