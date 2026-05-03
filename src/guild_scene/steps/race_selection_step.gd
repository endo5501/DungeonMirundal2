class_name RaceSelectionStep
extends CharacterCreationStep

const FONT_SIZE := 18

var _rows: Array[CursorMenuRow] = []
var _content: VBoxContainer


func get_title() -> String:
	return "Step 2/5 - 種族選択"


func build(content: VBoxContainer, context) -> void:
	_content = content
	_rows = []
	context.set_cursor_index(0)
	var races: Array[RaceData] = context.get_available_races()
	for race in races:
		var stats := race.get_base_stats()
		var text := "%s  STR:%d INT:%d PIE:%d VIT:%d AGI:%d LUC:%d" % [
			race.race_name, stats[&"STR"], stats[&"INT"], stats[&"PIE"],
			stats[&"VIT"], stats[&"AGI"], stats[&"LUC"]]
		_rows.append(CursorMenuRow.create(content, text, FONT_SIZE))
	if context.get_selected_race_index() >= 0:
		context.set_cursor_index(context.get_selected_race_index())
	_update_cursor(context.get_cursor_index())

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	content.add_child(spacer)
	var hint := Label.new()
	hint.text = "[↑↓] 選択  [Enter] 次へ  [Backspace] 戻る  [Esc] やめる"
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
		context.select_race(context.get_cursor_index())
		return StepTransition.ADVANCE
	if event.is_action_pressed("step_back"):
		return StepTransition.BACK
	if event.is_action_pressed("ui_cancel"):
		return StepTransition.CANCEL
	return StepTransition.STAY


func _update_cursor(selected: int) -> void:
	for i in range(_rows.size()):
		_rows[i].set_selected(i == selected)
