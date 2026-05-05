extends GutTest


# holy_water ships with add-status-confusion-blind-paralysis: a consumable that
# strips every status from a single ally (CombatActor in battle, Character outside).

const HOLY_WATER_PATH := "res://data/items/holy_water.tres"


class _FakeActor extends CombatActor:
	var _hp: int = 10
	var _max: int = 10

	func _init(p_name: String = "Fake") -> void:
		actor_name = p_name

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


func _make_status(id: StringName, scope: int) -> StatusData:
	var s := StatusData.new()
	s.id = id
	s.display_name = String(id)
	s.scope = scope
	return s


func _make_repo() -> StatusRepository:
	var repo := StatusRepository.new()
	repo.register(_make_status(&"sleep", StatusData.Scope.BATTLE_ONLY))
	repo.register(_make_status(&"silence", StatusData.Scope.BATTLE_ONLY))
	repo.register(_make_status(&"poison", StatusData.Scope.PERSISTENT))
	repo.register(_make_status(&"petrify", StatusData.Scope.PERSISTENT))
	repo.register(_make_status(&"confusion", StatusData.Scope.BATTLE_ONLY))
	repo.register(_make_status(&"blind", StatusData.Scope.BATTLE_ONLY))
	repo.register(_make_status(&"paralysis", StatusData.Scope.BATTLE_ONLY))
	return repo


func test_holy_water_loads_as_item():
	var item := load(HOLY_WATER_PATH) as Item
	assert_not_null(item, "holy_water.tres should load as Item")
	assert_eq(item.item_id, &"holy_water")
	assert_eq(item.item_name, "聖水")
	assert_eq(item.category, Item.ItemCategory.CONSUMABLE)
	assert_true(item.is_consumable())
	assert_eq(item.price, 600)


func test_holy_water_effect_is_cure_all_with_scope_all():
	var item := load(HOLY_WATER_PATH) as Item
	assert_is(item.effect, CureAllStatusItemEffect, "holy_water effect should be CureAllStatusItemEffect")
	var eff := item.effect as CureAllStatusItemEffect
	assert_eq(eff.scope, CureAllStatusItemEffect.SCOPE_ALL)


func test_holy_water_target_conditions_include_alive_only():
	var item := load(HOLY_WATER_PATH) as Item
	assert_eq(item.target_conditions.size(), 1)
	assert_is(item.target_conditions[0], AliveOnly, "holy_water should require alive_only")


func test_holy_water_cures_every_status_simultaneously():
	var item := load(HOLY_WATER_PATH) as Item
	var eff := item.effect as CureAllStatusItemEffect
	eff.set_status_repo_for_testing(_make_repo())
	var actor := _FakeActor.new("Alice")
	actor.statuses.apply(&"sleep", 3)
	actor.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	actor.statuses.apply(&"blind", 4)
	var result: ItemEffectResult = eff.apply([actor], null)
	assert_true(result.success)
	assert_false(actor.statuses.has(&"sleep"))
	assert_false(actor.statuses.has(&"poison"))
	assert_false(actor.statuses.has(&"blind"))


func test_holy_water_on_clean_target_fails():
	var item := load(HOLY_WATER_PATH) as Item
	var eff := item.effect as CureAllStatusItemEffect
	eff.set_status_repo_for_testing(_make_repo())
	var actor := _FakeActor.new("Bob")
	var result: ItemEffectResult = eff.apply([actor], null)
	assert_false(result.success, "use on a target without any status should fail")
