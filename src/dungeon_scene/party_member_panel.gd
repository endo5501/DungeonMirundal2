class_name PartyMemberPanel
extends Control

const PANEL_WIDTH := 180
const PANEL_HEIGHT := 80
const ICON_SIZE := 48
const FONT_SIZE := 14
const BG_COLOR := Color(0.15, 0.15, 0.2, 0.7)
const ICON_BG_COLOR := Color(0.3, 0.3, 0.35)
const HP_COLOR := Color(0.2, 0.8, 0.2)
const MP_COLOR := Color(0.3, 0.4, 0.9)

var _data: PartyMemberData

func _init() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_member(data: PartyMemberData) -> void:
	_data = data
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, PANEL_HEIGHT)), BG_COLOR)

	if _data == null:
		return

	var data := _data

	# Placeholder icon
	var icon_rect := Rect2(4, 4, ICON_SIZE, ICON_SIZE)
	draw_rect(icon_rect, ICON_BG_COLOR)

	# Text area starts after icon
	var tx := ICON_SIZE + 10
	var font := ThemeDB.fallback_font
	var line_h := FONT_SIZE + 2

	# Name
	draw_string(font, Vector2(tx, line_h), data.member_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	# LV
	draw_string(font, Vector2(tx, line_h * 2), "LV:%d" % data.level, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	# HP
	draw_string(font, Vector2(tx, line_h * 3), "HP:%d/%d" % [data.current_hp, data.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, HP_COLOR)
	# MP
	draw_string(font, Vector2(tx, line_h * 4), "MP:%d/%d" % [data.current_mp, data.max_mp], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, MP_COLOR)
