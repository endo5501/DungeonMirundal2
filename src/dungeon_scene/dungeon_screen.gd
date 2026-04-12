class_name DungeonScreen
extends Control

var _dungeon_scene: DungeonScene
var _sub_viewport: SubViewport
var _minimap_display: MinimapDisplay
var _party_display: PartyDisplay
var _player_state: PlayerState
var _wiz_map: WizMap
var _explored_map: ExploredMap
var _dungeon_view: DungeonView

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

func setup(wiz_map: WizMap, player_state: PlayerState) -> void:
	_wiz_map = wiz_map
	_player_state = player_state
	_explored_map = ExploredMap.new()

	_dungeon_scene.wiz_map = wiz_map
	_dungeon_scene.player_state = player_state

	_minimap_display.setup(wiz_map, _explored_map, player_state)

	var party_data := PartyData.create_placeholder()
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

	var moved := false
	match event.keycode:
		KEY_UP, KEY_W:
			moved = _player_state.move_forward(_wiz_map)
		KEY_DOWN, KEY_S:
			moved = _player_state.move_backward(_wiz_map)
		KEY_LEFT, KEY_A:
			_player_state.turn_left()
			moved = true
		KEY_RIGHT, KEY_D:
			_player_state.turn_right()
			moved = true

	if moved:
		_refresh_all()
