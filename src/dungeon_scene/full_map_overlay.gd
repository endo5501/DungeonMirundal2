class_name FullMapOverlay
extends Control

const BG_COLOR := Color(0, 0, 0, 0.85)
const HUD_MARGIN := 24
const NAME_FONT_SIZE := 24
const HUD_FONT_SIZE := 18
const HUD_LABEL_WIDTH := 200
const TEXTURE_TOP_MARGIN := 64
const TEXTURE_BOTTOM_MARGIN := 64
const FALLBACK_TARGET := Vector2i(512, 512)

var _wiz_map: WizMap
var _explored_map: ExploredMap
var _player_state: PlayerState
var _dungeon_data: DungeonData
var _minimap_display: Control

var _renderer: FullMapRenderer
var _bg_panel: ColorRect
var _name_label: Label
var _coord_label: Label
var _explored_label: Label
var _texture_rect: TextureRect
var _texture: ImageTexture


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_renderer = FullMapRenderer.new()

	_bg_panel = ColorRect.new()
	_bg_panel.color = BG_COLOR
	_bg_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_panel)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.offset_top = HUD_MARGIN
	_name_label.offset_bottom = HUD_MARGIN + NAME_FONT_SIZE + 8
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_texture_rect.offset_top = TEXTURE_TOP_MARGIN
	_texture_rect.offset_bottom = -TEXTURE_BOTTOM_MARGIN
	_texture_rect.offset_left = HUD_MARGIN
	_texture_rect.offset_right = -HUD_MARGIN
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	_coord_label = Label.new()
	_coord_label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	_coord_label.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	_coord_label.offset_left = HUD_MARGIN
	_coord_label.offset_right = HUD_MARGIN + HUD_LABEL_WIDTH
	_coord_label.offset_top = -HUD_MARGIN - HUD_FONT_SIZE - 4
	_coord_label.offset_bottom = -HUD_MARGIN
	_coord_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_coord_label)

	_explored_label = Label.new()
	_explored_label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	_explored_label.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_explored_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_explored_label.offset_left = -HUD_LABEL_WIDTH
	_explored_label.offset_right = -HUD_MARGIN
	_explored_label.offset_top = -HUD_MARGIN - HUD_FONT_SIZE - 4
	_explored_label.offset_bottom = -HUD_MARGIN
	_explored_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_explored_label)


func setup(wiz_map: WizMap, explored_map: ExploredMap, player_state: PlayerState,
		dungeon_data: DungeonData, minimap_display: Control) -> void:
	_wiz_map = wiz_map
	_explored_map = explored_map
	_player_state = player_state
	_dungeon_data = dungeon_data
	_minimap_display = minimap_display


func open() -> void:
	if _wiz_map == null or _explored_map == null or _player_state == null:
		return
	visible = true
	_refresh()
	if _minimap_display != null:
		_minimap_display.visible = false


func close() -> void:
	visible = false
	if _minimap_display != null:
		_minimap_display.visible = true


func is_open() -> bool:
	return visible


func get_displayed_dungeon_name() -> String:
	return _name_label.text if _name_label != null else ""


func get_displayed_coordinates() -> String:
	return _coord_label.text if _coord_label != null else ""


func get_displayed_exploration_rate() -> String:
	return _explored_label.text if _explored_label != null else ""


func _refresh() -> void:
	if _dungeon_data != null:
		_name_label.text = _dungeon_data.dungeon_name
		var rate := _dungeon_data.get_exploration_rate()
		_explored_label.text = "%d%%" % int(round(rate * 100.0))
	if _player_state != null:
		_coord_label.text = "(%d, %d)" % [_player_state.position.x, _player_state.position.y]

	if _wiz_map != null and _explored_map != null and _player_state != null:
		var target := _compute_render_target()
		var img := _renderer.render(_wiz_map, _explored_map, _player_state, target)
		if _texture == null:
			_texture = ImageTexture.create_from_image(img)
			_texture_rect.texture = _texture
		else:
			_texture.set_image(img)


func _compute_render_target() -> Vector2i:
	var rect := get_viewport_rect()
	var w := int(rect.size.x) - HUD_MARGIN * 2
	var h := int(rect.size.y) - TEXTURE_TOP_MARGIN - TEXTURE_BOTTOM_MARGIN
	if w < 64:
		w = FALLBACK_TARGET.x
	if h < 64:
		h = FALLBACK_TARGET.y
	return Vector2i(w, h)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
