extends GutTest

var _repo: MonsterRepository
var _slime: MonsterData
var _goblin: MonsterData


func before_each():
	_slime = MonsterData.new()
	_slime.monster_id = &"slime"
	_slime.monster_name = "Slime"
	_slime.max_hp_min = 5
	_slime.max_hp_max = 10

	_goblin = MonsterData.new()
	_goblin.monster_id = &"goblin"
	_goblin.monster_name = "Goblin"
	_goblin.max_hp_min = 8
	_goblin.max_hp_max = 12

	_repo = MonsterRepository.new()


func test_empty_repository_returns_null():
	assert_null(_repo.find(&"slime"))


func test_register_and_lookup():
	_repo.register(_slime)
	var found := _repo.find(&"slime")
	assert_not_null(found)
	assert_eq(found.monster_id, &"slime")


func test_lookup_missing_id_returns_null():
	_repo.register(_slime)
	assert_null(_repo.find(&"nonexistent"))


func test_multiple_monsters_indexed_by_id():
	_repo.register(_slime)
	_repo.register(_goblin)
	assert_eq(_repo.find(&"slime").monster_name, "Slime")
	assert_eq(_repo.find(&"goblin").monster_name, "Goblin")


func test_register_all_bulk():
	_repo.register_all([_slime, _goblin])
	assert_eq(_repo.size(), 2)
	assert_not_null(_repo.find(&"slime"))
	assert_not_null(_repo.find(&"goblin"))


func test_register_rejects_invalid_monster():
	var broken := MonsterData.new()
	broken.monster_id = &""
	broken.monster_name = "Broken"
	assert_false(_repo.register(broken))
	assert_eq(_repo.size(), 0)


func test_register_overwrites_same_id():
	_repo.register(_slime)
	var updated := MonsterData.new()
	updated.monster_id = &"slime"
	updated.monster_name = "King Slime"
	updated.max_hp_min = 50
	updated.max_hp_max = 80
	_repo.register(updated)
	assert_eq(_repo.find(&"slime").monster_name, "King Slime")
	assert_eq(_repo.size(), 1)


func test_loads_from_data_directory():
	var loader := DataLoader.new()
	var all := loader.load_all_monsters()
	_repo.register_all(all)
	assert_not_null(_repo.find(&"slime"))
	assert_not_null(_repo.find(&"goblin"))
	assert_not_null(_repo.find(&"bat"))


# --- add-monster-tier-encounters: find_by_tier ---

func test_find_by_tier_returns_array_of_matching_monsters():
	_slime.tier = 1
	_goblin.tier = 2
	var skeleton := MonsterData.new()
	skeleton.monster_id = &"skeleton"
	skeleton.monster_name = "Skeleton"
	skeleton.max_hp_min = 10
	skeleton.max_hp_max = 16
	skeleton.tier = 2
	_repo.register_all([_slime, _goblin, skeleton])

	var tier_2 := _repo.find_by_tier(2)
	assert_eq(tier_2.size(), 2)
	var ids: Array[StringName] = []
	for m in tier_2:
		ids.append(m.monster_id)
	assert_true(ids.has(&"goblin"))
	assert_true(ids.has(&"skeleton"))


func test_find_by_tier_returns_empty_for_unmatched_tier():
	_slime.tier = 1
	_repo.register(_slime)
	var result := _repo.find_by_tier(99)
	assert_typeof(result, TYPE_ARRAY)
	assert_eq(result.size(), 0)


func test_find_by_tier_never_returns_null():
	# Even on an empty repository, find_by_tier should return an empty array (not null).
	var result := _repo.find_by_tier(3)
	assert_not_null(result)
	assert_eq(result.size(), 0)


func test_find_by_tier_is_deterministic_across_calls():
	_slime.tier = 3
	_goblin.tier = 3
	var bat := MonsterData.new()
	bat.monster_id = &"bat"
	bat.monster_name = "Bat"
	bat.max_hp_min = 3
	bat.max_hp_max = 6
	bat.tier = 3
	_repo.register_all([_slime, _goblin, bat])

	var first := _repo.find_by_tier(3)
	var second := _repo.find_by_tier(3)
	assert_eq(first.size(), second.size())
	for i in first.size():
		assert_eq(first[i].monster_id, second[i].monster_id,
			"find_by_tier should return monsters in the same order each call")


func test_find_by_tier_with_loaded_data_returns_tier_2_monsters():
	var loader := DataLoader.new()
	_repo.register_all(loader.load_all_monsters())
	var tier_2 := _repo.find_by_tier(2)
	var ids: Array[StringName] = []
	for m in tier_2:
		ids.append(m.monster_id)
	assert_true(ids.has(&"goblin"), "tier 2 should contain goblin")
	assert_true(ids.has(&"skeleton"), "tier 2 should contain skeleton")


# --- add-monster-magic: new spell-casting monsters ---

func test_loads_new_spell_casting_monsters():
	var loader := DataLoader.new()
	_repo.register_all(loader.load_all_monsters())
	var new_ids := [&"witch", &"dark_priest", &"imp", &"lich", &"goblin_shaman", &"wraith"]
	for id in new_ids:
		var monster: MonsterData = _repo.find(id)
		assert_not_null(monster, "monster %s should load" % String(id))
		assert_gt(monster.known_spells.size(), 0,
			"monster %s should have at least one known spell" % String(id))


func test_witch_has_expected_spells_and_row():
	var loaded := ResourceLoader.load("res://data/monsters/witch.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.default_row, Row.BACK)
	assert_eq(loaded.attack_range, WeaponRange.RANGED)
	assert_true(loaded.known_spells.has(&"fire"))
	assert_true(loaded.known_spells.has(&"frost"))
	assert_true(loaded.known_spells.has(&"katino"))


func test_dark_priest_has_expected_spells_and_resists():
	var loaded := ResourceLoader.load("res://data/monsters/dark_priest.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.default_row, Row.BACK)
	assert_eq(loaded.attack_range, WeaponRange.MELEE)
	assert_true(loaded.known_spells.has(&"heal"))
	assert_true(loaded.known_spells.has(&"holy"))
	assert_true(loaded.known_spells.has(&"badi"))
	assert_almost_eq(float(loaded.resists.get(&"poison", 0.0)), 1.0, 0.001)
	assert_almost_eq(float(loaded.resists.get(&"sleep", 0.0)), 1.0, 0.001)


func test_imp_has_expected_setup():
	var loaded := ResourceLoader.load("res://data/monsters/imp.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.default_row, Row.FRONT)
	assert_eq(loaded.attack_range, WeaponRange.MELEE)
	assert_true(loaded.known_spells.has(&"dazil"))
	assert_true(loaded.known_spells.has(&"poison_dart"))


func test_lich_has_expected_setup():
	var loaded := ResourceLoader.load("res://data/monsters/lich.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.default_row, Row.BACK)
	assert_eq(loaded.attack_range, WeaponRange.RANGED)
	assert_true(loaded.known_spells.has(&"flame"))
	assert_true(loaded.known_spells.has(&"blizzard"))
	assert_true(loaded.known_spells.has(&"madalto"))
	assert_almost_eq(float(loaded.resists.get(&"poison", 0.0)), 1.0, 0.001)


func test_goblin_shaman_has_expected_setup():
	var loaded := ResourceLoader.load("res://data/monsters/goblin_shaman.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.default_row, Row.BACK)
	assert_eq(loaded.attack_range, WeaponRange.MELEE)
	assert_true(loaded.known_spells.has(&"heal"))
	assert_true(loaded.known_spells.has(&"manifo"))


func test_wraith_has_expected_setup():
	var loaded := ResourceLoader.load("res://data/monsters/wraith.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.default_row, Row.BACK)
	assert_eq(loaded.attack_range, WeaponRange.RANGED)
	assert_true(loaded.known_spells.has(&"poison_dart"))
	assert_true(loaded.known_spells.has(&"dazil"))
	assert_almost_eq(float(loaded.resists.get(&"blind", 0.0)), 1.0, 0.001)


func test_new_monsters_mp_supports_cheapest_known_spell():
	var loader := DataLoader.new()
	var spell_repo := loader.load_spell_repository()
	_repo.register_all(loader.load_all_monsters())
	var new_ids := [&"witch", &"dark_priest", &"imp", &"lich", &"goblin_shaman", &"wraith"]
	for id in new_ids:
		var monster: MonsterData = _repo.find(id)
		assert_not_null(monster)
		var cheapest: int = 999
		for spell_id in monster.known_spells:
			var spell: SpellData = spell_repo.find(spell_id)
			if spell != null and spell.mp_cost < cheapest:
				cheapest = spell.mp_cost
		assert_gte(monster.max_mp_min, cheapest,
			"monster %s max_mp_min (%d) should cover cheapest known spell mp_cost (%d)"
				% [String(id), monster.max_mp_min, cheapest])
