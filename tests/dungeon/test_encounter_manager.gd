extends GutTest

const TEST_SEED: int = 12345
const NO_COOLDOWN: int = 0


var _repo: MonsterRepository
var _table: EncounterTableData


func before_each():
	_repo = MonsterRepository.new()
	_repo.register(TestHelpers.make_monster_data(&"slime", "Slime", 1, 5, 10))
	_repo.register(TestHelpers.make_monster_data(&"goblin", "Goblin", 2, 8, 12))
	_repo.register(TestHelpers.make_monster_data(&"bat", "Bat", 1, 3, 6))
	_table = TestHelpers.make_encounter_table(1, 0.1, {1: 2, 2: 1}, 1, 1, 2, 4)


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

func test_generate_returns_empty_party_when_table_null():
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	var rng := _make_rng(TEST_SEED)
	var party := manager.generate(rng)
	assert_not_null(party)
	assert_eq(party.size(), 0)


func test_generate_returns_empty_when_tier_weights_empty():
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 1.0
	table.tier_weights = {}
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(table)
	var rng := _make_rng(TEST_SEED)
	var party := manager.generate(rng)
	assert_not_null(party)
	assert_eq(party.size(), 0)


func test_generate_picks_monster_from_tier():
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 1.0
	table.tier_weights = {2: 1}  # only goblin (tier 2) should be picked
	table.species_count_min = 1
	table.species_count_max = 1
	table.count_per_species_min = 2
	table.count_per_species_max = 2
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(table)
	var rng := _make_rng(TEST_SEED)
	var party := manager.generate(rng)
	assert_eq(party.size(), 2)
	for m in party.members:
		assert_eq(m.data.monster_id, &"goblin")


func test_generate_respects_count_per_species_range():
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 1.0
	table.tier_weights = {2: 1}
	table.species_count_min = 1
	table.species_count_max = 1
	table.count_per_species_min = 2
	table.count_per_species_max = 5
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(table)
	for i in range(30):
		var rng := _make_rng(TEST_SEED + i)
		var party := manager.generate(rng)
		assert_between(party.size(), 2, 5)


func test_generate_respects_species_count_range():
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 1.0
	table.tier_weights = {1: 1, 2: 1}
	table.species_count_min = 2
	table.species_count_max = 2
	table.count_per_species_min = 1
	table.count_per_species_max = 1
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(table)
	var rng := _make_rng(TEST_SEED)
	var party := manager.generate(rng)
	assert_eq(party.size(), 2, "species_count=2 + count_per_species=1 should yield 2 monsters")


func test_generate_is_deterministic_for_same_seed():
	var manager_a := EncounterManager.new(_repo, NO_COOLDOWN)
	manager_a.set_table(_table)
	var manager_b := EncounterManager.new(_repo, NO_COOLDOWN)
	manager_b.set_table(_table)
	var party_a := manager_a.generate(_make_rng(TEST_SEED))
	var party_b := manager_b.generate(_make_rng(TEST_SEED))
	assert_eq(party_a.size(), party_b.size())
	for i in range(party_a.size()):
		assert_eq(party_a.members[i].data.monster_id, party_b.members[i].data.monster_id)


func test_generate_weights_select_dominant_tier():
	# Heavy tier 1 weight should make slime/bat dominate over goblin (tier 2)
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 1.0
	table.tier_weights = {1: 10, 2: 1}
	table.species_count_min = 1
	table.species_count_max = 1
	table.count_per_species_min = 1
	table.count_per_species_max = 1
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(table)
	var tier_1_count := 0
	for i in range(100):
		var rng := _make_rng(TEST_SEED + i)
		var party := manager.generate(rng)
		if party.size() > 0 and party.members[0].data.tier == 1:
			tier_1_count += 1
	assert_gt(tier_1_count, 70, "with 10:1 weight tier 1 should dominate")


func test_generate_skips_empty_tier_and_emits_warning():
	# tier 5 has no candidates; the slot should be skipped, leaving 0 monsters.
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 1.0
	table.tier_weights = {5: 1}
	table.species_count_min = 1
	table.species_count_max = 1
	table.count_per_species_min = 3
	table.count_per_species_max = 3
	var manager := EncounterManager.new(_repo, NO_COOLDOWN)
	manager.set_table(table)
	var rng := _make_rng(TEST_SEED)
	var party := manager.generate(rng)
	assert_eq(party.size(), 0)
	assert_push_warning("no monsters registered for tier 5")


func test_generate_handles_empty_repository_gracefully():
	var empty_repo := MonsterRepository.new()
	var manager := EncounterManager.new(empty_repo, NO_COOLDOWN)
	manager.set_table(_table)
	var rng := _make_rng(TEST_SEED)
	var party := manager.generate(rng)
	assert_not_null(party)
	assert_eq(party.size(), 0)
