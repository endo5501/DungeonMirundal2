class_name ConfirmationStep
extends CharacterCreationStep

const FONT_SIZE := 18


func get_title() -> String:
	return "Step 5/5 - 確認"


func build(content: VBoxContainer, context) -> void:
	var s: Dictionary = context.get_summary()
	if s.is_empty():
		_add_label(content, "エラー: キャラクターを作成できません")
		return
	_add_label(content, "名前: %s" % s["name"])
	_add_label(content, "種族: %s    職業: %s" % [s["race"].race_name, s["job"].job_name])
	_add_label(content, "LV: %d    HP: %d    MP: %d" % [s["level"], s["hp"], s["mp"]])
	_add_label(content, "")
	var st: Dictionary = s["stats"]
	_add_label(content, "STR:%d  INT:%d  PIE:%d" % [st[&"STR"], st[&"INT"], st[&"PIE"]])
	_add_label(content, "VIT:%d  AGI:%d  LUC:%d" % [st[&"VIT"], st[&"AGI"], st[&"LUC"]])
	_add_label(content, "")
	_add_label(content, "この内容で作成しますか？")

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	content.add_child(spacer)
	var hint := Label.new()
	hint.text = "[Enter] 作成  [Backspace] 戻る  [Esc] やめる"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	content.add_child(hint)


func handle_input(event: InputEvent, _context) -> int:
	if event.is_action_pressed("ui_accept"):
		return StepTransition.ADVANCE
	if event.is_action_pressed("step_back"):
		return StepTransition.BACK
	if event.is_action_pressed("ui_cancel"):
		return StepTransition.CANCEL
	return StepTransition.STAY


func _add_label(content: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	content.add_child(label)
