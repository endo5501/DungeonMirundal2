class_name DungeonScreen
extends Control

signal return_to_town
signal step_taken(new_position: Vector2i)

const RETURN_DIALOG_MESSAGE := "地上に戻りますか？"

var _dungeon_scene: DungeonScene
var _sub_viewport: SubViewport
var _minimap_display: MinimapDisplay
var _party_display: PartyDisplay
var _full_map_overlay: FullMapOverlay
var _player_state: PlayerState
var _wiz_map: WizMap
var _explored_map: ExploredMap
var _dungeon_data: DungeonData
var _dungeon_view: DungeonView

var _return_dialog: ConfirmDialog
var _encounter_active: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_dungeon_view = DungeonView.new()

	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(_sub_viewport)

	_dungeon_scene = DungeonScene.new()
	_sub_viewport.add_child(_dungeon_scene)

	_minimap_display = MinimapDisplay.new()
	add_child(_minimap_display)

	_party_display = PartyDisplay.new()
	add_child(_party_display)

	_full_map_overlay = FullMapOverlay.new()
	add_child(_full_map_overlay)

	_return_dialog = ConfirmDialog.new()
	add_child(_return_dialog)
	_return_dialog.confirmed.connect(_on_return_confirmed)

func setup_from_data(dungeon_data: DungeonData, party_data: PartyData = null) -> void:
	_dungeon_data = dungeon_data
	setup(dungeon_data.wiz_map, dungeon_data.player_state, dungeon_data.explored_map, party_data)

func setup(wiz_map: WizMap, player_state: PlayerState, explored_map: ExploredMap = null, party_data: PartyData = null) -> void:
	_wiz_map = wiz_map
	_player_state = player_state
	_explored_map = explored_map if explored_map else ExploredMap.new()

	_dungeon_scene.wiz_map = wiz_map
	_dungeon_scene.player_state = player_state

	_minimap_display.setup(wiz_map, _explored_map, player_state)

	if party_data == null:
		party_data = PartyData.create_placeholder()
	_party_display.setup(party_data)

	_full_map_overlay.setup(_wiz_map, _explored_map, _player_state, _dungeon_data, _minimap_display)

	_refresh_all()

func is_full_map_open() -> bool:
	return _full_map_overlay != null and _full_map_overlay.is_open()

func _refresh_all() -> void:
	var render_cells := _dungeon_view.get_render_cells(
		_wiz_map, _player_state.position, _player_state.facing)
	var explore_cells := _dungeon_view.get_explored_cells(
		_wiz_map, _player_state.position, _player_state.facing)
	_explored_map.mark_visible(explore_cells)
	_dungeon_scene.refresh(render_cells)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_minimap_display.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if _player_state == null or _wiz_map == null:
		return

	if event.is_action_pressed("toggle_full_map"):
		if _encounter_active or is_showing_return_dialog():
			return
		_toggle_full_map_overlay()
		return

	if _full_map_overlay != null and _full_map_overlay.is_open():
		return

	if _encounter_active:
		return

	# ConfirmDialog handles its own input via its own _unhandled_input.
	if is_showing_return_dialog():
		return

	if event.is_action_pressed("move_forward"):
		if _player_state.move_forward(_wiz_map):
			_on_position_changed()
	elif event.is_action_pressed("move_back"):
		if _player_state.move_backward(_wiz_map):
			_on_position_changed()
	elif event.is_action_pressed("strafe_left"):
		if _player_state.strafe_left(_wiz_map):
			_on_position_changed()
	elif event.is_action_pressed("strafe_right"):
		if _player_state.strafe_right(_wiz_map):
			_on_position_changed()
	elif event.is_action_pressed("turn_left"):
		_player_state.turn_left()
		_refresh_all()
	elif event.is_action_pressed("turn_right"):
		_player_state.turn_right()
		_refresh_all()

func _toggle_full_map_overlay() -> void:
	if _full_map_overlay == null:
		return
	if _full_map_overlay.is_open():
		_full_map_overlay.close()
	else:
		_full_map_overlay.open()

func _on_position_changed() -> void:
	_refresh_all()
	# step_taken listeners may set_encounter_active(true) synchronously,
	# so re-check the flag before showing the return dialog.
	step_taken.emit(_player_state.position)
	if not _encounter_active and is_on_start_tile():
		_show_return_dialog()

func set_encounter_active(active: bool) -> void:
	_encounter_active = active

func is_encounter_active() -> bool:
	return _encounter_active

func is_showing_return_dialog() -> bool:
	return _return_dialog.visible

func refresh_party_display(party_data: PartyData) -> void:
	if _party_display != null and party_data != null:
		_party_display.setup(party_data)

func check_start_tile_return() -> void:
	if _encounter_active or is_showing_return_dialog():
		return
	if is_on_start_tile():
		_show_return_dialog()

func is_on_start_tile() -> bool:
	if _wiz_map == null or _player_state == null:
		return false
	return _wiz_map.cell(_player_state.position.x, _player_state.position.y).tile == TileType.START

func _show_return_dialog() -> void:
	_return_dialog.setup(RETURN_DIALOG_MESSAGE, ConfirmDialog.DEFAULT_NO_INDEX)

func _on_return_confirmed() -> void:
	return_to_town.emit()
