class_name PartyDisplay
extends Control

const MARGIN := 8
const FRONT_LABEL := "FRONT"
const BACK_LABEL := "BACK"
const LABEL_FONT_SIZE := 20
const LABEL_AREA_HEIGHT := 26
const LABEL_COLOR := Color(0.95, 0.95, 0.95, 1.0)
const LABEL_OUTLINE_SIZE := 3
const LABEL_OUTLINE_COLOR := Color(0, 0, 0, 0.85)
const LABEL_BOX_WIDTH := 200.0
const WINDOW_PADDING := 8.0
const WINDOW_BG_COLOR := Color(0.04, 0.04, 0.05, 0.62)

const HUD_HEIGHT := LABEL_AREA_HEIGHT + PartyMemberPanel.PANEL_HEIGHT + 4

var _front_panels: Array  # Array[PartyMemberPanel]
var _back_panels: Array   # Array[PartyMemberPanel]


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = -float(HUD_HEIGHT)
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_front_panels = _create_panels()
	_back_panels = _create_panels()

	_layout_panels(size.x)
	resized.connect(func() -> void: _layout_panels(size.x))


func _create_panels() -> Array:
	var panels: Array = []
	for i in range(3):
		var panel := PartyMemberPanel.new()
		add_child(panel)
		panels.append(panel)
	return panels


# Front row left-aligned with MARGIN inset; back row right-aligned with
# MARGIN inset from the right edge. Both rows share the same y. Idempotent
# when called twice with the same width — skips redundant resized firings.
func _layout_panels(width: float) -> void:
	if _front_panels.is_empty() or _back_panels.is_empty():
		return

	var pw: float = float(PartyMemberPanel.PANEL_WIDTH)
	var m: float = float(MARGIN)

	# Skip when the previously-applied width matches.
	var prev_right_edge: float = _back_panels[2].position.x + pw + m
	if is_equal_approx(prev_right_edge, width):
		return

	var panel_y: float = float(LABEL_AREA_HEIGHT)
	var step: float = pw + m

	for i in range(3):
		_front_panels[i].position = Vector2(m + float(i) * step, panel_y)
		_front_panels[i]._layout_position = _front_panels[i].position
		_back_panels[i].position = Vector2(width - m - float(3 - i) * pw - float(2 - i) * m, panel_y)
		_back_panels[i]._layout_position = _back_panels[i].position

	queue_redraw()


func _draw() -> void:
	if _front_panels.is_empty() or _back_panels.is_empty():
		return

	var font := ThemeDB.fallback_font
	_draw_window(get_front_window_rect())
	_draw_window(get_back_window_rect())
	# Outline so labels stay legible against light dungeon walls.
	_draw_label(font, FRONT_LABEL, get_front_label_position(), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	var pos_back: Vector2 = get_back_label_position()
	_draw_label(font, BACK_LABEL,
		Vector2(pos_back.x - LABEL_BOX_WIDTH, pos_back.y),
		HORIZONTAL_ALIGNMENT_RIGHT, LABEL_BOX_WIDTH)


func _draw_label(font: Font, text: String, pos: Vector2, alignment: int, box_width: float) -> void:
	draw_string_outline(font, pos, text, alignment, box_width,
		LABEL_FONT_SIZE, LABEL_OUTLINE_SIZE, LABEL_OUTLINE_COLOR)
	draw_string(font, pos, text, alignment, box_width,
		LABEL_FONT_SIZE, LABEL_COLOR)


func _draw_window(rect: Rect2) -> void:
	CombatWindowStyle.draw_window(self, rect, WINDOW_BG_COLOR)


func get_front_window_rect() -> Rect2:
	return _row_window_rect(_front_panels)


func get_back_window_rect() -> Rect2:
	return _row_window_rect(_back_panels)


func _row_window_rect(panels: Array) -> Rect2:
	if panels.is_empty():
		return Rect2()
	var left := INF
	var right := -INF
	for panel in panels:
		var p := panel as PartyMemberPanel
		left = min(left, p.position.x)
		right = max(right, p.position.x + float(PartyMemberPanel.PANEL_WIDTH))
	return Rect2(
		Vector2(left - WINDOW_PADDING, 0.0),
		Vector2(right - left + WINDOW_PADDING * 2.0, float(HUD_HEIGHT))
	)


# x = front-row group's left edge, y = label baseline.
func get_front_label_position() -> Vector2:
	return Vector2(float(MARGIN), float(LABEL_FONT_SIZE))


# x = back-row group's right edge, y = label baseline. Derived from the
# rightmost back panel's actual position so callers always see the current
# layout.
func get_back_label_position() -> Vector2:
	var right_edge: float = _back_panels[2].position.x + float(PartyMemberPanel.PANEL_WIDTH)
	return Vector2(right_edge, float(LABEL_FONT_SIZE))


func setup(party_data: PartyData) -> void:
	var front := party_data.get_front_row()
	var back := party_data.get_back_row()
	for i in range(3):
		_front_panels[i].set_member(front[i])
		_back_panels[i].set_member(back[i])


# Bind PartyDisplay to live Character objects so subsequent HP/MP/status
# mutations on any of them refresh only the corresponding PartyMemberPanel.
# Each row is an Array of length 3 whose entries are Character or null
# (null means "empty slot — render nothing for that panel").
func bind_party_characters(front_row: Array, back_row: Array) -> void:
	for i in range(3):
		var f: Character = front_row[i] if i < front_row.size() else null
		var b: Character = back_row[i] if i < back_row.size() else null
		if f != null:
			_front_panels[i].bind_character(f)
		else:
			_front_panels[i].bind_character(null)
		if b != null:
			_back_panels[i].bind_character(b)
		else:
			_back_panels[i].bind_character(null)
