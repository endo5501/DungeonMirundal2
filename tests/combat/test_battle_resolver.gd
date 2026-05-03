extends GutTest

const TEST_SEED: int = 12345


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _make_job() -> JobData:
	var job := JobData.new()
	job.job_name = "Fighter"
	job.base_hp = 10
	job.hp_per_level = 4
	job.exp_table = PackedInt64Array([30, 80])
	return job


func _make_character(name: String) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.job = _make_job()
	ch.level = 1
	ch.base_stats = {&"STR": 10, &"INT": 10, &"PIE": 10, &"VIT": 10, &"AGI": 10, &"LUC": 10}
	ch.max_hp = 20
	ch.current_hp = 20
	return ch


func _make_monster_data(exp: int = 60, gold_min: int = 10, gold_max: int = 20) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = &"slime"
	data.monster_name = "Slime"
	data.max_hp_min = 5
	data.max_hp_max = 5
	data.attack = 1
	data.defense = 0
	data.agility = 1
	data.experience = exp
	data.gold_min = gold_min
	data.gold_max = gold_max
	return data


func _make_cleared_engine(characters: Array, monsters: Array) -> TurnEngine:
	var engine := TurnEngine.new()
	var party: Array = []
	for ch in characters:
		party.append(PartyCombatant.new(ch, DummyEquipmentProvider.new()))
	var combat_monsters: Array = []
	for monster in monsters:
		var combatant := MonsterCombatant.new(monster)
		combatant.take_damage(999)
		combat_monsters.append(combatant)
	engine.start_battle(party, combat_monsters)
	engine._finish(EncounterOutcome.Result.CLEARED)
	return engine


func test_cleared_outcome_returns_experience_and_gold():
	var engine := _make_cleared_engine([_make_character("P1")], [Monster.new(_make_monster_data(60, 10, 20), _make_rng())])
	var summary := BattleResolver.resolve_rewards(engine, _make_rng())
	assert_gt(summary.gained_experience, 0)
	assert_between(summary.gained_gold, 10, 20)


func test_gold_drop_sums_min_max_rolls():
	var engine := _make_cleared_engine(
		[_make_character("P1")],
		[
			Monster.new(_make_monster_data(0, 3, 3), _make_rng()),
			Monster.new(_make_monster_data(0, 10, 10), _make_rng()),
		]
	)
	var summary := BattleResolver.resolve_rewards(engine, _make_rng())
	assert_eq(summary.gained_gold, 13)


func test_level_up_is_detected():
	var ch := _make_character("P1")
	var engine := _make_cleared_engine([ch], [Monster.new(_make_monster_data(60, 0, 0), _make_rng())])
	var summary := BattleResolver.resolve_rewards(engine, _make_rng())
	assert_eq(summary.level_ups, [{"name": "P1", "new_level": 2}])


func test_escaped_and_wiped_return_empty_summary():
	var engine := TurnEngine.new()
	engine.start_battle([], [])
	engine._finish(EncounterOutcome.Result.ESCAPED)
	var escaped := BattleResolver.resolve_rewards(engine, _make_rng())
	assert_eq(escaped.gained_experience, 0)
	assert_eq(escaped.gained_gold, 0)
	assert_eq(escaped.level_ups, [])

	engine._finish(EncounterOutcome.Result.WIPED)
	var wiped := BattleResolver.resolve_rewards(engine, _make_rng())
	assert_eq(wiped.gained_experience, 0)
	assert_eq(wiped.gained_gold, 0)
	assert_eq(wiped.level_ups, [])
