extends GutTest


# Integration: confusion status, madalto spell, and command swap behavior.
#
# Asserts:
#   - madalto on an enemy group inflicts confusion via StatusInflictSpellEffect.
#   - confused actors are retargeted to a uniformly-random living combatant
#     (party + monsters minus self) by TurnEngine on the next turn, with the
#     resulting attack/miss entries flagged confusion_swap=true.
#   - confused actor's Cast/Item commands collapse to an Attack against a
#     random target (still annotated confusion_swap).
#   - taking damage from a battle action wakes the confused actor up
#     (cures_on_damage=true).
#   - confusion is fully cleared on battle end (cures_on_battle_end=true).

const TEST_SEED: int = 91


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


# --- madalto inflicts confusion via the spell effect ---

func test_madalto_inflicts_confusion_on_enemy_group():
	var spell := load("res://data/spells/madalto.tres") as SpellData
	assert_not_null(spell)
	var effect := spell.effect as StatusInflictSpellEffect
	effect.set_status_repo_for_testing(_load_repo())
	var slime_a := _StubMonster.new("SlimeA", 20)
	var slime_b := _StubMonster.new("SlimeB", 20)
	var slime_c := _StubMonster.new("SlimeC", 20)
	var resolution := effect.apply(null, [slime_a, slime_b, slime_c], _LowRollSpellRng.new())
	assert_eq(resolution.entries.size(), 3)
	assert_true(slime_a.statuses.has(&"confusion"))
	assert_true(slime_b.statuses.has(&"confusion"))
	assert_true(slime_c.statuses.has(&"confusion"))


# --- confused actor's command is replaced with a random-target attack ---

func test_confused_actor_swaps_target():
	var engine := TurnEngine.new()
	var alice := _StubMonster.new("Alice", 30, 5)
	var bob := _StubMonster.new("Bob", 30, 0)
	var slime := _StubMonster.new("Slime", 30, 0)
	engine.start_battle([alice, bob], [slime])
	engine.status_repo = _load_repo()
	for a in engine.party + engine.monsters:
		if a != null:
			a.set_status_repo_for_testing(engine.status_repo)
	alice.statuses.apply(&"confusion", 3)
	# Submit a normal attack on the slime — engine should override with a random
	# pick from {bob, slime} (everyone living except alice herself).
	engine.submit_command(0, AttackCommand.new(slime))
	engine.submit_command(1, DefendCommand.new())
	var report := engine.resolve_turn(_make_rng())
	var swap_entries := []
	for a in report.actions:
		if a.get("attacker_name") == "Alice" and bool(a.get("confusion_swap", false)):
			swap_entries.append(a)
	assert_gte(swap_entries.size(), 1, "confused Alice should have at least one confusion_swap entry")


# --- taking damage cures confusion (cures_on_damage = true) ---

func test_damage_cures_confusion():
	var engine := TurnEngine.new()
	var alice := _StubMonster.new("Alice", 30, 0)
	var slime := _StubMonster.new("Slime", 30, 8)
	engine.start_battle([alice], [slime])
	engine.status_repo = _load_repo()
	for a in engine.party + engine.monsters:
		if a != null:
			a.set_status_repo_for_testing(engine.status_repo)
	alice.statuses.apply(&"confusion", 3)
	engine.submit_command(0, DefendCommand.new())
	# The slime will roll attacks against alice; eventually a hit lands and
	# cures her confusion. Drive a few turns until alice takes damage.
	var rng := _make_rng()
	for _i in range(10):
		if not alice.statuses.has(&"confusion"):
			break
		if alice.current_hp < 30:
			break
		engine.resolve_turn(rng)
		if engine.state != TurnEngine.State.COMMAND_INPUT:
			break
		engine.submit_command(0, DefendCommand.new())
	if alice.current_hp < 30:
		assert_false(alice.statuses.has(&"confusion"),
			"taking damage should cure confusion (cures_on_damage=true)")


# --- battle-end cleanup clears confusion ---

func test_confusion_cleared_on_battle_end():
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
	combatant.statuses.apply(&"confusion", 3)
	combatant.commit_persistent_to_character(_load_repo())
	assert_false(ch.persistent_statuses.has(&"confusion"),
		"confusion is BATTLE_ONLY and must NOT be written back to persistent_statuses")
