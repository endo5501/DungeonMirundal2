extends GutTest


# Integration: katino + sleep status flow against the shipped TurnEngine.
#
# Asserts:
#   - katino (StatusInflictSpellEffect on real sleep.tres) inflicts sleep on a
#     deterministic SpellRng to a slime.
#   - A sleeping monster's action is skipped at TurnEngine resolution time
#     (action_locked event in the report).
#   - Damaging a sleeping monster wakes it (cures_on_damage).
#   - Sleep's default 3-turn duration ticks down to zero in three resolve_turn
#     calls when no damage is taken.

const TEST_SEED: int = 42


class _LowRollSpellRng extends SpellRng:
	# Force every roll to 0 → all chance checks succeed (effective threshold
	# is `chance * 100`, and 0 < that threshold whenever chance > 0).
	func _init() -> void:
		super(null)

	func roll(_low: int, _high: int) -> int:
		return 0


class _StubMonster extends CombatActor:
	var _hp: int
	var _max: int
	var _attack: int

	func _init(p_name: String, p_hp: int, p_attack: int = 0) -> void:
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


class _StubFighter extends CombatActor:
	var _hp: int
	var _max: int
	var _attack: int

	func _init(p_name: String, p_hp: int, p_attack: int) -> void:
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


class _StubPriest extends CombatActor:
	var _hp: int
	var _max: int
	var _mp: int
	var _mp_max: int

	func _init(p_name: String, p_hp: int, p_mp: int) -> void:
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
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
		return 0


func _load_repo() -> StatusRepository:
	# Reset the static cache so a previous test that injected a stub repo
	# does not leak into here.
	DataLoader._status_repo_cache = null
	return DataLoader.new().load_status_repository()


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _inject_repo(engine: TurnEngine, repo: StatusRepository) -> void:
	engine.status_repo = repo
	for a in engine.party + engine.monsters:
		if a != null:
			a.set_status_repo_for_testing(repo)


# --- katino → SpellEffect-level inflict ---

func test_katino_inflicts_sleep_on_every_living_slime():
	var katino := load("res://data/spells/katino.tres") as SpellData
	var effect := katino.effect as StatusInflictSpellEffect
	var repo := _load_repo()
	effect.set_status_repo_for_testing(repo)
	var slimes: Array = [
		_StubMonster.new("Slime A", 5),
		_StubMonster.new("Slime B", 5),
		_StubMonster.new("Slime C", 5),
	]
	var resolution := effect.apply(null, slimes, _LowRollSpellRng.new())
	assert_eq(resolution.entries.size(), 3)
	for s in slimes:
		assert_true(s.statuses.has(&"sleep"), "%s should have sleep" % s.actor_name)


# --- TurnEngine: inflict events surface as TurnReport.inflict actions ---

func test_engine_cast_inflict_emits_inflict_action_in_report():
	# Regression: when a status spell hits, the engine must translate the
	# SpellResolution events into TurnReport `inflict` actions so CombatLog
	# can render "Slime は 睡眠 になった" instead of "効果はなかった".
	var engine := TurnEngine.new()
	# Caster with high agility goes first; zero attack so monster doesn't die.
	var caster := _StubFighter.new("Alice", 30, 0)
	caster._max = 30
	var slime := _StubMonster.new("Slime", 30, 0)
	# Give the caster MP so they can pay katino's mp_cost.
	# (StubFighter has no MP fields; replace with a tiny inline that spend_mp accepts.)
	engine.start_battle([caster], [slime])
	_inject_repo(engine, _load_repo())
	# Stub spell repo: use real katino but with a deterministic-success effect so
	# this test does not depend on the engine's RNG sequence.
	var fake_spell := SpellData.new()
	fake_spell.id = &"katino"
	fake_spell.display_name = "カティノ"
	fake_spell.school = SpellData.SCHOOL_MAGE
	fake_spell.level = 1
	fake_spell.mp_cost = 0  # bypass MP check on the stub fighter
	fake_spell.target_type = SpellData.TargetType.ENEMY_GROUP
	fake_spell.scope = SpellData.Scope.BATTLE_ONLY
	var fake_effect := StatusInflictSpellEffect.new()
	fake_effect.status_id = &"sleep"
	fake_effect.chance = 1.0
	fake_effect.duration = 3
	fake_effect.set_status_repo_for_testing(_load_repo())
	fake_spell.effect = fake_effect
	var stub_repo := SpellRepository.new()
	stub_repo.register(fake_spell)
	engine.spell_repo = stub_repo
	engine.submit_command(0, CastCommand.new(&"katino", 0, slime))
	var report := engine.resolve_turn(_make_rng())
	var inflicts := []
	for a in report.actions:
		if a.get("type") == "inflict":
			inflicts.append(a)
	assert_eq(inflicts.size(), 1, "engine should emit one inflict action per hit target")
	assert_eq(inflicts[0]["target_name"], "Slime")
	assert_eq(inflicts[0]["status_id"], &"sleep")


# --- TurnEngine: sleeping target's action is skipped ---

func test_sleeping_monster_skips_action_at_turn_head():
	var engine := TurnEngine.new()
	var p := _StubFighter.new("P1", 30, 0)  # zero attack so monster doesn't die from attack
	var slime := _StubMonster.new("Slime", 30, 5)
	engine.start_battle([p], [slime])
	_inject_repo(engine, _load_repo())
	slime.statuses.apply(&"sleep", 3)
	# Party defends so the test focuses on the monster's skipped turn.
	engine.submit_command(0, DefendCommand.new())
	var report := engine.resolve_turn(_make_rng())
	var locked := []
	for a in report.actions:
		if a.get("type") == "action_locked":
			locked.append(a)
	assert_eq(locked.size(), 1)
	assert_eq(locked[0]["actor_name"], "Slime")


# --- TurnEngine: damaging a sleeping monster wakes it ---

func test_attack_wakes_sleeping_slime():
	var engine := TurnEngine.new()
	var p := _StubFighter.new("P1", 30, 5)
	var slime := _StubMonster.new("Slime", 30, 0)
	engine.start_battle([p], [slime])
	_inject_repo(engine, _load_repo())
	slime.statuses.apply(&"sleep", 3)
	engine.submit_command(0, AttackCommand.new(slime))
	var report := engine.resolve_turn(_make_rng())
	var woke := []
	for a in report.actions:
		if a.get("type") == "wake":
			woke.append(a)
	assert_gte(woke.size(), 1, "monster should wake from damage")
	assert_eq(woke[0]["status_id"], &"sleep")
	assert_false(slime.statuses.has(&"sleep"))


# --- TurnEngine: sleep duration ticks down to 0 over 3 turns when no damage ---

func test_sleep_naturally_clears_after_three_turns():
	var engine := TurnEngine.new()
	var p := _StubFighter.new("P1", 30, 0)
	var slime := _StubMonster.new("Slime", 30, 0)  # zero attack so no damage exchanges
	engine.start_battle([p], [slime])
	_inject_repo(engine, _load_repo())
	slime.statuses.apply(&"sleep", 3)
	for i in range(3):
		# Battle ends if monsters are wiped; here neither side dies, so we just
		# keep submitting Defend.
		if engine.state == TurnEngine.State.FINISHED:
			break
		engine.submit_command(0, DefendCommand.new())
		engine.resolve_turn(_make_rng())
	assert_false(slime.statuses.has(&"sleep"),
		"sleep should expire after duration ticks reach zero")


# --- TurnEngine: dios cures sleep on an ally + MP accounting ---

func test_dios_on_sleeping_ally_emits_cure_and_consumes_mp():
	var engine := TurnEngine.new()
	var priest := _StubPriest.new("Priest", 20, 5)
	var ally := _StubFighter.new("Ally", 20, 0)
	# Stub monster only exists so the battle has an enemy side.
	var slime := _StubMonster.new("Slime", 30, 0)
	engine.start_battle([priest, ally], [slime])
	_inject_repo(engine, _load_repo())
	ally.statuses.apply(&"sleep", 3)
	# Both party members defend except for the priest, who casts dios on ally.
	engine.submit_command(0, CastCommand.new(&"dios", 0, ally))
	engine.submit_command(1, DefendCommand.new())
	var report := engine.resolve_turn(_make_rng())
	assert_eq(priest.current_mp, 3, "dios must consume mp_cost (2) from caster")
	assert_false(ally.statuses.has(&"sleep"), "dios should clear sleep on the ally")
	var cures := []
	for a in report.actions:
		if a.get("type") == "cure":
			cures.append(a)
	assert_eq(cures.size(), 1, "report should contain exactly one cure action")
	assert_eq(cures[0]["actor_name"], "Ally")
	assert_eq(cures[0]["status_id"], &"sleep")


func test_dios_on_clean_ally_consumes_mp_without_cure_event():
	var engine := TurnEngine.new()
	var priest := _StubPriest.new("Priest", 20, 5)
	var ally := _StubFighter.new("Ally", 20, 0)
	var slime := _StubMonster.new("Slime", 30, 0)
	engine.start_battle([priest, ally], [slime])
	_inject_repo(engine, _load_repo())
	# No sleep applied to the ally — dios is a no-op cure but still costs MP.
	engine.submit_command(0, CastCommand.new(&"dios", 0, ally))
	engine.submit_command(1, DefendCommand.new())
	var report := engine.resolve_turn(_make_rng())
	assert_eq(priest.current_mp, 3, "MP is consumed regardless of cure outcome")
	for a in report.actions:
		assert_ne(a.get("type"), "cure",
			"dios on a clean target must not emit a cure action")
