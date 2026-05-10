extends GutTest


func test_monster_data_default_row_is_front():
	var data := MonsterData.new()
	assert_eq(data.default_row, Row.FRONT)


func test_monster_data_default_attack_range_is_melee():
	var data := MonsterData.new()
	assert_eq(data.attack_range, WeaponRange.MELEE)


func test_monster_data_can_set_back_row_and_ranged():
	var data := MonsterData.new()
	data.default_row = Row.BACK
	data.attack_range = WeaponRange.RANGED
	assert_eq(data.default_row, Row.BACK)
	assert_eq(data.attack_range, WeaponRange.RANGED)


func test_existing_monster_tres_loads_with_front_melee_fallback():
	var loader := DataLoader.new()
	var all_monsters: Array[MonsterData] = loader.load_all_monsters()
	var slime: MonsterData = null
	for data in all_monsters:
		if data.monster_id == &"slime":
			slime = data
			break
	assert_not_null(slime, "slime should be in repository")
	assert_eq(slime.default_row, Row.FRONT, "default_row should fall back to FRONT")
	assert_eq(slime.attack_range, WeaponRange.MELEE, "attack_range should fall back to MELEE")
