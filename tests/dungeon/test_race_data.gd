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
