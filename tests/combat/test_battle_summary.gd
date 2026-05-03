extends GutTest


func test_battle_summary_keeps_values():
	var level_ups := [{"name": "P1", "new_level": 2}]
	var summary := BattleSummary.new(12, 34, level_ups)
	assert_eq(summary.gained_experience, 12)
	assert_eq(summary.gained_gold, 34)
	assert_eq(summary.level_ups, level_ups)


func test_empty_returns_zero_values():
	var summary := BattleSummary.empty()
	assert_eq(summary.gained_experience, 0)
	assert_eq(summary.gained_gold, 0)
	assert_eq(summary.level_ups, [])
