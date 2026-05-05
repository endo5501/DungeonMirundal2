extends GutTest

# PartyHud.attach_to_turn_engine wires the engine's UI signals to handlers
# that route events to the matching PartyMemberPanel based on actor.character,
# binds each PartyCombatant to the corresponding panel for stat-modifier
# rendering, and detaches cleanly when combat ends or the engine is replaced.


var _saved_guild: Guild


func before_each() -> void:
	_saved_guild = GameState.guild
	GameState.guild = Guild.new()


func after_each() -> void:
	# Make sure attach state is cleared between tests so a leaked attach
	# can't poison the next case.
	var hud := _hud()
	if hud != null and hud.has_method("detach_from_turn_engine"):
		hud.detach_from_turn_engine()
	GameState.guild = _saved_guild


func _hud() -> Node:
	return TestHelpers.get_party_hud()


# Build a guild with 3 front-row characters and bind PartyHud to it; returns
# the (front_row_characters, party_combatants) used by the test.
func _setup_party_with_three_members() -> Array:
	var guild: Guild = GameState.guild
	var f0 := TestHelpers.make_test_character("F0")
	var f1 := TestHelpers.make_test_character("F1")
	var f2 := TestHelpers.make_test_character("F2")
	guild.register(f0); guild.register(f1); guild.register(f2)
	guild.assign_to_party(f0, 0, 0)
	guild.assign_to_party(f1, 0, 1)
	guild.assign_to_party(f2, 0, 2)
	var hud := _hud()
	hud.bind_active_party()

	var pcs: Array = [
		PartyCombatant.new(f0, DummyEquipmentProvider.new()),
		PartyCombatant.new(f1, DummyEquipmentProvider.new()),
		PartyCombatant.new(f2, DummyEquipmentProvider.new()),
	]
	return [[f0, f1, f2], pcs]


class _MonsterStub extends CombatActor:
	func _init() -> void:
		super()
		actor_name = "M1"

	func _read_current_hp() -> int:
		return 5

	func _write_current_hp(_v: int) -> void:
		pass

	func _read_max_hp() -> int:
		return 5


# --- API exists ---

func test_party_hud_exposes_attach_and_detach():
	var hud := _hud()
	assert_true(hud.has_method("attach_to_turn_engine"))
	assert_true(hud.has_method("detach_from_turn_engine"))


# --- attach connects the five signals ---

func test_attach_connects_all_five_signals():
	var setup := _setup_party_with_three_members()
	var pcs: Array = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle(pcs, [_MonsterStub.new()])
	_hud().attach_to_turn_engine(engine)
	# The PartyHud handlers are private — we can't reference them by name
	# without coupling to internals. Instead assert connection_count > 0 for
	# each signal: the only listener PartyHud adds is its own handler.
	assert_gt(engine.actor_action_started.get_connections().size(), 0)
	assert_gt(engine.actor_dealt_damage.get_connections().size(), 0)
	assert_gt(engine.actor_healed.get_connections().size(), 0)
	assert_gt(engine.actor_died.get_connections().size(), 0)
	assert_gt(engine.actor_status_inflicted.get_connections().size(), 0)


# --- attach binds each PartyCombatant to its matching panel ---

func test_attach_binds_combat_actors_to_panels_by_character():
	var setup := _setup_party_with_three_members()
	var pcs: Array = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle(pcs, [_MonsterStub.new()])
	_hud().attach_to_turn_engine(engine)
	var pd: PartyDisplay = _hud().get_party_display()
	for i in range(3):
		var panel: PartyMemberPanel = pd._front_panels[i]
		assert_same(panel._combat_actor, pcs[i],
			"front[%d] should be bound to pcs[%d]" % [i, i])


# --- routing ---

func test_action_started_routes_to_matching_panel_lift():
	var setup := _setup_party_with_three_members()
	var pcs: Array = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle(pcs, [_MonsterStub.new()])
	_hud().attach_to_turn_engine(engine)
	var pd: PartyDisplay = _hud().get_party_display()
	var target_panel: PartyMemberPanel = pd._front_panels[1]
	assert_null(target_panel._active_lift_tween)
	engine.actor_action_started.emit(pcs[1], &"attack")
	assert_not_null(target_panel._active_lift_tween)
	# Other panels should be untouched.
	assert_null(pd._front_panels[0]._active_lift_tween)
	assert_null(pd._front_panels[2]._active_lift_tween)


func test_actor_died_routes_to_matching_panel_die():
	var setup := _setup_party_with_three_members()
	var pcs: Array = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle(pcs, [_MonsterStub.new()])
	_hud().attach_to_turn_engine(engine)
	var pd: PartyDisplay = _hud().get_party_display()
	var target_panel: PartyMemberPanel = pd._front_panels[2]
	assert_null(target_panel._active_die_tween)
	engine.actor_died.emit(pcs[2])
	assert_not_null(target_panel._active_die_tween)


func test_monster_signals_do_not_touch_any_panel():
	var setup := _setup_party_with_three_members()
	var pcs: Array = setup[1]
	var monster := _MonsterStub.new()
	var engine := TurnEngine.new()
	engine.start_battle(pcs, [monster])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	# Snapshot per-panel Tween references before emitting the monster signals
	# so we can prove none of them changed (the autoload PartyHud carries
	# state from earlier tests, so absolute null assertions are unsafe).
	var pd: PartyDisplay = hud.get_party_display()
	var before_lift := []
	var before_die := []
	for i in range(3):
		before_lift.append(pd._front_panels[i]._active_lift_tween)
		before_die.append(pd._front_panels[i]._active_die_tween)
	engine.actor_action_started.emit(monster, &"attack")
	engine.actor_died.emit(monster)
	for i in range(3):
		assert_same(pd._front_panels[i]._active_lift_tween, before_lift[i],
			"front[%d] lift tween should be unchanged by monster signal" % i)
		assert_same(pd._front_panels[i]._active_die_tween, before_die[i],
			"front[%d] die tween should be unchanged by monster signal" % i)


# --- re-attach detaches the previous engine ---

func test_re_attach_detaches_previous_engine():
	var setup := _setup_party_with_three_members()
	var pcs: Array = setup[1]
	var engine_a := TurnEngine.new()
	engine_a.start_battle(pcs, [_MonsterStub.new()])
	_hud().attach_to_turn_engine(engine_a)
	var engine_b := TurnEngine.new()
	engine_b.start_battle(pcs, [_MonsterStub.new()])
	_hud().attach_to_turn_engine(engine_b)
	# All signals on engine_a must now be free of PartyHud connections.
	assert_eq(engine_a.actor_action_started.get_connections().size(), 0)
	assert_eq(engine_a.actor_dealt_damage.get_connections().size(), 0)
	assert_eq(engine_a.actor_healed.get_connections().size(), 0)
	assert_eq(engine_a.actor_died.get_connections().size(), 0)
	assert_eq(engine_a.actor_status_inflicted.get_connections().size(), 0)
	# engine_b carries the new connections.
	assert_gt(engine_b.actor_action_started.get_connections().size(), 0)


# --- detach clears connections AND combat_actor bindings ---

func test_detach_disconnects_all_signals_and_clears_bindings():
	var setup := _setup_party_with_three_members()
	var pcs: Array = setup[1]
	var engine := TurnEngine.new()
	engine.start_battle(pcs, [_MonsterStub.new()])
	var hud := _hud()
	hud.attach_to_turn_engine(engine)
	hud.detach_from_turn_engine()
	assert_eq(engine.actor_action_started.get_connections().size(), 0)
	assert_eq(engine.actor_dealt_damage.get_connections().size(), 0)
	assert_eq(engine.actor_healed.get_connections().size(), 0)
	assert_eq(engine.actor_died.get_connections().size(), 0)
	assert_eq(engine.actor_status_inflicted.get_connections().size(), 0)
	var pd: PartyDisplay = hud.get_party_display()
	for i in range(3):
		assert_null(pd._front_panels[i]._combat_actor,
			"front[%d] combat_actor should be cleared" % i)


func test_detach_when_not_attached_is_a_noop():
	var hud := _hud()
	# No attach beforehand; this must not push errors or crash.
	hud.detach_from_turn_engine()
	pass_test("detach without prior attach did not error")
