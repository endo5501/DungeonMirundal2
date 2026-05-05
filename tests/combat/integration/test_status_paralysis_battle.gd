extends GutTest


# Integration: paralysis status, badi spell, and action_lock skip behavior.
#
# Asserts:
#   - badi applies paralysis via StatusInflictSpellEffect.
#   - paralyzed actors emit action_locked entries (TurnEngine skips the turn).
#   - paralysis ticks down naturally and is BATTLE_ONLY (not persisted).
#   - holy_water removes paralysis along with any other status.

const TEST_SEED: int = 93


class _LowRollSpellRng extends SpellRng:
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


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


# --- badi applies paralysis ---

func test_badi_inflicts_paralysis_on_target():
	var spell := load("res://data/spells/badi.tres") as SpellData
	assert_not_null(spell)
	var effect := spell.effect as StatusInflictSpellEffect
	effect.set_status_repo_for_testing(_load_repo())
	var slime := _StubMonster.new("Slime", 20)
	var resolution := effect.apply(null, [slime], _LowRollSpellRng.new())
	assert_eq(resolution.entries.size(), 1)
	assert_true(slime.statuses.has(&"paralysis"), "badi should apply paralysis")


# --- paralysis locks action ---

func test_paralyzed_actor_skips_turn_via_action_locked():
	var engine := TurnEngine.new()
	var fighter := _StubMonster.new("Fighter", 30, 0)
	var slime := _StubMonster.new("Slime", 30, 5)
	engine.start_battle([fighter], [slime])
	engine.status_repo = _load_repo()
	for a in engine.party + engine.monsters:
		if a != null:
			a.set_status_repo_for_testing(engine.status_repo)
	slime.statuses.apply(&"paralysis", 2)
	engine.submit_command(0, DefendCommand.new())
	var report := engine.resolve_turn(_make_rng())
	var locked := []
	for a in report.actions:
		if a.get("type") == "action_locked":
			locked.append(a)
	assert_gte(locked.size(), 1, "paralyzed actors should be skipped via action_locked")


# --- paralysis is BATTLE_ONLY (does not persist post-battle) ---

func test_paralysis_cleared_on_battle_end():
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
	combatant.statuses.apply(&"paralysis", 2)
	combatant.commit_persistent_to_character(_load_repo())
	assert_false(ch.persistent_statuses.has(&"paralysis"),
		"paralysis is BATTLE_ONLY and must NOT be written back to persistent_statuses")


# --- holy_water removes paralysis (and other statuses) ---

func test_holy_water_removes_paralysis():
	var item := load("res://data/items/holy_water.tres") as Item
	var eff := item.effect as CureAllStatusItemEffect
	eff.set_status_repo_for_testing(_load_repo())
	var slime := _StubMonster.new("Slime", 30, 0)
	slime.statuses.apply(&"paralysis", 2)
	slime.statuses.apply(&"blind", 4)
	var result: ItemEffectResult = eff.apply([slime], null)
	assert_true(result.success)
	assert_false(slime.statuses.has(&"paralysis"))
	assert_false(slime.statuses.has(&"blind"))
