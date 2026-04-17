extends GutTest

const TEST_SEED: int = 12345


func _make_monster_data(id: StringName, name: String) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = name
	data.max_hp_min = 5
	data.max_hp_max = 5
	return data


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func test_party_is_refcounted():
	var party := MonsterParty.new()
	assert_true(party is RefCounted)


func test_empty_party_has_zero_members():
	var party := MonsterParty.new()
	assert_eq(party.size(), 0)
	assert_true(party.is_empty())


func test_party_add_monster():
	var party := MonsterParty.new()
	party.add(Monster.new(_make_monster_data(&"slime", "Slime"), _make_rng()))
	party.add(Monster.new(_make_monster_data(&"slime", "Slime"), _make_rng()))
	party.add(Monster.new(_make_monster_data(&"goblin", "Goblin"), _make_rng()))
	assert_eq(party.size(), 3)


func test_party_counts_by_species():
	var party := MonsterParty.new()
	party.add(Monster.new(_make_monster_data(&"slime", "Slime"), _make_rng()))
	party.add(Monster.new(_make_monster_data(&"slime", "Slime"), _make_rng()))
	party.add(Monster.new(_make_monster_data(&"goblin", "Goblin"), _make_rng()))
	var counts := party.counts_by_species()
	assert_eq(counts[&"slime"], 2)
	assert_eq(counts[&"goblin"], 1)


func test_party_preserves_insertion_order():
	var party := MonsterParty.new()
	var m1 := Monster.new(_make_monster_data(&"slime", "Slime"), _make_rng())
	var m2 := Monster.new(_make_monster_data(&"goblin", "Goblin"), _make_rng())
	party.add(m1)
	party.add(m2)
	assert_eq(party.members[0], m1)
	assert_eq(party.members[1], m2)
