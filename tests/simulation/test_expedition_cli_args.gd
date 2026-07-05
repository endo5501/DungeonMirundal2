extends GutTest

# Pure-function tests for the CLI's argument handling. The script extends
# SceneTree, so it is never instantiated here: _parse_args/_apply_overrides
# are static and are exercised directly on the preloaded script. Spawning
# godot subprocesses is deliberately avoided.

const ExpeditionCliScript := preload("res://src/simulation/expedition_cli.gd")


func _parse(args: Array) -> Dictionary:
	return ExpeditionCliScript._parse_args(PackedStringArray(args))


func _valid_config() -> ExpeditionConfig:
	return ExpeditionConfig.parse({
		"party": [{"name": "F1", "race": "human", "job": "fighter", "level": 1, "row": "front"}],
	})


# --- _parse_args: accepted forms ---

func test_config_arg_alone_parses():
	var parsed := _parse(["--config=docs/simulation/sample_expedition_config.json"])
	assert_true(bool(parsed["ok"]), "got error: %s" % parsed["error"])
	assert_eq(String(parsed["args"]["config"]), "docs/simulation/sample_expedition_config.json")
	assert_false((parsed["args"] as Dictionary).has("csv"))
	assert_false((parsed["args"] as Dictionary).has("runs"))
	assert_false((parsed["args"] as Dictionary).has("seed"))


func test_all_override_args_parse_with_types():
	var parsed := _parse(["--config=c.json", "--csv=out.csv", "--runs=7", "--seed=-3"])
	assert_true(bool(parsed["ok"]), "got error: %s" % parsed["error"])
	var args: Dictionary = parsed["args"]
	assert_eq(String(args["config"]), "c.json")
	assert_eq(String(args["csv"]), "out.csv")
	assert_eq(int(args["runs"]), 7)
	assert_eq(int(args["seed"]), -3)


# --- _parse_args: usage errors ---

func test_unknown_argument_is_rejected():
	var parsed := _parse(["--config=c.json", "--bogus=1"])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed["error"]), "unknown argument")
	assert_string_contains(String(parsed["error"]), "--bogus=1")


func test_missing_config_is_rejected():
	var parsed := _parse(["--runs=5"])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed["error"]), "--config")


func test_empty_config_value_is_rejected():
	var parsed := _parse(["--config="])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed["error"]), "--config")


func test_non_integer_runs_is_rejected():
	var parsed := _parse(["--config=c.json", "--runs=abc"])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed["error"]), "--runs")
	assert_string_contains(String(parsed["error"]), "abc")


func test_non_integer_seed_is_rejected():
	var parsed := _parse(["--config=c.json", "--seed=1.5"])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed["error"]), "--seed")


# --- _apply_overrides ---

func test_overrides_apply_to_config():
	var config := _valid_config()
	assert_true(config.errors.is_empty(), "fixture config must be valid")
	ExpeditionCliScript._apply_overrides(config, {"csv": "elsewhere.csv", "runs": 9, "seed": 42})
	assert_eq(config.csv_path, "elsewhere.csv")
	assert_eq(config.runs, 9)
	assert_eq(config.master_seed, 42)
	assert_true(config.errors.is_empty(), "positive --runs adds no validation error")


func test_overrides_absent_keys_leave_config_untouched():
	var config := _valid_config()
	var csv_before := config.csv_path
	var runs_before := config.runs
	var seed_before := config.master_seed
	ExpeditionCliScript._apply_overrides(config, {})
	assert_eq(config.csv_path, csv_before)
	assert_eq(config.runs, runs_before)
	assert_eq(config.master_seed, seed_before)


func test_non_positive_runs_override_appends_validation_error():
	var config := _valid_config()
	ExpeditionCliScript._apply_overrides(config, {"runs": 0})
	assert_eq(config.runs, 0)
	assert_false(config.errors.is_empty(), "--runs=0 must fail validation like \"runs\": 0 would")
	assert_string_contains("\n".join(config.errors), "runs")
