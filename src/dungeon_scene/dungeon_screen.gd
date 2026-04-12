class_name DungeonScreen
extends Control

var _dungeon_scene: DungeonScene
var _sub_viewport: SubViewport
var _player_state: PlayerState
var _wiz_map: WizMap

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_sub_viewport)

	_dungeon_scene = DungeonScene.new()
	_sub_viewport.add_child(_dungeon_scene)

func setup(wiz_map: WizMap, player_state: PlayerState) -> void:
	_wiz_map = wiz_map
	_player_state = player_state
	_dungeon_scene.wiz_map = wiz_map
	_dungeon_scene.player_state = player_state
	_dungeon_scene.refresh()

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
		_dungeon_scene.refresh()
