extends GutTest

func _make_character() -> Character:
	var race := load("res://data/races/human.tres") as RaceData
	var job := load("res://data/jobs/fighter.tres") as JobData
	var allocation := {&"STR": 2, &"INT": 1, &"PIE": 1, &"VIT": 2, &"AGI": 1, &"LUC": 1}
	return Character.create("テスト太郎", race, job, allocation)

func test_to_dict_basic_fields():
	var ch := _make_character()
	var d := ch.to_dict()
	assert_eq(d["character_name"], "テスト太郎")
	assert_eq(d["level"], 1)
	assert_eq(d["current_hp"], ch.current_hp)
	assert_eq(d["max_hp"], ch.max_hp)
	assert_eq(d["current_mp"], ch.current_mp)
	assert_eq(d["max_mp"], ch.max_mp)

func test_to_dict_race_id():
	var ch := _make_character()
	var d := ch.to_dict()
	assert_eq(d["race_id"], "human")

func test_to_dict_job_id():
	var ch := _make_character()
	var d := ch.to_dict()
	assert_eq(d["job_id"], "fighter")

func test_to_dict_base_stats():
	var ch := _make_character()
	var d := ch.to_dict()
	assert_true(d.has("base_stats"))
	assert_eq(d["base_stats"]["STR"], ch.base_stats[&"STR"])
	assert_eq(d["base_stats"]["INT"], ch.base_stats[&"INT"])

func test_from_dict():
	var ch := _make_character()
	var d := ch.to_dict()
	var restored := Character.from_dict(d)
	assert_eq(restored.character_name, ch.character_name)
	assert_eq(restored.level, ch.level)
	assert_eq(restored.current_hp, ch.current_hp)
	assert_eq(restored.max_hp, ch.max_hp)
	assert_eq(restored.current_mp, ch.current_mp)
	assert_eq(restored.max_mp, ch.max_mp)

func test_from_dict_race_restored():
	var ch := _make_character()
	var d := ch.to_dict()
	var restored := Character.from_dict(d)
	assert_not_null(restored.race)
	assert_eq(restored.race.race_name, "Human")

func test_from_dict_job_restored():
	var ch := _make_character()
	var d := ch.to_dict()
	var restored := Character.from_dict(d)
	assert_not_null(restored.job)
	assert_eq(restored.job.job_name, "Fighter")

func test_from_dict_base_stats_restored():
	var ch := _make_character()
	var d := ch.to_dict()
	var restored := Character.from_dict(d)
	for key in Character.STAT_KEYS:
		assert_eq(restored.base_stats[key], ch.base_stats[key])

func test_roundtrip_elf_mage():
	var race := load("res://data/races/elf.tres") as RaceData
	var job := load("res://data/jobs/mage.tres") as JobData
	var allocation := {&"STR": 0, &"INT": 3, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 5}
	var ch := Character.create("エルフ魔術師", race, job, allocation)
	assert_not_null(ch, "Character creation should succeed")
	var restored := Character.from_dict(ch.to_dict())
	assert_eq(restored.character_name, "エルフ魔術師")
	assert_eq(restored.race.race_name, race.race_name)
	assert_eq(restored.job.job_name, job.job_name)
	assert_true(restored.max_mp > 0)

func test_from_dict_missing_fields_uses_defaults():
	var d := {
		"character_name": "最小データ",
		"race_id": "human",
		"job_id": "fighter",
	}
	var restored := Character.from_dict(d)
	assert_eq(restored.character_name, "最小データ")
	assert_eq(restored.level, 1)
	assert_eq(restored.current_hp, 0)

func test_from_dict_returns_null_when_race_missing():
	var d := {
		"character_name": "壊れた",
		"race_id": "bogus_race_xyz",
		"job_id": "fighter",
	}
	var restored := Character.from_dict(d)
	assert_null(restored)
	assert_push_warning("race")

func test_from_dict_returns_null_when_job_missing():
	var d := {
		"character_name": "壊れた",
		"race_id": "human",
		"job_id": "bogus_job_xyz",
	}
	var restored := Character.from_dict(d)
	assert_null(restored)
	assert_push_warning("job")
