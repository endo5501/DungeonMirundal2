extends CanvasLayer

# PartyHud is registered as the `PartyHud` autoload in project.godot. It owns
# a single PartyDisplay child throughout the game session and exposes
# show_hud() / hide_hud() to toggle visibility from screen-transition code.
#
# During combat, encounter overlay code calls attach_to_turn_engine(engine) so
# the HUD subscribes to UI signals and routes them to the matching
# PartyMemberPanel. detach_from_turn_engine() is called when combat ends to
# release the engine reference.

# Event queue type tags. Constants prevent typos between the producer
# (handlers) and consumer (_play_event match) silently dropping events.
const EVT_LIFT: StringName = &"lift"
const EVT_SHAKE: StringName = &"shake"
const EVT_FLASH: StringName = &"flash"
const EVT_MP_SPEND: StringName = &"mp_spend"
const EVT_DIE: StringName = &"die"
const EVT_REDRAW: StringName = &"redraw"

var _party_display: PartyDisplay
var _bound_guild: Guild
var _attached_engine: TurnEngine = null
var _attached_monster_panel: CombatMonsterPanel = null

# Buffering machinery (combat-party-reactions §D10): while begin_buffering()
# is active, signal handlers queue events tagged with the engine's pending
# action index so CombatOverlay can release them in lockstep with log line
# playback. Outside the begin/end window, handlers fire immediately.
var _is_buffering: bool = false
var _event_queue: Array = []  # [{ "type": StringName, "actor": CombatActor, "delta": int?, "step": int }, ...]


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


# --- combat hookup ---

func attach_to_turn_engine(engine: TurnEngine) -> void:
	if engine == null:
		return
	if _attached_engine != null:
		detach_from_turn_engine()
	_attached_engine = engine
	engine.actor_action_started.connect(_on_actor_action_started)
	engine.actor_dealt_damage.connect(_on_actor_dealt_damage)
	engine.actor_healed.connect(_on_actor_healed)
	engine.actor_died.connect(_on_actor_died)
	engine.actor_status_inflicted.connect(_on_actor_status_inflicted)
	engine.actor_spent_mp.connect(_on_actor_spent_mp)
	for pc in engine.party:
		var panel: PartyMemberPanel = _find_panel_for_combat_actor(pc)
		if panel != null:
			panel.bind_combat_actor(pc)


func detach_from_turn_engine() -> void:
	if _attached_engine == null:
		return
	# Drain any pending buffered events before tearing down so we don't strand
	# animations the player would otherwise have seen.
	end_buffering()
	var e := _attached_engine
	if e.actor_action_started.is_connected(_on_actor_action_started):
		e.actor_action_started.disconnect(_on_actor_action_started)
	if e.actor_dealt_damage.is_connected(_on_actor_dealt_damage):
		e.actor_dealt_damage.disconnect(_on_actor_dealt_damage)
	if e.actor_healed.is_connected(_on_actor_healed):
		e.actor_healed.disconnect(_on_actor_healed)
	if e.actor_died.is_connected(_on_actor_died):
		e.actor_died.disconnect(_on_actor_died)
	if e.actor_status_inflicted.is_connected(_on_actor_status_inflicted):
		e.actor_status_inflicted.disconnect(_on_actor_status_inflicted)
	if e.actor_spent_mp.is_connected(_on_actor_spent_mp):
		e.actor_spent_mp.disconnect(_on_actor_spent_mp)
	detach_monster_panel()
	_attached_engine = null
	if _party_display == null:
		return
	for panel in _all_panels():
		panel.bind_combat_actor(null)


func _all_panels() -> Array:
	if _party_display == null:
		return []
	return _party_display._front_panels + _party_display._back_panels


func _find_panel_for_combat_actor(actor) -> PartyMemberPanel:
	if actor == null or _party_display == null:
		return null
	if not (actor is PartyCombatant):
		return null
	var ch: Character = (actor as PartyCombatant).character
	for panel in _all_panels():
		if (panel as PartyMemberPanel)._character == ch:
			return panel
	return null


# --- monster panel bridging ---

func attach_monster_panel(panel: CombatMonsterPanel) -> void:
	_attached_monster_panel = panel


func detach_monster_panel() -> void:
	_attached_monster_panel = null


# --- buffering API ---

# CombatOverlay calls begin_buffering before resolve_turn so signal-driven
# animations are deferred and replayed in sync with log line playback.
func begin_buffering() -> void:
	_is_buffering = true
	_event_queue.clear()


# Release every queued event whose step ≤ `step`. CombatOverlay calls this
# with the index of the log line about to be (or just) displayed.
func flush_up_to_step(step: int) -> void:
	while not _event_queue.is_empty():
		var ev: Dictionary = _event_queue[0]
		if int(ev.get("step", -1)) > step:
			break
		_event_queue.pop_front()
		_play_event(ev)


# Drain whatever is left and exit buffering mode. Idempotent.
func end_buffering() -> void:
	while not _event_queue.is_empty():
		var ev: Dictionary = _event_queue.pop_front()
		_play_event(ev)
	_is_buffering = false


func _emit_step() -> int:
	if _attached_engine != null and _attached_engine.has_method("get_pending_action_index"):
		var idx: int = _attached_engine.get_pending_action_index()
		if idx >= 0:
			return idx
	return 0


func _play_event(ev: Dictionary) -> void:
	var actor = ev.get("actor")
	var delta: int = int(ev.get("delta", 0))
	var type: StringName = ev.get("type", &"")
	# Monster die is the only event that doesn't target a PartyMemberPanel,
	# so it's resolved before the panel lookup.
	if type == EVT_DIE and not (actor is PartyCombatant):
		if _attached_monster_panel != null and actor != null:
			_attached_monster_panel.apply_died(actor)
		return
	var panel: PartyMemberPanel = _find_panel_for_combat_actor(actor)
	if panel == null:
		return
	match type:
		EVT_LIFT:
			panel.play_lift_animation()
		EVT_SHAKE:
			panel.apply_combat_hp_delta(delta)
			panel.play_shake_animation()
		EVT_FLASH:
			panel.apply_combat_hp_delta(delta)
			panel.play_heal_flash_animation()
		EVT_MP_SPEND:
			panel.apply_combat_mp_delta(delta)
		EVT_DIE:
			# Zero displayed HP first so the faded panel never shows a positive bar.
			panel.set_combat_displayed_hp(0)
			panel.play_die_animation()
		EVT_REDRAW:
			panel.queue_redraw()


# --- signal handlers ---

func _on_actor_action_started(actor: CombatActor, _kind: StringName) -> void:
	if _is_buffering:
		_event_queue.append({"type": EVT_LIFT, "actor": actor, "step": _emit_step()})
	else:
		_play_event({"type": EVT_LIFT, "actor": actor})


func _on_actor_died(actor: CombatActor) -> void:
	if _is_buffering:
		_event_queue.append({"type": EVT_DIE, "actor": actor, "step": _emit_step()})
	else:
		_play_event({"type": EVT_DIE, "actor": actor})


func _on_actor_dealt_damage(target: CombatActor, amount: int, _source: CombatActor) -> void:
	var ev := {"type": EVT_SHAKE, "actor": target, "delta": -amount}
	if _is_buffering:
		ev["step"] = _emit_step()
		_event_queue.append(ev)
	else:
		_play_event(ev)


func _on_actor_healed(target: CombatActor, amount: int, _source: CombatActor) -> void:
	var ev := {"type": EVT_FLASH, "actor": target, "delta": amount}
	if _is_buffering:
		ev["step"] = _emit_step()
		_event_queue.append(ev)
	else:
		_play_event(ev)


func _on_actor_spent_mp(actor: CombatActor, cost: int) -> void:
	var ev := {"type": EVT_MP_SPEND, "actor": actor, "delta": -cost}
	if _is_buffering:
		ev["step"] = _emit_step()
		_event_queue.append(ev)
	else:
		_play_event(ev)


# Persistent statuses are committed at battle end so the panel's icon row
# reflects only post-battle state. We still queue a redraw on inflict so any
# future per-status combat icon work has a hook.
func _on_actor_status_inflicted(actor: CombatActor, _status_id: StringName) -> void:
	if _is_buffering:
		_event_queue.append({"type": EVT_REDRAW, "actor": actor, "step": _emit_step()})
	else:
		_play_event({"type": EVT_REDRAW, "actor": actor})
