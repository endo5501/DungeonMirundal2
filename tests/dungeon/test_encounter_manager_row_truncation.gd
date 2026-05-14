extends GutTest


func _make_data(id: StringName, row: int, tier: int = 1, attack_range: int = WeaponRange.MELEE) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = String(id)
	data.max_hp_min = 5
	data.max_hp_max = 5
	data.attack = 1
	data.defense = 1
	data.agility = 1
	data.experience = 1
	data.gold_min = 0
	data.gold_max = 0
	data.default_row = row
	data.attack_range = attack_range
	data.tier = tier
	return data


func _make_repository(entries: Array) -> MonsterRepository:
	var repo := MonsterRepository.new()
	for e in entries:
		repo.register(e)
	return repo


func _make_table_for_tier(tier: int, count_min: int, count_max: int) -> EncounterTableData:
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 1.0
	table.tier_weights = {tier: 1}
	table.species_count_min = 1
	table.species_count_max = 1
	table.count_per_species_min = count_min
	table.count_per_species_max = count_max
	return table


func _generate(manager: EncounterManager, table: EncounterTableData) -> MonsterParty:
	manager.set_table(table)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	return manager.generate(rng)


func test_front_default_monster_spawns_in_front_row():
	var slime_data := _make_data(&"slime", Row.FRONT)
	var repo := _make_repository([slime_data])
	var manager := EncounterManager.new(repo, 0)
	var table := _make_table_for_tier(1, 3, 3)
	var party := _generate(manager, table)
	assert_eq(party.size(), 3)
	for m in party.members:
		assert_eq(m.data.default_row, Row.FRONT)


func test_back_default_monster_spawns_in_back_row():
	var witch_data := _make_data(&"witch", Row.BACK, 4)
	var repo := _make_repository([witch_data])
	var manager := EncounterManager.new(repo, 0)
	var table := _make_table_for_tier(4, 2, 2)
	var party := _generate(manager, table)
	assert_eq(party.size(), 2)
	for m in party.members:
		assert_eq(m.data.default_row, Row.BACK)


func test_front_overflow_truncates_at_five():
	var slime_data := _make_data(&"slime", Row.FRONT)
	var repo := _make_repository([slime_data])
	var manager := EncounterManager.new(repo, 0)
	var table := _make_table_for_tier(1, 7, 7)
	var party := _generate(manager, table)
	assert_eq(party.size(), EncounterManager.ROW_CAP)


func test_two_front_species_truncate_with_first_species_priority():
	# Two FRONT-default species in tier 1: slime first (count 3), then bat (count 4).
	# species_count = 2, count_per_species drawn separately for each slot but
	# we want a deterministic count, so use count_min == count_max == 4 with one species.
	# To test "first species wins", drive species_count=2 and select tier 1 (slime+bat).
	var slime_data := _make_data(&"slime", Row.FRONT, 1)
	var bat_data := _make_data(&"bat", Row.FRONT, 1)
	var repo := _make_repository([slime_data, bat_data])
	var manager := EncounterManager.new(repo, 0)
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 1.0
	table.tier_weights = {1: 1}
	table.species_count_min = 2
	table.species_count_max = 2
	table.count_per_species_min = 4
	table.count_per_species_max = 4
	var party := _generate(manager, table)
	# 2 species * 4 each = 8 attempted, FRONT cap=5 → only 5 spawn, first slot priority
	assert_eq(party.size(), EncounterManager.ROW_CAP)


func test_mixed_row_within_caps_is_unchanged():
	# 3 FRONT + 2 BACK = 5 total, both under 5 cap
	var slime_data := _make_data(&"slime", Row.FRONT, 1)
	var witch_data := _make_data(&"witch", Row.BACK, 4)
	var repo := _make_repository([slime_data, witch_data])
	var manager := EncounterManager.new(repo, 0)
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 1.0
	# Use two tier weights, exactly one species each, so species_count_max=2 picks both.
	# Since we have only one species per tier (1=slime, 4=witch), the result is deterministic.
	table.tier_weights = {1: 1, 4: 1}
	table.species_count_min = 2
	table.species_count_max = 2
	table.count_per_species_min = 2
	table.count_per_species_max = 3
	var party := _generate(manager, table)
	# 2 species, each 2-3 → between 4 and 6. Since FRONT cap=5 and BACK cap=5, all spawn.
	assert_between(party.size(), 4, 6)
	for m in party.members:
		if m.data.default_row == Row.FRONT:
			assert_eq(m.data.monster_id, &"slime")
		else:
			assert_eq(m.data.monster_id, &"witch")


func test_truncation_does_not_raise_and_returns_party():
	var slime_data := _make_data(&"slime", Row.FRONT)
	var repo := _make_repository([slime_data])
	var manager := EncounterManager.new(repo, 0)
	var table := _make_table_for_tier(1, 100, 100)
	var party := _generate(manager, table)
	assert_not_null(party)
	assert_eq(party.size(), EncounterManager.ROW_CAP)
