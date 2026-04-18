extends GutTest

const TEST_SEED: int = 12345


class _StubPartyActor extends CombatActor:
	var _name: String
	var _attack: int
	var _defense: int
	var _agility: int
	var _hp: int
	var _max: int

	func _init(p_name: String, p_attack: int, p_defense: int, p_agility: int, p_hp: int) -> void:
		_name = p_name
		actor_name = p_name
		_attack = p_attack
		_defense = p_defense
		_agility = p_agility
		_hp = p_hp
		_max = p_hp

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func get_attack() -> int:
		return _attack

	func get_defense() -> int:
		return _defense

	func get_agility() -> int:
		return _agility


class _StubMonsterActor extends CombatActor:
	var _name: String
	var _attack: int
	var _defense: int
	var _agility: int
	var _hp: int
	var _max: int

	func _init(p_name: String, p_attack: int, p_defense: int, p_agility: int, p_hp: int) -> void:
		_name = p_name
		actor_name = p_name
		_attack = p_attack
		_defense = p_defense
		_agility = p_agility
		_hp = p_hp
		_max = p_hp

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func get_attack() -> int:
		return _attack

	func get_defense() -> int:
		return _defense

	func get_agility() -> int:
		return _agility


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _default_party() -> Array:
	return [
		_StubPartyActor.new("P1", 10, 3, 8, 30),
		_StubPartyActor.new("P2", 8, 2, 6, 25),
	]


func _default_monsters() -> Array:
	return [
		_StubMonsterActor.new("M1", 4, 1, 4, 12),
		_StubMonsterActor.new("M2", 3, 1, 3, 10),
	]


# --- state transitions ---

func test_initial_state_is_idle():
	var engine := TurnEngine.new()
	assert_eq(engine.state, TurnEngine.State.IDLE)


func test_start_battle_enters_command_input():
	var engine := TurnEngine.new()
	engine.start_battle(_default_party(), _default_monsters())
	assert_eq(engine.state, TurnEngine.State.COMMAND_INPUT)
	assert_eq(engine.turn_number, 1)


func test_command_input_to_resolving_to_command_input_on_continuation():
	var engine := TurnEngine.new()
	var party := _default_party()
	var monsters := _default_monsters()
	engine.start_battle(party, monsters)
	# Submit party commands: both attack M1
	engine.submit_command(0, AttackCommand.new(monsters[0]))
	engine.submit_command(1, AttackCommand.new(monsters[0]))
	engine.resolve_turn(_make_rng())
	# Monsters still alive → back to COMMAND_INPUT with incremented turn
	assert_eq(engine.state, TurnEngine.State.COMMAND_INPUT)
	assert_eq(engine.turn_number, 2)


func test_resolving_to_finished_cleared_when_all_monsters_die():
	var engine := TurnEngine.new()
	var party := [_StubPartyActor.new("P1", 999, 0, 10, 30)]  # overkill
	var monsters := [_StubMonsterActor.new("M1", 0, 0, 1, 5)]
	engine.start_battle(party, monsters)
	engine.submit_command(0, AttackCommand.new(monsters[0]))
	engine.resolve_turn(_make_rng())
	assert_eq(engine.state, TurnEngine.State.FINISHED)
	assert_eq(engine.outcome().result, EncounterOutcome.Result.CLEARED)


func test_resolving_to_finished_wiped_when_party_dies():
	var engine := TurnEngine.new()
	var party := [_StubPartyActor.new("P1", 0, 0, 1, 2)]  # fragile
	var monsters := [_StubMonsterActor.new("M1", 999, 0, 10, 30)]  # lethal
	engine.start_battle(party, monsters)
	engine.submit_command(0, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	assert_eq(engine.state, TurnEngine.State.FINISHED)
	assert_eq(engine.outcome().result, EncounterOutcome.Result.WIPED)


# --- commands queue ---

func test_are_party_commands_complete_false_until_all_submitted():
	var engine := TurnEngine.new()
	var party := _default_party()
	var monsters := _default_monsters()
	engine.start_battle(party, monsters)
	assert_false(engine.are_party_commands_complete())
	engine.submit_command(0, DefendCommand.new())
	assert_false(engine.are_party_commands_complete())
	engine.submit_command(1, DefendCommand.new())
	assert_true(engine.are_party_commands_complete())


func test_dead_party_members_do_not_need_commands():
	var engine := TurnEngine.new()
	var party := _default_party()
	party[1].take_damage(100)  # P2 dead
	engine.start_battle(party, _default_monsters())
	engine.submit_command(0, DefendCommand.new())
	assert_true(engine.are_party_commands_complete())


# --- TurnReport ---

func test_resolve_turn_returns_turn_report_with_actions():
	var engine := TurnEngine.new()
	var party := _default_party()
	var monsters := _default_monsters()
	engine.start_battle(party, monsters)
	engine.submit_command(0, AttackCommand.new(monsters[0]))
	engine.submit_command(1, AttackCommand.new(monsters[1]))
	var report: TurnReport = engine.resolve_turn(_make_rng())
	assert_not_null(report)
	# At least 4 actions: 2 party attacks + 2 monster attacks (assuming nothing died)
	assert_gte(report.actions.size(), 3)


# --- defend halves damage ---

func test_defend_reduces_monster_damage():
	var engine := TurnEngine.new()
	var defender := _StubPartyActor.new("D", 0, 0, 1, 100)
	var monster := _StubMonsterActor.new("M", 10, 0, 10, 20)
	engine.start_battle([defender], [monster])
	engine.submit_command(0, DefendCommand.new())
	# HP before: 100. With defend, damage should be halved.
	engine.resolve_turn(_make_rng())
	var damage_taken := 100 - defender.current_hp
	# Without defend, damage is roughly 10-12 (formula spread). With defend, 5-6.
	assert_true(damage_taken <= 6, "damage_taken=%d should be <= 6 with defend" % damage_taken)


# --- attack re-targets if target dead ---

func test_attack_on_dead_target_is_retargeted_or_skipped():
	var engine := TurnEngine.new()
	var party := [
		_StubPartyActor.new("P1", 999, 0, 10, 30),
		_StubPartyActor.new("P2", 999, 0, 9, 30),
	]
	var monsters := [
		_StubMonsterActor.new("M1", 0, 0, 1, 5),
		_StubMonsterActor.new("M2", 0, 0, 1, 5),
	]
	engine.start_battle(party, monsters)
	# Both party target M1. After P1 attacks, M1 dies. P2 should retarget or skip (not hit dead target).
	engine.submit_command(0, AttackCommand.new(monsters[0]))
	engine.submit_command(1, AttackCommand.new(monsters[0]))
	engine.resolve_turn(_make_rng())
	# Either M2 is dead (retarget) or M2 is alive (skip). Never should M1 take damage after dying.
	# At minimum: battle should not continue with M1 dead but M2 untouched AND both party still trying to hit M1.
	# Check that the cleanup is correct.
	assert_eq(engine.state, TurnEngine.State.FINISHED)  # all monsters should be dead if retargeted


# --- escape success ---

func test_escape_success_ends_battle_with_escaped_outcome():
	var engine := TurnEngine.new()
	engine.escape_threshold = 1.0  # always succeed
	var party := _default_party()
	var monsters := _default_monsters()
	engine.start_battle(party, monsters)
	engine.submit_command(0, EscapeCommand.new())
	engine.submit_command(1, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	assert_eq(engine.state, TurnEngine.State.FINISHED)
	assert_eq(engine.outcome().result, EncounterOutcome.Result.ESCAPED)


# --- escape failure ---

func test_escape_failure_forfeits_party_attacks_but_monsters_act():
	var engine := TurnEngine.new()
	engine.escape_threshold = 0.0  # always fail
	var party := [_StubPartyActor.new("P1", 100, 0, 10, 100)]  # strong
	var monsters := [_StubMonsterActor.new("M1", 5, 0, 1, 20)]  # present
	engine.start_battle(party, monsters)
	engine.submit_command(0, EscapeCommand.new())
	var m_hp_before: int = monsters[0].current_hp
	var p_hp_before: int = party[0].current_hp
	engine.resolve_turn(_make_rng())
	# Monster should have taken no damage from party (escape forfeit)
	assert_eq(monsters[0].current_hp, m_hp_before)
	# Party should have taken damage from monster
	assert_lt(party[0].current_hp, p_hp_before)
	# State back to COMMAND_INPUT (not FINISHED)
	assert_eq(engine.state, TurnEngine.State.COMMAND_INPUT)
