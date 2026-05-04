extends GutTest


# Integration: poison status, poison_dart spell, and persist-on-battle-end.
#
# Asserts:
#   - poison_dart on a slime stamps a battle-only StatusTrack entry that ticks
#     for 1 damage at the head of the next turn.
#   - poison applied on a PartyCombatant survives `commit_persistent_to_character`
#     and ends up in character.persistent_statuses (since cures_on_battle_end=false).

const TEST_SEED: int = 41


class _LowRollSpellRng extends SpellRng:
	# Force every roll to 0 so chance/inflict checks always succeed.
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


func _load_repo() -> StatusRepository:
	DataLoader._status_repo_cache = null
	return DataLoader.new().load_status_repository()


# --- poison_dart applies poison status ---

func test_poison_dart_inflicts_poison_on_target():
	var spell := load("res://data/spells/poison_dart.tres") as SpellData
	assert_not_null(spell)
	var effect := spell.effect as DamageWithStatusSpellEffect
	var repo := _load_repo()
	effect.set_status_repo_for_testing(repo)
	var slime := _StubMonster.new("Slime", 30)
	# spread=1 / base=3 → damage of 2..4. roll=0 picks the low end (2).
	var resolution := effect.apply(null, [slime], _LowRollSpellRng.new())
	assert_eq(resolution.entries.size(), 1)
	assert_true(slime.statuses.has(&"poison"), "poison_dart should apply poison")
	# Damage should be in [2, 4] for base=3, spread=1.
	assert_lt(slime.current_hp, 30, "poison_dart should also deal damage")


# --- poison ticks at the head of every battle turn ---

func test_poisoned_actor_takes_one_damage_each_turn():
	var engine := TurnEngine.new()
	var fighter := _StubMonster.new("Fighter", 30, 0)  # acts as our "party" stub
	var slime := _StubMonster.new("Slime", 30, 0)
	engine.start_battle([fighter], [slime])
	engine.status_repo = _load_repo()
	for a in engine.party + engine.monsters:
		if a != null:
			a.set_status_repo_for_testing(engine.status_repo)
	# Apply poison directly to bypass RNG.
	slime.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	var initial_hp := slime.current_hp
	engine.submit_command(0, DefendCommand.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	engine.resolve_turn(rng)
	# Per design.md decision 3: poison.tick_in_battle = 1.
	assert_eq(slime.current_hp, initial_hp - 1,
		"poison should deal exactly 1 HP damage at the head of the turn")


# --- commit_persistent_to_character preserves poison ---

func test_commit_persistent_writes_poison_back_to_character():
	var human := load("res://data/races/human.tres") as RaceData
	var fighter_job := load("res://data/jobs/fighter.tres") as JobData
	var ch := Character.new()
	ch.character_name = "Alice"
	ch.race = human
	ch.job = fighter_job
	ch.level = 1
	ch.base_stats = {&"STR": 8, &"INT": 8, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	ch.max_hp = 20
	ch.current_hp = 20
	ch.max_mp = 0
	ch.current_mp = 0
	var combatant := PartyCombatant.new(ch, null)
	# Apply poison via PERSISTENT_DURATION (mirrors the inflict path).
	combatant.statuses.apply(&"poison", StatusTrack.PERSISTENT_DURATION)
	combatant.commit_persistent_to_character(_load_repo())
	assert_true(ch.persistent_statuses.has(&"poison"),
		"poison must persist back to Character.persistent_statuses (cures_on_battle_end=false)")
