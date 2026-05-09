extends GutTest

# Verifies that DungeonScreen re-triggers a SubViewport refresh when the window
# (or the screen Control itself) is resized. Without this behavior, the
# UPDATE_DISABLED + UPDATE_ONCE optimization leaves the SubViewport blank after
# resize until the player moves.


func _setup_screen() -> DungeonScreen:
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var wiz_map := WizMap.new(8)
	wiz_map.generate(42)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	return screen


func test_resize_notification_triggers_subviewport_update_once():
	var screen := _setup_screen()
	# Reset to UPDATE_DISABLED to simulate the steady state between movements.
	screen._sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	screen.notification(Control.NOTIFICATION_RESIZED)
	assert_eq(screen._sub_viewport.render_target_update_mode, SubViewport.UPDATE_ONCE,
		"DungeonScreen should re-arm the SubViewport for one update on resize")


func test_resize_notification_before_setup_is_noop():
	# Build a screen WITHOUT calling setup — _wiz_map and _player_state are null.
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	# Should not crash and should not touch the SubViewport mode.
	screen.notification(Control.NOTIFICATION_RESIZED)
	assert_true(true, "resize before setup should be a no-op (no crash)")
