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
