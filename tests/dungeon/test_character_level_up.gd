extends GutTest


var _loader: DataLoader
var _human: RaceData
var _fighter_job: JobData
var _mage_job: JobData


func before_each():
	_loader = DataLoader.new()
	for race in _loader.load_all_races():
		if race.race_name == "Human":
			_human = race
	for job in _loader.load_all_jobs():
		if job.job_name == "Fighter":
			_fighter_job = job
		elif job.job_name == "Mage":
			_mage_job = job


func _make_character(job: JobData, vit: int = 12, level: int = 1, current_hp: int = 15, max_hp: int = 15, current_mp: int = 0, max_mp: int = 0) -> Character:
	var ch := Character.new()
	ch.character_name = "Tester"
	ch.race = _human
	ch.job = job
	ch.level = level
	ch.base_stats = {&"STR": 14, &"INT": 12, &"PIE": 10, &"VIT": vit, &"AGI": 10, &"LUC": 10}
	ch.max_hp = max_hp
	ch.current_hp = current_hp
	ch.max_mp = max_mp
	ch.current_mp = current_mp
	ch.accumulated_exp = 0
	return ch


# --- accumulation ---

func test_gain_experience_accumulates_under_threshold():
	var ch := _make_character(_fighter_job)
	ch.gain_experience(100)
	assert_eq(ch.level, 1)
	assert_eq(ch.accumulated_exp, 100)


func test_gain_experience_zero_does_not_change_accumulated():
	var ch := _make_character(_fighter_job)
	ch.gain_experience(0)
	assert_eq(ch.accumulated_exp, 0)


# --- single level-up ---

func test_gain_experience_levels_up_on_threshold():
	var ch := _make_character(_fighter_job)
	ch.accumulated_exp = 900
	var threshold: int = _fighter_job.exp_to_reach_level(2)  # 1000 for fighter
	assert_eq(threshold, 1000)
	ch.gain_experience(200)
	assert_eq(ch.level, 2)


# --- HP growth on level-up ---

func test_level_up_increases_max_hp_by_job_growth_plus_vit_third():
	var ch := _make_character(_fighter_job, 12, 1, 15, 15)
	# fighter hp_per_level = 7, VIT = 12 → +7 + 12/3 = +11
	ch.gain_experience(1000)  # threshold
	assert_eq(ch.level, 2)
	assert_eq(ch.max_hp, 15 + 11)
	assert_eq(ch.current_hp, 15 + 11)


func test_level_up_minimum_hp_growth_is_one():
	# Create a hypothetical job where hp_per_level is 0 and VIT is 0
	var job := JobData.new()
	job.job_name = "Weak"
	job.base_hp = 4
	job.has_magic = false
	job.base_mp = 0
	job.hp_per_level = 0
	job.mp_per_level = 0
	job.exp_table = PackedInt64Array([100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200])
	var ch := Character.new()
	ch.character_name = "Weakling"
	ch.race = _human
	ch.job = job
	ch.level = 1
	ch.base_stats = {&"STR": 1, &"INT": 1, &"PIE": 1, &"VIT": 0, &"AGI": 1, &"LUC": 1}
	ch.max_hp = 4
	ch.current_hp = 4
	ch.max_mp = 0
	ch.current_mp = 0
	ch.accumulated_exp = 0
	ch.gain_experience(100)
	assert_eq(ch.level, 2)
	# growth = 0 + 0/3 = 0 → floor to 1
	assert_eq(ch.max_hp, 5)


# --- MP growth on level-up (magic only) ---

func test_level_up_mage_gains_mp():
	var ch := _make_character(_mage_job, 10, 1, 8, 8, 5, 5)
	# mage mp_per_level = 2
	ch.gain_experience(1100)  # threshold for mage
	assert_eq(ch.level, 2)
	assert_eq(ch.max_mp, 5 + 2)
	assert_eq(ch.current_mp, 5 + 2)


func test_level_up_fighter_does_not_gain_mp():
	var ch := _make_character(_fighter_job, 12, 1, 15, 15)
	ch.gain_experience(1000)
	assert_eq(ch.max_mp, 0)
	assert_eq(ch.current_mp, 0)


# --- no stat change ---

func test_level_up_does_not_change_base_stats():
	var ch := _make_character(_fighter_job)
	var stats_before := ch.base_stats.duplicate()
	ch.gain_experience(1000)
	for key in Character.STAT_KEYS:
		assert_eq(ch.base_stats[key], stats_before[key], String(key))


# --- multi-level ---

func test_gain_experience_can_trigger_multiple_level_ups():
	var ch := _make_character(_fighter_job)
	# fighter thresholds: 1000, 1724, 2972. Give 5000 at lv1 → reach lv4
	ch.gain_experience(5000)
	assert_gte(ch.level, 3, "should have reached at least lv3 with 5000 exp")


func test_level_up_stops_when_exp_below_next_threshold():
	var ch := _make_character(_fighter_job)
	# 1500 → lv2 (threshold 1000), but not lv3 (threshold 1724)
	ch.gain_experience(1500)
	assert_eq(ch.level, 2)


# --- to_dict / from_dict roundtrip ---

func test_accumulated_exp_persists_via_to_dict_from_dict():
	var ch := _make_character(_fighter_job)
	ch.gain_experience(500)
	var data := ch.to_dict()
	var restored := Character.from_dict(data)
	assert_eq(restored.accumulated_exp, 500)
