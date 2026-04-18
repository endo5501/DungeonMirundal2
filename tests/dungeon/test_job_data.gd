extends GutTest

var _fighter: JobData
var _mage: JobData
var _lord: JobData

func before_each():
	_fighter = JobData.new()
	_fighter.job_name = "Fighter"
	_fighter.base_hp = 10
	_fighter.has_magic = false
	_fighter.base_mp = 0
	_fighter.required_str = 0
	_fighter.required_int = 0
	_fighter.required_pie = 0
	_fighter.required_vit = 0
	_fighter.required_agi = 0
	_fighter.required_luc = 0

	_mage = JobData.new()
	_mage.job_name = "Mage"
	_mage.base_hp = 4
	_mage.has_magic = true
	_mage.base_mp = 5
	_mage.required_str = 0
	_mage.required_int = 11
	_mage.required_pie = 0
	_mage.required_vit = 0
	_mage.required_agi = 0
	_mage.required_luc = 0

	_lord = JobData.new()
	_lord.job_name = "Lord"
	_lord.base_hp = 10
	_lord.has_magic = true
	_lord.base_mp = 2
	_lord.required_str = 15
	_lord.required_int = 12
	_lord.required_pie = 12
	_lord.required_vit = 15
	_lord.required_agi = 14
	_lord.required_luc = 15

func test_job_data_is_resource():
	assert_true(_fighter is Resource)

func test_fighter_fields():
	assert_eq(_fighter.job_name, "Fighter")
	assert_eq(_fighter.base_hp, 10)
	assert_eq(_fighter.has_magic, false)
	assert_eq(_fighter.base_mp, 0)

func test_mage_fields():
	assert_eq(_mage.job_name, "Mage")
	assert_eq(_mage.has_magic, true)
	assert_eq(_mage.base_mp, 5)
	assert_eq(_mage.required_int, 11)

func test_fighter_qualifies_with_any_stats():
	var stats := {&"STR": 8, &"INT": 8, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	assert_true(_fighter.can_qualify(stats))

func test_mage_qualifies_with_sufficient_int():
	var stats := {&"STR": 8, &"INT": 11, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	assert_true(_mage.can_qualify(stats))

func test_mage_does_not_qualify_with_insufficient_int():
	var stats := {&"STR": 8, &"INT": 10, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	assert_false(_mage.can_qualify(stats))

func test_lord_qualifies_with_all_stats_met():
	var stats := {&"STR": 15, &"INT": 12, &"PIE": 12, &"VIT": 15, &"AGI": 14, &"LUC": 15}
	assert_true(_lord.can_qualify(stats))

func test_lord_fails_if_single_stat_below():
	var stats := {&"STR": 15, &"INT": 12, &"PIE": 12, &"VIT": 14, &"AGI": 14, &"LUC": 15}
	assert_false(_lord.can_qualify(stats))

# --- hp_per_level / mp_per_level / exp_table (combat-system) ---

func test_hp_per_level_field_assignable():
	_fighter.hp_per_level = 4
	assert_eq(_fighter.hp_per_level, 4)

func test_mp_per_level_field_assignable():
	_mage.mp_per_level = 2
	assert_eq(_mage.mp_per_level, 2)

func test_exp_table_field_holds_packed_int_array():
	_fighter.exp_table = PackedInt64Array([1000, 2000, 3000])
	assert_eq(_fighter.exp_table.size(), 3)
	assert_eq(_fighter.exp_table[0], 1000)
	assert_eq(_fighter.exp_table[2], 3000)

# --- exp_to_reach_level ---

func test_exp_to_reach_level_for_level_one_or_below_is_zero():
	_fighter.exp_table = PackedInt64Array([1000, 2000])
	assert_eq(_fighter.exp_to_reach_level(1), 0)
	assert_eq(_fighter.exp_to_reach_level(0), 0)
	assert_eq(_fighter.exp_to_reach_level(-5), 0)

func test_exp_to_reach_level_two_returns_first_entry():
	_fighter.exp_table = PackedInt64Array([1000, 2000, 3000])
	assert_eq(_fighter.exp_to_reach_level(2), 1000)

func test_exp_to_reach_level_three_returns_second_entry():
	_fighter.exp_table = PackedInt64Array([1000, 2000, 3000])
	assert_eq(_fighter.exp_to_reach_level(3), 2000)

func test_exp_to_reach_level_out_of_range_returns_last_entry():
	_fighter.exp_table = PackedInt64Array([1000, 2000, 3000])
	assert_eq(_fighter.exp_to_reach_level(10), 3000)
