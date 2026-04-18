extends GutTest

var _slime: MonsterData
var _goblin: MonsterData

func before_each():
	_slime = MonsterData.new()
	_slime.monster_id = &"slime"
	_slime.monster_name = "Slime"
	_slime.max_hp_min = 5
	_slime.max_hp_max = 10
	_slime.attack = 3
	_slime.defense = 1
	_slime.agility = 2
	_slime.experience = 4

	_goblin = MonsterData.new()
	_goblin.monster_id = &"goblin"
	_goblin.monster_name = "Goblin"
	_goblin.max_hp_min = 8
	_goblin.max_hp_max = 12
	_goblin.attack = 5
	_goblin.defense = 2
	_goblin.agility = 4
	_goblin.experience = 7


func test_monster_data_is_resource():
	assert_true(_slime is Resource)


func test_slime_fields_readable():
	assert_eq(_slime.monster_id, &"slime")
	assert_eq(_slime.monster_name, "Slime")
	assert_eq(_slime.max_hp_min, 5)
	assert_eq(_slime.max_hp_max, 10)
	assert_eq(_slime.attack, 3)
	assert_eq(_slime.defense, 1)
	assert_eq(_slime.agility, 2)
	assert_eq(_slime.experience, 4)


func test_goblin_fields_readable():
	assert_eq(_goblin.monster_id, &"goblin")
	assert_eq(_goblin.max_hp_min, 8)
	assert_eq(_goblin.max_hp_max, 12)


func test_is_valid_returns_true_for_normal_range():
	assert_true(_slime.is_valid())


func test_is_valid_returns_true_when_min_equals_max():
	var fixed := MonsterData.new()
	fixed.monster_id = &"fixed"
	fixed.monster_name = "Fixed"
	fixed.max_hp_min = 10
	fixed.max_hp_max = 10
	assert_true(fixed.is_valid())


func test_is_valid_returns_false_when_min_exceeds_max():
	var broken := MonsterData.new()
	broken.monster_id = &"broken"
	broken.monster_name = "Broken"
	broken.max_hp_min = 15
	broken.max_hp_max = 10
	assert_false(broken.is_valid())


func test_is_valid_returns_false_when_min_is_negative():
	var broken := MonsterData.new()
	broken.monster_id = &"broken"
	broken.monster_name = "Broken"
	broken.max_hp_min = -1
	broken.max_hp_max = 10
	assert_false(broken.is_valid())


func test_is_valid_returns_false_when_monster_id_is_empty():
	var broken := MonsterData.new()
	broken.monster_id = &""
	broken.monster_name = "NoId"
	broken.max_hp_min = 5
	broken.max_hp_max = 10
	assert_false(broken.is_valid())


func test_slime_tres_loads_with_expected_fields():
	var loaded := ResourceLoader.load("res://data/monsters/slime.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.monster_id, &"slime")
	assert_eq(loaded.monster_name, "Slime")
	assert_eq(loaded.max_hp_min, 5)
	assert_eq(loaded.max_hp_max, 10)
	assert_true(loaded.is_valid())


func test_goblin_tres_loads_with_expected_fields():
	var loaded := ResourceLoader.load("res://data/monsters/goblin.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.monster_id, &"goblin")
	assert_eq(loaded.max_hp_min, 8)
	assert_eq(loaded.max_hp_max, 12)


func test_bat_tres_loads_with_expected_fields():
	var loaded := ResourceLoader.load("res://data/monsters/bat.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.monster_id, &"bat")
	assert_eq(loaded.agility, 7)


# --- items-and-economy: gold range ---

func test_gold_fields_default_to_zero():
	var md := MonsterData.new()
	md.monster_id = &"m"
	md.monster_name = "m"
	md.max_hp_min = 1
	md.max_hp_max = 1
	assert_eq(md.gold_min, 0)
	assert_eq(md.gold_max, 0)
	assert_true(md.is_valid())


func test_gold_range_valid_when_min_le_max():
	var md := MonsterData.new()
	md.monster_id = &"m"
	md.monster_name = "m"
	md.max_hp_min = 1
	md.max_hp_max = 1
	md.gold_min = 5
	md.gold_max = 15
	assert_true(md.is_valid())


func test_gold_range_rejects_min_greater_than_max():
	var md := MonsterData.new()
	md.monster_id = &"m"
	md.monster_name = "m"
	md.max_hp_min = 1
	md.max_hp_max = 1
	md.gold_min = 20
	md.gold_max = 5
	assert_false(md.is_valid())


func test_gold_range_rejects_negative_min():
	var md := MonsterData.new()
	md.monster_id = &"m"
	md.monster_name = "m"
	md.max_hp_min = 1
	md.max_hp_max = 1
	md.gold_min = -1
	md.gold_max = 0
	assert_false(md.is_valid())


func test_slime_tres_has_gold_range():
	var loaded := ResourceLoader.load("res://data/monsters/slime.tres") as MonsterData
	assert_gte(loaded.gold_min, 0)
	assert_gte(loaded.gold_max, loaded.gold_min)


func test_goblin_tres_has_gold_range():
	var loaded := ResourceLoader.load("res://data/monsters/goblin.tres") as MonsterData
	assert_eq(loaded.gold_min, 5)
	assert_eq(loaded.gold_max, 15)


func test_bat_tres_has_gold_range():
	var loaded := ResourceLoader.load("res://data/monsters/bat.tres") as MonsterData
	assert_gte(loaded.gold_max, loaded.gold_min)
