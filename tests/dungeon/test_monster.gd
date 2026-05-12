extends GutTest

const TEST_SEED: int = 12345

var _slime_data: MonsterData


func before_each():
	_slime_data = MonsterData.new()
	_slime_data.monster_id = &"slime"
	_slime_data.monster_name = "Slime"
	_slime_data.max_hp_min = 5
	_slime_data.max_hp_max = 10
	_slime_data.attack = 3
	_slime_data.defense = 1
	_slime_data.agility = 2
	_slime_data.experience = 4


func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_monster_is_refcounted():
	var monster := Monster.new(_slime_data, _make_rng(TEST_SEED))
	assert_true(monster is RefCounted)


func test_monster_exposes_source_data():
	var monster := Monster.new(_slime_data, _make_rng(TEST_SEED))
	assert_eq(monster.data, _slime_data)
	assert_eq(monster.data.monster_id, &"slime")
	assert_eq(monster.data.monster_name, "Slime")


func test_rolled_hp_within_range():
	for i in range(50):
		var rng := _make_rng(TEST_SEED + i)
		var monster := Monster.new(_slime_data, rng)
		assert_between(monster.max_hp, 5, 10,
			"max_hp %d should be in [5, 10]" % monster.max_hp)


func test_current_hp_starts_at_max():
	var monster := Monster.new(_slime_data, _make_rng(TEST_SEED))
	assert_eq(monster.current_hp, monster.max_hp)


func test_same_seed_produces_same_hp():
	var a := Monster.new(_slime_data, _make_rng(TEST_SEED))
	var b := Monster.new(_slime_data, _make_rng(TEST_SEED))
	assert_eq(a.max_hp, b.max_hp)


func test_fixed_range_produces_exact_value():
	var fixed_data := MonsterData.new()
	fixed_data.monster_id = &"fixed"
	fixed_data.monster_name = "Fixed"
	fixed_data.max_hp_min = 10
	fixed_data.max_hp_max = 10
	var monster := Monster.new(fixed_data, _make_rng(TEST_SEED))
	assert_eq(monster.max_hp, 10)
	assert_eq(monster.current_hp, 10)


# --- add-monster-magic: MP roll ---

func test_zero_mp_range_produces_zero_max_mp():
	var monster := Monster.new(_slime_data, _make_rng(TEST_SEED))
	assert_eq(monster.max_mp, 0)
	assert_eq(monster.current_mp, 0)


func test_mp_range_rolls_within_bounds():
	var mage_data := MonsterData.new()
	mage_data.monster_id = &"witch"
	mage_data.monster_name = "Witch"
	mage_data.max_hp_min = 12
	mage_data.max_hp_max = 22
	mage_data.max_mp_min = 6
	mage_data.max_mp_max = 12
	for i in range(50):
		var rng := _make_rng(TEST_SEED + i)
		var monster := Monster.new(mage_data, rng)
		assert_between(monster.max_mp, 6, 12,
			"max_mp %d should be in [6, 12]" % monster.max_mp)


func test_current_mp_starts_at_max():
	var mage_data := MonsterData.new()
	mage_data.monster_id = &"witch"
	mage_data.monster_name = "Witch"
	mage_data.max_hp_min = 12
	mage_data.max_hp_max = 12
	mage_data.max_mp_min = 8
	mage_data.max_mp_max = 8
	var monster := Monster.new(mage_data, _make_rng(TEST_SEED))
	assert_eq(monster.current_mp, monster.max_mp)
	assert_eq(monster.current_mp, 8)


func test_same_seed_produces_same_mp():
	var mage_data := MonsterData.new()
	mage_data.monster_id = &"witch"
	mage_data.monster_name = "Witch"
	mage_data.max_hp_min = 12
	mage_data.max_hp_max = 22
	mage_data.max_mp_min = 6
	mage_data.max_mp_max = 12
	var a := Monster.new(mage_data, _make_rng(TEST_SEED))
	var b := Monster.new(mage_data, _make_rng(TEST_SEED))
	assert_eq(a.max_mp, b.max_mp)
