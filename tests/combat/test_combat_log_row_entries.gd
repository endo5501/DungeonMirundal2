extends GutTest


func test_wait_action_renders_observation_message():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "wait",
		"actor_name": "Bat",
	})
	var lines := log.get_lines()
	assert_eq(lines.size(), 1)
	assert_string_contains(lines[0], "Bat")
	assert_string_contains(lines[0], "様子を見ている")


func test_attack_unreachable_action_renders_with_both_names():
	var log := CombatLog.new()
	add_child_autofree(log)
	log.append_from_report_action({
		"type": "attack_unreachable",
		"attacker_name": "Bob",
		"target_name": "Witch",
	})
	var lines := log.get_lines()
	assert_eq(lines.size(), 1)
	assert_string_contains(lines[0], "Bob")
	assert_string_contains(lines[0], "Witch")
	assert_string_contains(lines[0], "届かなかった")
