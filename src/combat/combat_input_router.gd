class_name CombatInputRouter
extends RefCounted


static func route(event: InputEvent, phase: int, panels: Dictionary) -> bool:
	match phase:
		CombatOverlay.Phase.COMMAND_MENU:
			return _route_to_panel(event, panels.get("command_menu", null))
		CombatOverlay.Phase.TARGET_SELECT, CombatOverlay.Phase.ITEM_TARGET:
			return _route_to_panel(event, panels.get("target_selector", null))
		CombatOverlay.Phase.SPELL_TARGET:
			return _route_to_panel_cancellable(event, panels.get("target_selector", null))
		CombatOverlay.Phase.SPELL_SELECT:
			return _route_to_panel_cancellable(event, panels.get("spell_selector", null))
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


# Same as _route_to_panel but additionally routes ui_cancel to `request_cancel`.
# Used by the spell-cast sub-flow so the player can back out of spell or target
# selection without submitting a Cast command.
static func _route_to_panel_cancellable(event: InputEvent, panel) -> bool:
	if event == null or panel == null:
		return false
	if event.is_action_pressed("ui_cancel") and panel.has_method("request_cancel"):
		panel.request_cancel()
		return true
	return _route_to_panel(event, panel)
