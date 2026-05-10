class_name CombatMonsterPanel
extends Control

const TITLE_TEXT := "ENEMY"
const VISUAL_COLOR := Color(0.25, 0.75, 0.25, 0.85)
const VISUAL_OUTLINE_COLOR := Color(0.05, 0.12, 0.05, 1.0)
const WINDOW_BG_COLOR := Color(0.04, 0.04, 0.05, 0.78)
const WINDOW_INSET := 8.0
const LIST_WINDOW_SIZE := Vector2(300, 138)
const TITLE_FONT_SIZE := 27
const LIST_FONT_SIZE := 27
const DESIRED_VISUAL_SIZE := Vector2(270, 216)
const MIN_VISUAL_SCALE := 0.45
const VISUAL_GAP := 42.0
# Row-based depth: BACK monsters draw smaller and higher than FRONT to evoke
# perspective. The vertical separation is computed as a fraction of FRONT
# visual height so the gap scales with the panel.
const BACK_SCALE_FACTOR := 0.85
const BACK_VERTICAL_LIFT_RATIO := 0.55

var _title_label: Label
var _label: Label
var _display_text: String = ""
var _dummy_visual_rects: Array[Rect2] = []
# MonsterCombatant -> bool. While _battle_active, refresh() reads from this
# dict instead of the live is_alive() so a dying monster stays visible until
# PartyHud flushes the matching actor_died step.
var _displayed_alive: Dictionary = {}
# Frozen at setup_for_battle so per-id "X/Y" denominators don't drift as
# monsters die. Reused across every apply_died.
var _initial_counts: Dictionary = {}
# Distinguishes "battle in progress with zero monsters registered" from
# "outside any battle"; the former still wants displayed_alive semantics.
var _battle_active: bool = false
var _monster_visual_entries: Array[Dictionary] = []


func _ready() -> void:
	_build_ui()
	resized.connect(_sync_label_layout)
	_sync_label_layout()


func setup_for_battle(monsters: Array) -> void:
	_displayed_alive.clear()
	for mc in monsters:
		if mc != null:
			_displayed_alive[mc] = true
	_initial_counts = _initial_counts_from(monsters)
	_battle_active = true
	refresh(monsters, _initial_counts)


func apply_died(actor) -> void:
	if actor == null:
		return
	if not _displayed_alive.get(actor, false):
		return
	_displayed_alive[actor] = false
	# Iteration order of the dict matches the insertion order from
	# setup_for_battle, which is the order the player saw at battle start.
	refresh(_displayed_alive.keys(), _initial_counts)


func _initial_counts_from(monsters: Array) -> Dictionary:
	var counts: Dictionary = {}
	for mc in monsters:
		if mc == null or mc.monster == null or mc.monster.data == null:
			continue
		var id: StringName = mc.monster.data.monster_id
		counts[id] = counts.get(id, 0) + 1
	return counts


func refresh(monster_combatants: Array, initial_counts: Dictionary) -> void:
	_ensure_label_ready()
	var alive_counts: Dictionary = {}
	var name_by_id: Dictionary = {}
	var order: Array = []
	var living_monsters: Array = []
	for mc in monster_combatants:
		if mc == null or mc.monster == null or mc.monster.data == null:
			continue
		var id: StringName = mc.monster.data.monster_id
		if not name_by_id.has(id):
			name_by_id[id] = mc.monster.data.monster_name
			order.append(id)
		var alive: bool = _displayed_alive.get(mc, true) if _battle_active else mc.is_alive()
		if alive:
			alive_counts[id] = alive_counts.get(id, 0) + 1
			living_monsters.append(mc)
	var lines: Array = []
	for id_raw in order:
		var id: StringName = id_raw
		var alive: int = alive_counts.get(id, 0)
		var initial: int = initial_counts.get(id, alive)
		lines.append("%s %d/%d" % [name_by_id[id], alive, initial])
	_display_text = "\n".join(lines)
	_monster_visual_entries = _build_monster_visual_entries(living_monsters)
	_dummy_visual_rects = _collect_dummy_visual_rects(_monster_visual_entries)
	if _label != null:
		_label.text = _display_text
	_sync_label_layout()
	queue_redraw()


func get_display_text() -> String:
	return _display_text


func get_title_text() -> String:
	return TITLE_TEXT


func get_enemy_list_window_rect() -> Rect2:
	return Rect2(Vector2(WINDOW_INSET, WINDOW_INSET), LIST_WINDOW_SIZE)


func get_enemy_visual_area_rect() -> Rect2:
	var list_rect := get_enemy_list_window_rect()
	var panel_size := _effective_size()
	var top := list_rect.position.y + list_rect.size.y + 18.0
	return Rect2(WINDOW_INSET, top, panel_size.x - WINDOW_INSET * 2.0, max(0.0, panel_size.y - top - WINDOW_INSET))


func get_dummy_visual_rects() -> Array:
	return _dummy_visual_rects.duplicate()


func get_monster_visual_entries() -> Array:
	return _monster_visual_entries.duplicate(true)


func _draw() -> void:
	CombatWindowStyle.draw_window(self, get_enemy_list_window_rect(), WINDOW_BG_COLOR)
	for entry in _monster_visual_entries:
		var rect: Rect2 = entry.get("rect", Rect2())
		var texture: Texture2D = entry.get("texture", null)
		if texture != null:
			draw_texture_rect(texture, _fit_texture_rect(texture, rect), false)
		else:
			_draw_dummy_visual(rect)


func _build_ui() -> void:
	if _label != null:
		return
	_title_label = Label.new()
	_title_label.text = TITLE_TEXT
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title_label)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", LIST_FONT_SIZE)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
	_sync_label_layout()


# Computes layout rects for one row (FRONT or BACK). FRONT row anchors at the
# existing baseline near the bottom of the visual area. BACK row floats above
# at BACK_SCALE_FACTOR with a vertical lift relative to FRONT visual height.
# Up to 5 monsters per row fit; the per-row scale shrinks if needed to avoid
# horizontal clipping.
func _build_row_rects(count: int, row: int, front_visual_size: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 0:
		return rects
	var capped: int = mini(count, 5)
	var visual_area := get_enemy_visual_area_rect()
	var row_scale_factor: float = 1.0 if row == Row.FRONT else BACK_SCALE_FACTOR
	var desired_size: Vector2 = DESIRED_VISUAL_SIZE * row_scale_factor
	var gaps_width: float = float(max(capped - 1, 0)) * VISUAL_GAP
	var fit_scale := 1.0
	var desired_total_width: float = float(capped) * desired_size.x + gaps_width
	if desired_total_width > visual_area.size.x:
		fit_scale = max(MIN_VISUAL_SCALE, (visual_area.size.x - gaps_width) / (float(capped) * desired_size.x))
	var visual_size: Vector2 = desired_size * fit_scale
	var total_width: float = float(capped) * visual_size.x + gaps_width
	# Center if there's slack; otherwise pin to visual_area's left edge so the
	# layout never overflows the right bound (visual_area is the hard limit).
	var slack: float = visual_area.size.x - total_width
	var start_x: float = visual_area.position.x
	if slack > 24.0:
		start_x += max(12.0, slack * 0.5)
	elif slack > 0.0:
		start_x += slack * 0.5
	# FRONT baseline keeps the existing geometry. BACK lifts above it.
	var front_base_y: float = visual_area.position.y + max(0.0, visual_area.size.y - front_visual_size.y - 36.0)
	var base_y: float
	if row == Row.FRONT:
		base_y = front_base_y
	else:
		base_y = front_base_y - front_visual_size.y * BACK_VERTICAL_LIFT_RATIO
	for i in range(capped):
		var x: float = start_x + float(i) * (visual_size.x + VISUAL_GAP)
		rects.append(Rect2(Vector2(x, base_y), visual_size))
	return rects


# Legacy single-row helper retained for tests that still reference it
# (test surface). Returns a flat FRONT-row layout for the supplied count.
func _build_dummy_visual_rects(living_count: int) -> Array[Rect2]:
	return _build_row_rects(living_count, Row.FRONT, DESIRED_VISUAL_SIZE)


func _build_monster_visual_entries(living_monsters: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	# Partition by original_row so each row gets its own layout pass.
	var front_list: Array = []
	var back_list: Array = []
	for mc in living_monsters:
		if mc == null:
			continue
		var row: int = Row.FRONT
		if mc is MonsterCombatant:
			row = mc.original_row
		if row == Row.BACK:
			back_list.append(mc)
		else:
			front_list.append(mc)
	# FRONT visual size drives both rows' baselines so layout stays anchored
	# even when the FRONT row is empty.
	var front_visual_size: Vector2 = DESIRED_VISUAL_SIZE
	var front_rects := _build_row_rects(front_list.size(), Row.FRONT, front_visual_size)
	var back_rects := _build_row_rects(back_list.size(), Row.BACK, front_visual_size)
	# Append BACK first so FRONT entries draw later (z_index 0 vs -1 also
	# enforces depth, but ordering ensures correctness for clients that don't
	# honor z_index).
	for i in range(back_rects.size()):
		var mc = back_list[i]
		entries.append({
			"rect": back_rects[i],
			"texture": _texture_of(mc),
			"row": Row.BACK,
			"z_index": -1,
		})
	for i in range(front_rects.size()):
		var mc = front_list[i]
		entries.append({
			"rect": front_rects[i],
			"texture": _texture_of(mc),
			"row": Row.FRONT,
			"z_index": 0,
		})
	return entries


func _texture_of(mc) -> Texture2D:
	if mc == null or mc.monster == null or mc.monster.data == null:
		return null
	return mc.monster.data.battle_texture


func _collect_dummy_visual_rects(entries: Array[Dictionary]) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for entry in entries:
		if entry.get("texture", null) == null:
			rects.append(entry.get("rect", Rect2()))
	return rects


func _draw_dummy_visual(rect: Rect2) -> void:
	draw_rect(rect.grow(2.0), VISUAL_OUTLINE_COLOR)
	draw_rect(rect, VISUAL_COLOR)
	var shine := Rect2(rect.position + Vector2(rect.size.x * 0.2, rect.size.y * 0.18), rect.size * 0.18)
	draw_rect(shine, Color(0.8, 1.0, 0.55, 0.75))


func _fit_texture_rect(texture: Texture2D, slot_rect: Rect2) -> Rect2:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return slot_rect
	var scale: float = min(slot_rect.size.x / texture_size.x, slot_rect.size.y / texture_size.y)
	var draw_size := texture_size * scale
	var position := Vector2(
		slot_rect.position.x + (slot_rect.size.x - draw_size.x) * 0.5,
		slot_rect.position.y + slot_rect.size.y - draw_size.y
	)
	return Rect2(position, draw_size)


func _ensure_label_ready() -> void:
	if _label == null:
		_build_ui()


func _sync_label_layout() -> void:
	if _title_label == null or _label == null:
		return
	var list_rect := get_enemy_list_window_rect()
	_title_label.position = list_rect.position + Vector2(8.0, 8.0)
	_title_label.size = Vector2(list_rect.size.x - 16.0, 24.0)
	_label.position = list_rect.position + Vector2(16.0, 46.0)
	_label.size = Vector2(list_rect.size.x - 32.0, list_rect.size.y - 54.0)


func _effective_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	return Vector2(900, 500)
