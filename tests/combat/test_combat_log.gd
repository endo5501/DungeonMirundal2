extends GutTest


func test_miss_action_renders_dodge_message():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "miss",
		"attacker_name": "P1",
		"target_name": "Slime",
	})
	var text := log.get_display_text()
	assert_true(text.length() > 0, "miss action should render a non-empty line")
	assert_true(text.contains("P1"), "log should name the attacker: %s" % text)
	assert_true(text.contains("Slime"), "log should name the target: %s" % text)


func test_retargeted_attack_log_mentions_original_and_new_target():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "attack",
		"attacker_name": "P1",
		"target_name": "Slime B",
		"damage": 8,
		"defended": false,
		"retargeted_from": "Slime A",
	})
	var text := log.get_display_text()
	assert_true(text.contains("Slime A"), "log should mention original target: %s" % text)
	assert_true(text.contains("Slime B"), "log should mention new target: %s" % text)


# --- add-magic-system: cast log entries ---

func test_cast_damage_entry_includes_caster_spell_target_and_damage():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "cast",
		"caster_name": "Alice",
		"spell_id": &"fire",
		"spell_display_name": "ファイア",
		"entries": [{"actor_name": "スライム", "hp_delta": -7}],
		"retargeted_from": "",
	})
	var text := log.get_display_text()
	assert_true(text.contains("Alice"), "log: %s" % text)
	assert_true(text.contains("ファイア"), "log: %s" % text)
	assert_true(text.contains("スライム"), "log: %s" % text)
	assert_true(text.contains("7"), "log: %s" % text)


func test_cast_group_entry_includes_each_target_delta():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "cast",
		"caster_name": "Alice",
		"spell_id": &"flame",
		"spell_display_name": "フレイム",
		"entries": [
			{"actor_name": "スライムA", "hp_delta": -5},
			{"actor_name": "スライムB", "hp_delta": -4},
		],
		"retargeted_from": "",
	})
	var text := log.get_display_text()
	assert_true(text.contains("スライムA"))
	assert_true(text.contains("スライムB"))
	assert_true(text.contains("5"))
	assert_true(text.contains("4"))


func test_cast_heal_entry_shows_positive_delta():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "cast",
		"caster_name": "Bob",
		"spell_id": &"heal",
		"spell_display_name": "ヒール",
		"entries": [{"actor_name": "Alice", "hp_delta": 6}],
		"retargeted_from": "",
	})
	var text := log.get_display_text()
	assert_true(text.contains("Bob"))
	assert_true(text.contains("ヒール"))
	assert_true(text.contains("Alice"))
	assert_true(text.contains("6"))


func test_cast_skipped_no_mp_entry_explains_reason():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "cast_skipped_no_mp",
		"caster_name": "Alice",
		"spell_id": &"fire",
		"spell_display_name": "ファイア",
	})
	var text := log.get_display_text()
	assert_true(text.contains("Alice"))
	assert_true(text.contains("ファイア"))
	assert_true(text.contains("MP"))


func test_cast_skipped_no_target_entry():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "cast_skipped_no_target",
		"caster_name": "Alice",
		"spell_id": &"fire",
		"spell_display_name": "ファイア",
	})
	var text := log.get_display_text()
	assert_true(text.contains("Alice"))
	assert_true(text.contains("ファイア"))
