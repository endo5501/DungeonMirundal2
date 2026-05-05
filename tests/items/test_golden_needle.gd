extends GutTest


# golden_needle ships with add-status-poison-and-petrify: a rare consumable that
# strips &"petrify" from a single ally.

const NEEDLE_PATH := "res://data/items/golden_needle.tres"


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


func test_golden_needle_loads_as_item():
	var item := load(NEEDLE_PATH) as Item
	assert_not_null(item, "golden_needle.tres should load as Item")
	assert_eq(item.item_id, &"golden_needle")
	assert_eq(item.item_name, "金の針")
	assert_eq(item.category, Item.ItemCategory.CONSUMABLE)
	assert_true(item.is_consumable())
	assert_eq(item.price, 1500)


func test_golden_needle_effect_is_cure_petrify():
	var item := load(NEEDLE_PATH) as Item
	assert_is(item.effect, CureStatusItemEffect, "golden_needle effect should be CureStatusItemEffect")
	var eff := item.effect as CureStatusItemEffect
	assert_eq(eff.status_id, &"petrify")


func test_golden_needle_target_conditions_include_alive_only():
	var item := load(NEEDLE_PATH) as Item
	assert_eq(item.target_conditions.size(), 1)
	assert_is(item.target_conditions[0], AliveOnly,
		"golden_needle should require alive_only")


func test_golden_needle_cures_petrified_character():
	var item := load(NEEDLE_PATH) as Item
	var ch := _make_character("Stoned")
	ch.persistent_statuses = [&"petrify"]
	var result: ItemEffectResult = item.effect.apply([ch], null)
	assert_true(result.success)
	assert_false(ch.persistent_statuses.has(&"petrify"))


func test_golden_needle_on_clean_target_fails():
	var item := load(NEEDLE_PATH) as Item
	var ch := _make_character("Free")
	var result: ItemEffectResult = item.effect.apply([ch], null)
	assert_false(result.success)
