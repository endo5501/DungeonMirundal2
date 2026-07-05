extends GutTest


func _member(
	name: String = "P1",
	race: String = "human",
	job: String = "fighter",
	level: int = 3,
	row: String = "front"
) -> Dictionary:
	return {"name": name, "race": race, "job": job, "level": level, "row": row}


func _full_dict() -> Dictionary:
	return {
		"runs": 20,
		"master_seed": 999,
		"max_battles": 10,
		"party": [
			_member("P1", "human", "fighter", 3, "front"),
			_member("P2", "elf", "mage", 3, "back"),
		],
		"ai": {
			"heal_hp_threshold": 0.5,
			"attack_magic_min_enemies": 3,
			"attack_magic_min_tier": 2,
		},
		"encounters": {"mode": "table", "floor": 3},
		"csv_path": "tmp/simulation/out.csv",
	}


func _errors_joined(cfg: ExpeditionConfig) -> String:
	return "\n".join(cfg.errors)


# --- Full parse ---

func test_full_dict_parses_all_fields():
	var cfg := ExpeditionConfig.parse(_full_dict())
	assert_not_null(cfg)
	assert_true(cfg.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(cfg))
	assert_eq(cfg.runs, 20)
	assert_eq(cfg.master_seed, 999)
	assert_eq(cfg.max_battles, 10)
	assert_eq(cfg.csv_path, "tmp/simulation/out.csv")
	assert_eq(cfg.party.size(), 2)
	assert_eq(cfg.party[0]["name"], "P1")
	assert_eq(cfg.party[1]["job"], "mage")
	assert_eq(cfg.party[1]["row"], "back")
	assert_almost_eq(cfg.ai_heal_hp_threshold, 0.5, 0.0001)
	assert_eq(cfg.ai_attack_magic_min_enemies, 3)
	assert_eq(cfg.ai_attack_magic_min_tier, 2)
	assert_eq(cfg.encounter_mode, "table")
	assert_eq(cfg.encounter_floor, 3)


func test_omitted_fields_get_defaults():
	var cfg := ExpeditionConfig.parse({"party": [_member()]})
	assert_true(cfg.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(cfg))
	assert_eq(cfg.runs, 100)
	assert_eq(cfg.master_seed, 12345)
	assert_eq(cfg.max_battles, 50)
	assert_eq(cfg.csv_path, "tmp/simulation/result.csv")
	assert_almost_eq(cfg.ai_heal_hp_threshold, 0.6, 0.0001)
	assert_eq(cfg.ai_attack_magic_min_enemies, 2)
	assert_eq(cfg.ai_attack_magic_min_tier, 0)
	assert_eq(cfg.encounter_mode, "table")


# --- Encounter modes ---

func test_fixed_encounter_mode_parses_patterns():
	var dict := _full_dict()
	dict["encounters"] = {
		"mode": "fixed",
		"patterns": [
			{"species": {"goblin": 3}},
			{"species": {"slime": 2}},
		],
	}
	var cfg := ExpeditionConfig.parse(dict)
	assert_true(cfg.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(cfg))
	assert_eq(cfg.encounter_mode, "fixed")
	assert_eq(cfg.encounter_patterns.size(), 2)
	assert_eq(int(cfg.encounter_patterns[0]["goblin"]), 3)
	assert_eq(int(cfg.encounter_patterns[1]["slime"]), 2)


func test_table_encounter_mode_parses_floor():
	var dict := _full_dict()
	dict["encounters"] = {"mode": "table", "floor": 5}
	var cfg := ExpeditionConfig.parse(dict)
	assert_true(cfg.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(cfg))
	assert_eq(cfg.encounter_mode, "table")
	assert_eq(cfg.encounter_floor, 5)


# --- Validation errors ---

func test_unknown_encounter_mode_is_error_naming_field():
	var dict := _full_dict()
	dict["encounters"] = {"mode": "bogus"}
	var cfg := ExpeditionConfig.parse(dict)
	assert_false(cfg.errors.is_empty())
	assert_string_contains(_errors_joined(cfg), "encounters.mode")
	assert_string_contains(_errors_joined(cfg), "bogus")


func test_empty_party_is_error_naming_field():
	var dict := _full_dict()
	dict["party"] = []
	var cfg := ExpeditionConfig.parse(dict)
	assert_false(cfg.errors.is_empty())
	assert_string_contains(_errors_joined(cfg), "party")


func test_negative_runs_is_error_naming_field():
	var dict := _full_dict()
	dict["runs"] = -5
	var cfg := ExpeditionConfig.parse(dict)
	assert_false(cfg.errors.is_empty())
	assert_string_contains(_errors_joined(cfg), "runs")


func test_non_positive_max_battles_is_error_naming_field():
	var dict := _full_dict()
	dict["max_battles"] = 0
	var cfg := ExpeditionConfig.parse(dict)
	assert_false(cfg.errors.is_empty())
	assert_string_contains(_errors_joined(cfg), "max_battles")


func test_member_missing_job_is_error_naming_field():
	var dict := _full_dict()
	var member: Dictionary = _member()
	member.erase("job")
	dict["party"] = [member]
	var cfg := ExpeditionConfig.parse(dict)
	assert_false(cfg.errors.is_empty())
	assert_string_contains(_errors_joined(cfg), "job")


func test_member_invalid_row_is_error_naming_field():
	var dict := _full_dict()
	dict["party"] = [_member("P1", "human", "fighter", 3, "middle")]
	var cfg := ExpeditionConfig.parse(dict)
	assert_false(cfg.errors.is_empty())
	assert_string_contains(_errors_joined(cfg), "row")


# --- File loading ---

func test_valid_file_loads_and_parses():
	var path := "user://test_expedition_config_valid.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_full_dict()))
	f.close()
	var cfg := ExpeditionConfig.load_from_file(path)
	assert_not_null(cfg)
	assert_true(cfg.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(cfg))
	assert_eq(cfg.runs, 20)
	assert_eq(cfg.party.size(), 2)
	DirAccess.remove_absolute(path)


func test_invalid_json_file_returns_null():
	var path := "user://test_expedition_config_broken.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	assert_null(ExpeditionConfig.load_from_file(path))
	DirAccess.remove_absolute(path)


func test_missing_file_returns_null():
	assert_null(ExpeditionConfig.load_from_file("user://test_expedition_config_missing_nope.json"))


func test_json_array_root_returns_null():
	var path := "user://test_expedition_config_array.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[1, 2, 3]")
	f.close()
	assert_null(ExpeditionConfig.load_from_file(path))
	DirAccess.remove_absolute(path)
