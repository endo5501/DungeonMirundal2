extends GutTest

# StatusData is a Custom Resource describing a status effect template.
# Tests verify the field surface and enum values.


func test_status_data_is_resource():
	var s := StatusData.new()
	assert_true(s is Resource)


func test_status_data_default_id_is_empty_string_name():
	var s := StatusData.new()
	assert_eq(s.id, &"")
	assert_typeof(s.id, TYPE_STRING_NAME)


func test_status_data_id_is_writable():
	var s := StatusData.new()
	s.id = &"poison"
	assert_eq(s.id, &"poison")


func test_status_data_default_display_name_is_empty():
	var s := StatusData.new()
	assert_eq(s.display_name, "")


func test_status_data_display_name_is_writable():
	var s := StatusData.new()
	s.display_name = "毒"
	assert_eq(s.display_name, "毒")


func test_status_data_scope_enum_values():
	assert_eq(StatusData.Scope.BATTLE_ONLY, 0)
	assert_eq(StatusData.Scope.PERSISTENT, 1)


func test_status_data_default_scope_is_battle_only():
	var s := StatusData.new()
	assert_eq(s.scope, StatusData.Scope.BATTLE_ONLY)


func test_status_data_scope_is_writable():
	var s := StatusData.new()
	s.scope = StatusData.Scope.PERSISTENT
	assert_eq(s.scope, StatusData.Scope.PERSISTENT)


func test_status_data_default_prevents_action_is_false():
	var s := StatusData.new()
	assert_false(s.prevents_action)


func test_status_data_prevents_action_is_writable():
	var s := StatusData.new()
	s.prevents_action = true
	assert_true(s.prevents_action)


func test_status_data_default_randomizes_target_is_false():
	var s := StatusData.new()
	assert_false(s.randomizes_target)


func test_status_data_randomizes_target_is_writable():
	var s := StatusData.new()
	s.randomizes_target = true
	assert_true(s.randomizes_target)


func test_status_data_default_blocks_cast_is_false():
	var s := StatusData.new()
	assert_false(s.blocks_cast)


func test_status_data_blocks_cast_is_writable():
	var s := StatusData.new()
	s.blocks_cast = true
	assert_true(s.blocks_cast)


func test_status_data_default_hit_penalty_is_zero():
	var s := StatusData.new()
	assert_eq(s.hit_penalty, 0.0)


func test_status_data_hit_penalty_is_writable():
	var s := StatusData.new()
	s.hit_penalty = 0.25
	assert_almost_eq(s.hit_penalty, 0.25, 0.0001)


func test_status_data_default_default_duration_is_zero():
	var s := StatusData.new()
	assert_eq(s.default_duration, 0)


func test_status_data_default_duration_is_writable():
	var s := StatusData.new()
	s.default_duration = 3
	assert_eq(s.default_duration, 3)


func test_status_data_default_tick_in_battle_is_zero():
	var s := StatusData.new()
	assert_eq(s.tick_in_battle, 0)


func test_status_data_tick_in_battle_is_writable():
	var s := StatusData.new()
	s.tick_in_battle = 2
	assert_eq(s.tick_in_battle, 2)


func test_status_data_default_tick_in_dungeon_is_zero():
	var s := StatusData.new()
	assert_eq(s.tick_in_dungeon, 0)


func test_status_data_tick_in_dungeon_is_writable():
	var s := StatusData.new()
	s.tick_in_dungeon = 1
	assert_eq(s.tick_in_dungeon, 1)


func test_status_data_default_tick_in_dungeon_ratio_is_zero():
	var s := StatusData.new()
	assert_eq(s.tick_in_dungeon_ratio, 0)


func test_status_data_tick_in_dungeon_ratio_is_writable():
	var s := StatusData.new()
	s.tick_in_dungeon_ratio = 16
	assert_eq(s.tick_in_dungeon_ratio, 16)


func test_status_data_default_cures_on_damage_is_false():
	var s := StatusData.new()
	assert_false(s.cures_on_damage)


func test_status_data_cures_on_damage_is_writable():
	var s := StatusData.new()
	s.cures_on_damage = true
	assert_true(s.cures_on_damage)


func test_status_data_default_cures_on_battle_end_is_false():
	var s := StatusData.new()
	assert_false(s.cures_on_battle_end)


func test_status_data_cures_on_battle_end_is_writable():
	var s := StatusData.new()
	s.cures_on_battle_end = true
	assert_true(s.cures_on_battle_end)


func test_status_data_default_resist_key_is_empty_string_name():
	var s := StatusData.new()
	assert_eq(s.resist_key, &"")
	assert_typeof(s.resist_key, TYPE_STRING_NAME)


func test_status_data_resist_key_is_writable():
	var s := StatusData.new()
	s.resist_key = &"poison"
	assert_eq(s.resist_key, &"poison")
