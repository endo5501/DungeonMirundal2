extends CanvasLayer

# PartyHud is registered as the `PartyHud` autoload in project.godot. It owns
# a single PartyDisplay child throughout the game session and exposes
# show_hud() / hide_hud() to toggle visibility from screen-transition code.

var _party_display: PartyDisplay
var _bound_guild: Guild


func _ready() -> void:
	_party_display = PartyDisplay.new()
	add_child(_party_display)


func show_hud() -> void:
	visible = true


func hide_hud() -> void:
	visible = false


func get_party_display() -> PartyDisplay:
	return _party_display


# Pull the active party from GameState.guild into the internal PartyDisplay
# and (re)connect to the guild's active_party_changed signal. Safe when
# GameState.guild is null. PartyMemberPanel.bind_character is identity-
# idempotent, so re-binding all 6 panels per signal is cheap.
func bind_active_party() -> void:
	if _party_display == null:
		return
	var guild: Guild = GameState.guild
	_ensure_subscribed(guild)
	if guild == null:
		_party_display.bind_party_characters([null, null, null], [null, null, null])
		return
	var rows := guild.get_party_characters()
	_party_display.bind_party_characters(rows[0], rows[1])


func _ensure_subscribed(guild: Guild) -> void:
	if _bound_guild == guild:
		return
	if _bound_guild != null and _bound_guild.active_party_changed.is_connected(_on_active_party_changed):
		_bound_guild.active_party_changed.disconnect(_on_active_party_changed)
	_bound_guild = guild
	if guild != null:
		guild.active_party_changed.connect(_on_active_party_changed)


func _on_active_party_changed() -> void:
	bind_active_party()
