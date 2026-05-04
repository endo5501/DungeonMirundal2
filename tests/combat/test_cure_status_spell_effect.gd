extends GutTest


class _FakeActor extends CombatActor:
	var _hp: int = 10
	var _max: int = 10

	func _init() -> void:
		actor_name = "Fake"

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


# --- structure ---

func test_effect_extends_spell_effect():
	var e := CureStatusSpellEffect.new()
	assert_is(e, SpellEffect)


# --- cure success ---

func test_cure_emits_event_when_status_was_present():
	var e := CureStatusSpellEffect.new()
	e.status_id = &"poison"
	var target := _FakeActor.new()
	target.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var res := e.apply(null, [target], null)
	assert_eq(res.size(), 1)
	var entry: Dictionary = res.entries[0]
	assert_eq(entry["hp_delta"], 0)
	var events: Array = entry["events"]
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "cure")
	assert_eq(events[0]["status_id"], &"poison")
	assert_false(target.statuses.has(&"poison"))


# --- clean target is no-op ---

func test_cure_on_clean_target_emits_no_event():
	var e := CureStatusSpellEffect.new()
	e.status_id = &"poison"
	var target := _FakeActor.new()
	var res := e.apply(null, [target], null)
	assert_eq(res.size(), 1)
	var entry: Dictionary = res.entries[0]
	# An entry IS produced (per add_entry) but its events list stays empty.
	assert_eq((entry["events"] as Array).size(), 0)
