extends CanvasLayer

# PartyHud is registered as the `PartyHud` autoload in project.godot. It owns
# a single PartyDisplay child throughout the game session and exposes
# show_hud() / hide_hud() to toggle visibility from screen-transition code.

var _party_display: PartyDisplay
# The Guild instance whose active_party_changed signal we are subscribed to.
# Tracked as a WeakRef so the autoload doesn't keep a stale Guild alive
# across new-game/load-game transitions.
var _bound_guild_ref: WeakRef = null


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
#
# As a side effect, ensure PartyHud is subscribed to the *current* guild's
# active_party_changed signal — so subsequent edits in the formation UI
# automatically refresh the HUD without an explicit caller-side rebind.
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
	var prev: Guild = _bound_guild_ref.get_ref() if _bound_guild_ref != null else null
	if prev == guild:
		return
	if prev != null and prev.active_party_changed.is_connected(_on_active_party_changed):
		prev.active_party_changed.disconnect(_on_active_party_changed)
	if guild != null:
		guild.active_party_changed.connect(_on_active_party_changed)
		_bound_guild_ref = weakref(guild)
	else:
		_bound_guild_ref = null


func _on_active_party_changed(_front_row: Array, _back_row: Array) -> void:
	# Re-pull from GameState rather than relying on signal payload so we keep
	# a single source of truth (mirrors what bind_active_party does directly).
	bind_active_party()
