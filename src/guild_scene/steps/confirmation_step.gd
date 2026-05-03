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

	add_nav_hint(content, "[Enter] 作成  [Backspace] 戻る  [Esc] やめる")


func handle_input(event: InputEvent, _context) -> int:
	if event.is_action_pressed("ui_accept"):
		return StepTransition.ADVANCE
	return back_or_cancel(event)


func _add_label(content: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	content.add_child(label)
