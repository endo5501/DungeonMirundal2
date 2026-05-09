extends GutTest


class _StubActor extends CombatActor:
	var _hp: int = 10
	var _max_hp: int = 10
	var _mp: int = 5
	var _max_mp: int = 5
	var _agility: int = 5

	func _init(p_name: String = "Stub", p_hp: int = 10, p_mp: int = 5) -> void:
		actor_name = p_name
		_hp = p_hp
		_max_hp = p_hp
		_mp = p_mp
		_max_mp = p_mp

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max_hp

	func _read_current_mp() -> int:
		return _mp

	func _write_current_mp(value: int) -> void:
		_mp = value

	func _read_max_mp() -> int:
		return _max_mp

	func get_agility() -> int:
		return _agility


func _make_engine(party: Array) -> TurnEngine:
	var engine := TurnEngine.new()
	engine.start_battle(party, [])
	return engine


# 1.1 submit then withdraw removes the entry and breaks completeness
func test_withdraw_removes_pending_command_and_breaks_completeness():
	var actor := _StubActor.new("A")
	var engine := _make_engine([actor])
	var dummy_target := _StubActor.new("T")

	engine.submit_command(0, AttackCommand.new(dummy_target))
	assert_true(engine.are_party_commands_complete(), "complete after submit")

	engine.withdraw_command(0)

	assert_false(engine.has_pending_command(0), "pending entry removed")
	assert_false(engine.are_party_commands_complete(), "completeness flips back to false")


# 1.2 state guard: RESOLVING / FINISHED → no-op
func test_withdraw_outside_command_input_is_noop():
	var actor := _StubActor.new("A")
	var engine := _make_engine([actor])
	var target := _StubActor.new("T")
	engine.submit_command(0, AttackCommand.new(target))

	# Force RESOLVING manually (we don't want to drive a real resolve here).
	engine.state = TurnEngine.State.RESOLVING
	engine.withdraw_command(0)
	assert_true(engine.has_pending_command(0), "RESOLVING: pending unchanged")

	engine.state = TurnEngine.State.FINISHED
	engine.withdraw_command(0)
	assert_true(engine.has_pending_command(0), "FINISHED: pending unchanged")


# 1.3 withdraw on an index without a pending command is a safe no-op
func test_withdraw_on_empty_index_is_safe_noop():
	var actor := _StubActor.new("A")
	var engine := _make_engine([actor])

	# No submit_command for index 0; should not raise.
	engine.withdraw_command(0)
	engine.withdraw_command(99)  # also out-of-range key; dict erase is safe

	assert_false(engine.has_pending_command(0))
	assert_false(engine.has_pending_command(99))


# 1.4 cast submit + withdraw leaves MP unchanged and emits no signals
func test_withdraw_cast_does_not_consume_mp_or_emit_signals():
	var caster := _StubActor.new("Mage", 10, 5)
	var engine := _make_engine([caster])

	watch_signals(engine)

	var cast_cmd := CastCommand.new(&"fire", 0, null)
	engine.submit_command(0, cast_cmd)
	assert_eq(caster.current_mp, 5, "submit_command does not touch MP")

	engine.withdraw_command(0)

	assert_eq(caster.current_mp, 5, "withdraw does not touch MP")
	assert_signal_not_emitted(engine, "actor_action_started")
	assert_signal_not_emitted(engine, "actor_spent_mp")
	assert_signal_not_emitted(engine, "actor_dealt_damage")
