class_name BonusAllocationStep
extends CharacterCreationStep

const FONT_SIZE := 18

var _content: VBoxContainer
var _summary_label: Label
var _rows: Array[CursorMenuRow] = []


func get_title() -> String:
	return "Step 3/5 - ボーナスポイント配分"


func build(content: VBoxContainer, context) -> void:
	_content = content
	_rows = []
	context.set_cursor_index(0)

	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_summary_label.text = _summary_text(context)
	content.add_child(_summary_label)

	var blank := Label.new()
	blank.add_theme_font_size_override("font_size", FONT_SIZE)
	content.add_child(blank)

	for key in Character.STAT_KEYS:
		_rows.append(CursorMenuRow.create(content, "%s: %d" % [key, context.get_stat_value(key)], FONT_SIZE))
	_update_cursor(0)

	add_nav_hint(content, "[↑↓] 選択  [→] +1  [←] -1  [R] 振り直し  [Enter] 次へ  [Backspace] 戻る  [Esc] やめる")


func handle_input(event: InputEvent, context) -> int:
	var count: int = Character.STAT_KEYS.size()
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
	if event.is_action_pressed("ui_right"):
		context.increment_stat(Character.STAT_KEYS[context.get_cursor_index()])
		_refresh(context)
		return StepTransition.STAY
	if event.is_action_pressed("ui_left"):
		context.decrement_stat(Character.STAT_KEYS[context.get_cursor_index()])
		_refresh(context)
		return StepTransition.STAY
	if event.is_action_pressed("reroll_stats"):
		context.reroll_bonus()
		_refresh(context)
		return StepTransition.STAY
	if event.is_action_pressed("ui_accept"):
		if context.get_remaining_points() == 0:
			return StepTransition.ADVANCE
		return StepTransition.STAY
	return back_or_cancel(event)


func _refresh(context) -> void:
	_summary_label.text = _summary_text(context)
	for i in range(Character.STAT_KEYS.size()):
		var key: StringName = Character.STAT_KEYS[i]
		_rows[i].set_text("%s: %d" % [key, context.get_stat_value(key)])
	_update_cursor(context.get_cursor_index())


func _update_cursor(selected: int) -> void:
	for i in range(_rows.size()):
		_rows[i].set_selected(i == selected)


func _summary_text(context) -> String:
	return "ボーナスポイント: %d  残り: %d" % [context.get_bonus_total(), context.get_remaining_points()]
