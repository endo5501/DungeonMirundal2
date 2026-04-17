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
