extends GutTest


class _PanelSpy:
	var up_count := 0
	var down_count := 0
	var confirm_count := 0

	func move_up() -> void:
		up_count += 1

	func move_down() -> void:
		down_count += 1

	func confirm_current() -> void:
		confirm_count += 1


class _ResultPanelSpy:
	var confirm_count := 0

	func confirm() -> void:
		confirm_count += 1


class _CancellablePanelSpy:
	var up_count := 0
	var down_count := 0
	var confirm_count := 0
	var cancel_count := 0

	func move_up() -> void:
		up_count += 1

	func move_down() -> void:
		down_count += 1

	func confirm_current() -> void:
		confirm_count += 1

	func request_cancel() -> void:
		cancel_count += 1


class _OverlaySpy:
	var undo_count := 0

	func request_undo_actor() -> void:
		undo_count += 1


func _event(action: StringName) -> InputEventAction:
	return TestHelpers.make_action_event(action)


func _panels(command_panel = null, target_panel = null, result_panel = null, overlay = null) -> Dictionary:
	return {
		"command_menu": command_panel,
		"target_selector": target_panel,
		"item_selector": null,
		"result_panel": result_panel,
		"overlay": overlay,
	}


func test_command_menu_routes_to_command_panel():
	var command_panel := _PanelSpy.new()
	var handled := CombatInputRouter.route(_event(&"ui_down"), CombatOverlay.Phase.COMMAND_MENU, _panels(command_panel))
	assert_true(handled)
	assert_eq(command_panel.down_count, 1)


func test_target_select_routes_accept_to_target_panel():
	var target_panel := _PanelSpy.new()
	var handled := CombatInputRouter.route(_event(&"ui_accept"), CombatOverlay.Phase.TARGET_SELECT, _panels(null, target_panel))
	assert_true(handled)
	assert_eq(target_panel.confirm_count, 1)


func test_item_target_routes_to_target_panel():
	var target_panel := _PanelSpy.new()
	var handled := CombatInputRouter.route(_event(&"ui_up"), CombatOverlay.Phase.ITEM_TARGET, _panels(null, target_panel))
	assert_true(handled)
	assert_eq(target_panel.up_count, 1)


func test_result_routes_accept_to_result_panel():
	var result_panel := _ResultPanelSpy.new()
	var handled := CombatInputRouter.route(_event(&"ui_accept"), CombatOverlay.Phase.RESULT, _panels(null, null, result_panel))
	assert_true(handled)
	assert_eq(result_panel.confirm_count, 1)


func test_idle_item_select_and_resolving_return_false():
	var panel := _PanelSpy.new()
	assert_false(CombatInputRouter.route(_event(&"ui_accept"), CombatOverlay.Phase.IDLE, _panels(panel, panel)))
	assert_false(CombatInputRouter.route(_event(&"ui_accept"), CombatOverlay.Phase.ITEM_SELECT, _panels(panel, panel)))
	assert_false(CombatInputRouter.route(_event(&"ui_accept"), CombatOverlay.Phase.RESOLVING, _panels(panel, panel)))


# 2.1 ui_cancel under COMMAND_MENU calls overlay.request_undo_actor
func test_command_menu_ui_cancel_routes_to_overlay_undo():
	var command_panel := _PanelSpy.new()
	var overlay := _OverlaySpy.new()
	var panels := _panels(command_panel, null, null, overlay)
	var handled := CombatInputRouter.route(_event(&"ui_cancel"), CombatOverlay.Phase.COMMAND_MENU, panels)
	assert_true(handled)
	assert_eq(overlay.undo_count, 1)


# 2.2 ui_cancel under COMMAND_MENU with null overlay returns false safely
func test_command_menu_ui_cancel_with_null_overlay_returns_false():
	var command_panel := _PanelSpy.new()
	var panels := _panels(command_panel, null, null, null)
	var handled := CombatInputRouter.route(_event(&"ui_cancel"), CombatOverlay.Phase.COMMAND_MENU, panels)
	assert_false(handled)


# 2.3 ui_down under COMMAND_MENU still routes to command_menu, not overlay
func test_command_menu_ui_down_does_not_invoke_overlay_undo():
	var command_panel := _PanelSpy.new()
	var overlay := _OverlaySpy.new()
	var panels := _panels(command_panel, null, null, overlay)
	var handled := CombatInputRouter.route(_event(&"ui_down"), CombatOverlay.Phase.COMMAND_MENU, panels)
	assert_true(handled)
	assert_eq(command_panel.down_count, 1)
	assert_eq(overlay.undo_count, 0)


# 2.4 ui_cancel under TARGET_SELECT calls target_selector.request_cancel
func test_target_select_ui_cancel_routes_to_target_request_cancel():
	var target_panel := _CancellablePanelSpy.new()
	var panels := _panels(null, target_panel, null, null)
	var handled := CombatInputRouter.route(_event(&"ui_cancel"), CombatOverlay.Phase.TARGET_SELECT, panels)
	assert_true(handled)
	assert_eq(target_panel.cancel_count, 1)


# 2.5 ui_up under TARGET_SELECT still moves the cursor (regression)
func test_target_select_ui_up_still_moves_cursor():
	var target_panel := _CancellablePanelSpy.new()
	var panels := _panels(null, target_panel, null, null)
	var handled := CombatInputRouter.route(_event(&"ui_up"), CombatOverlay.Phase.TARGET_SELECT, panels)
	assert_true(handled)
	assert_eq(target_panel.up_count, 1)
	assert_eq(target_panel.cancel_count, 0)


# 2.6 ui_cancel under SPELL_TARGET still calls target.request_cancel (regression)
func test_spell_target_ui_cancel_still_routes_to_target_request_cancel():
	var target_panel := _CancellablePanelSpy.new()
	var panels := _panels(null, target_panel, null, null)
	var handled := CombatInputRouter.route(_event(&"ui_cancel"), CombatOverlay.Phase.SPELL_TARGET, panels)
	assert_true(handled)
	assert_eq(target_panel.cancel_count, 1)
