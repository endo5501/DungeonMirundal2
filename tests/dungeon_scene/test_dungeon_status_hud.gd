extends GutTest


# DungeonScreen exposes a toast surface that displays one-line status-tick
# messages emitted from EncounterCoordinator.dungeon_status_tick.
# A short Timer auto-removes the message; tests drive the timer manually
# via show_status_tick(...) plus _expire_status_tick(label) (test hook).


func _make_screen() -> DungeonScreen:
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	# Setup is required so the screen builds its tree.
	var wiz_map := WizMap.new(8)
	wiz_map.generate(42)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	return screen


func test_screen_has_status_toast_container():
	var screen := _make_screen()
	assert_not_null(screen.get_status_toast_container(),
		"DungeonScreen must expose a toast container for status ticks")


func test_show_status_tick_appends_label_with_message():
	var screen := _make_screen()
	screen.show_status_tick("Alice", &"poison", 2)
	var container := screen.get_status_toast_container()
	assert_eq(container.get_child_count(), 1)
	var label := container.get_child(0) as Label
	assert_not_null(label)
	assert_true(label.text.contains("Alice"))
	assert_true(label.text.contains("2"))


func test_show_status_tick_uses_status_display_name_when_known():
	var screen := _make_screen()
	# poison.tres is shipped, so the display name "毒" should be substituted.
	screen.show_status_tick("Bob", &"poison", 3)
	var container := screen.get_status_toast_container()
	var label := container.get_child(0) as Label
	assert_true(label.text.contains("毒"), "should resolve poison → 毒 via StatusRepository")


func test_multiple_ticks_stack_as_separate_labels():
	var screen := _make_screen()
	screen.show_status_tick("Alice", &"poison", 2)
	screen.show_status_tick("Bob", &"poison", 1)
	var container := screen.get_status_toast_container()
	assert_eq(container.get_child_count(), 2)


func test_expire_status_tick_removes_label():
	var screen := _make_screen()
	screen.show_status_tick("Alice", &"poison", 2)
	var container := screen.get_status_toast_container()
	var label := container.get_child(0) as Label
	# Test hook to skip the SceneTree timer.
	screen._expire_status_tick(label)
	# Container is processed in the next frame; queue_free defers deletion.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(container.get_child_count(), 0)
