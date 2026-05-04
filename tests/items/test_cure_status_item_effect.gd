extends GutTest


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


# A duck-typed Character substitute exposing persistent_statuses + is_alive.
class _FakeCharacter extends RefCounted:
	var persistent_statuses: Array[StringName] = []
	var current_hp: int = 10
	var max_hp: int = 10

	func is_dead() -> bool:
		return current_hp <= 0

	func is_alive() -> bool:
		return current_hp > 0


# --- structure ---

func test_effect_extends_item_effect():
	var e := CureStatusItemEffect.new()
	assert_is(e, ItemEffect)


# --- battle context: cures from PartyCombatant.statuses ---

func test_cures_from_combat_actor_status_track():
	var e := CureStatusItemEffect.new()
	e.status_id = &"poison"
	var target := _FakeActor.new("Alice")
	target.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var result: ItemEffectResult = e.apply([target], null)
	assert_true(result.success)
	assert_false(target.statuses.has(&"poison"))


# --- out-of-battle context: cures from Character.persistent_statuses ---

func test_cures_from_character_persistent_statuses():
	var e := CureStatusItemEffect.new()
	e.status_id = &"poison"
	var ch := _FakeCharacter.new()
	ch.persistent_statuses = [&"poison", &"petrify"]
	var result: ItemEffectResult = e.apply([ch], null)
	assert_true(result.success)
	assert_false(ch.persistent_statuses.has(&"poison"))
	assert_true(ch.persistent_statuses.has(&"petrify"))


# --- clean target fails ---

func test_clean_target_fails():
	var e := CureStatusItemEffect.new()
	e.status_id = &"poison"
	var target := _FakeActor.new("Bob")
	var result: ItemEffectResult = e.apply([target], null)
	assert_false(result.success)


# --- empty targets fails ---

func test_empty_targets_fails():
	var e := CureStatusItemEffect.new()
	e.status_id = &"poison"
	var result: ItemEffectResult = e.apply([], null)
	assert_false(result.success)
