extends GutTest


var _saved_inventory: Inventory
var _saved_guild: Guild
var _saved_location: String
var _saved_repo: ItemRepository


func before_each():
	_saved_inventory = GameState.inventory
	_saved_guild = GameState.guild
	_saved_location = GameState.game_location
	_saved_repo = GameState.item_repository
	GameState.inventory = Inventory.new()
	GameState.guild = Guild.new()
	GameState.item_repository = ItemRepository.new()
	GameState.game_location = GameState.LOCATION_DUNGEON


func after_each():
	GameState.inventory = _saved_inventory
	GameState.guild = _saved_guild
	GameState.game_location = _saved_location
	GameState.item_repository = _saved_repo


func _make_potion() -> Item:
	var it := Item.new()
	it.item_id = &"potion"
	it.item_name = "ポーション"
	it.category = Item.ItemCategory.CONSUMABLE
	it.equip_slot = Item.EquipSlot.NONE
	var e := HealHpEffect.new()
	e.power = 20
	it.effect = e
	var tc: Array[TargetCondition] = [AliveOnly.new(), NotFullHp.new()]
	it.target_conditions = tc
	it.price = 50
	return it


func _make_escape_scroll() -> Item:
	var it := Item.new()
	it.item_id = &"escape_scroll"
	it.item_name = "脱出の巻物"
	it.category = Item.ItemCategory.CONSUMABLE
	it.equip_slot = Item.EquipSlot.NONE
	it.effect = EscapeToTownEffect.new()
	var cc: Array[ContextCondition] = [InDungeonOnly.new(), NotInCombatOnly.new()]
	it.context_conditions = cc
	it.price = 500
	return it


func _make_sword() -> Item:
	var it := Item.new()
	it.item_id = &"long_sword"
	it.item_name = "Long Sword"
	it.category = Item.ItemCategory.WEAPON
	it.equip_slot = Item.EquipSlot.WEAPON
	it.price = 150
	return it


func _make_character(p_name: String = "Aragorn", hp: int = 10, max_hp: int = 40) -> Character:
	var ch := Character.new()
	ch.character_name = p_name
	ch.level = 1
	ch.race = load("res://data/races/human.tres") as RaceData
	ch.job = load("res://data/jobs/fighter.tres") as JobData
	ch.base_stats = {&"STR": 10, &"INT": 10, &"PIE": 10, &"VIT": 10, &"AGI": 10, &"LUC": 10}
	ch.current_hp = hp
	ch.max_hp = max_hp
	ch.current_mp = 0
	ch.max_mp = 0
	return ch


func _open_items_view(menu: EscMenu) -> void:
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.get_party_menu().selected_index = EscMenu.PARTY_IDX_ITEMS
	menu.select_current_item()  # → items


# --- use flow: potion ---

func test_select_potion_with_target_opens_target_view():
	var potion := _make_potion()
	var inst := ItemInstance.new(potion, true)
	GameState.inventory.add(inst)
	GameState.guild.register(_make_character("Aragorn", 10, 40))
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_items_view(menu)
	menu._items_index = 0
	menu.select_current_item()
	assert_eq(menu.get_current_view(), EscMenu.View.ITEM_USE_TARGET)


func test_using_potion_heals_target_and_removes_instance():
	var potion := _make_potion()
	var inst := ItemInstance.new(potion, true)
	GameState.inventory.add(inst)
	var ch := _make_character("Aragorn", 10, 40)
	GameState.guild.register(ch)
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_items_view(menu)
	menu._items_index = 0
	menu.select_current_item()  # → target view
	menu._item_use_target_index = 0
	menu.select_current_item()  # confirm target
	assert_eq(ch.current_hp, 30)
	assert_false(GameState.inventory.contains(inst))


func test_escape_key_from_target_view_goes_back_to_items():
	var potion := _make_potion()
	GameState.inventory.add(ItemInstance.new(potion, true))
	GameState.guild.register(_make_character("Aragorn", 10, 40))
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_items_view(menu)
	menu._items_index = 0
	menu.select_current_item()  # → target view
	menu.go_back()
	assert_eq(menu.get_current_view(), EscMenu.View.ITEMS)


# --- use flow: escape scroll ---

func test_select_escape_scroll_opens_confirm_view():
	var scroll := _make_escape_scroll()
	GameState.inventory.add(ItemInstance.new(scroll, true))
	GameState.guild.register(_make_character())
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_items_view(menu)
	menu._items_index = 0
	menu.select_current_item()
	assert_eq(menu.get_current_view(), EscMenu.View.ITEM_USE_CONFIRM)


func test_confirm_yes_on_escape_scroll_emits_return_to_town():
	var scroll := _make_escape_scroll()
	var inst := ItemInstance.new(scroll, true)
	GameState.inventory.add(inst)
	GameState.guild.register(_make_character())
	var menu := EscMenu.new()
	add_child_autofree(menu)
	watch_signals(menu)
	_open_items_view(menu)
	menu._items_index = 0
	menu.select_current_item()  # → confirm
	menu._item_use_confirm_index = 0  # はい
	menu.select_current_item()
	assert_signal_emitted(menu, "return_to_town_requested")
	assert_false(GameState.inventory.contains(inst))
	assert_false(menu.is_menu_visible())


func test_confirm_no_on_escape_scroll_keeps_instance():
	var scroll := _make_escape_scroll()
	var inst := ItemInstance.new(scroll, true)
	GameState.inventory.add(inst)
	GameState.guild.register(_make_character())
	var menu := EscMenu.new()
	add_child_autofree(menu)
	watch_signals(menu)
	_open_items_view(menu)
	menu._items_index = 0
	menu.select_current_item()  # → confirm
	menu._item_use_confirm_index = 1  # いいえ
	menu.select_current_item()
	assert_signal_not_emitted(menu, "return_to_town_requested")
	assert_true(GameState.inventory.contains(inst))
	assert_eq(menu.get_current_view(), EscMenu.View.ITEMS)


# --- context failure ---

func test_escape_scroll_in_town_cannot_be_used():
	GameState.game_location = GameState.LOCATION_TOWN
	var scroll := _make_escape_scroll()
	var inst := ItemInstance.new(scroll, true)
	GameState.inventory.add(inst)
	GameState.guild.register(_make_character())
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_items_view(menu)
	menu._items_index = 0
	menu.select_current_item()  # should NOT switch to confirm/target
	assert_eq(menu.get_current_view(), EscMenu.View.ITEMS)
	assert_true(GameState.inventory.contains(inst))


# --- non-consumable ignored ---

func test_select_sword_does_nothing():
	var sword := _make_sword()
	var inst := ItemInstance.new(sword, true)
	GameState.inventory.add(inst)
	GameState.guild.register(_make_character())
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_items_view(menu)
	menu._items_index = 0
	menu.select_current_item()
	assert_eq(menu.get_current_view(), EscMenu.View.ITEMS)
	assert_true(GameState.inventory.contains(inst))


# --- target condition: full-HP character ---

func test_full_hp_target_is_blocked_with_message():
	var potion := _make_potion()
	GameState.inventory.add(ItemInstance.new(potion, true))
	GameState.guild.register(_make_character("Full", 40, 40))
	var menu := EscMenu.new()
	add_child_autofree(menu)
	_open_items_view(menu)
	menu._items_index = 0
	menu.select_current_item()  # → target view
	# first valid target index should have fallen through to 0 since no valid targets;
	# attempting to confirm should not heal
	var before: int = (GameState.guild.get_all_characters()[0] as Character).current_hp
	menu._item_use_target_index = 0
	menu.select_current_item()
	var after: int = (GameState.guild.get_all_characters()[0] as Character).current_hp
	assert_eq(before, after)
