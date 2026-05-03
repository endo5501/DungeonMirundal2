class_name CharacterCreationStep
extends RefCounted

enum StepTransition { STAY, ADVANCE, BACK, CANCEL }


func get_title() -> String:
	return ""


func build(_content: VBoxContainer, _context) -> void:
	pass


func handle_input(_event: InputEvent, _context) -> int:
	return StepTransition.STAY
