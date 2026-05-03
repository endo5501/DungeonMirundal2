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

	add_nav_hint(content, "[↑↓] 選択  [Enter] 次へ  [Backspace] 戻る  [Esc] やめる")


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
	return back_or_cancel(event)


func _update_cursor(selected: int) -> void:
	for i in range(_rows.size()):
		_rows[i].set_selected(i == selected)
