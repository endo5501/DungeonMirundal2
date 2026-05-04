extends GutTest

# TurnEngine flow extensions for status effects:
#   - tick_battle_turn at head of every turn
#   - tick-induced WIPED / CLEARED early termination
#   - has_action_lock / has_silence_flag / has_confusion_flag command interception
#   - cures_on_damage handling after every take_damage
#   - battle-end cleanup: cure_all_battle_only / commit_persistent_to_character / clear_battle_only


const TEST_SEED: int = 12345


class _StubPartyActor extends CombatActor:
	var _hp: int
	var _max: int
	var _mp: int
	var _mp_max: int
	var _attack: int
	var _defense: int
	var _agility: int

	func _init(
		p_name: String,
		p_hp: int,
		p_attack: int = 5,
		p_defense: int = 0,
		p_agility: int = 5,
		p_mp: int = 0
	) -> void:
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
		_attack = p_attack
		_defense = p_defense
		_agility = p_agility
		_mp = p_mp
		_mp_max = p_mp

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func _read_current_mp() -> int:
		return _mp

	func _write_current_mp(value: int) -> void:
		_mp = value

	func _read_max_mp() -> int:
		return _mp_max

	func get_attack() -> int:
		return _attack

	func get_defense() -> int:
		return _defense

	func get_agility() -> int:
		return _agility


class _StubMonsterActor extends CombatActor:
	var _hp: int
	var _max: int
	var _attack: int

	func _init(p_name: String, p_hp: int, p_attack: int = 1) -> void:
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
		_attack = p_attack

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func get_attack() -> int:
		return _attack


func _make_status(
	id: StringName,
	scope: int = StatusData.Scope.BATTLE_ONLY,
	tick_in_battle: int = 0,
	cures_on_damage: bool = false,
	prevents_action: bool = false,
	blocks_cast: bool = false,
	randomizes_target: bool = false
) -> StatusData:
	var s := StatusData.new()
	s.id = id
	s.display_name = String(id)
	s.scope = scope
	s.tick_in_battle = tick_in_battle
	s.cures_on_damage = cures_on_damage
	s.prevents_action = prevents_action
	s.blocks_cast = blocks_cast
	s.randomizes_target = randomizes_target
	return s


func _make_repo() -> StatusRepository:
	var repo := StatusRepository.new()
	repo.register(_make_status(&"sleep", StatusData.Scope.BATTLE_ONLY, 0, true, true))   # cures_on_damage + prevents_action
	repo.register(_make_status(&"silence", StatusData.Scope.BATTLE_ONLY, 0, false, false, true))  # blocks_cast
	repo.register(_make_status(&"confusion", StatusData.Scope.BATTLE_ONLY, 0, false, false, false, true))  # randomizes_target
	repo.register(_make_status(&"poison", StatusData.Scope.PERSISTENT, 2, false))         # tick_in_battle=2
	repo.register(_make_status(&"paralysis", StatusData.Scope.BATTLE_ONLY, 0, false, true))  # prevents_action
	return repo


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


# Inject our test repo into every actor so has_*_flag queries also see it.
func _inject_repo_into_actors(engine: TurnEngine, repo: StatusRepository) -> void:
	engine.status_repo = repo
	for a in engine.party + engine.monsters:
		if a != null:
			a.set_status_repo_for_testing(repo)


# --- status_repo lazy-load + injection ---

func test_status_repo_can_be_injected():
	var engine := TurnEngine.new()
	var repo := _make_repo()
	engine.status_repo = repo
	assert_same(engine.get_status_repo(), repo)


func test_status_repo_lazy_loads_when_unset():
	var engine := TurnEngine.new()
	var repo := engine.get_status_repo()
	assert_not_null(repo)
	assert_is(repo, StatusRepository)


# --- tick at head of turn ---

func test_tick_at_head_of_turn_applies_damage_before_actions():
	var engine := TurnEngine.new()
	var party_member := _StubPartyActor.new("P1", 10)
	var monster := _StubMonsterActor.new("M1", 10)
	engine.start_battle([party_member], [monster])
	_inject_repo_into_actors(engine, _make_repo())
	party_member.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	# Submit a defend so no damage interactions confuse the test.
	engine.submit_command(0, DefendCommand.new())
	var report := engine.resolve_turn(_make_rng())
	# tick (2) is applied first, then defend, then monster attack.
	# Tick must show in the report.
	var tick_entries := []
	for a in report.actions:
		if a.get("type") == "tick_damage":
			tick_entries.append(a)
	assert_eq(tick_entries.size(), 1)
	assert_eq(tick_entries[0]["status_id"], &"poison")
	assert_eq(tick_entries[0]["amount"], 2)


func test_tick_can_wipe_party_and_terminate_battle():
	# Party member has 2 HP, poison ticks 2 → dies from tick.
	var engine := TurnEngine.new()
	var party_member := _StubPartyActor.new("P1", 2)
	var monster := _StubMonsterActor.new("M1", 10)
	engine.start_battle([party_member], [monster])
	_inject_repo_into_actors(engine, _make_repo())
	party_member.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	engine.submit_command(0, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	assert_eq(engine.state, TurnEngine.State.FINISHED)
	assert_eq(engine.outcome().result, EncounterOutcome.Result.WIPED)


func test_tick_can_wipe_monsters_and_terminate_battle():
	# We need a monster with status; poison only on monster side. Verify CLEARED.
	var engine := TurnEngine.new()
	var party_member := _StubPartyActor.new("P1", 30)
	var monster := _StubMonsterActor.new("M1", 2)
	engine.start_battle([party_member], [monster])
	_inject_repo_into_actors(engine, _make_repo())
	monster.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	engine.submit_command(0, DefendCommand.new())
	engine.resolve_turn(_make_rng())
	assert_eq(engine.state, TurnEngine.State.FINISHED)
	assert_eq(engine.outcome().result, EncounterOutcome.Result.CLEARED)


# --- action_lock skip ---

func test_action_lock_skips_attack_command():
	var engine := TurnEngine.new()
	var party_member := _StubPartyActor.new("P1", 30, 999)  # huge attack
	var monster := _StubMonsterActor.new("M1", 10)
	engine.start_battle([party_member], [monster])
	_inject_repo_into_actors(engine, _make_repo())
	party_member.statuses.apply(&"sleep", 3)  # prevents_action
	engine.submit_command(0, AttackCommand.new(monster))
	var report := engine.resolve_turn(_make_rng())
	# Monster should still be alive (party member skipped).
	assert_true(monster.is_alive())
	var locked := []
	for a in report.actions:
		if a.get("type") == "action_locked":
			locked.append(a)
	assert_eq(locked.size(), 1)
	assert_eq(locked[0]["actor_name"], "P1")


# --- silence intercept of CastCommand ---

func test_silence_blocks_cast_without_consuming_mp():
	var engine := TurnEngine.new()
	var caster := _StubPartyActor.new("Mage", 30, 5, 0, 5, 5)  # 5 MP
	var monster := _StubMonsterActor.new("M1", 10)
	engine.start_battle([caster], [monster])
	_inject_repo_into_actors(engine, _make_repo())
	caster.statuses.apply(&"silence", 3)
	var cast := CastCommand.new(&"fire", 0, monster)
	engine.submit_command(0, cast)
	var report := engine.resolve_turn(_make_rng())
	assert_eq(caster.current_mp, 5, "silenced cast must not consume MP")
	var silenced := []
	for a in report.actions:
		if a.get("type") == "cast_silenced":
			silenced.append(a)
	assert_eq(silenced.size(), 1)
	assert_eq(silenced[0]["caster_name"], "Mage")
	assert_eq(silenced[0]["spell_id"], &"fire")


func test_silence_does_not_block_attack_command():
	var engine := TurnEngine.new()
	var party_member := _StubPartyActor.new("P1", 30, 99)  # one-shot
	var monster := _StubMonsterActor.new("M1", 1)
	engine.start_battle([party_member], [monster])
	_inject_repo_into_actors(engine, _make_repo())
	party_member.statuses.apply(&"silence", 3)
	engine.submit_command(0, AttackCommand.new(monster))
	engine.resolve_turn(_make_rng())
	assert_false(monster.is_alive(), "silence must not block attacks")


# --- confusion swap to AttackCommand ---

func test_confusion_swaps_attack_to_random_living_actor():
	var engine := TurnEngine.new()
	var party_member := _StubPartyActor.new("P1", 30, 99, 0, 99)  # initiative high so acts first
	var monster := _StubMonsterActor.new("M1", 10)
	engine.start_battle([party_member], [monster])
	_inject_repo_into_actors(engine, _make_repo())
	party_member.statuses.apply(&"confusion", 3)
	# AttackCommand against monster — confusion replaces target with random living
	# from the union of party + monsters minus self. Only `monster` exists besides
	# self, so target is deterministically `monster`.
	engine.submit_command(0, AttackCommand.new(monster))
	var report := engine.resolve_turn(_make_rng())
	# Find the attack action (or miss); it must be marked confusion_swap == true.
	var marked_count := 0
	for a in report.actions:
		if (a.get("type") == "attack" or a.get("type") == "miss") and a.get("confusion_swap", false):
			marked_count += 1
	assert_eq(marked_count, 1)


func test_confusion_swap_cast_to_attack_keeps_mp():
	var engine := TurnEngine.new()
	var caster := _StubPartyActor.new("Mage", 30, 5, 0, 99, 5)
	var monster := _StubMonsterActor.new("M1", 10)
	engine.start_battle([caster], [monster])
	_inject_repo_into_actors(engine, _make_repo())
	caster.statuses.apply(&"confusion", 3)
	engine.submit_command(0, CastCommand.new(&"fire", 0, monster))
	var report := engine.resolve_turn(_make_rng())
	assert_eq(caster.current_mp, 5, "confused cast becomes attack — no MP consumed")
	# No cast action at all
	for a in report.actions:
		assert_ne(a.get("type"), "cast", "no cast action should exist after confusion swap")


# --- handle_damage_taken (cures_on_damage) wakes sleeper ---

func test_attack_damage_wakes_sleeper_on_target():
	# Attacker hits a sleeping monster. Sleep cures_on_damage = true. We expect
	# a `wake` entry in the report.
	var engine := TurnEngine.new()
	var party_member := _StubPartyActor.new("P1", 30, 5)
	var monster := _StubMonsterActor.new("M1", 30)  # plenty of HP so doesn't die
	engine.start_battle([party_member], [monster])
	_inject_repo_into_actors(engine, _make_repo())
	monster.statuses.apply(&"sleep", 3)
	engine.submit_command(0, AttackCommand.new(monster))
	var report := engine.resolve_turn(_make_rng())
	var woke := []
	for a in report.actions:
		if a.get("type") == "wake":
			woke.append(a)
	assert_gte(woke.size(), 1, "monster should wake on damage")
	assert_eq(woke[0]["status_id"], &"sleep")
	assert_false(monster.statuses.has(&"sleep"))


# --- battle-end cleanup ---

func test_battle_end_cures_all_battle_only_statuses():
	# Setup: party alive, monster killed in 1 hit. P1 holds &"sleep" (BATTLE_ONLY).
	var engine := TurnEngine.new()
	var party_member := _StubPartyActor.new("P1", 30, 999)
	var monster := _StubMonsterActor.new("M1", 5)
	engine.start_battle([party_member], [monster])
	_inject_repo_into_actors(engine, _make_repo())
	# Manually apply sleep so we can verify it's cleared at battle end.
	# (We use silence instead of sleep to avoid the action_lock skip; use silence — BATTLE_ONLY.)
	party_member.statuses.apply(&"silence", 3)
	engine.submit_command(0, AttackCommand.new(monster))
	engine.resolve_turn(_make_rng())
	assert_eq(engine.outcome().result, EncounterOutcome.Result.CLEARED)
	assert_false(party_member.statuses.has(&"silence"),
		"BATTLE_ONLY status must be cured at battle end")


func test_battle_end_clears_battle_only_modifier_stack():
	var engine := TurnEngine.new()
	var party_member := _StubPartyActor.new("P1", 30, 999)
	var monster := _StubMonsterActor.new("M1", 5)
	engine.start_battle([party_member], [monster])
	_inject_repo_into_actors(engine, _make_repo())
	party_member.modifier_stack.add(&"attack", 2, 5)
	engine.submit_command(0, AttackCommand.new(monster))
	engine.resolve_turn(_make_rng())
	assert_eq(party_member.modifier_stack.sum(&"attack"), 0,
		"modifier_stack must be cleared at battle end")
