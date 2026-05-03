class_name CharacterCreationStep
extends RefCounted

enum StepTransition { STAY, ADVANCE, BACK, CANCEL }

const _HINT_FONT_SIZE := 14
const _HINT_COLOR := Color(0.6, 0.6, 0.6)
const _HINT_TOP_SPACER_PX := 8


func get_title() -> String:
	return ""


func build(_content: VBoxContainer, _context) -> void:
	pass


func handle_input(_event: InputEvent, _context) -> int:
	return StepTransition.STAY


# Shared helpers for subclasses ------------------------------------------

# Adds the standard 8px spacer + dim hint label that every step ends with.
static func add_nav_hint(content: VBoxContainer, text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = _HINT_TOP_SPACER_PX
	content.add_child(spacer)
	var hint := Label.new()
	hint.text = text
	hint.add_theme_font_size_override("font_size", _HINT_FONT_SIZE)
	hint.add_theme_color_override("font_color", _HINT_COLOR)
	content.add_child(hint)


# step_back -> BACK, ui_cancel -> CANCEL. Returns STAY if neither matched.
static func back_or_cancel(event: InputEvent) -> int:
	if event.is_action_pressed("step_back"):
		return StepTransition.BACK
	if event.is_action_pressed("ui_cancel"):
		return StepTransition.CANCEL
	return StepTransition.STAY
