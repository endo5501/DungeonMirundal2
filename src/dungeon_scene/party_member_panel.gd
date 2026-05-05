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
# When non-null, the panel auto-refreshes from this Character's signals
# (hp_changed / mp_changed / statuses_changed). When null, the panel is
# operating in legacy snapshot mode via set_member(PartyMemberData).
var _character: Character

func _init() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# Bind the panel to a live Character so subsequent state changes refresh
# the display automatically. Pass null to unbind. Switching between
# Characters disconnects the previous one before connecting the new one.
func bind_character(ch: Character) -> void:
	if _character == ch:
		return
	_disconnect_from_character()
	_character = ch
	if _character != null:
		_character.hp_changed.connect(_on_character_hp_changed)
		_character.mp_changed.connect(_on_character_mp_changed)
		_character.statuses_changed.connect(_on_character_statuses_changed)
		_data = _character.to_party_member_data()
	else:
		_data = null
	queue_redraw()


# Snapshot path: set the panel to render a static PartyMemberData. This
# disconnects from any previously bound Character so out-of-band changes
# do not overwrite the snapshot.
func set_member(data: PartyMemberData) -> void:
	_disconnect_from_character()
	_data = data
	queue_redraw()


func _disconnect_from_character() -> void:
	if _character == null:
		return
	if _character.hp_changed.is_connected(_on_character_hp_changed):
		_character.hp_changed.disconnect(_on_character_hp_changed)
	if _character.mp_changed.is_connected(_on_character_mp_changed):
		_character.mp_changed.disconnect(_on_character_mp_changed)
	if _character.statuses_changed.is_connected(_on_character_statuses_changed):
		_character.statuses_changed.disconnect(_on_character_statuses_changed)
	_character = null


func _on_character_hp_changed(_current_hp: int, _max_hp: int) -> void:
	if _character == null:
		return
	_data = _character.to_party_member_data()
	queue_redraw()


func _on_character_mp_changed(_current_mp: int, _max_mp: int) -> void:
	if _character == null:
		return
	_data = _character.to_party_member_data()
	queue_redraw()


func _on_character_statuses_changed(_persistent_statuses: Array[StringName]) -> void:
	if _character == null:
		return
	_data = _character.to_party_member_data()
	queue_redraw()


func _exit_tree() -> void:
	# Detach from Character so the signal Callable doesn't dangle if the
	# Character outlives the panel (e.g., on scene change).
	_disconnect_from_character()


# Test hook: reports whether _draw() would render anything in the panel's
# current state. When false, _draw() takes the early-return path and emits
# no draw_rect / draw_string calls. Stub returns false; replaced in green
# phase.
func has_visible_content() -> bool:
	return false


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
