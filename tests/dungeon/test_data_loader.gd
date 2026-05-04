extends GutTest

var _loader: DataLoader

func before_each():
	_loader = DataLoader.new()

func test_load_all_races_returns_5():
	var races := _loader.load_all_races()
	assert_eq(races.size(), 5)

func test_load_all_races_contains_expected_names():
	var races := _loader.load_all_races()
	var names: Array[String] = []
	for race in races:
		names.append(race.race_name)
	names.sort()
	assert_eq(names, ["Dwarf", "Elf", "Gnome", "Hobbit", "Human"])

func test_load_all_jobs_returns_8():
	var jobs := _loader.load_all_jobs()
	assert_eq(jobs.size(), 8)

func test_load_all_jobs_contains_expected_names():
	var jobs := _loader.load_all_jobs()
	var names: Array[String] = []
	for job in jobs:
		names.append(job.job_name)
	names.sort()
	assert_eq(names, ["Bishop", "Fighter", "Lord", "Mage", "Ninja", "Priest", "Samurai", "Thief"])

func test_loaded_human_has_correct_stats():
	var races := _loader.load_all_races()
	var human: RaceData
	for race in races:
		if race.race_name == "Human":
			human = race
			break
	assert_not_null(human)
	assert_eq(human.base_str, 8)
	assert_eq(human.base_int, 8)
	assert_eq(human.base_pie, 8)
	assert_eq(human.base_vit, 8)
	assert_eq(human.base_agi, 8)
	assert_eq(human.base_luc, 8)

func test_loaded_mage_has_correct_requirements():
	var jobs := _loader.load_all_jobs()
	var mage: JobData
	for job in jobs:
		if job.job_name == "Mage":
			mage = job
			break
	assert_not_null(mage)
	assert_eq(mage.required_int, 11)
	assert_eq(mage.has_magic, true)
	assert_eq(mage.base_mp, 5)

func test_loaded_fighter_has_no_requirements():
	var jobs := _loader.load_all_jobs()
	var fighter: JobData
	for job in jobs:
		if job.job_name == "Fighter":
			fighter = job
			break
	assert_not_null(fighter)
	assert_eq(fighter.required_str, 0)
	assert_eq(fighter.required_int, 0)
	assert_eq(fighter.required_pie, 0)
	assert_eq(fighter.required_vit, 0)
	assert_eq(fighter.required_agi, 0)
	assert_eq(fighter.required_luc, 0)


func test_load_all_monsters_returns_3():
	var monsters := _loader.load_all_monsters()
	assert_eq(monsters.size(), 3)


func test_load_all_monsters_contains_expected_ids():
	var monsters := _loader.load_all_monsters()
	var ids: Array[StringName] = []
	for m in monsters:
		ids.append(m.monster_id)
	assert_true(ids.has(&"slime"))
	assert_true(ids.has(&"goblin"))
	assert_true(ids.has(&"bat"))


func test_loaded_slime_has_correct_fields():
	var monsters := _loader.load_all_monsters()
	var slime: MonsterData
	for m in monsters:
		if m.monster_id == &"slime":
			slime = m
			break
	assert_not_null(slime)
	assert_eq(slime.monster_name, "Slime")
	assert_eq(slime.max_hp_min, 5)
	assert_eq(slime.max_hp_max, 10)
	assert_eq(slime.attack, 3)
	assert_true(slime.is_valid())


func test_load_all_encounter_tables_returns_at_least_one():
	var tables := _loader.load_all_encounter_tables()
	assert_gte(tables.size(), 1)


func test_loaded_floor_1_table_is_valid():
	var tables := _loader.load_all_encounter_tables()
	var floor_1: EncounterTableData
	for t in tables:
		if t.floor == 1:
			floor_1 = t
			break
	assert_not_null(floor_1)
	assert_true(floor_1.is_valid())
	assert_gt(floor_1.entries.size(), 0)
	assert_gt(floor_1.probability_per_step, 0.0)


func test_loaded_floor_2_table_is_valid():
	var tables := _loader.load_all_encounter_tables()
	var floor_2: EncounterTableData
	for t in tables:
		if t.floor == 2:
			floor_2 = t
			break
	assert_not_null(floor_2)
	assert_true(floor_2.is_valid())
	assert_gt(floor_2.entries.size(), 0)
	assert_gt(floor_2.probability_per_step, 0.0)


func test_load_all_encounter_tables_returns_floor_1_and_2():
	var tables := _loader.load_all_encounter_tables()
	var floor_numbers: Array[int] = []
	for t in tables:
		floor_numbers.append(t.floor)
	assert_true(floor_numbers.has(1), "encounter tables include floor 1")
	assert_true(floor_numbers.has(2), "encounter tables include floor 2")


# --- combat-system: per-level growth and exp_table ---

func _find_job_by_name(name: String) -> JobData:
	var jobs := _loader.load_all_jobs()
	for j in jobs:
		if j.job_name == name:
			return j
	return null


func test_loaded_fighter_has_positive_hp_per_level():
	var fighter := _find_job_by_name("Fighter")
	assert_not_null(fighter)
	assert_gt(fighter.hp_per_level, 0)


func test_loaded_fighter_has_zero_mp_per_level():
	var fighter := _find_job_by_name("Fighter")
	assert_not_null(fighter)
	assert_eq(fighter.mp_per_level, 0)


func test_loaded_thief_has_zero_mp_per_level():
	var thief := _find_job_by_name("Thief")
	assert_not_null(thief)
	assert_eq(thief.mp_per_level, 0)


func test_loaded_mage_has_positive_hp_and_mp_per_level():
	var mage := _find_job_by_name("Mage")
	assert_not_null(mage)
	assert_gt(mage.hp_per_level, 0)
	assert_gt(mage.mp_per_level, 0)


func test_loaded_all_jobs_have_exp_table_with_at_least_12_entries():
	var jobs := _loader.load_all_jobs()
	for job in jobs:
		assert_gte(job.exp_table.size(), 12, "%s exp_table size" % job.job_name)


func test_loaded_all_jobs_have_monotonic_exp_table():
	var jobs := _loader.load_all_jobs()
	for job in jobs:
		for i in range(1, job.exp_table.size()):
			assert_gt(job.exp_table[i], job.exp_table[i - 1],
				"%s exp_table[%d] > exp_table[%d]" % [job.job_name, i, i - 1])


# --- items-and-economy: item loading ---

func test_load_all_items_returns_repository():
	var repo := _loader.load_all_items()
	assert_not_null(repo)
	assert_is(repo, ItemRepository)


func test_load_all_items_contains_long_sword():
	var repo := _loader.load_all_items()
	var sword := repo.find(&"long_sword")
	assert_not_null(sword)
	assert_eq(sword.item_name, "Long Sword")
	assert_eq(sword.category, Item.ItemCategory.WEAPON)


func test_load_all_items_has_every_equip_slot_covered():
	var repo := _loader.load_all_items()
	var needed_slots := [
		Item.EquipSlot.WEAPON,
		Item.EquipSlot.ARMOR,
		Item.EquipSlot.HELMET,
		Item.EquipSlot.SHIELD,
		Item.EquipSlot.GAUNTLET,
		Item.EquipSlot.ACCESSORY,
	]
	for slot in needed_slots:
		var covered := false
		for item in repo.all():
			if item.equip_slot == slot:
				covered = true
				break
		assert_true(covered, "no item for slot %d" % slot)


# --- missing-directory diagnostics ---

func test_load_resources_missing_dir_returns_empty_and_logs_error():
	var results: Array = _loader._load_resources("res://this_dir_does_not_exist_xyz/")
	assert_eq(results.size(), 0)
	assert_push_error("cannot open")
