class_name PartyMemberPanel
extends Control

const PANEL_WIDTH := 180
const PANEL_HEIGHT := 168
const PORTRAIT_WIDTH := 128
const PORTRAIT_HEIGHT := 104
const ICON_SIZE := PORTRAIT_WIDTH
const FONT_SIZE := 14
const BADGE_FONT_SIZE := 12
const BG_COLOR := Color(0.15, 0.15, 0.2, 0.7)
const ICON_BG_COLOR := Color(0.3, 0.3, 0.35)
const FRAME_COLOR := Color(0.72, 0.58, 0.28, 0.95)
const HP_COLOR := Color(0.2, 0.8, 0.2)
const MP_COLOR := Color(0.3, 0.4, 0.9)
const BAR_BG_COLOR := Color(0.04, 0.04, 0.05, 0.9)
const BAR_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.85)
const TEXT_COLOR := Color(0.95, 0.95, 0.95, 1.0)
const BADGE_BG_COLOR := Color(0.05, 0.05, 0.06, 0.9)

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

# PartyDisplay assigns this when it positions the panel; shake/lift Tweens
# offset from this anchor and snap back here when they complete.
var _layout_position: Vector2 = Vector2.ZERO
# Previous current_hp observed via hp_changed; used to compute delta so we
# can pick shake (delta < 0) vs. flash (delta > 0). Resets in bind_character.
var _prev_hp: int = 0
# Combat-only display state. -1 means "not in combat mode" (panel reads from
# live _data). When >= 0, _draw_stat_bar and is_incapacitated use these values
# instead of the live Character so HP/MP bars and dim overlay stay in lockstep
# with PartyHud's buffered log playback. Latched in bind_combat_actor.
var _combat_displayed_hp: int = -1
var _combat_displayed_mp: int = -1
# Heal flash overlay alpha tweened down from FLASH_START to 0 over FLASH_DURATION.
var _flash_alpha: float = 0.0

# Active animation Tweens — one slot per kind so consecutive triggers can
# kill the previous and start a fresh Tween (per design D4).
var _active_shake_tween: Tween
var _active_flash_tween: Tween
var _active_lift_tween: Tween
var _active_die_tween: Tween

# Animation parameters.
const SHAKE_AMPLITUDE: float = 4.0
const SHAKE_DURATION: float = 0.2
const FLASH_START: float = 0.5
const FLASH_DURATION: float = 0.3
const FLASH_OVERLAY_COLOR := Color(0.4, 1.0, 0.4, 1.0)  # alpha multiplied by _flash_alpha
const LIFT_OFFSET: float = 8.0
const LIFT_HALF_DURATION: float = 0.15
const DIE_TARGET_ALPHA: float = 0.7
const DIE_DURATION: float = 0.4


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
		_prev_hp = _character.current_hp
	else:
		_data = null
		_prev_hp = 0
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
		_combat_displayed_hp = _combat_actor.current_hp
		_combat_displayed_mp = _combat_actor.current_mp
	else:
		_combat_displayed_hp = -1
		_combat_displayed_mp = -1
	queue_redraw()


# Apply a signed delta to the combat-displayed HP, clamped to [0, max_hp].
# PartyHud calls this from flush_up_to_step right before the matching shake
# or heal-flash animation, so the bar value transitions in sync with the log
# line that explains the change.
func apply_combat_hp_delta(delta: int) -> void:
	if _combat_actor == null:
		return
	var max_hp: int = _combat_actor.max_hp
	_combat_displayed_hp = clampi(_combat_displayed_hp + delta, 0, max_hp)
	queue_redraw()


func apply_combat_mp_delta(delta: int) -> void:
	if _combat_actor == null:
		return
	var max_mp: int = _combat_actor.max_mp
	_combat_displayed_mp = clampi(_combat_displayed_mp + delta, 0, max_mp)
	queue_redraw()


# Force the displayed HP to a specific value (clamped). Used by PartyHud to
# zero the bar immediately before play_die_animation so a faded panel never
# shows a positive HP bar.
func set_combat_displayed_hp(value: int) -> void:
	if _combat_actor == null:
		return
	var max_hp: int = _combat_actor.max_hp
	_combat_displayed_hp = clampi(value, 0, max_hp)
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


func _on_character_hp_changed(p_current_hp: int, _max_hp: int) -> void:
	if _character == null:
		return
	_data = _character.to_party_member_data()
	var delta: int = p_current_hp - _prev_hp
	# In combat, animations are driven by PartyHud via TurnEngine signals so
	# they sync with log playback. Out of combat (no CombatActor bound), hp
	# changes drive shake / heal flash / revival immediately as before.
	if _combat_actor == null:
		if delta < 0:
			_play_shake()
		elif delta > 0:
			_play_heal_flash()
			if _prev_hp == 0:
				if _active_die_tween != null and _active_die_tween.is_valid():
					_active_die_tween.kill()
				_active_die_tween = null
				modulate.a = 1.0
	_prev_hp = p_current_hp
	queue_redraw()


# Public wrappers PartyHud invokes after dequeuing buffered combat events.
# Out of combat, _on_character_hp_changed handles these directly.
func play_shake_animation() -> void:
	_play_shake()


func play_heal_flash_animation() -> void:
	_play_heal_flash()
	# A heal restores any lingering die fade. Cheap no-op when modulate is
	# already 1.0; avoids needing PartyHud to track prior dead state.
	if _active_die_tween != null and _active_die_tween.is_valid():
		_active_die_tween.kill()
	_active_die_tween = null
	modulate.a = 1.0


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


# --- Animation API ---

func play_lift_animation() -> void:
	if _active_lift_tween != null and _active_lift_tween.is_valid():
		_active_lift_tween.kill()
	# Snap y back to layout before re-entering so the lift always starts from
	# rest, even if the previous Tween was killed mid-flight.
	position.y = _layout_position.y
	var t := create_tween()
	t.tween_property(self, "position:y", _layout_position.y - LIFT_OFFSET, LIFT_HALF_DURATION)
	t.tween_property(self, "position:y", _layout_position.y, LIFT_HALF_DURATION)
	_active_lift_tween = t


func play_die_animation() -> void:
	if _active_die_tween != null and _active_die_tween.is_valid():
		_active_die_tween.kill()
	var t := create_tween()
	t.tween_property(self, "modulate:a", DIE_TARGET_ALPHA, DIE_DURATION)
	_active_die_tween = t


func _play_shake() -> void:
	if _active_shake_tween != null and _active_shake_tween.is_valid():
		_active_shake_tween.kill()
	# Always restore x to the layout anchor before chaining a new shake so
	# successive damage doesn't accumulate offsets.
	position.x = _layout_position.x
	var t := create_tween()
	var step: float = SHAKE_DURATION / 4.0
	t.tween_property(self, "position:x", _layout_position.x + SHAKE_AMPLITUDE, step)
	t.tween_property(self, "position:x", _layout_position.x - SHAKE_AMPLITUDE, step)
	t.tween_property(self, "position:x", _layout_position.x + SHAKE_AMPLITUDE, step)
	t.tween_property(self, "position:x", _layout_position.x, step)
	_active_shake_tween = t


func _play_heal_flash() -> void:
	if _active_flash_tween != null and _active_flash_tween.is_valid():
		_active_flash_tween.kill()
	_flash_alpha = FLASH_START
	queue_redraw()
	var t := create_tween()
	t.tween_property(self, "_flash_alpha", 0.0, FLASH_DURATION)
	t.tween_callback(queue_redraw)
	_active_flash_tween = t


# Mirrors _draw()'s early-return condition so tests can verify "panel
# renders nothing" without invoking the live draw context.
func has_visible_content() -> bool:
	return _data != null


# Snapshot mode (no Character bound) returns false since we have no live
# status array to evaluate.
func is_incapacitated() -> bool:
	if _character == null:
		return false
	# In combat the panel's "is the bar empty?" check has to use the lagged
	# display value so dim overlay appears together with the death log line,
	# not the moment the engine zeroes live HP.
	if _combat_actor != null:
		if _combat_displayed_hp <= 0:
			return true
	elif _character.current_hp <= 0:
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


func get_portrait_rect() -> Rect2:
	return Rect2((float(PANEL_WIDTH) - float(PORTRAIT_WIDTH)) * 0.5, 6.0, PORTRAIT_WIDTH, PORTRAIT_HEIGHT)


func get_level_badge_rect() -> Rect2:
	var portrait := get_portrait_rect()
	return Rect2(portrait.position.x + portrait.size.x - 34.0, portrait.position.y + 2.0, 32.0, 18.0)


func get_name_badge_rect() -> Rect2:
	var portrait := get_portrait_rect()
	return Rect2(portrait.position.x + 4.0, portrait.position.y + portrait.size.y - 20.0, portrait.size.x - 8.0, 18.0)


func get_hp_bar_rect() -> Rect2:
	return Rect2(32, 112, 88, 12)


func get_mp_bar_rect() -> Rect2:
	return Rect2(32, 134, 88, 12)


func get_icon_row_origin() -> Vector2:
	return Vector2(6, PANEL_HEIGHT - STATUS_ICON_SIZE - 5)


func stat_bar_ratio(current_value: int, max_value: int) -> float:
	if max_value <= 0:
		return 0.0
	return clamp(float(current_value) / float(max_value), 0.0, 1.0)


func get_status_icon_rects() -> Array:
	return _build_status_icon_rects(get_status_icons().size(), 0.0)


func get_stat_modifier_icon_rects(leading_count: int = 0) -> Array:
	var leading_width := float(leading_count) * float(STATUS_ICON_SIZE + STATUS_ICON_GAP)
	if leading_count > 0:
		leading_width += float(STATUS_ICON_GAP * 2)
	return _build_stat_modifier_icon_rects(get_stat_modifier_icons().size(), leading_width)


func _draw() -> void:
	if _data == null:
		return

	draw_rect(Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, PANEL_HEIGHT)), BG_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, PANEL_HEIGHT)), FRAME_COLOR, false, 2.0)

	var data := _data
	var font := ThemeDB.fallback_font

	_draw_portrait(font, data)
	_draw_name(font, data)
	# In combat mode the panel renders the lagged display values so the bars
	# advance in step with PartyHud's flush_up_to_step calls. Out of combat the
	# live snapshot in _data drives the bars directly.
	var hp_value: int = _combat_displayed_hp if _combat_actor != null else data.current_hp
	var mp_value: int = _combat_displayed_mp if _combat_actor != null else data.current_mp
	_draw_stat_bar(font, "HP", hp_value, data.max_hp, get_hp_bar_rect(), HP_COLOR)
	_draw_stat_bar(font, "MP", mp_value, data.max_mp, get_mp_bar_rect(), MP_COLOR)

	var status_count: int = _draw_status_icons(font)
	_draw_stat_modifier_icons(font, status_count)

	if _flash_alpha > 0.0:
		var c: Color = FLASH_OVERLAY_COLOR
		c.a = _flash_alpha
		draw_rect(Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, PANEL_HEIGHT)), c)

	if is_incapacitated():
		draw_rect(Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, PANEL_HEIGHT)), DIM_OVERLAY_COLOR)


func _draw_portrait(font: Font, data: PartyMemberData) -> void:
	var portrait := get_portrait_rect()
	draw_rect(portrait, ICON_BG_COLOR)
	draw_rect(Rect2(portrait.position + Vector2(10, 10), portrait.size - Vector2(20, 20)), Color(0.35, 0.35, 0.42, 1.0))
	var badge := get_level_badge_rect()
	draw_rect(badge, BADGE_BG_COLOR)
	draw_string(font, Vector2(badge.position.x + 3.0, badge.position.y + BADGE_FONT_SIZE + 2.0),
		"LV.%d" % data.level, HORIZONTAL_ALIGNMENT_LEFT, badge.size.x - 4.0, BADGE_FONT_SIZE, TEXT_COLOR)


func _draw_name(font: Font, data: PartyMemberData) -> void:
	var badge := get_name_badge_rect()
	draw_rect(badge, BADGE_BG_COLOR)
	draw_string(font, Vector2(badge.position.x + 4.0, badge.position.y + FONT_SIZE),
		data.member_name, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x - 8.0, FONT_SIZE, TEXT_COLOR)


func _draw_stat_bar(font: Font, label: String, current_value: int, max_value: int, bar_rect: Rect2, color: Color) -> void:
	draw_string(font, Vector2(7, bar_rect.position.y + FONT_SIZE - 1.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, 24.0, FONT_SIZE, color)
	draw_rect(bar_rect.grow(1.0), BAR_OUTLINE_COLOR)
	draw_rect(bar_rect, BAR_BG_COLOR)
	var fill := bar_rect
	fill.size.x *= stat_bar_ratio(current_value, max_value)
	if fill.size.x > 0.0:
		draw_rect(fill, color)
	var value_text := "%d / %d" % [current_value, max_value]
	draw_string(font, Vector2(124, bar_rect.position.y + FONT_SIZE - 1.0), value_text,
		HORIZONTAL_ALIGNMENT_RIGHT, PANEL_WIDTH - 130, FONT_SIZE, TEXT_COLOR)


# Returns the number of icons drawn so adjacent rows can offset their x.
func _draw_status_icons(font: Font) -> int:
	var icons: Array = get_status_icons()
	if icons.is_empty():
		return 0
	var drawn := 0
	var rects := get_status_icon_rects()
	for i in range(icons.size()):
		if i >= rects.size():
			break
		var rect: Rect2 = rects[i]
		draw_rect(rect, icons[i]["color"])
		draw_string(
			font,
			Vector2(rect.position.x + 2, rect.position.y + STATUS_ICON_FONT_SIZE),
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
	var rects := get_stat_modifier_icon_rects(leading_count)
	for i in range(icons.size()):
		if i >= rects.size():
			break
		var rect: Rect2 = rects[i]
		draw_rect(rect, icons[i]["color"])
		draw_string(
			font,
			Vector2(rect.position.x + 2, rect.position.y + STATUS_ICON_FONT_SIZE),
			icons[i]["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1,
			STATUS_ICON_FONT_SIZE,
			STATUS_ICON_LABEL_COLOR,
		)


func _build_status_icon_rects(count: int, offset_x: float) -> Array:
	var rects: Array = []
	var origin := get_icon_row_origin()
	for i in range(count):
		var x := origin.x + offset_x + float(i) * float(STATUS_ICON_SIZE + STATUS_ICON_GAP)
		if x + STATUS_ICON_SIZE > PANEL_WIDTH - 4:
			break
		rects.append(Rect2(x, origin.y, STATUS_ICON_SIZE, STATUS_ICON_SIZE))
	return rects


func _build_stat_modifier_icon_rects(count: int, offset_x: float) -> Array:
	var rects: Array = []
	var origin := get_icon_row_origin()
	var icon_w := STATUS_ICON_SIZE + 6
	for i in range(count):
		var x := origin.x + offset_x + float(i) * float(icon_w + STATUS_ICON_GAP)
		if x + icon_w > PANEL_WIDTH - 4:
			break
		rects.append(Rect2(x, origin.y, icon_w, STATUS_ICON_SIZE))
	return rects
