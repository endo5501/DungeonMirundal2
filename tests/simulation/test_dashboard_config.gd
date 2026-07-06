extends GutTest

# Tests for DashboardConfig (task 4.1): validation of party_template / levels /
# floors / runs / max_battles / master_seed, the optional sweep block
# (knob / from / to / steps / scenarios), template -> leveled party expansion,
# and the shipped sample config. Follows the ExpeditionConfig pattern:
# load_from_file returns null for unreadable input, parse always returns an
# object whose `errors` array lists every validation problem.

const SHIPPED_CONFIG_PATH := "res://data/balance/dashboard_config.json"


func _valid_dict() -> Dictionary:
	return {
		"runs": 7,
		"max_battles": 4,
		"master_seed": 999,
		"party_template": [
			{"race": "human", "job": "fighter", "row": "front"},
			{"race": "human", "job": "priest", "row": "back"},
		],
		"levels": [2, 6],
		"floors": [1, 3],
	}


func _sweep_dict() -> Dictionary:
	var dict := _valid_dict()
	dict["sweep"] = {
		"knob": "curves.attack.growth",
		"from": 1.4,
		"to": 2.0,
		"steps": 4,
		"scenarios": [{"level": 4, "floor": 2}],
	}
	return dict


func _errors_text(cfg: DashboardConfig) -> String:
	return "\n".join(cfg.errors)


# --- basic fields ---

func test_valid_dict_parses_all_fields():
	var cfg := DashboardConfig.parse(_valid_dict())
	assert_true(cfg.errors.is_empty(), "unexpected errors: %s" % _errors_text(cfg))
	assert_eq(cfg.runs, 7)
	assert_eq(cfg.max_battles, 4)
	assert_eq(cfg.master_seed, 999)
	assert_eq(cfg.party_template.size(), 2)
	assert_eq(cfg.levels, [2, 6])
	assert_eq(cfg.floors, [1, 3])
	assert_false(cfg.sweep_defined, "no sweep block declared")


func test_defaults_apply_when_optional_keys_missing():
	var dict := _valid_dict()
	dict.erase("runs")
	dict.erase("max_battles")
	dict.erase("master_seed")
	var cfg := DashboardConfig.parse(dict)
	assert_true(cfg.errors.is_empty(), "unexpected errors: %s" % _errors_text(cfg))
	assert_eq(cfg.runs, 100)
	assert_eq(cfg.max_battles, 10)
	assert_eq(cfg.master_seed, 12345)
	assert_eq(cfg.levels, [2, 6], "levels must still be parsed")


func test_non_positive_runs_is_error():
	var dict := _valid_dict()
	dict["runs"] = 0
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "runs")


func test_non_positive_max_battles_is_error():
	var dict := _valid_dict()
	dict["max_battles"] = -1
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "max_battles")


# --- party_template ---

func test_missing_party_template_is_error():
	var dict := _valid_dict()
	dict.erase("party_template")
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "party_template")


func test_empty_party_template_is_error():
	var dict := _valid_dict()
	dict["party_template"] = []
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "party_template")


func test_member_missing_job_is_error():
	var dict := _valid_dict()
	dict["party_template"] = [{"race": "human", "row": "front"}]
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "party_template[0].job")


func test_member_unknown_row_is_error():
	var dict := _valid_dict()
	dict["party_template"] = [{"race": "human", "job": "fighter", "row": "middle"}]
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "party_template[0].row")
	assert_string_contains(_errors_text(cfg), "middle")


func test_member_not_object_is_error():
	var dict := _valid_dict()
	dict["party_template"] = ["fighter"]
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "party_template[0]")


# --- levels / floors ---

func test_missing_levels_is_error():
	var dict := _valid_dict()
	dict.erase("levels")
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "levels")


func test_empty_levels_is_error():
	var dict := _valid_dict()
	dict["levels"] = []
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "levels")


func test_non_positive_level_is_error():
	var dict := _valid_dict()
	dict["levels"] = [2, 0]
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "levels")


func test_missing_floors_is_error():
	var dict := _valid_dict()
	dict.erase("floors")
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "floors")


func test_non_positive_floor_is_error():
	var dict := _valid_dict()
	dict["floors"] = [-2]
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "floors")


# --- sweep block ---

func test_sweep_block_parses():
	var cfg := DashboardConfig.parse(_sweep_dict())
	assert_true(cfg.errors.is_empty(), "unexpected errors: %s" % _errors_text(cfg))
	assert_true(cfg.sweep_defined)
	assert_eq(cfg.sweep_knob, "curves.attack.growth")
	assert_almost_eq(cfg.sweep_from, 1.4, 0.000001)
	assert_almost_eq(cfg.sweep_to, 2.0, 0.000001)
	assert_eq(cfg.sweep_steps, 4)
	assert_eq(cfg.sweep_scenarios.size(), 1)
	if cfg.sweep_scenarios.size() == 1:
		var scenario: Dictionary = cfg.sweep_scenarios[0]
		assert_eq(int(scenario["level"]), 4)
		assert_eq(int(scenario["floor"]), 2)


func test_sweep_steps_below_two_is_error():
	var dict := _sweep_dict()
	dict["sweep"]["steps"] = 1
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "sweep.steps")


func test_sweep_missing_knob_is_error():
	var dict := _sweep_dict()
	dict["sweep"].erase("knob")
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "sweep.knob")


func test_sweep_empty_knob_is_error():
	var dict := _sweep_dict()
	dict["sweep"]["knob"] = ""
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "sweep.knob")


func test_sweep_non_number_from_is_error():
	var dict := _sweep_dict()
	dict["sweep"]["from"] = "wide"
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "sweep.from")


func test_sweep_missing_scenarios_is_error():
	var dict := _sweep_dict()
	dict["sweep"].erase("scenarios")
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "sweep.scenarios")


func test_sweep_empty_scenarios_is_error():
	var dict := _sweep_dict()
	dict["sweep"]["scenarios"] = []
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "sweep.scenarios")


func test_sweep_scenario_missing_floor_is_error():
	var dict := _sweep_dict()
	dict["sweep"]["scenarios"] = [{"level": 4}]
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "sweep.scenarios[0]")


func test_sweep_scenario_non_positive_level_is_error():
	var dict := _sweep_dict()
	dict["sweep"]["scenarios"] = [{"level": 0, "floor": 1}]
	var cfg := DashboardConfig.parse(dict)
	assert_string_contains(_errors_text(cfg), "sweep.scenarios[0]")


# --- template expansion (spec: Template expands to leveled parties) ---

func test_party_specs_at_level_expands_template():
	var cfg := DashboardConfig.parse(_valid_dict())
	var specs := cfg.party_specs_at_level(6)
	assert_eq(specs.size(), 2, "one spec per template member")
	if specs.size() != 2:
		return
	var first: Dictionary = specs[0]
	var second: Dictionary = specs[1]
	assert_eq(String(first["race"]), "human")
	assert_eq(String(first["job"]), "fighter")
	assert_eq(String(first["row"]), "front")
	assert_eq(int(first["level"]), 6, "every member gets the cell's level")
	assert_eq(String(second["job"]), "priest")
	assert_eq(String(second["row"]), "back")
	assert_eq(int(second["level"]), 6)
	assert_true(first.has("name") and second.has("name"), "PartyFactory specs carry a name")
	assert_ne(String(first["name"]), String(second["name"]), "names must be unique")


func test_party_specs_at_different_levels_share_composition():
	var cfg := DashboardConfig.parse(_valid_dict())
	var low := cfg.party_specs_at_level(2)
	var high := cfg.party_specs_at_level(6)
	assert_eq(low.size(), high.size())
	for i in range(low.size()):
		var a: Dictionary = low[i]
		var b: Dictionary = high[i]
		assert_eq(String(a["job"]), String(b["job"]))
		assert_eq(String(a["race"]), String(b["race"]))
		assert_eq(String(a["row"]), String(b["row"]))
		assert_eq(int(a["level"]), 2)
		assert_eq(int(b["level"]), 6)


# --- file loading ---

func test_load_from_file_missing_returns_null():
	assert_null(DashboardConfig.load_from_file("res://data/balance/does_not_exist.json"))


func test_load_from_file_invalid_json_returns_null():
	var path := "user://test_dashboard_config_invalid.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{not valid json")
	file.close()
	assert_null(DashboardConfig.load_from_file(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- shipped sample config (task 4.7) ---

func test_shipped_dashboard_config_loads_without_errors():
	var cfg := DashboardConfig.load_from_file(SHIPPED_CONFIG_PATH)
	assert_not_null(cfg, "shipped dashboard config must exist and parse")
	if cfg == null:
		return
	assert_true(cfg.errors.is_empty(), "unexpected errors: %s" % _errors_text(cfg))
	assert_eq(cfg.party_template.size(), 6, "fighter x3 + priest + mage + thief")
	var jobs: Array = []
	for member in cfg.party_template:
		jobs.append(String((member as Dictionary)["job"]))
	assert_eq(jobs.count("fighter"), 3)
	assert_has(jobs, "priest")
	assert_has(jobs, "mage")
	assert_has(jobs, "thief")
	assert_eq(cfg.levels, [2, 4, 6, 8, 10])
	assert_eq(cfg.floors.size(), 12, "floors 1-12")
	assert_eq(cfg.runs, 100)
	assert_eq(cfg.max_battles, 10)
	assert_eq(cfg.master_seed, 12345)
