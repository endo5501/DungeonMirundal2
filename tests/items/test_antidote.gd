extends GutTest


# antidote ships with add-status-poison-and-petrify: a consumable that strips
# &"poison" from a single ally (CombatActor in battle, Character outside).

const ANTIDOTE_PATH := "res://data/items/antidote.tres"


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


func _make_character(name: String) -> Character:
	var human := load("res://data/races/human.tres") as RaceData
	var fighter := load("res://data/jobs/fighter.tres") as JobData
	var ch := Character.new()
	ch.character_name = name
	ch.race = human
	ch.job = fighter
	ch.level = 1
	ch.base_stats = {&"STR": 8, &"INT": 8, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	ch.max_hp = 10
	ch.current_hp = 10
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


func test_antidote_loads_as_item():
	var item := load(ANTIDOTE_PATH) as Item
	assert_not_null(item, "antidote.tres should load as Item")
	assert_eq(item.item_id, &"antidote")
	assert_eq(item.item_name, "解毒草")
	assert_eq(item.category, Item.ItemCategory.CONSUMABLE)
	assert_true(item.is_consumable())
	assert_eq(item.price, 100)


func test_antidote_effect_is_cure_poison():
	var item := load(ANTIDOTE_PATH) as Item
	assert_is(item.effect, CureStatusItemEffect, "antidote effect should be CureStatusItemEffect")
	var eff := item.effect as CureStatusItemEffect
	assert_eq(eff.status_id, &"poison")


func test_antidote_target_conditions_include_alive_only():
	var item := load(ANTIDOTE_PATH) as Item
	assert_eq(item.target_conditions.size(), 1)
	assert_is(item.target_conditions[0], AliveOnly, "antidote should require alive_only")


func test_antidote_cures_poisoned_combat_actor():
	var item := load(ANTIDOTE_PATH) as Item
	var actor := _FakeActor.new("Alice")
	actor.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var result: ItemEffectResult = item.effect.apply([actor], null)
	assert_true(result.success)
	assert_false(actor.statuses.has(&"poison"))


func test_antidote_cures_poisoned_character_persistent_statuses():
	var item := load(ANTIDOTE_PATH) as Item
	var ch := _make_character("Bob")
	ch.persistent_statuses = [&"poison"]
	var result: ItemEffectResult = item.effect.apply([ch], null)
	assert_true(result.success)
	assert_false(ch.persistent_statuses.has(&"poison"))


func test_antidote_on_clean_target_fails():
	var item := load(ANTIDOTE_PATH) as Item
	var actor := _FakeActor.new("Carol")
	var result: ItemEffectResult = item.effect.apply([actor], null)
	assert_false(result.success, "use on a target without poison should fail")
