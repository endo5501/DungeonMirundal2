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


func _make_character(name: String, job: JobData, stats: Dictionary, max_hp: int = 30) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.race = _human
	ch.job = job
	ch.level = 1
	ch.base_stats = stats
	ch.max_hp = max_hp
	ch.current_hp = max_hp
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


func _default_stats() -> Dictionary:
	return {&"STR": 14, &"INT": 12, &"PIE": 12, &"VIT": 12, &"AGI": 10, &"LUC": 10}


# --- structure ---

func test_party_combatant_is_combat_actor():
	var ch := _make_character("Hero", _fighter_job, _default_stats())
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	assert_is(pc, CombatActor)


# --- actor_name ---

func test_actor_name_comes_from_character_name():
	var ch := _make_character("Argus", _fighter_job, _default_stats())
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	assert_eq(pc.actor_name, "Argus")


# --- hp proxy ---

func test_current_hp_reads_character_current_hp():
	var ch := _make_character("Hero", _fighter_job, _default_stats())
	ch.current_hp = 22
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	assert_eq(pc.current_hp, 22)


func test_max_hp_reads_character_max_hp():
	var ch := _make_character("Hero", _fighter_job, _default_stats(), 40)
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	assert_eq(pc.max_hp, 40)


func test_take_damage_writes_back_to_character():
	var ch := _make_character("Hero", _fighter_job, _default_stats(), 30)
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	pc.take_damage(7)
	assert_eq(ch.current_hp, 23)
	assert_eq(pc.current_hp, 23)


func test_take_damage_clamps_character_hp_to_zero():
	var ch := _make_character("Hero", _fighter_job, _default_stats(), 10)
	var pc := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	pc.take_damage(100)
	assert_eq(ch.current_hp, 0)
	assert_false(pc.is_alive())


# --- derived stats via EquipmentProvider ---

func test_get_attack_delegates_to_equipment_provider():
	var ch := _make_character("Hero", _fighter_job, _default_stats())
	var provider := DummyEquipmentProvider.new()
	var pc := PartyCombatant.new(ch, provider)
	assert_eq(pc.get_attack(), provider.get_attack(ch))


func test_get_defense_delegates_to_equipment_provider():
	var ch := _make_character("Hero", _fighter_job, _default_stats())
	var provider := DummyEquipmentProvider.new()
	var pc := PartyCombatant.new(ch, provider)
	assert_eq(pc.get_defense(), provider.get_defense(ch))


func test_get_agility_delegates_to_equipment_provider():
	var ch := _make_character("Hero", _mage_job, _default_stats())
	var provider := DummyEquipmentProvider.new()
	var pc := PartyCombatant.new(ch, provider)
	assert_eq(pc.get_agility(), provider.get_agility(ch))


# --- substitute stub provider ---

class _StubProvider extends EquipmentProvider:
	func get_attack(_c: Character) -> int:
		return 42
	func get_defense(_c: Character) -> int:
		return 7
	func get_agility(_c: Character) -> int:
		return 99


func test_stub_provider_substitution_is_honored():
	var ch := _make_character("Hero", _fighter_job, _default_stats())
	var pc := PartyCombatant.new(ch, _StubProvider.new())
	assert_eq(pc.get_attack(), 42)
	assert_eq(pc.get_defense(), 7)
	assert_eq(pc.get_agility(), 99)
