extends GutTest


# CombatLog renders status TurnReport actions as one human-readable line each.
# StatusRepository is loaded lazily so display names match shipped data
# (sleep → "睡眠", silence → "沈黙").

func _add_log() -> CombatLog:
	var log := CombatLog.new()
	add_child_autofree(log)
	return log


func test_tick_damage_entry_renders_with_status_display():
	var log := _add_log()
	log.append_from_report_action({
		"type": "tick_damage",
		"actor_name": "Alice",
		"status_id": &"sleep",
		"amount": 2,
		"killed_by_tick": false,
	})
	var text := log.get_display_text()
	assert_true(text.contains("Alice"), "log: %s" % text)
	assert_true(text.contains("睡眠"), "log should use sleep display name: %s" % text)
	assert_true(text.contains("2"), "log should show damage amount: %s" % text)


func test_wake_entry_renders_wake_message():
	var log := _add_log()
	log.append_from_report_action({
		"type": "wake",
		"actor_name": "Slime",
		"status_id": &"sleep",
	})
	var text := log.get_display_text()
	assert_true(text.contains("Slime"))
	assert_true(text.contains("目を覚ました"), "log: %s" % text)


func test_inflict_entry_renders_with_status_display():
	var log := _add_log()
	log.append_from_report_action({
		"type": "inflict",
		"target_name": "Slime",
		"status_id": &"silence",
		"success": true,
	})
	var text := log.get_display_text()
	assert_true(text.contains("Slime"))
	assert_true(text.contains("沈黙"), "log: %s" % text)


func test_cure_entry_renders_with_status_display():
	var log := _add_log()
	log.append_from_report_action({
		"type": "cure",
		"actor_name": "Alice",
		"status_id": &"sleep",
	})
	var text := log.get_display_text()
	assert_true(text.contains("Alice"))
	assert_true(text.contains("睡眠"), "log: %s" % text)
	assert_true(text.contains("治った"), "log: %s" % text)


func test_resist_entry_renders_with_status_display():
	var log := _add_log()
	log.append_from_report_action({
		"type": "resist",
		"target_name": "Slime",
		"status_id": &"sleep",
	})
	var text := log.get_display_text()
	assert_true(text.contains("Slime"))
	assert_true(text.contains("睡眠"), "log: %s" % text)
	assert_true(text.contains("抵抗"), "log: %s" % text)


func test_action_locked_entry_renders_non_empty_line():
	var log := _add_log()
	log.append_from_report_action({
		"type": "action_locked",
		"actor_name": "Alice",
	})
	var text := log.get_display_text()
	assert_true(text.contains("Alice"))
	assert_true(text.contains("行動できない"), "log: %s" % text)


func test_cast_silenced_entry_names_caster():
	var log := _add_log()
	log.append_from_report_action({
		"type": "cast_silenced",
		"caster_name": "Alice",
		"spell_id": &"katino",
	})
	var text := log.get_display_text()
	assert_true(text.contains("Alice"))
	assert_true(text.contains("声が出ない"), "log: %s" % text)


func test_unknown_status_id_falls_back_to_string_form():
	var log := _add_log()
	log.append_from_report_action({
		"type": "inflict",
		"target_name": "Goblin",
		"status_id": &"unknown_xyz",
		"success": true,
	})
	var text := log.get_display_text()
	assert_true(text.contains("Goblin"))
	assert_true(text.contains("unknown_xyz"),
		"unknown status_id should fall back to its string form: %s" % text)


func test_stat_mod_entry_renders_signed_delta():
	var log := _add_log()
	log.append_from_report_action({
		"type": "stat_mod",
		"target_name": "Alice",
		"stat": &"AGI",
		"delta": -2,
		"turns": 3,
	})
	var text := log.get_display_text()
	assert_true(text.contains("Alice"))
	# allow either the stat key or a Japanese label — at minimum delta must appear.
	assert_true(text.contains("2"), "log should mention delta magnitude: %s" % text)
