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


# --- 4.x: delta on shake / flash / mp_spend events ---

func test_dealt_damage_queue_entry_carries_negative_delta():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	hud.begin_buffering()
	engine._resolve_report = TurnReport.new()
	engine.actor_dealt_damage.emit(pc, 7, null)
	assert_eq(hud._event_queue.size(), 1)
	var ev: Dictionary = hud._event_queue[0]
	assert_eq(String(ev.get("type", "")), "shake")
	assert_eq(int(ev.get("delta", 999)), -7)
	assert_eq(int(ev.get("step", -1)), 0)


func test_healed_queue_entry_carries_positive_delta():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	hud.begin_buffering()
	engine._resolve_report = TurnReport.new()
	engine.actor_healed.emit(pc, 5, null)
	assert_eq(hud._event_queue.size(), 1)
	var ev: Dictionary = hud._event_queue[0]
	assert_eq(String(ev.get("type", "")), "flash")
	assert_eq(int(ev.get("delta", -999)), 5)


func test_actor_spent_mp_signal_is_subscribed():
	var setup := _setup_party_with_one_member()
	var _pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([setup[1]], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	assert_true(engine.actor_spent_mp.is_connected(hud._on_actor_spent_mp))


func test_spent_mp_queue_entry_carries_negative_delta():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	hud.begin_buffering()
	engine._resolve_report = TurnReport.new()
	engine.actor_spent_mp.emit(pc, 4)
	assert_eq(hud._event_queue.size(), 1)
	var ev: Dictionary = hud._event_queue[0]
	assert_eq(String(ev.get("type", "")), "mp_spend")
	assert_eq(int(ev.get("delta", 999)), -4)
	assert_eq(int(ev.get("step", -1)), 0)


# --- 4.x: flush applies delta then plays animation ---

func test_flush_shake_applies_hp_delta_then_plays_animation():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := _front_panel(0)
	# bind_combat_actor latched displayed_hp from pc.current_hp; record it.
	var hp_before: int = panel._combat_displayed_hp
	var before_shake = panel._active_shake_tween
	hud.begin_buffering()
	engine._resolve_report = TurnReport.new()
	engine.actor_dealt_damage.emit(pc, 3, null)
	hud.flush_up_to_step(0)
	assert_eq(panel._combat_displayed_hp, hp_before - 3,
		"apply_combat_hp_delta must reduce displayed HP by amount")
	assert_ne(panel._active_shake_tween, before_shake,
		"shake animation must fire after delta is applied")


func test_flush_flash_applies_hp_delta_then_plays_animation():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := _front_panel(0)
	# Set displayed HP low so heal delta visibly increases it.
	panel.set_combat_displayed_hp(2)
	var before_flash = panel._active_flash_tween
	hud.begin_buffering()
	engine._resolve_report = TurnReport.new()
	engine.actor_healed.emit(pc, 4, null)
	hud.flush_up_to_step(0)
	assert_eq(panel._combat_displayed_hp, 6,
		"apply_combat_hp_delta must increase displayed HP by amount")
	assert_ne(panel._active_flash_tween, before_flash,
		"flash animation must fire after delta is applied")


func test_flush_mp_spend_applies_mp_delta_with_no_extra_animation():
	var setup := _setup_party_with_one_member()
	var ch: Character = setup[0]
	ch.max_mp = 10
	ch.current_mp = 5
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := _front_panel(0)
	# bind_combat_actor latched displayed_mp = 5 from the live MP.
	var before_shake = panel._active_shake_tween
	var before_flash = panel._active_flash_tween
	var before_lift = panel._active_lift_tween
	hud.begin_buffering()
	engine._resolve_report = TurnReport.new()
	engine.actor_spent_mp.emit(pc, 2)
	hud.flush_up_to_step(0)
	assert_eq(panel._combat_displayed_mp, 3,
		"apply_combat_mp_delta must reduce displayed MP by cost")
	assert_same(panel._active_shake_tween, before_shake, "no shake on mp_spend")
	assert_same(panel._active_flash_tween, before_flash, "no flash on mp_spend")
	assert_same(panel._active_lift_tween, before_lift, "no lift on mp_spend")


func test_flush_die_zeroes_displayed_hp_then_fades():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := _front_panel(0)
	# Suppose previous shakes already left displayed_hp positive.
	panel.set_combat_displayed_hp(2)
	var before_die = panel._active_die_tween
	hud.begin_buffering()
	engine._resolve_report = TurnReport.new()
	engine.actor_died.emit(pc)
	hud.flush_up_to_step(0)
	assert_eq(panel._combat_displayed_hp, 0,
		"die flush must zero displayed HP before fading")
	assert_ne(panel._active_die_tween, before_die,
		"play_die_animation must fire after displayed HP is zeroed")


func test_non_buffering_spent_mp_applies_delta_immediately():
	var setup := _setup_party_with_one_member()
	var ch: Character = setup[0]
	ch.max_mp = 10
	ch.current_mp = 5
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([pc], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := _front_panel(0)
	# bind_combat_actor latched displayed_mp = 5.
	# No begin_buffering — direct emit must apply immediately.
	engine.actor_spent_mp.emit(pc, 2)
	assert_eq(panel._combat_displayed_mp, 3)


func test_detach_disconnects_actor_spent_mp():
	var setup := _setup_party_with_one_member()
	var _pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle([setup[1]], [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	hud.detach_from_turn_engine()
	assert_false(engine.actor_spent_mp.is_connected(hud._on_actor_spent_mp))


# --- 6.x: monster panel bridging ---

func _make_monster_data() -> MonsterData:
	var d := MonsterData.new()
	d.monster_id = &"goblin"
	d.monster_name = "ゴブリン"
	d.max_hp_min = 5
	d.max_hp_max = 5
	d.attack = 1
	d.defense = 0
	d.agility = 1
	return d


func _make_monster() -> MonsterCombatant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	return MonsterCombatant.new(Monster.new(_make_monster_data(), rng))


func test_party_hud_exposes_monster_panel_api():
	var hud := _hud()
	assert_true(hud.has_method("attach_monster_panel"))
	assert_true(hud.has_method("detach_monster_panel"))


func test_buffered_monster_die_queues_event_and_flushes_via_apply_died():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	var mc := _make_monster()
	engine.start_battle([pc], [mc])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := CombatMonsterPanel.new()
	add_child_autofree(panel)
	panel.setup_for_battle([mc])
	hud.attach_monster_panel(panel)
	hud.begin_buffering()
	engine._resolve_report = TurnReport.new()
	engine.actor_died.emit(mc)
	# Before flush: still alive in display.
	assert_true(panel._displayed_alive.get(mc, false), "monster must remain alive until flushed")
	hud.flush_up_to_step(0)
	assert_false(panel._displayed_alive.get(mc, true),
		"flush_up_to_step must invoke apply_died on the attached monster panel")


func test_unbuffered_monster_die_applies_immediately():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	var mc := _make_monster()
	engine.start_battle([pc], [mc])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	var panel := CombatMonsterPanel.new()
	add_child_autofree(panel)
	panel.setup_for_battle([mc])
	hud.attach_monster_panel(panel)
	# No begin_buffering — direct emit must apply immediately.
	engine.actor_died.emit(mc)
	assert_false(panel._displayed_alive.get(mc, true),
		"unbuffered monster actor_died must call apply_died synchronously")


func test_monster_die_without_attached_panel_is_noop():
	var setup := _setup_party_with_one_member()
	var pc: CombatActor = setup[1]
	var engine := TurnEngine.new()
	var mc := _make_monster()
	engine.start_battle([pc], [mc])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	# No attach_monster_panel — should not crash.
	engine.actor_died.emit(mc)
	# If we reach here without error the no-op path worked.
	assert_true(true)


func test_detach_clears_attached_monster_panel():
	var hud := _hud()
	var panel := CombatMonsterPanel.new()
	add_child_autofree(panel)
	hud.attach_monster_panel(panel)
	# attach_to_turn_engine is required so detach_from_turn_engine actually runs.
	var engine := TurnEngine.new()
	engine.start_battle([_setup_party_with_one_member()[1]], [_MonsterStub.new()])
	hud.attach_to_turn_engine(engine)
	hud.detach_from_turn_engine()
	assert_null(hud._attached_monster_panel,
		"detach_from_turn_engine must release the attached monster panel reference")
