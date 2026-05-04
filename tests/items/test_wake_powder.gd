extends GutTest


# wake_powder ships with add-status-sleep-and-silence: a consumable that strips
# &"sleep" from a single ally. These tests exercise the resource the way the
# game will use it (load → effect.apply on a sleeping target / clean target).

const WAKE_POWDER_PATH := "res://data/items/wake_powder.tres"


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


func test_wake_powder_loads_as_item():
	var item := load(WAKE_POWDER_PATH) as Item
	assert_not_null(item, "wake_powder.tres should load as Item")
	assert_eq(item.item_id, &"wake_powder")
	assert_eq(item.item_name, "覚醒の粉")
	assert_eq(item.category, Item.ItemCategory.CONSUMABLE)
	assert_true(item.is_consumable())


func test_wake_powder_effect_is_cure_sleep():
	var item := load(WAKE_POWDER_PATH) as Item
	assert_is(item.effect, CureStatusItemEffect, "wake_powder effect should be CureStatusItemEffect")
	var eff := item.effect as CureStatusItemEffect
	assert_eq(eff.status_id, &"sleep")


func test_wake_powder_target_conditions_include_alive_only():
	var item := load(WAKE_POWDER_PATH) as Item
	assert_eq(item.target_conditions.size(), 1)
	assert_is(item.target_conditions[0], AliveOnly,
		"wake_powder should require alive_only on target")


func test_wake_powder_cures_sleeping_combat_actor():
	var item := load(WAKE_POWDER_PATH) as Item
	var actor := _FakeActor.new("Alice")
	actor.statuses.apply(&"sleep", 3)
	var result: ItemEffectResult = item.effect.apply([actor], null)
	assert_true(result.success, "should cure sleep on the target")
	assert_false(actor.statuses.has(&"sleep"))


func test_wake_powder_on_clean_target_fails():
	var item := load(WAKE_POWDER_PATH) as Item
	var actor := _FakeActor.new("Bob")
	# No sleep applied.
	var result: ItemEffectResult = item.effect.apply([actor], null)
	assert_false(result.success, "use on a target without sleep should fail (no consumption)")
