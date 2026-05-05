extends GutTest

# PartyHud buffering: while begin_buffering() is active, signal handlers
# queue events keyed by the engine's pending-action-index (i.e., the index
# in report.actions where the related log entry will land). flush_up_to_step
# releases events whose step is ≤ the current displayed log index, so HUD
# animations track log playback instead of bunching up at turn start.


var _saved_guild: Guild


func before_each() -> void:
	_saved_guild = GameState.guild
	GameState.guild = Guild.new()


func after_each() -> void:
	var hud := _hud()
	if hud != null and hud.has_method("detach_from_turn_engine"):
		hud.detach_from_turn_engine()
	GameState.guild = _saved_guild


func _hud() -> Node:
	return TestHelpers.get_party_hud()


class _MonsterStub extends CombatActor:
	func _init() -> void:
		super()
		actor_name = "M"

	func _read_current_hp() -> int:
		return 5

	func _write_current_hp(_v: int) -> void:
		pass

	func _read_max_hp() -> int:
		return 5


func _setup_party_with_one_member() -> Array:
	var guild: Guild = GameState.guild
	var f0 := TestHelpers.make_test_character("F0")
	guild.register(f0)
	guild.assign_to_party(f0, 0, 0)
	var hud := _hud()
	hud.bind_active_party()
	var pc := PartyCombatant.new(f0, DummyEquipmentProvider.new())
	return [f0, pc]


func _front_panel(idx: int) -> PartyMemberPanel:
	return _hud().get_party_display()._front_panels[idx]


# --- API exists ---

func test_party_hud_exposes_buffering_api():
	var hud := _hud()
	assert_true(hud.has_method("begin_buffering"))
	assert_true(hud.has_method("end_buffering"))
	assert_true(hud.has_method("flush_up_to_step"))


# --- engine exposes pending action index ---

func test_engine_get_pending_action_index_returns_minus_one_outside_resolve():
	var engine := TurnEngine.new()
	assert_eq(engine.get_pending_action_index(), -1)


# --- buffering defers immediate animation ---

func test_action_started_does_not_play_lift_immediately_while_buffering():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	# Snapshot tween state, then begin buffering and emit.
	var panel := _front_panel(0)
	var before_lift = panel._active_lift_tween
	hud.begin_buffering()
	# Need a live report so PartyHud can capture a step.
	engine._resolve_report = TurnReport.new()
	engine.actor_action_started.emit(pc, &"attack")
	assert_same(panel._active_lift_tween, before_lift,
		"lift must NOT fire while buffering")


# --- flush releases queued events ---

func test_flush_up_to_step_releases_lift():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := _front_panel(0)
	var before_lift = panel._active_lift_tween
	hud.begin_buffering()
	engine._resolve_report = TurnReport.new()
	# Step is 0 because no actions in the report yet.
	engine.actor_action_started.emit(pc, &"attack")
	# step=0 event should fire after flush_up_to_step(0).
	hud.flush_up_to_step(0)
	assert_ne(panel._active_lift_tween, before_lift,
		"lift should fire after flush_up_to_step(0)")


func test_flush_up_to_step_does_not_release_higher_steps():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := _front_panel(0)
	var before_lift = panel._active_lift_tween
	hud.begin_buffering()
	engine._resolve_report = TurnReport.new()
	engine._resolve_report.actions.append({"type": "previous"})  # bumps index to 1
	engine.actor_action_started.emit(pc, &"attack")  # step = 1
	# Flushing only step <= 0 should not release this event.
	hud.flush_up_to_step(0)
	assert_same(panel._active_lift_tween, before_lift,
		"step=1 event must not fire on flush_up_to_step(0)")
	# Now flush step <= 1.
	hud.flush_up_to_step(1)
	assert_ne(panel._active_lift_tween, before_lift,
		"step=1 event should fire on flush_up_to_step(1)")


# --- end_buffering flushes remainder ---

func test_end_buffering_flushes_all_pending_events():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := _front_panel(0)
	var before_die = panel._active_die_tween
	hud.begin_buffering()
	engine._resolve_report = TurnReport.new()
	engine._resolve_report.actions.append({"type": "x"})
	engine._resolve_report.actions.append({"type": "y"})
	engine.actor_died.emit(pc)  # step = 2
	# Even though step is 2, end_buffering must flush regardless.
	hud.end_buffering()
	assert_ne(panel._active_die_tween, before_die,
		"end_buffering should flush the queued die event")


# --- non-buffering path stays immediate ---

func test_non_buffering_signals_play_immediately():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	# No begin_buffering. Direct emit should fire animation immediately.
	var panel := _front_panel(0)
	var before_lift = panel._active_lift_tween
	engine.actor_action_started.emit(pc, &"attack")
	assert_ne(panel._active_lift_tween, before_lift)


# --- damage / heal animations route through PartyHud ---

func test_dealt_damage_triggers_panel_shake_via_hud():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := _front_panel(0)
	var before_shake = panel._active_shake_tween
	# Non-buffering → should be immediate.
	engine.actor_dealt_damage.emit(pc, 3, null)
	assert_ne(panel._active_shake_tween, before_shake,
		"actor_dealt_damage must drive panel shake via PartyHud")


func test_actor_healed_triggers_panel_flash_via_hud():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := _front_panel(0)
	var before_flash = panel._active_flash_tween
	engine.actor_healed.emit(pc, 5, null)
	assert_ne(panel._active_flash_tween, before_flash,
		"actor_healed must drive panel heal flash via PartyHud")


# --- panel suppresses hp_changed-driven animation while bound to combat actor ---

func test_panel_suppresses_hp_changed_shake_during_combat_binding():
	var setup := _setup_party_with_one_member()
	var ch: Character = setup[0]
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	# Panel is now bound to a CombatActor (combat mode).
	var panel := _front_panel(0)
	var before_shake = panel._active_shake_tween
	# Mutate Character HP directly — would normally drive shake via hp_changed.
	ch.current_hp = ch.current_hp - 1
	assert_same(panel._active_shake_tween, before_shake,
		"panel must NOT shake from hp_changed while a CombatActor is bound")
