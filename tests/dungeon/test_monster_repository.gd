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
