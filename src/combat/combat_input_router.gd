class_name CombatInputRouter
extends RefCounted


static func route(event: InputEvent, phase: int, panels: Dictionary) -> bool:
	match phase:
		CombatOverlay.Phase.COMMAND_MENU:
			return _route_to_panel(event, panels.get("command_menu", null))
		CombatOverlay.Phase.TARGET_SELECT, CombatOverlay.Phase.ITEM_TARGET:
			return _route_to_panel(event, panels.get("target_selector", null))
		CombatOverlay.Phase.RESULT:
			return _route_to_panel(event, panels.get("result_panel", null))
		_:
			return false


static func _route_to_panel(event: InputEvent, panel) -> bool:
	if event == null or panel == null:
		return false
	if event.is_action_pressed("ui_up") and panel.has_method("move_up"):
		panel.move_up()
		return true
	if event.is_action_pressed("ui_down") and panel.has_method("move_down"):
		panel.move_down()
		return true
	if event.is_action_pressed("ui_accept"):
		if panel.has_method("confirm_current"):
			panel.confirm_current()
			return true
		if panel.has_method("confirm"):
			panel.confirm()
			return true
	return false
