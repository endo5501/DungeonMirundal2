extends GutTest


class _StubCharacter:
	extends RefCounted
	var current_hp: int = 10
	var max_hp: int = 40
	var current_mp: int = 0
	var max_mp: int = 0

	func is_dead() -> bool:
		return current_hp <= 0


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


func _alive(hp: int = 10, max_h: int = 40) -> _StubCharacter:
	var c := _StubCharacter.new()
	c.current_hp = hp
	c.max_hp = max_h
	return c


# --- Success path ---

func test_use_item_consumes_on_success():
	var inv := Inventory.new()
	var inst := ItemInstance.new(_make_potion(), true)
	inv.add(inst)
	var target := _alive(10, 40)
	var ctx := ItemUseContext.make(true, false)
	var result: ItemEffectResult = inv.use_item(inst, [target], ctx)
	assert_true(result.success)
	assert_false(inv.contains(inst))


func test_use_item_applies_heal():
	var inv := Inventory.new()
	var inst := ItemInstance.new(_make_potion(), true)
	inv.add(inst)
	var target := _alive(10, 40)
	inv.use_item(inst, [target], ItemUseContext.make(true, false))
	assert_eq(target.current_hp, 30)


# --- Context failure ---

func test_context_failure_preserves_instance():
	var inv := Inventory.new()
	var inst := ItemInstance.new(_make_escape_scroll(), true)
	inv.add(inst)
	var ctx := ItemUseContext.make(false, false)  # not in dungeon
	var result: ItemEffectResult = inv.use_item(inst, [], ctx)
	assert_false(result.success)
	assert_true(inv.contains(inst))


func test_context_failure_returns_reason():
	var inv := Inventory.new()
	var inst := ItemInstance.new(_make_escape_scroll(), true)
	inv.add(inst)
	var ctx := ItemUseContext.make(false, false)
	var result: ItemEffectResult = inv.use_item(inst, [], ctx)
	assert_true(result.message.length() > 0)


# --- Target failure ---

func test_target_failure_preserves_instance():
	var inv := Inventory.new()
	var inst := ItemInstance.new(_make_potion(), true)
	inv.add(inst)
	var target := _alive(40, 40)  # full HP
	var result: ItemEffectResult = inv.use_item(inst, [target], ItemUseContext.make(true, false))
	assert_false(result.success)
	assert_true(inv.contains(inst))


func test_target_failure_does_not_modify_target():
	var inv := Inventory.new()
	var inst := ItemInstance.new(_make_potion(), true)
	inv.add(inst)
	var target := _alive(40, 40)
	inv.use_item(inst, [target], ItemUseContext.make(true, false))
	assert_eq(target.current_hp, 40)


# --- Missing instance ---

func test_unknown_instance_fails_without_side_effects():
	var inv := Inventory.new()
	var other := ItemInstance.new(_make_potion(), true)
	# not added
	var result: ItemEffectResult = inv.use_item(other, [], ItemUseContext.make(true, false))
	assert_false(result.success)
	assert_eq(inv.list().size(), 0)


# --- No-target consumable ---

func test_no_target_consumable_works():
	var inv := Inventory.new()
	var inst := ItemInstance.new(_make_escape_scroll(), true)
	inv.add(inst)
	var result: ItemEffectResult = inv.use_item(inst, [], ItemUseContext.make(true, false))
	assert_true(result.success)
	assert_true(result.request_town_return)
	assert_false(inv.contains(inst))
