extends CanvasLayer

# PartyHud is registered as the `PartyHud` autoload in project.godot. It owns
# a single PartyDisplay child throughout the game session and exposes
# show_hud() / hide_hud() to toggle visibility from screen-transition code.

var _party_display: PartyDisplay


func _ready() -> void:
	_party_display = PartyDisplay.new()
	add_child(_party_display)


func show_hud() -> void:
	visible = true


func hide_hud() -> void:
	visible = false


func get_party_display() -> PartyDisplay:
	return _party_display
