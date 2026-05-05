class_name PartyDisplay
extends Control

const MARGIN := 8
const FRONT_LABEL := "FRONT"
const BACK_LABEL := "BACK"
const LABEL_FONT_SIZE := 20
const LABEL_AREA_HEIGHT := 26
const LABEL_COLOR := Color(0.95, 0.95, 0.95, 1.0)

const HUD_HEIGHT := LABEL_AREA_HEIGHT + PartyMemberPanel.PANEL_HEIGHT + 4

var _front_panels: Array  # Array[PartyMemberPanel]
var _back_panels: Array   # Array[PartyMemberPanel]
var _layout_width: float = 0.0

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

	_layout_panels()
	resized.connect(_layout_panels)


func _create_panels() -> Array:
	var panels: Array = []
	for i in range(3):
		var panel := PartyMemberPanel.new()
		add_child(panel)
		panels.append(panel)
	return panels


# Recomputes panel positions for the given width. When override_width is
# negative (the default), the current self.size.x is used — that's the
# normal in-tree path triggered by the resized signal. Tests pass an
# explicit override_width to avoid relying on the deferred anchor resolution.
# Front row is left-aligned with MARGIN inset; back row is right-aligned
# with MARGIN inset from the right edge. Both rows share the same y.
func _layout_panels(override_width: float = -1.0) -> void:
	if _front_panels == null or _back_panels == null:
		return
	if _front_panels.is_empty() or _back_panels.is_empty():
		return

	var width: float = size.x if override_width < 0.0 else override_width
	_layout_width = width

	var panel_y: float = float(LABEL_AREA_HEIGHT)
	var step: float = float(PartyMemberPanel.PANEL_WIDTH + MARGIN)

	for i in range(3):
		var fx: float = float(MARGIN) + float(i) * step
		_front_panels[i].position = Vector2(fx, panel_y)

	for i in range(3):
		# i = 0 leftmost back, i = 2 rightmost back. Rightmost panel's right
		# edge sits at width - MARGIN.
		var bx: float = width - float(MARGIN) \
			- float(3 - i) * float(PartyMemberPanel.PANEL_WIDTH) \
			- float(2 - i) * float(MARGIN)
		_back_panels[i].position = Vector2(bx, panel_y)

	queue_redraw()


func _draw() -> void:
	if _front_panels == null or _back_panels == null:
		return
	if _front_panels.is_empty() or _back_panels.is_empty():
		return

	var font := ThemeDB.fallback_font
	var pos_front: Vector2 = get_front_label_position()
	draw_string(font, pos_front, FRONT_LABEL,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LABEL_COLOR)

	var pos_back: Vector2 = get_back_label_position()
	# Right-align by drawing within a fixed-width box ending at pos_back.x.
	var label_box_width: float = 200.0
	var back_draw_x: float = pos_back.x - label_box_width
	draw_string(font, Vector2(back_draw_x, pos_back.y), BACK_LABEL,
		HORIZONTAL_ALIGNMENT_RIGHT, label_box_width, LABEL_FONT_SIZE, LABEL_COLOR)


# The position returned is the baseline anchor for draw_string: x is the left
# edge of the label, y is the baseline. Anchored to the front-row group's
# left edge.
func get_front_label_position() -> Vector2:
	return Vector2(float(MARGIN), float(LABEL_FONT_SIZE))


# The position returned is the right edge of the BACK label baseline: x is
# the right boundary, y is the baseline. Anchored to the back-row group's
# right edge. Uses the width established by the most recent _layout_panels()
# call so tests get deterministic values.
func get_back_label_position() -> Vector2:
	var width: float = _layout_width if _layout_width > 0.0 else size.x
	return Vector2(width - float(MARGIN), float(LABEL_FONT_SIZE))


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
