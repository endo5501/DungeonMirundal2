extends GutTest


func _make_data(id: StringName, row: int, attack_range: int = WeaponRange.MELEE) -> MonsterData:
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
	return data


func _make_repository(entries: Array) -> MonsterRepository:
	var repo := MonsterRepository.new()
	for e in entries:
		repo.register(e)
	return repo


func _make_pattern_with_group(monster_id: StringName, count: int) -> EncounterPattern:
	var pattern := EncounterPattern.new()
	var group := MonsterGroupSpec.new()
	group.monster_id = monster_id
	group.count_min = count
	group.count_max = count
	pattern.groups.append(group)
	return pattern


func _populate(manager: EncounterManager, pattern: EncounterPattern) -> MonsterParty:
	# Bypass _table machinery: directly invoke private populate via reflection-ish helper.
	# Instead, set up a minimal table containing the pattern with full weight.
	var entry := EncounterEntry.new()
	entry.weight = 1
	entry.pattern = pattern
	var table := EncounterTableData.new()
	table.entries.append(entry)
	table.probability_per_step = 1.0
	manager.set_table(table)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	return manager.generate(rng)


func test_front_default_monster_spawns_in_front_row():
	var slime_data := _make_data(&"slime", Row.FRONT)
	var repo := _make_repository([slime_data])
	var manager := EncounterManager.new(repo, 0)
	var pattern := _make_pattern_with_group(&"slime", 3)
	var party := _populate(manager, pattern)
	assert_eq(party.size(), 3)
	for m in party.members:
		assert_eq(m.data.default_row, Row.FRONT)


func test_back_default_monster_spawns_in_back_row():
	var witch_data := _make_data(&"witch", Row.BACK)
	var repo := _make_repository([witch_data])
	var manager := EncounterManager.new(repo, 0)
	var pattern := _make_pattern_with_group(&"witch", 2)
	var party := _populate(manager, pattern)
	assert_eq(party.size(), 2)
	for m in party.members:
		assert_eq(m.data.default_row, Row.BACK)


func test_front_overflow_truncates_at_five():
	var slime_data := _make_data(&"slime", Row.FRONT)
	var repo := _make_repository([slime_data])
	var manager := EncounterManager.new(repo, 0)
	var pattern := _make_pattern_with_group(&"slime", 7)
	var party := _populate(manager, pattern)
	assert_eq(party.size(), EncounterManager.ROW_CAP)


func test_two_front_groups_truncate_with_first_group_priority():
	var slime_data := _make_data(&"slime", Row.FRONT)
	var goblin_data := _make_data(&"goblin", Row.FRONT)
	var repo := _make_repository([slime_data, goblin_data])
	var manager := EncounterManager.new(repo, 0)
	var pattern := EncounterPattern.new()
	var g1 := MonsterGroupSpec.new()
	g1.monster_id = &"slime"
	g1.count_min = 3
	g1.count_max = 3
	var g2 := MonsterGroupSpec.new()
	g2.monster_id = &"goblin"
	g2.count_min = 4
	g2.count_max = 4
	pattern.groups.append(g1)
	pattern.groups.append(g2)
	var party := _populate(manager, pattern)
	assert_eq(party.size(), EncounterManager.ROW_CAP)
	# First 3 should be slimes (priority), last 2 should be goblins (truncated)
	var slime_count := 0
	var goblin_count := 0
	for m in party.members:
		if m.data.monster_id == &"slime":
			slime_count += 1
		elif m.data.monster_id == &"goblin":
			goblin_count += 1
	assert_eq(slime_count, 3)
	assert_eq(goblin_count, 2)


func test_mixed_row_pattern_within_caps_is_unchanged():
	var slime_data := _make_data(&"slime", Row.FRONT)
	var witch_data := _make_data(&"witch", Row.BACK)
	var repo := _make_repository([slime_data, witch_data])
	var manager := EncounterManager.new(repo, 0)
	var pattern := EncounterPattern.new()
	var g1 := MonsterGroupSpec.new()
	g1.monster_id = &"slime"
	g1.count_min = 3
	g1.count_max = 3
	var g2 := MonsterGroupSpec.new()
	g2.monster_id = &"witch"
	g2.count_min = 2
	g2.count_max = 2
	pattern.groups.append(g1)
	pattern.groups.append(g2)
	var party := _populate(manager, pattern)
	assert_eq(party.size(), 5)


func test_truncation_does_not_raise_and_returns_party():
	var slime_data := _make_data(&"slime", Row.FRONT)
	var repo := _make_repository([slime_data])
	var manager := EncounterManager.new(repo, 0)
	var pattern := _make_pattern_with_group(&"slime", 100)
	var party := _populate(manager, pattern)
	assert_not_null(party)
	assert_eq(party.size(), EncounterManager.ROW_CAP)
