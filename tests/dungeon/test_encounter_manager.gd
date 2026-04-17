extends GutTest

const TEST_SEED: int = 12345
const NO_COOLDOWN: int = 0


var _repo: MonsterRepository
var _table: EncounterTableData


func before_each():
	_repo = MonsterRepository.new()
	_repo.register(_make_monster_data(&"slime", "Slime", 5, 10))
	_repo.register(_make_monster_data(&"goblin", "Goblin", 8, 12))
	_repo.register(_make_monster_data(&"bat", "Bat", 3, 6))
	_table = _make_simple_table()


func _make_monster_data(id: StringName, name: String, hp_min: int, hp_max: int) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = name
	data.max_hp_min = hp_min
	data.max_hp_max = hp_max
	data.attack = 1
	data.defense = 1
	data.agility = 1
	data.experience = 1
	return data


func _make_group(id: StringName, min_count: int, max_count: int) -> MonsterGroupSpec:
	var spec := MonsterGroupSpec.new()
	spec.monster_id = id
	spec.count_min = min_count
	spec.count_max = max_count
	return spec


func _make_pattern(groups: Array[MonsterGroupSpec]) -> EncounterPattern:
	var pattern := EncounterPattern.new()
	pattern.groups = groups
	return pattern


func _make_entry(pattern: EncounterPattern, weight: int) -> EncounterEntry:
	var entry := EncounterEntry.new()
	entry.pattern = pattern
	entry.weight = weight
	return entry


func _make_simple_table() -> EncounterTableData:
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 0.1
	table.entries = [
		_make_entry(_make_pattern([_make_group(&"slime", 2, 4)]), 1),
		_make_entry(_make_pattern([_make_group(&"goblin", 1, 2)]), 1),
		_make_entry(_make_pattern([_make_group(&"bat", 2, 3)]), 1),
	]
	return table


func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- should_trigger: probability threshold ---

func test_manager_is_refcounted():
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	assert_true(manager is RefCounted)


func test_no_trigger_when_table_not_set():
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	var rng := _make_rng(TEST_SEED)
	assert_false(manager.should_trigger(rng))


func test_trigger_sequence_is_deterministic_for_same_seed():
	var a := EncounterManager.new(_repo, NO_COOLDOWN)
	a.set_table(_table)
	var b := EncounterManager.new(_repo, NO_COOLDOWN)
	b.set_table(_table)
	var rng_a := _make_rng(TEST_SEED)
	var rng_b := _make_rng(TEST_SEED)
	var seq_a: Array[bool] = []
	var seq_b: Array[bool] = []
	for i in range(100):
		seq_a.append(a.should_trigger(rng_a))
		seq_b.append(b.should_trigger(rng_b))
	assert_eq(seq_a, seq_b)


func test_high_probability_triggers_frequently():
	_table.probability_per_step = 1.0
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(_table)
	var rng := _make_rng(TEST_SEED)
	var triggered := 0
	for i in range(20):
		if manager.should_trigger(rng):
			triggered += 1
	assert_eq(triggered, 20)


func test_zero_probability_never_triggers():
	_table.probability_per_step = 0.0
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(_table)
	var rng := _make_rng(TEST_SEED)
	for i in range(20):
		assert_false(manager.should_trigger(rng))


# --- Cooldown ---

func test_cooldown_suppresses_consecutive_triggers():
	_table.probability_per_step = 1.0
	var manager := EncounterManager.new(_repo, 3)
	manager.set_table(_table)
	var rng := _make_rng(TEST_SEED)
	# first: triggers
	assert_true(manager.should_trigger(rng))
	manager.notify_encounter_occurred()
	# next 3: suppressed
	for i in range(3):
		assert_false(manager.should_trigger(rng), "step %d should be suppressed" % i)
	# 4th: triggers again
	assert_true(manager.should_trigger(rng))


func test_cooldown_zero_means_no_suppression():
	_table.probability_per_step = 1.0
	var manager := EncounterManager.new(_repo, 0)
	manager.set_table(_table)
	var rng := _make_rng(TEST_SEED)
	assert_true(manager.should_trigger(rng))
	manager.notify_encounter_occurred()
	assert_true(manager.should_trigger(rng))


# --- generate ---

func test_generate_produces_party_matching_a_pattern():
	_table.probability_per_step = 1.0
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(_table)
	var rng := _make_rng(TEST_SEED)
	var party := manager.generate(rng)
	assert_not_null(party)
	assert_gt(party.size(), 0)
	# party content must match exactly one pattern (one species only, per our simple table)
	var counts := party.counts_by_species()
	assert_eq(counts.size(), 1)


func test_generate_selects_single_entry_when_only_one():
	var single_table := EncounterTableData.new()
	single_table.floor = 1
	single_table.probability_per_step = 1.0
	single_table.entries = [_make_entry(_make_pattern([_make_group(&"slime", 2, 4)]), 1)]
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(single_table)
	var rng := _make_rng(TEST_SEED)
	var party := manager.generate(rng)
	var counts := party.counts_by_species()
	assert_true(counts.has(&"slime"))
	assert_between(counts[&"slime"], 2, 4)


func test_generate_counts_match_pattern_range_over_many_runs():
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(_table)
	for i in range(30):
		var rng := _make_rng(TEST_SEED + i)
		var party := manager.generate(rng)
		var counts := party.counts_by_species()
		for id in counts.keys():
			match id:
				&"slime": assert_between(counts[id], 2, 4)
				&"goblin": assert_between(counts[id], 1, 2)
				&"bat": assert_between(counts[id], 2, 3)
				_: fail_test("unexpected species %s" % id)


func test_generate_respects_weights_deterministically():
	# A heavy-weight entry should be selected more often under a fixed seed
	var weighted := EncounterTableData.new()
	weighted.floor = 1
	weighted.probability_per_step = 1.0
	weighted.entries = [
		_make_entry(_make_pattern([_make_group(&"slime", 1, 1)]), 10),
		_make_entry(_make_pattern([_make_group(&"goblin", 1, 1)]), 1),
	]
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(weighted)
	var slime_count := 0
	for i in range(100):
		var rng := _make_rng(TEST_SEED + i)
		var party := manager.generate(rng)
		if party.counts_by_species().has(&"slime"):
			slime_count += 1
	# With 10:1 weight, slime should dominate
	assert_gt(slime_count, 70)


func test_generate_fails_gracefully_when_monster_id_missing():
	var empty_repo := MonsterRepository.new()  # no monsters registered
	var manager := EncounterManager.new(empty_repo, NO_COOLDOWN)
	manager.set_table(_table)
	var rng := _make_rng(TEST_SEED)
	var party := manager.generate(rng)
	# returns empty party rather than a malformed one
	assert_not_null(party)
	assert_eq(party.size(), 0)
