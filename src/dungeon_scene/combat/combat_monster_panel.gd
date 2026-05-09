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


func _build_dummy_visual_rects(living_count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if living_count <= 0:
		return rects
	var count: int = min(living_count, 6)
	var visual_area := get_enemy_visual_area_rect()
	var gaps_width := float(max(count - 1, 0)) * VISUAL_GAP
	var scale := 1.0
	var desired_total_width := float(count) * DESIRED_VISUAL_SIZE.x + gaps_width
	if desired_total_width > visual_area.size.x:
		scale = max(MIN_VISUAL_SCALE, (visual_area.size.x - gaps_width) / (float(count) * DESIRED_VISUAL_SIZE.x))
	var visual_size := DESIRED_VISUAL_SIZE * scale
	var total_width := float(count) * visual_size.x + gaps_width
	var start_x: float = visual_area.position.x + max(12.0, (visual_area.size.x - total_width) * 0.5)
	var base_y: float = visual_area.position.y + max(0.0, visual_area.size.y - visual_size.y - 36.0)
	for i in range(count):
		var x := start_x + float(i) * (visual_size.x + VISUAL_GAP)
		rects.append(Rect2(Vector2(x, base_y), visual_size))
	return rects


func _build_monster_visual_entries(living_monsters: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var rects := _build_dummy_visual_rects(living_monsters.size())
	for i in range(rects.size()):
		var mc = living_monsters[i]
		var texture: Texture2D = null
		if mc != null and mc.monster != null and mc.monster.data != null:
			texture = mc.monster.data.battle_texture
		entries.append({
			"rect": rects[i],
			"texture": texture,
		})
	return entries


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
