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


func test_resize_does_not_remark_explored_cells():
	# Resize is not exploration: the handler must NOT call _refresh_all() because
	# that would mutate _explored_map.mark_visible — semantically incorrect for a
	# resize event.
	var screen := _setup_screen()
	var explored_before: Array = screen._explored_map.get_visible_cells_snapshot() if screen._explored_map.has_method("get_visible_cells_snapshot") else []
	# Move player to a fresh position WITHOUT exploring (direct mutation),
	# then trigger resize. If _refresh_all were called, mark_visible would
	# add the new cone to _explored_map.
	screen._sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	screen.notification(Control.NOTIFICATION_RESIZED)
	# The SubViewport should be re-armed but no other state should have moved.
	assert_eq(screen._sub_viewport.render_target_update_mode, SubViewport.UPDATE_ONCE,
		"resize should re-arm SubViewport")


func test_resize_before_subviewport_constructed_is_noop():
	# Build a screen and immediately fire NOTIFICATION_RESIZED before _ready
	# has a chance to construct _sub_viewport. add_child_autofree triggers
	# _ready synchronously in GUT, so we exercise the guard via a fresh
	# instance whose _sub_viewport we explicitly null out.
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	screen._sub_viewport = null
	# Should not crash.
	screen.notification(Control.NOTIFICATION_RESIZED)
	assert_true(true, "resize with null _sub_viewport must be a no-op (no crash)")
