extends GutTest

# Pure-function tests for the dashboard CLI's argument handling (task 4.4).
# The script extends SceneTree, so it is never instantiated here: _parse_args
# is static and exercised directly on the preloaded script. Usage errors
# (ok=false) map to exit code 2 in the CLI, so the sweep-without---balance
# scenario lives here.

const DashboardCliScript := preload("res://src/simulation/balance_dashboard_cli.gd")


func _parse(args: Array) -> Dictionary:
	return DashboardCliScript._parse_args(PackedStringArray(args))


# --- accepted forms ---

func test_heatmap_minimal_args_parse():
	var parsed := _parse(["--config=c.json", "--mode=heatmap"])
	assert_true(bool(parsed["ok"]), "got error: %s" % parsed["error"])
	var args: Dictionary = parsed.get("args", {})
	assert_eq(String(args.get("config", "")), "c.json")
	assert_eq(String(args.get("mode", "")), "heatmap")
	assert_false(args.has("balance"))
	assert_false(args.has("csv"))


func test_heatmap_accepts_optional_balance_and_csv():
	var parsed := _parse([
		"--config=c.json", "--mode=heatmap",
		"--balance=data/balance/monster_curve.json", "--csv=out.csv",
	])
	assert_true(bool(parsed["ok"]), "got error: %s" % parsed["error"])
	var args: Dictionary = parsed.get("args", {})
	assert_eq(String(args.get("balance", "")), "data/balance/monster_curve.json")
	assert_eq(String(args.get("csv", "")), "out.csv")


func test_sweep_with_balance_parses():
	var parsed := _parse(["--config=c.json", "--mode=sweep", "--balance=b.json"])
	assert_true(bool(parsed["ok"]), "got error: %s" % parsed["error"])
	assert_eq(String((parsed.get("args", {}) as Dictionary).get("mode", "")), "sweep")


# --- usage errors (exit code 2) ---

func test_sweep_without_balance_is_usage_error():
	var parsed := _parse(["--config=c.json", "--mode=sweep"])
	assert_false(bool(parsed["ok"]), "sweep without --balance must be a usage error")
	assert_string_contains(String(parsed.get("error", "")), "--balance")


func test_unknown_mode_is_usage_error():
	var parsed := _parse(["--config=c.json", "--mode=optimize"])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed.get("error", "")), "optimize")


func test_missing_mode_is_usage_error():
	var parsed := _parse(["--config=c.json"])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed.get("error", "")), "--mode")


func test_empty_mode_is_usage_error():
	var parsed := _parse(["--config=c.json", "--mode="])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed.get("error", "")), "--mode")


func test_missing_config_is_usage_error():
	var parsed := _parse(["--mode=heatmap"])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed.get("error", "")), "--config")


func test_empty_config_is_usage_error():
	var parsed := _parse(["--config=", "--mode=heatmap"])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed.get("error", "")), "--config")


func test_unknown_argument_is_usage_error():
	var parsed := _parse(["--config=c.json", "--mode=heatmap", "--bogus=1"])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed.get("error", "")), "unknown argument")
	assert_string_contains(String(parsed.get("error", "")), "--bogus=1")
