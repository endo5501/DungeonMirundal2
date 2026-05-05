extends GutTest

func test_human_race_has_all_base_stats_at_8():
	var race := RaceData.new()
	race.race_name = "Human"
	race.base_str = 8
	race.base_int = 8
	race.base_pie = 8
	race.base_vit = 8
	race.base_agi = 8
	race.base_luc = 8

	assert_eq(race.race_name, "Human")
	assert_eq(race.base_str, 8)
	assert_eq(race.base_int, 8)
	assert_eq(race.base_pie, 8)
	assert_eq(race.base_vit, 8)
	assert_eq(race.base_agi, 8)
	assert_eq(race.base_luc, 8)

func test_elf_race_has_asymmetric_stats():
	var race := RaceData.new()
	race.race_name = "Elf"
	race.base_str = 7
	race.base_int = 10
	race.base_pie = 10
	race.base_vit = 6
	race.base_agi = 9
	race.base_luc = 6

	assert_eq(race.race_name, "Elf")
	assert_eq(race.base_str, 7)
	assert_eq(race.base_int, 10)
	assert_eq(race.base_pie, 10)
	assert_eq(race.base_vit, 6)
	assert_eq(race.base_agi, 9)
	assert_eq(race.base_luc, 6)

func test_race_data_is_resource():
	var race := RaceData.new()
	assert_true(race is Resource)


# --- tighten-types-and-contracts: id field ---

func test_race_data_has_id_field():
	var race := RaceData.new()
	race.id = &"human"
	assert_eq(race.id, &"human")
	assert_typeof(race.id, TYPE_STRING_NAME)


func test_race_data_id_defaults_to_empty_string_name():
	var race := RaceData.new()
	assert_eq(race.id, &"")


func test_loaded_race_tres_files_have_id_matching_filename():
	var loader := DataLoader.new()
	var races := loader.load_all_races()
	assert_gt(races.size(), 0)
	for race in races:
		var basename := race.resource_path.get_file().get_basename()
		assert_eq(String(race.id), basename, "race %s id should equal filename" % race.resource_path)


# --- add-status-effect-infrastructure: resists dictionary ---

func test_race_data_has_resists_field():
	var race := RaceData.new()
	assert_typeof(race.resists, TYPE_DICTIONARY)


func test_race_data_resists_default_is_empty():
	var race := RaceData.new()
	assert_eq(race.resists.size(), 0)


func test_race_data_resists_is_writable():
	var race := RaceData.new()
	race.resists = {&"poison": 0.2}
	assert_eq(race.resists.get(&"poison"), 0.2)


func test_loaded_race_tres_files_have_resists_dictionary():
	var loader := DataLoader.new()
	var races := loader.load_all_races()
	assert_gt(races.size(), 0)
	for race in races:
		assert_typeof(race.resists, TYPE_DICTIONARY,
			"race %s.resists should be Dictionary" % race.resource_path)


# --- add-status-confusion-blind-paralysis: race-specific resist values ---

func _find_race(name: String) -> RaceData:
	for r in DataLoader.new().load_all_races():
		if r.race_name == name:
			return r
	return null


func test_loaded_human_has_empty_resists():
	var human := _find_race("Human")
	assert_not_null(human)
	assert_eq(human.resists.size(), 0, "Human should have no resists")


func test_loaded_elf_has_silence_and_poison_vulnerabilities():
	var elf := _find_race("Elf")
	assert_not_null(elf)
	assert_almost_eq(float(elf.resists.get(&"silence", 0.0)), -0.10, 0.001)
	assert_almost_eq(float(elf.resists.get(&"poison", 0.0)), -0.10, 0.001)


func test_loaded_dwarf_resists_poison_and_petrify():
	var dwarf := _find_race("Dwarf")
	assert_not_null(dwarf)
	assert_almost_eq(float(dwarf.resists.get(&"poison", 0.0)), 0.20, 0.001)
	assert_almost_eq(float(dwarf.resists.get(&"petrify", 0.0)), 0.10, 0.001)


func test_loaded_hobbit_resists_sleep_and_paralysis():
	var hobbit := _find_race("Hobbit")
	assert_not_null(hobbit)
	assert_almost_eq(float(hobbit.resists.get(&"sleep", 0.0)), 0.10, 0.001)
	assert_almost_eq(float(hobbit.resists.get(&"paralysis", 0.0)), 0.10, 0.001)


func test_loaded_gnome_resists_silence():
	var gnome := _find_race("Gnome")
	assert_not_null(gnome)
	assert_almost_eq(float(gnome.resists.get(&"silence", 0.0)), 0.10, 0.001)
