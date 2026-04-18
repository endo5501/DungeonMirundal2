class_name DungeonScreen
extends Control

signal return_to_town
signal step_taken(new_position: Vector2i)

var _dungeon_scene: DungeonScene
var _sub_viewport: SubViewport
var _minimap_display: MinimapDisplay
var _party_display: PartyDisplay
var _player_state: PlayerState
var _wiz_map: WizMap
var _explored_map: ExploredMap
var _dungeon_view: DungeonView
const RETURN_OPTIONS: Array[String] = ["はい", "いいえ"]

var _showing_return_dialog: bool = false
var _return_dialog_selected: int = 0
var _return_dialog_rows: Array[CursorMenuRow] = []
var _return_dialog_container: Control
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

func setup_from_data(dungeon_data: DungeonData, party_data: PartyData = null) -> void:
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

	_refresh_all()

func _refresh_all() -> void:
	var render_cells := _dungeon_view.get_visible_cells(
		_wiz_map, _player_state.position, _player_state.facing)
	var explore_cells := _dungeon_view.get_visible_cells(
		_wiz_map, _player_state.position, _player_state.facing, true)
	_explored_map.mark_visible(explore_cells)
	_dungeon_scene.refresh(render_cells)
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_minimap_display.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if _player_state == null or _wiz_map == null:
		return
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return

	if _encounter_active:
		return

	if _showing_return_dialog:
		_handle_return_dialog_input(event)
		get_viewport().set_input_as_handled()
		return

	match event.keycode:
		KEY_UP, KEY_W:
			if _player_state.move_forward(_wiz_map):
				_on_position_changed()
		KEY_DOWN, KEY_S:
			if _player_state.move_backward(_wiz_map):
				_on_position_changed()
		KEY_LEFT, KEY_A:
			_player_state.turn_left()
			_refresh_all()
		KEY_RIGHT, KEY_D:
			_player_state.turn_right()
			_refresh_all()

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
	return _showing_return_dialog


func refresh_party_display(party_data: PartyData) -> void:
	if _party_display != null and party_data != null:
		_party_display.setup(party_data)

func check_start_tile_return() -> void:
	if _encounter_active or _showing_return_dialog:
		return
	if is_on_start_tile():
		_show_return_dialog()

func is_on_start_tile() -> bool:
	if _wiz_map == null or _player_state == null:
		return false
	return _wiz_map.cell(_player_state.position.x, _player_state.position.y).tile == TileType.START

func _show_return_dialog() -> void:
	_showing_return_dialog = true
	_return_dialog_selected = 1  # default to いいえ (safer)
	_return_dialog_rows.clear()

	_return_dialog_container = CenterContainer.new()
	_return_dialog_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_return_dialog_container)

	var dialog_panel := PanelContainer.new()
	dialog_panel.custom_minimum_size = Vector2(300, 120)
	_return_dialog_container.add_child(dialog_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dialog_panel.add_child(vbox)

	var msg := Label.new()
	msg.text = "地上に戻りますか？"
	msg.add_theme_font_size_override("font_size", 20)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	for i in range(RETURN_OPTIONS.size()):
		var row := CursorMenuRow.new()
		row.set_text(RETURN_OPTIONS[i])
		row.set_text_font_size(18)
		vbox.add_child(row)
		_return_dialog_rows.append(row)
	_update_return_dialog_labels()

func _update_return_dialog_labels() -> void:
	for i in range(_return_dialog_rows.size()):
		_return_dialog_rows[i].set_selected(i == _return_dialog_selected)

func _handle_return_dialog_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_UP, KEY_W:
			_return_dialog_selected = 0
			_update_return_dialog_labels()
		KEY_DOWN, KEY_S:
			_return_dialog_selected = 1
			_update_return_dialog_labels()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _return_dialog_selected == 0:
				return_to_town.emit()
			_close_return_dialog()
		KEY_ESCAPE:
			_close_return_dialog()

func _close_return_dialog() -> void:
	_showing_return_dialog = false
	if _return_dialog_container:
		_return_dialog_container.queue_free()
		_return_dialog_container = null
	_return_dialog_rows.clear()
