class_name JobSelectionStep
extends CharacterCreationStep

const FONT_SIZE := 18

var _content: VBoxContainer
var _rows: Array[CursorMenuRow] = []


func get_title() -> String:
	return "Step 4/5 - 職業選択"


func build(content: VBoxContainer, context) -> void:
	_content = content
	_rows = []
	context.set_cursor_index(0)
	var jobs: Array[JobData] = context.get_available_jobs()
	var qualified: Dictionary = context.get_qualified_jobs()
	for i in range(jobs.size()):
		var job := jobs[i]
		var suffix := "  HP:%d  MP:%d" % [job.base_hp, job.base_mp] if job.has_magic else "  HP:%d" % job.base_hp
		var text := job.job_name + suffix
		if not qualified.get(i, false):
			text += "  (条件未達)"
		var row := CursorMenuRow.create(content, text, FONT_SIZE)
		if not qualified.get(i, false):
			row.set_disabled(true)
		_rows.append(row)
	if context.get_selected_job_index() >= 0:
		context.set_cursor_index(context.get_selected_job_index())
	_update_cursor(context.get_cursor_index())

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	content.add_child(spacer)
	var hint := Label.new()
	hint.text = "[↑↓] 選択  [Enter] 決定  [Backspace] 戻る  [Esc] やめる"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	content.add_child(hint)


func handle_input(event: InputEvent, context) -> int:
	var count := _rows.size()
	if count == 0:
		return StepTransition.STAY
	if event.is_action_pressed("ui_down"):
		var i: int = (context.get_cursor_index() + 1) % count
		context.set_cursor_index(i)
		_update_cursor(i)
		return StepTransition.STAY
	if event.is_action_pressed("ui_up"):
		var i: int = (context.get_cursor_index() - 1 + count) % count
		context.set_cursor_index(i)
		_update_cursor(i)
		return StepTransition.STAY
	if event.is_action_pressed("ui_accept"):
		var qualified: Dictionary = context.get_qualified_jobs()
		var idx: int = context.get_cursor_index()
		if qualified.get(idx, false):
			context.select_job(idx)
			return StepTransition.ADVANCE
		return StepTransition.STAY
	if event.is_action_pressed("step_back"):
		return StepTransition.BACK
	if event.is_action_pressed("ui_cancel"):
		return StepTransition.CANCEL
	return StepTransition.STAY


func _update_cursor(selected: int) -> void:
	for i in range(_rows.size()):
		_rows[i].set_selected(i == selected)
