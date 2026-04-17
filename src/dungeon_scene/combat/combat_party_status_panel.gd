class_name CombatPartyStatusPanel
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
	title.text = "パーティ"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	vbox.add_child(_label)


func refresh(party_combatants: Array) -> void:
	_ensure_label_ready()
	var lines: Array = []
	for pc in party_combatants:
		if pc == null:
			continue
		var ch: Character = null
		if pc is PartyCombatant:
			ch = pc.character
		if ch == null:
			lines.append("%s  HP %d/%d" % [pc.actor_name, pc.current_hp, pc.max_hp])
		else:
			lines.append("%s  Lv%d  HP %d/%d" % [ch.character_name, ch.level, ch.current_hp, ch.max_hp])
	_display_text = "\n".join(lines)
	if _label != null:
		_label.text = _display_text


func get_display_text() -> String:
	return _display_text


func _ensure_label_ready() -> void:
	if _label == null:
		_build_ui()
