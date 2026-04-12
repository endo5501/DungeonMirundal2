class_name PartyDisplay
extends Control

const MARGIN := 8
const ROW_GAP := 4
const BG_COLOR := Color(0, 0, 0, 0.4)

var _bg_panel: ColorRect
var _front_panels: Array  # Array[PartyMemberPanel]
var _back_panels: Array   # Array[PartyMemberPanel]

func _ready() -> void:
	# Center horizontally, anchor to bottom
	var panel_h: float = (PartyMemberPanel.PANEL_HEIGHT * 2) + ROW_GAP + MARGIN * 2
	var panel_w: float = (PartyMemberPanel.PANEL_WIDTH * 3) + MARGIN * 4
	var half_w: float = panel_w / 2.0

	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -half_w
	offset_right = half_w
	offset_top = -panel_h - MARGIN
	offset_bottom = -MARGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background
	_bg_panel = ColorRect.new()
	_bg_panel.color = BG_COLOR
	_bg_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_panel)

	# Create panels
	_front_panels = _create_row(0)
	_back_panels = _create_row(1)

func _create_row(row_index: int) -> Array:
	var panels: Array = []
	for i in range(3):
		var panel := PartyMemberPanel.new()
		var x := MARGIN + i * (PartyMemberPanel.PANEL_WIDTH + MARGIN)
		var y := MARGIN + row_index * (PartyMemberPanel.PANEL_HEIGHT + ROW_GAP)
		panel.position = Vector2(x, y)
		add_child(panel)
		panels.append(panel)
	return panels

func setup(party_data: PartyData) -> void:
	var front := party_data.get_front_row()
	var back := party_data.get_back_row()
	for i in range(3):
		_front_panels[i].set_member(front[i])
		_back_panels[i].set_member(back[i])
