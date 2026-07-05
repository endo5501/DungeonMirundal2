extends GutTest

const TEST_SEED: int = 12345
const FLOOR_3_TABLE_PATH: String = "res://data/encounter_tables/floor_3.tres"


var _repo: MonsterRepository


func before_each():
	_repo = MonsterRepository.new()
	_repo.register(TestHelpers.make_monster_data(&"slime", "Slime", 1, 4, 8, Row.BACK))
	_repo.register(TestHelpers.make_monster_data(&"goblin", "Goblin", 2, 8, 12, Row.FRONT))
	_repo.register(TestHelpers.make_monster_data(&"wolf", "Wolf", 2, 6, 10, Row.FRONT))
	_repo.register(TestHelpers.make_monster_data(&"ogre", "Ogre", 3, 15, 20, Row.FRONT))


func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _load_floor_3() -> EncounterTableData:
	var table: EncounterTableData = load(FLOOR_3_TABLE_PATH)
	assert_not_null(table, "floor_3.tres should load as EncounterTableData")
	return table


# --- EncounterSource (base) ---

func test_base_source_is_refcounted():
	assert_true(EncounterSource.new() is RefCounted)


func test_base_next_returns_null_and_pushes_error():
	var source := EncounterSource.new()
	var party := source.next(_make_rng(TEST_SEED))
	assert_null(party, "base next() should return null")
	assert_push_error("must be overridden")


func test_base_describe_returns_empty_string():
	assert_eq(EncounterSource.new().describe(), "")


# --- FixedPatternSource ---

func test_fixed_source_is_encounter_source():
	var source := FixedPatternSource.new([{&"goblin": 1}], _repo)
	assert_true(source is EncounterSource)


func test_fixed_patterns_cycle_in_order_and_wrap():
	var source := FixedPatternSource.new([{&"goblin": 3}, {&"slime": 2}], _repo)
	var rng := _make_rng(TEST_SEED)
	var first := source.next(rng)
	var second := source.next(rng)
	var third := source.next(rng)
	assert_eq(first.counts_by_species(), {&"goblin": 3}, "battle 1 should be goblin x3")
	assert_eq(second.counts_by_species(), {&"slime": 2}, "battle 2 should be slime x2")
	assert_eq(third.counts_by_species(), {&"goblin": 3}, "battle 3 should wrap to goblin x3")


func test_fixed_multi_species_pattern_builds_all_species():
	var source := FixedPatternSource.new([{&"goblin": 2, &"slime": 1}], _repo)
	var party := source.next(_make_rng(TEST_SEED))
	assert_eq(party.counts_by_species(), {&"goblin": 2, &"slime": 1})


func test_fixed_accepts_string_keys():
	var source := FixedPatternSource.new([{"goblin": 2}], _repo)
	var party := source.next(_make_rng(TEST_SEED))
	assert_eq(party.counts_by_species(), {&"goblin": 2})


func test_fixed_monsters_are_real_instances_with_repository_data():
	var source := FixedPatternSource.new([{&"goblin": 2}], _repo)
	var party := source.next(_make_rng(TEST_SEED))
	assert_eq(party.size(), 2)
	var expected: MonsterData = _repo.find(&"goblin")
	for m in party.members:
		assert_true(m is Monster, "party members should be Monster instances")
		assert_eq(m.data, expected, "monster data should come from the repository")
		assert_between(m.max_hp, expected.max_hp_min, expected.max_hp_max)
		assert_eq(m.current_hp, m.max_hp)


func test_fixed_hp_rolls_use_passed_rng_deterministically():
	var a := FixedPatternSource.new([{&"goblin": 3}], _repo)
	var b := FixedPatternSource.new([{&"goblin": 3}], _repo)
	var party_a := a.next(_make_rng(TEST_SEED))
	var party_b := b.next(_make_rng(TEST_SEED))
	assert_eq(party_a.size(), party_b.size())
	for i in range(mini(party_a.size(), party_b.size())):
		assert_eq(party_a.members[i].data.monster_id, party_b.members[i].data.monster_id)
		assert_eq(party_a.members[i].max_hp, party_b.members[i].max_hp,
			"HP rolls should be identical for identical seeds")


func test_fixed_describe_reflects_last_returned_pattern():
	var source := FixedPatternSource.new([{&"goblin": 3}, {&"slime": 2}], _repo)
	var rng := _make_rng(TEST_SEED)
	source.next(rng)
	assert_eq(source.describe(), "pattern_0:goblin_x3")
	source.next(rng)
	assert_eq(source.describe(), "pattern_1:slime_x2")
	source.next(rng)
	assert_eq(source.describe(), "pattern_0:goblin_x3", "describe should wrap with the patterns")


func test_fixed_describe_joins_multi_species_pattern():
	var source := FixedPatternSource.new([{&"goblin": 2, &"slime": 1}], _repo)
	source.next(_make_rng(TEST_SEED))
	assert_eq(source.describe(), "pattern_0:goblin_x2+slime_x1")


func test_fixed_unknown_species_pushes_error_and_is_skipped():
	var source := FixedPatternSource.new([{&"dragon": 2, &"goblin": 1}], _repo)
	var party := source.next(_make_rng(TEST_SEED))
	assert_eq(party.counts_by_species(), {&"goblin": 1},
		"unknown species should be skipped, known species kept")
	assert_push_error("dragon")


func test_fixed_all_unknown_species_yields_empty_party():
	var source := FixedPatternSource.new([{&"dragon": 2}], _repo)
	var party := source.next(_make_rng(TEST_SEED))
	assert_not_null(party)
	assert_eq(party.size(), 0, "a pattern of only unknown species should yield an empty party")
	assert_push_error("dragon")


# --- TableEncounterSource ---

func test_table_source_is_encounter_source():
	var source := TableEncounterSource.new(_load_floor_3(), _repo)
	assert_true(source is EncounterSource)


func test_table_source_ignores_trigger_probability():
	# probability_per_step gates *walking* encounters; the simulator source
	# must yield a battle on every call regardless.
	var table := TestHelpers.make_encounter_table(1, 0.0, {3: 1}, 1, 1, 2, 2)
	var source := TableEncounterSource.new(table, _repo)
	var party := source.next(_make_rng(TEST_SEED))
	assert_eq(party.size(), 2, "next() should always produce a battle even at probability 0")


func test_table_source_matches_encounter_manager_generation():
	# The source must reuse the production generation logic: for the same
	# table, repository, and seed it yields the same composition and HP
	# rolls as EncounterManager.generate().
	var table := _load_floor_3()
	var source := TableEncounterSource.new(table, _repo)
	var manager := EncounterManager.new(_repo, 0)
	manager.set_table(table)
	for i in range(20):
		var expected := manager.generate(_make_rng(TEST_SEED + i))
		var actual := source.next(_make_rng(TEST_SEED + i))
		assert_eq(actual.size(), expected.size(), "draw %d: party size" % i)
		for j in range(mini(actual.size(), expected.size())):
			assert_eq(actual.members[j].data.monster_id, expected.members[j].data.monster_id,
				"draw %d member %d: species" % [i, j])
			assert_eq(actual.members[j].max_hp, expected.members[j].max_hp,
				"draw %d member %d: hp roll" % [i, j])


func test_table_source_respects_floor3_constraints():
	# Production generation draws species_count slots, each with a per-slot
	# count in [count_per_species_min, count_per_species_max]. Two slots may
	# roll the same species (counts merge) and rows are capped at 5, so the
	# observable per-species bounds are [1, species_count_max * count_per_species_max].
	var table := _load_floor_3()
	var weights := table.normalized_tier_weights()
	var source := TableEncounterSource.new(table, _repo)
	for i in range(50):
		var party := source.next(_make_rng(TEST_SEED + i))
		assert_gt(party.size(), 0, "draw %d: party should not be empty" % i)
		var counts := party.counts_by_species()
		assert_between(counts.size(), 1, table.species_count_max,
			"draw %d: distinct species count" % i)
		for species_id in counts:
			assert_between(counts[species_id], 1,
				table.species_count_max * table.count_per_species_max,
				"draw %d: count for %s" % [i, species_id])
		for m in party.members:
			assert_true(weights.has(m.data.tier),
				"draw %d: tier %d must be a key of floor_3 tier_weights" % [i, m.data.tier])


func test_table_source_count_per_species_within_range_for_single_slot():
	# With exactly one species slot and a single-monster tier there is no
	# same-species merging and no row truncation (count max 4 <= row cap 5),
	# so the strict per-species range must hold.
	var table := TestHelpers.make_encounter_table(3, 1.0, {3: 1}, 1, 1, 2, 4)
	var source := TableEncounterSource.new(table, _repo)
	for i in range(30):
		var party := source.next(_make_rng(TEST_SEED + i))
		var counts := party.counts_by_species()
		assert_eq(counts.keys(), [&"ogre"], "draw %d: only ogre (tier 3) is registered" % i)
		assert_between(counts[&"ogre"], table.count_per_species_min, table.count_per_species_max,
			"draw %d: per-species count" % i)


func test_table_source_is_deterministic_for_same_seed():
	var table := _load_floor_3()
	var a := TableEncounterSource.new(table, _repo)
	var b := TableEncounterSource.new(table, _repo)
	var party_a := a.next(_make_rng(TEST_SEED))
	var party_b := b.next(_make_rng(TEST_SEED))
	assert_eq(party_a.size(), party_b.size())
	for i in range(mini(party_a.size(), party_b.size())):
		assert_eq(party_a.members[i].data.monster_id, party_b.members[i].data.monster_id)
		assert_eq(party_a.members[i].max_hp, party_b.members[i].max_hp)


func test_table_describe_returns_floor_label():
	var source := TableEncounterSource.new(_load_floor_3(), _repo)
	assert_eq(source.describe(), "floor_3")
