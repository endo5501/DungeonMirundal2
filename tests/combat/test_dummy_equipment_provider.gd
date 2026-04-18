extends GutTest


var _provider: DummyEquipmentProvider
var _loader: DataLoader
var _races_by_name: Dictionary = {}
var _jobs_by_name: Dictionary = {}


func before_each():
	_provider = DummyEquipmentProvider.new()
	_loader = DataLoader.new()
	_races_by_name.clear()
	for race in _loader.load_all_races():
		_races_by_name[race.race_name] = race
	_jobs_by_name.clear()
	for job in _loader.load_all_jobs():
		_jobs_by_name[job.job_name] = job


func _make_character(job_name: String, stats: Dictionary) -> Character:
	var ch := Character.new()
	ch.character_name = "Test" + job_name
	ch.race = _races_by_name["Human"]
	ch.job = _jobs_by_name[job_name]
	ch.level = 1
	ch.base_stats = stats.duplicate()
	ch.max_hp = 10
	ch.current_hp = 10
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


func _default_stats() -> Dictionary:
	return {
		&"STR": 14,
		&"INT": 12,
		&"PIE": 12,
		&"VIT": 12,
		&"AGI": 10,
		&"LUC": 10,
	}


func test_extends_equipment_provider():
	assert_is(_provider, EquipmentProvider)


# --- Fighter: weapon 5 / armor 3 ---

func test_fighter_attack_uses_str_half_plus_weapon_bonus():
	var ch := _make_character("Fighter", _default_stats())  # STR 14
	assert_eq(_provider.get_attack(ch), 14 / 2 + 5)


func test_fighter_defense_uses_vit_third_plus_armor_bonus():
	var ch := _make_character("Fighter", _default_stats())  # VIT 12
	assert_eq(_provider.get_defense(ch), 12 / 3 + 3)


func test_fighter_agility_is_just_agi():
	var ch := _make_character("Fighter", _default_stats())  # AGI 10
	assert_eq(_provider.get_agility(ch), 10)


# --- All eight jobs return without missing-key errors ---

func test_every_job_has_attack_value():
	for job_name in ["Fighter", "Mage", "Priest", "Thief", "Bishop", "Samurai", "Lord", "Ninja"]:
		var ch := _make_character(job_name, _default_stats())
		var value := _provider.get_attack(ch)
		assert_true(value >= 0, "%s get_attack=%d" % [job_name, value])


func test_every_job_has_defense_value():
	for job_name in ["Fighter", "Mage", "Priest", "Thief", "Bishop", "Samurai", "Lord", "Ninja"]:
		var ch := _make_character(job_name, _default_stats())
		var value := _provider.get_defense(ch)
		assert_true(value >= 0, "%s get_defense=%d" % [job_name, value])


func test_every_job_has_agility_value():
	for job_name in ["Fighter", "Mage", "Priest", "Thief", "Bishop", "Samurai", "Lord", "Ninja"]:
		var ch := _make_character(job_name, _default_stats())
		var value := _provider.get_agility(ch)
		assert_eq(value, _default_stats()[&"AGI"], job_name)


# --- Mage: weapon 1 / armor 1 ---

func test_mage_attack_bonus_is_one():
	var ch := _make_character("Mage", _default_stats())
	assert_eq(_provider.get_attack(ch), 14 / 2 + 1)


func test_mage_defense_bonus_is_one():
	var ch := _make_character("Mage", _default_stats())
	assert_eq(_provider.get_defense(ch), 12 / 3 + 1)


# --- Priest: weapon 2 / armor 3 ---

func test_priest_attack_and_defense():
	var ch := _make_character("Priest", _default_stats())
	assert_eq(_provider.get_attack(ch), 14 / 2 + 2)
	assert_eq(_provider.get_defense(ch), 12 / 3 + 3)


# --- Agility never uses equipment bonus ---

func test_agility_uses_raw_agi_regardless_of_job():
	var stats := _default_stats()
	stats[&"AGI"] = 18
	for job_name in ["Fighter", "Mage", "Samurai", "Ninja"]:
		var ch := _make_character(job_name, stats)
		assert_eq(_provider.get_agility(ch), 18, job_name)
