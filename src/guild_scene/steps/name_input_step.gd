class_name NameInputStep
extends CharacterCreationStep

const FONT_SIZE := 18

var _name_edit: LineEdit


func get_title() -> String:
	return "Step 1/5 - 名前入力"


func build(content: VBoxContainer, context) -> void:
	var label := Label.new()
	label.text = "名前を入力してください:"
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	content.add_child(label)

	_name_edit = LineEdit.new()
	_name_edit.text = context.get_name_input()
	_name_edit.custom_minimum_size.x = 200
	_name_edit.text_changed.connect(func(t: String): context.set_name_input(t))
	_name_edit.text_submitted.connect(func(t: String): context.submit_name(t))
	content.add_child(_name_edit)
	_name_edit.grab_focus()

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	content.add_child(spacer)
	var hint := Label.new()
	hint.text = "[Enter] 次へ  [Esc] やめる"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	content.add_child(hint)


func handle_input(event: InputEvent, _context) -> int:
	if event.is_action_pressed("ui_cancel"):
		return StepTransition.CANCEL
	if event.is_action_pressed("ui_accept"):
		if _name_edit != null and not _name_edit.has_focus():
			_name_edit.grab_focus()
		return StepTransition.STAY
	return StepTransition.STAY


func get_line_edit() -> LineEdit:
	return _name_edit
