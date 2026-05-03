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


func _event(action: StringName) -> InputEventAction:
	return TestHelpers.make_action_event(action)


func _panels(command_panel = null, target_panel = null, result_panel = null) -> Dictionary:
	return {
		"command_menu": command_panel,
		"target_selector": target_panel,
		"item_selector": null,
		"result_panel": result_panel,
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
