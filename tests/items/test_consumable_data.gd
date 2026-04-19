extends GutTest


var _repo: ItemRepository


func before_all():
	_repo = DataLoader.new().load_all_items()


func test_potion_is_loaded():
	var potion := _repo.find(&"potion")
	assert_not_null(potion)
	assert_eq(potion.category, Item.ItemCategory.CONSUMABLE)
	assert_eq(potion.equip_slot, Item.EquipSlot.NONE)
	assert_eq(potion.price, 50)


func test_potion_has_heal_hp_effect():
	var potion := _repo.find(&"potion")
	assert_is(potion.effect, HealHpEffect)
	assert_eq((potion.effect as HealHpEffect).power, 20)


func test_potion_has_alive_and_not_full_hp_conditions():
	var potion := _repo.find(&"potion")
	assert_eq(potion.target_conditions.size(), 2)
	assert_eq(potion.context_conditions.size(), 0)


func test_magic_potion_is_loaded():
	var mp := _repo.find(&"magic_potion")
	assert_not_null(mp)
	assert_eq(mp.category, Item.ItemCategory.CONSUMABLE)
	assert_eq(mp.price, 200)


func test_magic_potion_has_heal_mp_effect():
	var mp := _repo.find(&"magic_potion")
	assert_is(mp.effect, HealMpEffect)
	assert_eq((mp.effect as HealMpEffect).power, 10)


func test_magic_potion_has_three_target_conditions():
	var mp := _repo.find(&"magic_potion")
	assert_eq(mp.target_conditions.size(), 3)


func test_escape_scroll_is_loaded():
	var es := _repo.find(&"escape_scroll")
	assert_not_null(es)
	assert_eq(es.category, Item.ItemCategory.CONSUMABLE)
	assert_eq(es.price, 500)


func test_escape_scroll_has_escape_effect():
	var es := _repo.find(&"escape_scroll")
	assert_is(es.effect, EscapeToTownEffect)


func test_escape_scroll_has_both_context_conditions():
	var es := _repo.find(&"escape_scroll")
	assert_eq(es.context_conditions.size(), 2)
	assert_eq(es.target_conditions.size(), 0)


func test_emergency_escape_scroll_is_loaded():
	var ee := _repo.find(&"emergency_escape_scroll")
	assert_not_null(ee)
	assert_eq(ee.category, Item.ItemCategory.CONSUMABLE)
	assert_eq(ee.price, 2000)


func test_emergency_escape_scroll_has_escape_effect():
	var ee := _repo.find(&"emergency_escape_scroll")
	assert_is(ee.effect, EscapeToTownEffect)


func test_emergency_escape_scroll_has_only_in_dungeon_context():
	var ee := _repo.find(&"emergency_escape_scroll")
	# Only InDungeonOnly, not NotInCombatOnly
	assert_eq(ee.context_conditions.size(), 1)
	var has_in_dungeon := false
	var has_not_in_combat := false
	for c in ee.context_conditions:
		if c is InDungeonOnly:
			has_in_dungeon = true
		if c is NotInCombatOnly:
			has_not_in_combat = true
	assert_true(has_in_dungeon)
	assert_false(has_not_in_combat)


func test_escape_scroll_includes_not_in_combat_only():
	var es := _repo.find(&"escape_scroll")
	var has_not_in_combat := false
	for c in es.context_conditions:
		if c is NotInCombatOnly:
			has_not_in_combat = true
	assert_true(has_not_in_combat)


func test_equipment_items_still_load():
	var sword := _repo.find(&"long_sword")
	assert_not_null(sword)
	assert_eq(sword.category, Item.ItemCategory.WEAPON)
	assert_null(sword.effect)
	assert_eq(sword.context_conditions.size(), 0)
	assert_eq(sword.target_conditions.size(), 0)
