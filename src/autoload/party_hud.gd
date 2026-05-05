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


# Read the current active party from GameState.guild and forward it to the
# internal PartyDisplay. Empty slots are passed through as nulls so the
# corresponding PartyMemberPanel renders nothing. Safe to call when
# GameState.guild is null (no-op).
func bind_active_party() -> void:
	if _party_display == null:
		return
	var guild: Guild = GameState.guild
	if guild == null:
		_party_display.bind_party_characters([null, null, null], [null, null, null])
		return
	var rows := guild.get_party_characters()
	_party_display.bind_party_characters(rows[0], rows[1])
