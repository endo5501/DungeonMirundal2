extends SceneTree

# Headless CLI entry point for the combat expedition simulator (design D1).
#
# Usage:
#   godot --headless -s src/simulation/expedition_cli.gd -- --config=<path> \
#       [--csv=<path>] [--runs=<int>] [--seed=<int>]
#
# Everything after "--" is read via OS.get_cmdline_user_args(). --csv/--runs/
# --seed override the corresponding config fields. Exit codes:
#   0  success (summary printed, CSV written)
#   1  config / runtime failure (unreadable config, validation errors,
#      expedition failure, CSV write failure)
#   2  command-line usage error (missing --config, unknown argument,
#      non-integer --runs/--seed)
#
# Seed derivation (design D6): the RNG for run i is seeded with
#   hash(str(master_seed) + ":" + str(i))
# hash() of a String is stable across runs and platforms in Godot 4, so an
# identical config file reproduces every run (and the CSV) byte-for-byte.

const USAGE := """Usage: godot --headless -s src/simulation/expedition_cli.gd -- --config=<path> [options]
Options:
  --config=<path>  expedition config JSON (required)
  --csv=<path>     override csv_path from the config
  --runs=<int>     override runs from the config
  --seed=<int>     override master_seed from the config"""


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var parsed := _parse_args(OS.get_cmdline_user_args())
	if not parsed["ok"]:
		printerr(String(parsed["error"]))
		printerr(USAGE)
		return 2
	var args: Dictionary = parsed["args"]

	var config_path := String(args["config"])
	var config := ExpeditionConfig.load_from_file(config_path)
	if config == null:
		printerr("expedition_cli: cannot read config '%s' (missing file or invalid JSON)" % config_path)
		return 1
	_apply_overrides(config, args)
	if not config.errors.is_empty():
		for e in config.errors:
			printerr("expedition_cli: config error: %s" % e)
		return 1

	# Load shared repositories once; ExpeditionRunner would otherwise reload
	# all monster/spell resources for every run.
	var loader := DataLoader.new()
	var monster_repo := MonsterRepository.new()
	monster_repo.register_all(loader.load_all_monsters())
	var spell_repo := loader.load_spell_repository()

	var all_rows: Array = []
	var run_stats: Array = []
	for i in range(config.runs):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(config.master_seed) + ":" + str(i))
		var result := ExpeditionRunner.run_expedition(
			config, i, rng, ExpeditionRunner.DEFAULT_TURN_LIMIT, monster_repo, spell_repo
		)
		if result == null:
			printerr("expedition_cli: run %d failed (see errors above)" % i)
			return 1
		all_rows.append_array(result.battle_rows)
		run_stats.append(result.to_run_stats())

	if not SimulationCsvWriter.write(config.csv_path, all_rows):
		printerr("expedition_cli: failed to write CSV to '%s'" % config.csv_path)
		return 1

	var summary := ResultAggregator.aggregate(run_stats)
	print(SummaryFormatter.format(summary, {
		"runs": config.runs,
		"master_seed": config.master_seed,
		"encounters": _encounters_label(config),
	}))
	print("csv: %s" % config.csv_path)
	return 0


# --- helpers ---

# Returns {"ok": bool, "args": Dictionary, "error": String}. `args` holds
# "config" (String) and optional "csv" (String) / "runs" / "seed" (int).
static func _parse_args(user_args: PackedStringArray) -> Dictionary:
	var args := {}
	for arg in user_args:
		if arg.begins_with("--config="):
			args["config"] = arg.trim_prefix("--config=")
		elif arg.begins_with("--csv="):
			args["csv"] = arg.trim_prefix("--csv=")
		elif arg.begins_with("--runs="):
			var raw := arg.trim_prefix("--runs=")
			if not raw.is_valid_int():
				return _usage_error("expedition_cli: --runs expects an integer (got '%s')" % raw)
			args["runs"] = raw.to_int()
		elif arg.begins_with("--seed="):
			var raw := arg.trim_prefix("--seed=")
			if not raw.is_valid_int():
				return _usage_error("expedition_cli: --seed expects an integer (got '%s')" % raw)
			args["seed"] = raw.to_int()
		else:
			return _usage_error("expedition_cli: unknown argument '%s'" % arg)
	if not args.has("config") or String(args["config"]).is_empty():
		return _usage_error("expedition_cli: --config=<path> is required")
	return {"ok": true, "args": args, "error": ""}


static func _usage_error(message: String) -> Dictionary:
	return {"ok": false, "args": {}, "error": message}


# Overrides are applied before the errors check so an overridden value is
# validated too (e.g. --runs=0 fails the same way "runs": 0 would).
static func _apply_overrides(config: ExpeditionConfig, args: Dictionary) -> void:
	if args.has("csv"):
		config.csv_path = String(args["csv"])
	if args.has("runs"):
		var runs := int(args["runs"])
		config.runs = runs
		if runs <= 0:
			config.errors.append("runs: must be positive (got %d)" % runs)
	if args.has("seed"):
		config.master_seed = int(args["seed"])


static func _encounters_label(config: ExpeditionConfig) -> String:
	if config.encounter_mode == "fixed":
		return "fixed[%d patterns]" % config.encounter_patterns.size()
	return "floor_%d" % config.encounter_floor
