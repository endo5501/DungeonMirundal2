extends GutTest


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
