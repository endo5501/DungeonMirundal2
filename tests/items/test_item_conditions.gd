extends GutTest


class _StubCharacter:
	extends RefCounted
	var current_hp: int = 10
	var max_hp: int = 40
	var current_mp: int = 0
	var max_mp: int = 0

	func is_dead() -> bool:
		return current_hp <= 0


func _alive(hp: int = 10, max_h: int = 40, mp: int = 0, max_m: int = 0) -> _StubCharacter:
	var c := _StubCharacter.new()
	c.current_hp = hp
	c.max_hp = max_h
	c.current_mp = mp
	c.max_mp = max_m
	return c


# --- InDungeonOnly ---

func test_in_dungeon_only_satisfied_when_in_dungeon():
	var cond := InDungeonOnly.new()
	var ctx := ItemUseContext.make(true, false)
	assert_true(cond.is_satisfied(ctx))


func test_in_dungeon_only_not_satisfied_in_town():
	var cond := InDungeonOnly.new()
	var ctx := ItemUseContext.make(false, false)
	assert_false(cond.is_satisfied(ctx))


func test_in_dungeon_only_has_reason():
	var cond := InDungeonOnly.new()
	assert_true(cond.reason().length() > 0)


# --- NotInCombatOnly ---

func test_not_in_combat_only_satisfied_out_of_combat():
	var cond := NotInCombatOnly.new()
	var ctx := ItemUseContext.make(true, false)
	assert_true(cond.is_satisfied(ctx))


func test_not_in_combat_only_not_satisfied_in_combat():
	var cond := NotInCombatOnly.new()
	var ctx := ItemUseContext.make(true, true)
	assert_false(cond.is_satisfied(ctx))


func test_not_in_combat_only_has_reason():
	var cond := NotInCombatOnly.new()
	assert_true(cond.reason().length() > 0)


# --- AliveOnly ---

func test_alive_only_satisfied_when_alive():
	var cond := AliveOnly.new()
	var target := _alive(10, 40)
	assert_true(cond.is_satisfied(target, null))


func test_alive_only_not_satisfied_when_dead():
	var cond := AliveOnly.new()
	var target := _alive(0, 40)
	assert_false(cond.is_satisfied(target, null))


func test_alive_only_not_satisfied_for_null():
	var cond := AliveOnly.new()
	assert_false(cond.is_satisfied(null, null))


# --- NotFullHp ---

func test_not_full_hp_satisfied_when_wounded():
	var cond := NotFullHp.new()
	var target := _alive(10, 40)
	assert_true(cond.is_satisfied(target, null))


func test_not_full_hp_not_satisfied_when_full():
	var cond := NotFullHp.new()
	var target := _alive(40, 40)
	assert_false(cond.is_satisfied(target, null))


# --- NotFullMp ---

func test_not_full_mp_satisfied_when_mp_low():
	var cond := NotFullMp.new()
	var target := _alive(40, 40, 5, 30)
	assert_true(cond.is_satisfied(target, null))


func test_not_full_mp_not_satisfied_when_mp_full():
	var cond := NotFullMp.new()
	var target := _alive(40, 40, 30, 30)
	assert_false(cond.is_satisfied(target, null))


func test_not_full_mp_not_satisfied_when_no_mp_slot():
	var cond := NotFullMp.new()
	var target := _alive(40, 40, 0, 0)
	assert_false(cond.is_satisfied(target, null))


# --- HasMpSlot ---

func test_has_mp_slot_satisfied_for_caster():
	var cond := HasMpSlot.new()
	var target := _alive(40, 40, 10, 30)
	assert_true(cond.is_satisfied(target, null))


func test_has_mp_slot_not_satisfied_for_fighter():
	var cond := HasMpSlot.new()
	var target := _alive(40, 40, 0, 0)
	assert_false(cond.is_satisfied(target, null))


# --- ItemUseContext factory ---

func test_item_use_context_make_sets_fields():
	var party := ["a", "b"]
	var ctx := ItemUseContext.make(true, true, party)
	assert_true(ctx.is_in_dungeon)
	assert_true(ctx.is_in_combat)
	assert_eq(ctx.party.size(), 2)


func test_item_use_context_party_is_defensive_copy():
	var party := ["a"]
	var ctx := ItemUseContext.make(true, false, party)
	party.append("b")
	assert_eq(ctx.party.size(), 1)
