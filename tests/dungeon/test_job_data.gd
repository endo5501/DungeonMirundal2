extends GutTest

var _fighter: JobData
var _mage: JobData
var _lord: JobData

func before_each():
	_fighter = JobData.new()
	_fighter.job_name = "Fighter"
	_fighter.base_hp = 10
	_fighter.mage_school = false
	_fighter.priest_school = false
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
	_mage.mage_school = true
	_mage.priest_school = false
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
	_lord.mage_school = false
	_lord.priest_school = true
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
	assert_eq(_fighter.mage_school, false)
	assert_eq(_fighter.priest_school, false)
	assert_eq(_fighter.base_mp, 0)

func test_mage_fields():
	assert_eq(_mage.job_name, "Mage")
	assert_eq(_mage.mage_school, true)
	assert_eq(_mage.priest_school, false)
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

# --- magic-school flags & is_magic_capable ---

func test_is_magic_capable_for_fighter():
	assert_false(_fighter.is_magic_capable())

func test_is_magic_capable_for_mage():
	assert_true(_mage.is_magic_capable())

func test_is_magic_capable_for_priest_only():
	var priest := JobData.new()
	priest.priest_school = true
	assert_true(priest.is_magic_capable())

func test_is_magic_capable_for_bishop_with_both_schools():
	var bishop := JobData.new()
	bishop.mage_school = true
	bishop.priest_school = true
	assert_true(bishop.is_magic_capable())

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


# --- tighten-types-and-contracts: id field ---

func test_job_data_has_id_field():
	var job := JobData.new()
	job.id = &"fighter"
	assert_eq(job.id, &"fighter")
	assert_typeof(job.id, TYPE_STRING_NAME)


func test_job_data_id_defaults_to_empty_string_name():
	var job := JobData.new()
	assert_eq(job.id, &"")


func test_loaded_job_tres_files_have_id_matching_filename():
	var loader := DataLoader.new()
	var jobs := loader.load_all_jobs()
	assert_gt(jobs.size(), 0)
	for job in jobs:
		var basename := job.resource_path.get_file().get_basename()
		assert_eq(String(job.id), basename, "job %s id should equal filename" % job.resource_path)


# --- add-magic-system: per-job spell_progression on disk ---

func _find_loaded(job_name: String) -> JobData:
	var loader := DataLoader.new()
	for j in loader.load_all_jobs():
		if j.job_name == job_name:
			return j
	return null


func test_loaded_fighter_has_no_magic_and_empty_progression():
	var f := _find_loaded("Fighter")
	assert_not_null(f)
	assert_eq(f.mage_school, false)
	assert_eq(f.priest_school, false)
	assert_eq(f.spell_progression.size(), 0)


func test_loaded_thief_has_no_magic_and_empty_progression():
	var t := _find_loaded("Thief")
	assert_not_null(t)
	assert_eq(t.mage_school, false)
	assert_eq(t.priest_school, false)
	assert_eq(t.spell_progression.size(), 0)


func test_loaded_ninja_has_no_magic_and_empty_progression():
	var n := _find_loaded("Ninja")
	assert_not_null(n)
	assert_eq(n.mage_school, false)
	assert_eq(n.priest_school, false)
	assert_eq(n.spell_progression.size(), 0)


func test_loaded_mage_has_only_mage_school_and_progression_at_levels_1_and_3():
	var m := _find_loaded("Mage")
	assert_not_null(m)
	assert_true(m.mage_school)
	assert_false(m.priest_school)
	assert_true(m.spell_progression.has(1))
	assert_true(m.spell_progression.has(3))
	var lv1: Array = m.spell_progression[1]
	assert_true(lv1.has(&"fire"))
	assert_true(lv1.has(&"frost"))
	var lv3: Array = m.spell_progression[3]
	assert_true(lv3.has(&"flame"))
	assert_true(lv3.has(&"blizzard"))


func test_loaded_priest_has_only_priest_school_and_progression():
	var p := _find_loaded("Priest")
	assert_not_null(p)
	assert_false(p.mage_school)
	assert_true(p.priest_school)
	var lv1: Array = p.spell_progression[1]
	assert_true(lv1.has(&"heal"))
	assert_true(lv1.has(&"holy"))


func test_loaded_bishop_has_both_schools_and_progression_at_levels_2_and_5():
	var b := _find_loaded("Bishop")
	assert_not_null(b)
	assert_true(b.mage_school)
	assert_true(b.priest_school)
	assert_true(b.spell_progression.has(2))
	assert_true(b.spell_progression.has(5))
	var lv2: Array = b.spell_progression[2]
	for sid in [&"fire", &"frost", &"heal", &"holy"]:
		assert_true(lv2.has(sid), "bishop lv2 missing %s" % sid)
	var lv5: Array = b.spell_progression[5]
	for sid in [&"flame", &"blizzard", &"heala", &"allheal"]:
		assert_true(lv5.has(sid), "bishop lv5 missing %s" % sid)


func test_loaded_samurai_has_mage_school_and_starts_at_level_4():
	var s := _find_loaded("Samurai")
	assert_not_null(s)
	assert_true(s.mage_school)
	assert_false(s.priest_school)
	assert_true(s.spell_progression.has(4))
	assert_true(s.spell_progression.has(8))
	var lv4: Array = s.spell_progression[4]
	assert_true(lv4.has(&"fire"))
	assert_true(lv4.has(&"frost"))


func test_loaded_lord_has_priest_school_and_starts_at_level_4():
	var l := _find_loaded("Lord")
	assert_not_null(l)
	assert_false(l.mage_school)
	assert_true(l.priest_school)
	assert_true(l.spell_progression.has(4))
	assert_true(l.spell_progression.has(8))
	var lv4: Array = l.spell_progression[4]
	assert_true(lv4.has(&"heal"))
	assert_true(lv4.has(&"holy"))


func test_spell_progression_ids_resolve_in_spell_repository():
	var loader := DataLoader.new()
	var repo := loader.load_spell_repository()
	for job in loader.load_all_jobs():
		for lv in job.spell_progression.keys():
			for sid in job.spell_progression[lv]:
				assert_true(repo.has_id(sid),
					"job %s lv %d spell id %s should exist in SpellRepository" % [job.job_name, lv, sid])
