extends GutTest


var _repo: ItemRepository
var _inventory: Inventory
var _guild: Guild
var _shop_inventory: ShopInventory


func _make_item(id: StringName, name: String, slot: Item.EquipSlot, price: int, allowed: Array = ["Fighter"]) -> Item:
	var item := Item.new()
	item.item_id = id
	item.item_name = name
	match slot:
		Item.EquipSlot.WEAPON: item.category = Item.ItemCategory.WEAPON
		Item.EquipSlot.ARMOR: item.category = Item.ItemCategory.ARMOR
		Item.EquipSlot.SHIELD: item.category = Item.ItemCategory.SHIELD
	item.equip_slot = slot
	item.price = price
	var typed: Array[StringName] = []
	for n in allowed:
		typed.append(StringName(n))
	item.allowed_jobs = typed
	return item


func before_each():
	_repo = ItemRepository.new()
	_repo.register(_make_item(&"cheap", "Cheap Sword", Item.EquipSlot.WEAPON, 25))
	_repo.register(_make_item(&"mid", "Mid Armor", Item.EquipSlot.ARMOR, 100))
	_repo.register(_make_item(&"costly", "Costly Shield", Item.EquipSlot.SHIELD, 600))
	_shop_inventory = ShopInventory.from_repository(_repo)
	_inventory = Inventory.new()
	_guild = Guild.new()


func _make_screen() -> ShopScreen:
	var s := ShopScreen.new()
	s.setup(_inventory, _guild, _shop_inventory)
	add_child_autofree(s)
	return s


# --- top menu ---

func test_top_menu_has_three_items():
	var s := _make_screen()
	var items := s.get_top_menu_items()
	assert_eq(items.size(), 3)
	assert_true(items.has("購入する"))
	assert_true(items.has("売却する"))
	assert_true(items.has("出る"))


func test_no_identify_option_in_top_menu():
	var s := _make_screen()
	var items := s.get_top_menu_items()
	for it in items:
		assert_false(it.contains("鑑定"))
		assert_false(it.to_lower().contains("identify"))


# --- buy ---

func test_buy_deducts_gold_and_adds_instance():
	_inventory.gold = 500
	var s := _make_screen()
	var mid := _repo.find(&"mid")
	assert_true(s.buy(mid))
	assert_eq(_inventory.gold, 400)
	assert_eq(_inventory.list().size(), 1)
	assert_eq(_inventory.list()[0].item, mid)


func test_buy_creates_identified_instance():
	_inventory.gold = 500
	var s := _make_screen()
	assert_true(s.buy(_repo.find(&"mid")))
	assert_true(_inventory.list()[0].identified)


func test_buy_blocked_when_insufficient_gold():
	_inventory.gold = 50
	var s := _make_screen()
	assert_false(s.buy(_repo.find(&"mid")))
	assert_eq(_inventory.gold, 50)
	assert_eq(_inventory.list().size(), 0)
	assert_true(s.get_last_message().contains("ゴールド"))


# --- sell ---

func test_sell_pays_half_price_floored():
	_inventory.gold = 0
	var inst := ItemInstance.new(_repo.find(&"mid"), true)
	_inventory.add(inst)
	var s := _make_screen()
	assert_true(s.sell(inst))
	assert_eq(_inventory.gold, 50)  # 100 / 2


func test_sell_floors_odd_price():
	_inventory.gold = 0
	var inst := ItemInstance.new(_repo.find(&"cheap"), true)
	_inventory.add(inst)
	var s := _make_screen()
	assert_true(s.sell(inst))
	assert_eq(_inventory.gold, 12)  # 25 / 2 = 12


func test_sell_removes_instance_from_inventory():
	_inventory.gold = 0
	var inst := ItemInstance.new(_repo.find(&"mid"), true)
	_inventory.add(inst)
	var s := _make_screen()
	s.sell(inst)
	assert_false(_inventory.contains(inst))


func test_equipped_instance_is_blocked_from_sell():
	_inventory.gold = 0
	var mid := _repo.find(&"mid")
	var inst := ItemInstance.new(mid, true)
	_inventory.add(inst)
	# Equip it on a character in the guild
	var human := load("res://data/races/human.tres") as RaceData
	var fighter := load("res://data/jobs/fighter.tres") as JobData
	var ch := Character.new()
	ch.character_name = "F"
	ch.race = human
	ch.job = fighter
	ch.level = 1
	ch.base_stats = {&"STR": 10, &"INT": 10, &"PIE": 10, &"VIT": 10, &"AGI": 10, &"LUC": 10}
	ch.max_hp = 10
	ch.current_hp = 10
	ch.equipment.equip(Equipment.EquipSlot.ARMOR, inst, ch)
	_guild.register(ch)
	var s := _make_screen()
	var candidates := s.get_sell_candidates()
	assert_false(candidates.has(inst))
	# Explicit sell attempt also fails
	assert_false(s.sell(inst))


func test_sell_candidates_includes_unequipped_items():
	_inventory.gold = 0
	var inst := ItemInstance.new(_repo.find(&"mid"), true)
	_inventory.add(inst)
	var s := _make_screen()
	assert_true(s.get_sell_candidates().has(inst))
