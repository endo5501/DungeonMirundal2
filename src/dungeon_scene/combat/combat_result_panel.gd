class_name CombatResultPanel
extends Control

signal confirmed()

var _title_label: Label
var _body_label: Label
var _hint_label: Label
var _display_text: String = ""


func _ready() -> void:
	_build_ui()
	visible = false


func _build_ui() -> void:
	if _title_label != null:
		return
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)
	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_body_label)
	_hint_label = Label.new()
	_hint_label.text = "[Enter] 次へ"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_hint_label)


func show_result(outcome: EncounterOutcome, level_ups: Array) -> void:
	_ensure_ready()
	var title_text: String = ""
	var body_lines: Array = []
	match outcome.result:
		EncounterOutcome.Result.CLEARED:
			title_text = "勝利！"
			body_lines.append("獲得経験値: %d" % outcome.gained_experience)
			for entry in level_ups:
				var name: String = entry.get("name", "")
				var new_level: int = int(entry.get("new_level", 0))
				body_lines.append("%s は Lv%d になった！" % [name, new_level])
		EncounterOutcome.Result.WIPED:
			title_text = "全滅..."
			body_lines.append("パーティは倒れた")
		EncounterOutcome.Result.ESCAPED:
			title_text = "逃走成功"
			body_lines.append("戦闘から離脱した")
	_title_label.text = title_text
	_display_text = "\n".join(body_lines)
	_body_label.text = _display_text
	visible = true


func confirm() -> void:
	confirmed.emit()


func get_display_text() -> String:
	return _display_text


func _ensure_ready() -> void:
	if _title_label == null:
		_build_ui()
