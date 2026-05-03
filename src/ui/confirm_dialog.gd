class_name ConfirmDialog
extends Control

signal confirmed
signal cancelled

func setup(_message: String, _default_index: int = 1) -> void:
	pass

func get_message() -> String:
	return ""

func get_selected_index() -> int:
	return -1
