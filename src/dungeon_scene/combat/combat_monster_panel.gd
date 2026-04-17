class_name CombatMonsterPanel
extends Control

var _label: Label
var _display_text: String = ""


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if _label != null:
		return
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "エンカウント！"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_label)


func refresh(monster_combatants: Array, initial_counts: Dictionary) -> void:
	_ensure_label_ready()
	var alive_counts: Dictionary = {}
	var name_by_id: Dictionary = {}
	var order: Array = []
	for mc in monster_combatants:
		if mc == null or mc.monster == null or mc.monster.data == null:
			continue
		var id: StringName = mc.monster.data.monster_id
		if not name_by_id.has(id):
			name_by_id[id] = mc.monster.data.monster_name
			order.append(id)
		if mc.is_alive():
			alive_counts[id] = alive_counts.get(id, 0) + 1
	var lines: Array = []
	for id_raw in order:
		var id: StringName = id_raw
		var alive: int = alive_counts.get(id, 0)
		var initial: int = initial_counts.get(id, alive)
		lines.append("%s %d/%d" % [name_by_id[id], alive, initial])
	_display_text = "\n".join(lines)
	if _label != null:
		_label.text = _display_text


func get_display_text() -> String:
	return _display_text


func _ensure_label_ready() -> void:
	# If refresh is called before _ready (e.g., when the overlay starts an encounter
	# before this panel has entered the tree), build the UI on demand.
	if _label == null:
		_build_ui()
