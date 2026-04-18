class_name CombatLog
extends Control

const MAX_LINES: int = 4

var _lines: Array[String] = []
var _label: Label


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if _label != null:
		return
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.size_flags_vertical = Control.SIZE_FILL
	panel.add_child(_label)


func append_line(text: String) -> void:
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	_refresh_label()


func append_from_report_action(action: Dictionary) -> void:
	var text := _format_action(action)
	if text.length() > 0:
		append_line(text)


func append_from_report(report: TurnReport) -> void:
	if report == null:
		return
	for action in report.actions:
		append_from_report_action(action)


func get_lines() -> Array[String]:
	return _lines.duplicate()


func get_display_text() -> String:
	return "\n".join(_lines)


func clear_log() -> void:
	_lines.clear()
	_refresh_label()


func _refresh_label() -> void:
	_ensure_ready()
	if _label != null:
		_label.text = get_display_text()


func _ensure_ready() -> void:
	if _label == null:
		_build_ui()


func _format_action(action: Dictionary) -> String:
	var type: String = action.get("type", "")
	var attacker: String = action.get("attacker_name", "")
	var target: String = action.get("target_name", "")
	var damage: int = int(action.get("damage", 0))
	var defended: bool = bool(action.get("defended", false))
	match type:
		"attack":
			if defended:
				return "%s の攻撃！ %s は身を守り %d ダメージ" % [attacker, target, damage]
			return "%s の攻撃！ %s に %d ダメージ" % [attacker, target, damage]
		"defend":
			return "%s は身を守っている" % attacker
		"escape":
			var success: bool = bool(action.get("success", false))
			if success:
				return "逃走に成功した"
			return "逃走に失敗した"
		"defeated":
			return "%s は倒れた" % target
		_:
			return ""
