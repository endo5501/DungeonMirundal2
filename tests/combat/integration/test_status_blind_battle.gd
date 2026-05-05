extends GutTest


# Integration: blind status, dazil spell, and DamageCalculator hit_chance penalty.
#
# Asserts:
#   - dazil applies blind via StatusInflictSpellEffect.
#   - DamageCalculator.hit_chance subtracts the blind hit_penalty (0.20) when
#     attacker is blind, and clamps the final hit chance to [0.05, 0.99].
#   - blind is BATTLE_ONLY and cures_on_battle_end=true (does NOT persist).

const TEST_SEED: int = 92


class _LowRollSpellRng extends SpellRng:
	func _init() -> void:
		super(null)

	func roll(_low: int, _high: int) -> int:
		return 0


class _StubActor extends CombatActor:
	var _hp: int
	var _max: int
	var _attack: int
	var _defense: int
	var _agility: int

	func _init(p_name: String, p_hp: int = 20, p_attack: int = 5, p_defense: int = 0, p_agility: int = 5) -> void:
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
		_attack = p_attack
		_defense = p_defense
		_agility = p_agility

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func _get_base_attack() -> int:
		return _attack

	func _get_base_defense() -> int:
		return _defense

	func _get_base_agility() -> int:
		return _agility


func _load_repo() -> StatusRepository:
	DataLoader._status_repo_cache = null
	return DataLoader.new().load_status_repository()


# --- dazil applies blind ---

func test_dazil_inflicts_blind_on_target():
	var spell := load("res://data/spells/dazil.tres") as SpellData
	assert_not_null(spell)
	var effect := spell.effect as StatusInflictSpellEffect
	effect.set_status_repo_for_testing(_load_repo())
	var slime := _StubActor.new("Slime")
	var resolution := effect.apply(null, [slime], _LowRollSpellRng.new())
	assert_eq(resolution.entries.size(), 1)
	assert_true(slime.statuses.has(&"blind"), "dazil should apply blind")


# --- blind reduces hit chance via DamageCalculator ---

func test_blind_attacker_loses_0_20_from_hit_chance():
	# Ensure DataLoader's StatusRepository cache is fresh and reflects blind.tres.
	_load_repo()
	var attacker := _StubActor.new("A", 20, 5, 0, 5)
	var defender := _StubActor.new("D", 20, 5, 0, 5)
	var clean_chance := DamageCalculator.hit_chance(attacker, defender)
	attacker.statuses.apply(&"blind", 4)
	var blind_chance := DamageCalculator.hit_chance(attacker, defender)
	assert_almost_eq(clean_chance - blind_chance, 0.20, 0.01,
		"blind should subtract 0.20 from hit_chance")


func test_blind_hit_chance_clamps_at_0_05_floor():
	_load_repo()
	# Make agility difference so massive that the final clamp engages.
	var attacker := _StubActor.new("A", 20, 5, 0, 0)
	var defender := _StubActor.new("D", 20, 5, 0, 100)
	attacker.statuses.apply(&"blind", 4)
	var chance := DamageCalculator.hit_chance(attacker, defender)
	assert_gte(chance, 0.05 - 0.0001, "hit chance should clamp at 0.05 floor")


# --- blind clears on battle end ---

func test_blind_cleared_on_battle_end():
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
	combatant.statuses.apply(&"blind", 4)
	combatant.commit_persistent_to_character(_load_repo())
	assert_false(ch.persistent_statuses.has(&"blind"),
		"blind is BATTLE_ONLY and must NOT be written back to persistent_statuses")
