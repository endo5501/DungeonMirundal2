extends GutTest


var _loader: DataLoader
var _human: RaceData
var _fighter_job: JobData


func before_each():
	_loader = DataLoader.new()
	for race in _loader.load_all_races():
		if race.race_name == "Human":
			_human = race
	for job in _loader.load_all_jobs():
		if job.job_name == "Fighter":
			_fighter_job = job


func _make_character(name: String) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.race = _human
	ch.job = _fighter_job
	ch.level = 1
	ch.base_stats = {&"STR": 14, &"INT": 12, &"PIE": 12, &"VIT": 12, &"AGI": 10, &"LUC": 10}
	ch.max_hp = 30
	ch.current_hp = 30
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


func test_party_combatant_default_row_is_front():
	var pc := PartyCombatant.new(_make_character("A"), DummyEquipmentProvider.new())
	assert_eq(pc.original_row, Row.FRONT)


func test_party_combatant_can_be_constructed_with_back_row():
	var pc := PartyCombatant.new(_make_character("A"), DummyEquipmentProvider.new(), Row.BACK)
	assert_eq(pc.original_row, Row.BACK)


func _make_monster_data(default_row: int = Row.FRONT, attack_range: int = WeaponRange.MELEE) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = &"x"
	data.monster_name = "X"
	data.max_hp_min = 5
	data.max_hp_max = 5
	data.attack = 3
	data.defense = 1
	data.agility = 2
	data.experience = 1
	data.default_row = default_row
	data.attack_range = attack_range
	return data


func test_monster_combatant_inherits_default_row_from_data():
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var data := _make_monster_data(Row.BACK, WeaponRange.RANGED)
	var m := Monster.new(data, rng)
	var mc := MonsterCombatant.new(m)
	assert_eq(mc.original_row, Row.BACK)


func test_monster_combatant_default_row_when_no_data():
	var mc := MonsterCombatant.new(null)
	assert_eq(mc.original_row, Row.FRONT)


func test_monster_combatant_can_override_row_explicitly():
	# Explicit p_row argument overrides MonsterData.default_row (used by
	# encounter generators that have already decided the row at spawn time).
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var data := _make_monster_data(Row.FRONT, WeaponRange.MELEE)
	var m := Monster.new(data, rng)
	var mc := MonsterCombatant.new(m, Row.BACK)
	assert_eq(mc.original_row, Row.BACK)
