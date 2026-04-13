class_name GuildTestEntry
extends Control

func _ready() -> void:
	var screen := GuildScreen.new()
	screen.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(screen)
