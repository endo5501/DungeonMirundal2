extends GutTest


func test_combat_log_keeps_enough_lines_for_tall_window():
	assert_eq(CombatLog.MAX_LINES, 8,
		"CombatLog should retain eight lines to fit the compact battle log window without overlapping commands")


func test_combat_log_clips_lines_to_its_window():
	var log := CombatLog.new()
	add_child_autofree(log)
	await get_tree().process_frame
	assert_true(log.clip_contents,
		"CombatLog should clip content so retained lines cannot draw over the command window")


func test_combat_log_splits_multiline_actions_into_display_lines():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_line("A\nB\nC")
	assert_eq(log.get_lines(), ["A", "B", "C"],
		"multi-line log text should be retained as visible display lines")


func test_combat_log_retains_eight_visible_lines_after_multiline_actions():
	var log := CombatLog.new()
	add_child_autofree(log)
	for i in range(4):
		log.append_line("Action%d-1\nAction%d-2\nAction%d-3" % [i, i, i])
	var lines := log.get_lines()
	assert_eq(lines.size(), CombatLog.MAX_LINES,
		"CombatLog should cap retained visible lines, not just action entries")
	for line in lines:
		assert_false((line as String).contains("\n"),
			"retained lines should not contain embedded newlines: %s" % line)
	assert_eq(lines[0], "Action1-2")
	assert_eq(lines[-1], "Action3-3")


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


# --- add-status-confusion-blind-paralysis: confusion_swap rendering ---

func test_confused_attack_includes_confusion_annotation():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "attack",
		"attacker_name": "Alice",
		"target_name": "Bob",
		"damage": 4,
		"defended": false,
		"retargeted_from": "",
		"confusion_swap": true,
	})
	var text := log.get_display_text()
	assert_true(text.contains("Alice"), "log should name attacker: %s" % text)
	assert_true(text.contains("Bob"), "log should name target: %s" % text)
	assert_true(text.contains("4"), "log should show damage: %s" % text)
	assert_true(text.contains("混乱"), "log should annotate confusion: %s" % text)


func test_confused_miss_includes_confusion_annotation():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "miss",
		"attacker_name": "Alice",
		"target_name": "Bob",
		"confusion_swap": true,
	})
	var text := log.get_display_text()
	assert_true(text.contains("Alice"), "log should name attacker: %s" % text)
	assert_true(text.contains("Bob"), "log should name target: %s" % text)
	assert_true(text.contains("外れた") or text.contains("身をかわした"),
		"log should describe a missed attack: %s" % text)
	assert_true(text.contains("混乱"), "log should annotate confusion: %s" % text)


func test_non_confused_attack_renders_without_confusion_annotation():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "attack",
		"attacker_name": "Alice",
		"target_name": "Slime",
		"damage": 3,
		"defended": false,
		"retargeted_from": "",
		"confusion_swap": false,
	})
	var text := log.get_display_text()
	assert_false(text.contains("混乱"), "non-confused attack should not annotate confusion: %s" % text)


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
