extends GutTest


var _sword: Item
var _shield: Item
var _repo: ItemRepository


func _make_item(id: StringName) -> Item:
	var item := Item.new()
	item.item_id = id
	item.item_name = String(id)
	return item


func before_each():
	_sword = _make_item(&"long_sword")
	_shield = _make_item(&"wooden_shield")
	_repo = ItemRepository.from_array([_sword, _shield])


# --- 2.1: basic operations ---

func test_new_inventory_is_empty():
	var inv := Inventory.new()
	assert_eq(inv.list().size(), 0)
	assert_eq(inv.gold, 0)


func test_add_appends_item():
	var inv := Inventory.new()
	var inst := ItemInstance.new(_sword, true)
	inv.add(inst)
	assert_eq(inv.list().size(), 1)
	assert_eq(inv.list()[0], inst)


func test_contains_returns_true_after_add():
	var inv := Inventory.new()
	var inst := ItemInstance.new(_sword, true)
	inv.add(inst)
	assert_true(inv.contains(inst))


func test_remove_existing_returns_true():
	var inv := Inventory.new()
	var inst := ItemInstance.new(_sword, true)
	inv.add(inst)
	assert_true(inv.remove(inst))
	assert_false(inv.contains(inst))


func test_remove_missing_returns_false():
	var inv := Inventory.new()
	var inst := ItemInstance.new(_sword, true)
	assert_false(inv.remove(inst))


func test_list_returns_defensive_copy():
	var inv := Inventory.new()
	inv.add(ItemInstance.new(_sword, true))
	var listed := inv.list()
	listed.clear()
	assert_eq(inv.list().size(), 1)


func test_many_additions_all_succeed():
	var inv := Inventory.new()
	for i in range(100):
		inv.add(ItemInstance.new(_sword, true))
	assert_eq(inv.list().size(), 100)


# --- 2.3: gold operations ---

func test_add_gold_increases_balance():
	var inv := Inventory.new()
	inv.gold = 100
	inv.add_gold(50)
	assert_eq(inv.gold, 150)


func test_spend_gold_succeeds_when_sufficient():
	var inv := Inventory.new()
	inv.gold = 100
	assert_true(inv.spend_gold(40))
	assert_eq(inv.gold, 60)


func test_spend_gold_fails_when_insufficient():
	var inv := Inventory.new()
	inv.gold = 30
	assert_false(inv.spend_gold(50))
	assert_eq(inv.gold, 30)


func test_spend_gold_exact_balance_succeeds():
	var inv := Inventory.new()
	inv.gold = 50
	assert_true(inv.spend_gold(50))
	assert_eq(inv.gold, 0)


func test_add_gold_negative_is_ignored():
	var inv := Inventory.new()
	inv.gold = 100
	inv.add_gold(-10)
	assert_eq(inv.gold, 100)


func test_spend_gold_negative_is_rejected():
	var inv := Inventory.new()
	inv.gold = 100
	assert_false(inv.spend_gold(-10))
	assert_eq(inv.gold, 100)


# --- tighten-types-and-contracts: spend_gold(0) is a successful no-op ---

func test_spend_gold_zero_returns_true_and_keeps_gold():
	var inv := Inventory.new()
	inv.gold = 100
	assert_true(inv.spend_gold(0))
	assert_eq(inv.gold, 100)


func test_spend_gold_zero_on_empty_balance_still_succeeds():
	var inv := Inventory.new()
	inv.gold = 0
	assert_true(inv.spend_gold(0))
	assert_eq(inv.gold, 0)


# --- 2.5: serialization ---

func test_to_dict_emits_gold_and_items():
	var inv := Inventory.new()
	inv.gold = 250
	inv.add(ItemInstance.new(_sword, true))
	inv.add(ItemInstance.new(_shield, false))
	var d := inv.to_dict()
	assert_eq(d.get("gold"), 250)
	var items: Array = d.get("items", [])
	assert_eq(items.size(), 2)
	assert_eq(items[0].get("item_id"), &"long_sword")
	assert_eq(items[1].get("identified"), false)


func test_roundtrip_preserves_gold():
	var inv := Inventory.new()
	inv.gold = 250
	var restored := Inventory.from_dict(inv.to_dict(), _repo)
	assert_eq(restored.gold, 250)


func test_roundtrip_preserves_item_order():
	var inv := Inventory.new()
	inv.add(ItemInstance.new(_sword, true))
	inv.add(ItemInstance.new(_shield, false))
	inv.add(ItemInstance.new(_sword, true))
	var restored := Inventory.from_dict(inv.to_dict(), _repo)
	var listed := restored.list()
	assert_eq(listed.size(), 3)
	assert_eq(listed[0].item.item_id, &"long_sword")
	assert_eq(listed[1].item.item_id, &"wooden_shield")
	assert_eq(listed[2].item.item_id, &"long_sword")


func test_from_dict_empty_data_returns_empty_inventory():
	var inv := Inventory.from_dict({}, _repo)
	assert_eq(inv.gold, 0)
	assert_eq(inv.list().size(), 0)


func test_from_dict_skips_unresolvable_items():
	var data := {
		"gold": 100,
		"items": [
			{"item_id": &"long_sword", "identified": true},
			{"item_id": &"unknown", "identified": true},  # not in repo
		],
	}
	var inv := Inventory.from_dict(data, _repo)
	assert_eq(inv.gold, 100)
	assert_eq(inv.list().size(), 1)
