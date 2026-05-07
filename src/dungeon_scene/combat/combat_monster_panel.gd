class_name CombatMonsterPanel
extends Control

const TITLE_TEXT := "ENEMY"
const VISUAL_COLOR := Color(0.25, 0.75, 0.25, 0.85)
const VISUAL_OUTLINE_COLOR := Color(0.05, 0.12, 0.05, 1.0)
const WINDOW_BG_COLOR := Color(0.04, 0.04, 0.05, 0.78)
const WINDOW_FRAME_COLOR := Color(0.72, 0.58, 0.28, 0.95)
const WINDOW_INSET := 8.0
const LIST_WINDOW_SIZE := Vector2(300, 138)
const TITLE_FONT_SIZE := 18
const LIST_FONT_SIZE := 18

var _title_label: Label
var _label: Label
var _display_text: String = ""
var _dummy_visual_rects: Array[Rect2] = []


func _ready() -> void:
	_build_ui()
	resized.connect(_sync_label_layout)
	_sync_label_layout()


func refresh(monster_combatants: Array, initial_counts: Dictionary) -> void:
	_ensure_label_ready()
	var alive_counts: Dictionary = {}
	var name_by_id: Dictionary = {}
	var order: Array = []
	var living_count := 0
	for mc in monster_combatants:
		if mc == null or mc.monster == null or mc.monster.data == null:
			continue
		var id: StringName = mc.monster.data.monster_id
		if not name_by_id.has(id):
			name_by_id[id] = mc.monster.data.monster_name
			order.append(id)
		if mc.is_alive():
			alive_counts[id] = alive_counts.get(id, 0) + 1
			living_count += 1
	var lines: Array = []
	for id_raw in order:
		var id: StringName = id_raw
		var alive: int = alive_counts.get(id, 0)
		var initial: int = initial_counts.get(id, alive)
		lines.append("%s %d/%d" % [name_by_id[id], alive, initial])
	_display_text = "\n".join(lines)
	_dummy_visual_rects = _build_dummy_visual_rects(living_count)
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


func _draw() -> void:
	var list_rect := get_enemy_list_window_rect()
	draw_rect(list_rect, WINDOW_BG_COLOR)
	draw_rect(list_rect, WINDOW_FRAME_COLOR, false, 2.0)
	for rect in _dummy_visual_rects:
		draw_rect(rect.grow(2.0), VISUAL_OUTLINE_COLOR)
		draw_rect(rect, VISUAL_COLOR)
		var shine := Rect2(rect.position + Vector2(rect.size.x * 0.2, rect.size.y * 0.18), rect.size * 0.18)
		draw_rect(shine, Color(0.8, 1.0, 0.55, 0.75))


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
	var visual_size := Vector2(72, 48)
	var total_width := float(count) * visual_size.x + float(max(count - 1, 0)) * 28.0
	var visual_area := get_enemy_visual_area_rect()
	var start_x: float = visual_area.position.x + max(12.0, (visual_area.size.x - total_width) * 0.5)
	var base_y: float = visual_area.position.y + max(0.0, visual_area.size.y - visual_size.y - 36.0)
	for i in range(count):
		var x := start_x + float(i) * (visual_size.x + 28.0)
		rects.append(Rect2(Vector2(x, base_y), visual_size))
	return rects


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
