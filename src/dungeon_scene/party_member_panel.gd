class_name PartyMemberPanel
extends Control

const PANEL_WIDTH := 180
const PANEL_HEIGHT := 130
const ICON_SIZE := 48
const FONT_SIZE := 20
const BG_COLOR := Color(0.15, 0.15, 0.2, 0.7)
const ICON_BG_COLOR := Color(0.3, 0.3, 0.35)
const HP_COLOR := Color(0.2, 0.8, 0.2)
const MP_COLOR := Color(0.3, 0.4, 0.9)

# Colors per persistent-party-display design.md §D5.
const STATUS_COLORS: Dictionary = {
	&"poison":    Color(0.6, 0.2, 0.7),
	&"blind":     Color(0.4, 0.4, 0.4),
	&"sleep":     Color(0.3, 0.4, 0.9),
	&"paralysis": Color(0.9, 0.8, 0.1),
	&"petrify":   Color(0.3, 0.3, 0.3),
	&"confusion": Color(0.9, 0.4, 0.7),
	&"silence":   Color(0.5, 0.3, 0.2),
}
const STATUS_LABELS: Dictionary = {
	&"poison":    "P",
	&"blind":     "B",
	&"sleep":     "S",
	&"paralysis": "Pa",
	&"petrify":   "St",
	&"confusion": "C",
	&"silence":   "Si",
}
const STATUS_ICON_SIZE := 16
const STATUS_ICON_GAP := 2
const STATUS_ICON_FONT_SIZE := 12
const STATUS_ICON_LABEL_COLOR := Color(1, 1, 1, 1)
const DIM_OVERLAY_COLOR := Color(0, 0, 0, 0.55)

# Stat modifier icon styling. Buff (delta > 0) leans green, debuff (delta < 0)
# leans red so the player can read intent at a glance.
const STAT_BUFF_COLOR := Color(0.25, 0.75, 0.25)
const STAT_DEBUFF_COLOR := Color(0.85, 0.25, 0.25)
const STAT_SHORT_LABELS: Dictionary = {
	&"attack":  "A",
	&"defense": "D",
	&"agility": "Ag",
	&"hit":     "H",
	&"evasion": "E",
}
const INCAPACITATING_STATUSES: Array[StringName] = [
	&"sleep", &"paralysis", &"petrify",
]

var _data: PartyMemberData
# When non-null, the panel auto-refreshes from this Character's signals
# (hp_changed / mp_changed / statuses_changed). When null, the panel is
# operating in legacy snapshot mode via set_member(PartyMemberData).
var _character: Character
# Combat-only binding: PartyHud.attach_to_turn_engine wires this to the
# matching PartyCombatant so the panel can read stat_modifier_stack and
# react to stat_modifiers_changed. Cleared on detach (bind_combat_actor(null)).
var _combat_actor: CombatActor

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


# Bind a CombatActor for combat-only state (stat_modifier_stack icon row).
# Pass null to clear. Switching actors disconnects the previous one before
# connecting the new one.
func bind_combat_actor(actor: CombatActor) -> void:
	if _combat_actor == actor:
		return
	_disconnect_from_combat_actor()
	_combat_actor = actor
	if _combat_actor != null:
		_combat_actor.stat_modifiers_changed.connect(_on_stat_modifiers_changed)
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


func _disconnect_from_combat_actor() -> void:
	if _combat_actor == null:
		return
	if _combat_actor.stat_modifiers_changed.is_connected(_on_stat_modifiers_changed):
		_combat_actor.stat_modifiers_changed.disconnect(_on_stat_modifiers_changed)
	_combat_actor = null


func _on_stat_modifiers_changed() -> void:
	queue_redraw()


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
	_disconnect_from_combat_actor()


# Mirrors _draw()'s early-return condition so tests can verify "panel
# renders nothing" without invoking the live draw context.
func has_visible_content() -> bool:
	return _data != null


# Snapshot mode (no Character bound) returns false since we have no live
# status array to evaluate.
func is_incapacitated() -> bool:
	if _character == null:
		return false
	if _character.current_hp <= 0:
		return true
	for sid in INCAPACITATING_STATUSES:
		if _character.persistent_statuses.has(sid):
			return true
	return false


# Returns one entry per active persistent status: {id, color, label}.
# Empty in snapshot mode.
func get_status_icons() -> Array:
	var result: Array = []
	if _character == null:
		return result
	for sid in _character.persistent_statuses:
		var color: Color = STATUS_COLORS.get(sid, BG_COLOR)
		var label: String = STATUS_LABELS.get(sid, "?")
		result.append({"id": sid, "color": color, "label": label})
	return result


# Returns one entry per StatModifierStack entry while a CombatActor is bound:
# {stat, delta, color, label}. Empty when no actor is bound or the stack
# itself is empty. Buffs lean green, debuffs lean red.
func get_stat_modifier_icons() -> Array:
	var result: Array = []
	if _combat_actor == null:
		return result
	for e in _combat_actor.modifier_stack._entries:
		var stat: StringName = e["stat"]
		var delta = e["delta"]
		var sign_label: String = "+" if float(delta) >= 0.0 else "-"
		var stat_label: String = STAT_SHORT_LABELS.get(stat, "?")
		result.append({
			"stat": stat,
			"delta": delta,
			"color": STAT_BUFF_COLOR if float(delta) >= 0.0 else STAT_DEBUFF_COLOR,
			"label": stat_label + sign_label,
		})
	return result


func _draw() -> void:
	if _data == null:
		return

	draw_rect(Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, PANEL_HEIGHT)), BG_COLOR)

	var data := _data

	# Placeholder icon
	var icon_rect := Rect2(4, 4, ICON_SIZE, ICON_SIZE)
	draw_rect(icon_rect, ICON_BG_COLOR)

	# Text area starts after icon
	var tx := ICON_SIZE + 10
	var font := ThemeDB.fallback_font
	var line_h := FONT_SIZE + 4

	# Name
	draw_string(font, Vector2(tx, line_h), data.member_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	# LV
	draw_string(font, Vector2(tx, line_h * 2), "LV:%d" % data.level, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	# HP
	draw_string(font, Vector2(tx, line_h * 3), "HP:%d/%d" % [data.current_hp, data.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, HP_COLOR)
	# MP
	draw_string(font, Vector2(tx, line_h * 4), "MP:%d/%d" % [data.current_mp, data.max_mp], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, MP_COLOR)

	var status_count: int = _draw_status_icons(font)
	_draw_stat_modifier_icons(font, status_count)

	if is_incapacitated():
		draw_rect(Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, PANEL_HEIGHT)), DIM_OVERLAY_COLOR)


# Returns the number of icons drawn so adjacent rows can offset their x.
func _draw_status_icons(font: Font) -> int:
	var icons: Array = get_status_icons()
	if icons.is_empty():
		return 0
	var origin_x := ICON_SIZE + 10
	var origin_y := PANEL_HEIGHT - STATUS_ICON_SIZE - 4
	var drawn := 0
	for i in range(icons.size()):
		var x := origin_x + i * (STATUS_ICON_SIZE + STATUS_ICON_GAP)
		if x + STATUS_ICON_SIZE > PANEL_WIDTH - 4:
			break
		var rect := Rect2(x, origin_y, STATUS_ICON_SIZE, STATUS_ICON_SIZE)
		draw_rect(rect, icons[i]["color"])
		draw_string(
			font,
			Vector2(x + 2, origin_y + STATUS_ICON_FONT_SIZE),
			icons[i]["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1,
			STATUS_ICON_FONT_SIZE,
			STATUS_ICON_LABEL_COLOR,
		)
		drawn += 1
	return drawn


# Stat modifier icons sit on the same row as persistent_status icons, offset
# to the right of them. The label is 2-3 chars wide so we widen the box.
func _draw_stat_modifier_icons(font: Font, leading_count: int) -> void:
	var icons: Array = get_stat_modifier_icons()
	if icons.is_empty():
		return
	var icon_w := STATUS_ICON_SIZE + 6  # extra width for 2-char labels
	var base_x := ICON_SIZE + 10 + leading_count * (STATUS_ICON_SIZE + STATUS_ICON_GAP)
	if leading_count > 0:
		base_x += STATUS_ICON_GAP * 2  # visible gap between status row and stat row
	var origin_y := PANEL_HEIGHT - STATUS_ICON_SIZE - 4
	for i in range(icons.size()):
		var x := base_x + i * (icon_w + STATUS_ICON_GAP)
		if x + icon_w > PANEL_WIDTH - 4:
			break
		var rect := Rect2(x, origin_y, icon_w, STATUS_ICON_SIZE)
		draw_rect(rect, icons[i]["color"])
		draw_string(
			font,
			Vector2(x + 2, origin_y + STATUS_ICON_FONT_SIZE),
			icons[i]["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1,
			STATUS_ICON_FONT_SIZE,
			STATUS_ICON_LABEL_COLOR,
		)
