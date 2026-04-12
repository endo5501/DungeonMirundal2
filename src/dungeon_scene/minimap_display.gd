class_name MinimapDisplay
extends Control

const MINIMAP_SIZE := 140
const MARGIN := 8
const BG_COLOR := Color(0, 0, 0, 0.5)

var _texture_rect: TextureRect
var _bg_panel: ColorRect
var _renderer: MinimapRenderer
var _wiz_map: WizMap
var _explored_map: ExploredMap
var _player_state: PlayerState
var _texture: ImageTexture

func _ready() -> void:
	_renderer = MinimapRenderer.new()

	# Position at top-right
	set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -(MINIMAP_SIZE + MARGIN * 2)
	offset_top = 0
	offset_right = 0
	offset_bottom = MINIMAP_SIZE + MARGIN * 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Semi-transparent background
	_bg_panel = ColorRect.new()
	_bg_panel.color = BG_COLOR
	_bg_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_panel)

	# Minimap image display
	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.offset_left = MARGIN
	_texture_rect.offset_top = MARGIN
	_texture_rect.offset_right = -MARGIN
	_texture_rect.offset_bottom = -MARGIN
	_texture_rect.anchor_right = 1.0
	_texture_rect.anchor_bottom = 1.0
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

func setup(wiz_map: WizMap, explored_map: ExploredMap, player_state: PlayerState) -> void:
	_wiz_map = wiz_map
	_explored_map = explored_map
	_player_state = player_state

func refresh() -> void:
	if _wiz_map == null or _explored_map == null or _player_state == null:
		return
	var img := _renderer.render(_wiz_map, _explored_map, _player_state)
	if _texture == null:
		_texture = ImageTexture.create_from_image(img)
		_texture_rect.texture = _texture
	else:
		_texture.update(img)
