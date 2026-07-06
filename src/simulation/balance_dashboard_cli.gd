extends SceneTree

# Headless CLI entry point for the balance dashboard (design D6/D7).
#
# Usage:
#   godot --headless -s src/simulation/balance_dashboard_cli.gd -- \
#       --config=<path> --mode=<heatmap|sweep> [--balance=<path>] [--csv=<path>]
#
# Everything after "--" is read via OS.get_cmdline_user_args(). Exit codes:
#   0  success (console table printed, CSV written)
#   1  config / balance / runtime failure (unreadable or invalid config,
#      balance validation errors, expedition failure, unknown knob path,
#      CSV write failure)
#   2  command-line usage error (missing --config/--mode, unknown mode or
#      argument, sweep mode without --balance)
#
# The balance definition is applied strictly in memory (BalanceRepoBuilder
# duplicates the loaded MonsterData resources); no file under data/monsters/
# is ever written. Monster and spell repositories are loaded once per process.
# Seed derivation lives in DashboardRunner (per-cell independent series based
# on hash(str(master_seed) + ":" + cell_key + ":" + str(i))), so identical
# config + balance inputs reproduce the CSV byte-for-byte.

const USAGE := """Usage: godot --headless -s src/simulation/balance_dashboard_cli.gd -- --config=<path> --mode=<heatmap|sweep> [options]
Options:
  --config=<path>   dashboard config JSON (required)
  --mode=<mode>     heatmap | sweep (required; sweep also requires --balance)
  --balance=<path>  balance definition JSON applied in memory (never writes .tres)
  --csv=<path>      output CSV path (default tmp/simulation/dashboard_<mode>.csv)
Tip: start with a coarse config (few levels/floors, small runs) to see the
whole grid, then narrow levels/floors and raise runs for the cells you care
about."""

const VALID_MODES: Array[String] = ["heatmap", "sweep"]

const GRID_LABEL_WIDTH := 6
const GRID_CELL_WIDTH := 7


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var parsed := _parse_args(OS.get_cmdline_user_args())
	if not parsed["ok"]:
		printerr(String(parsed["error"]))
		printerr(USAGE)
		return 2
	var args: Dictionary = parsed["args"]
	var mode := String(args["mode"])

	var config_path := String(args["config"])
	var config := DashboardConfig.load_from_file(config_path)
	if config == null:
		printerr(
			"balance_dashboard_cli: cannot read config '%s' (missing file or invalid JSON)"
			% config_path
		)
		return 1
	if not config.errors.is_empty():
		for e in config.errors:
			printerr("balance_dashboard_cli: config error: %s" % e)
		return 1
	if mode == "sweep" and not config.sweep_defined:
		printerr("balance_dashboard_cli: config error: sweep: required block is missing in sweep mode")
		return 1

	var balance_dict := {}
	var curve: MonsterCurve = null
	if args.has("balance"):
		var balance_path := String(args["balance"])
		var raw: Variant = _load_json_dict(balance_path)
		if not (raw is Dictionary):
			printerr(
				"balance_dashboard_cli: cannot read balance '%s' (missing file or invalid JSON)"
				% balance_path
			)
			return 1
		balance_dict = raw
		curve = MonsterCurve.parse(balance_dict)
		if not curve.errors.is_empty():
			for e in curve.errors:
				printerr("balance_dashboard_cli: balance error: %s" % e)
			return 1
		for w in curve.warnings:
			printerr("balance_dashboard_cli: balance warning: %s" % w)

	# Load shared repositories once per process (design D6).
	var loader := DataLoader.new()
	var base_monsters := loader.load_all_monsters()
	var spell_repo := loader.load_spell_repository()
	var csv_path := String(args.get("csv", "tmp/simulation/dashboard_%s.csv" % mode))

	var result: Dictionary
	var columns: PackedStringArray
	if mode == "heatmap":
		var monster_repo := BalanceRepoBuilder.build(base_monsters, curve)
		result = DashboardRunner.run_heatmap(config, monster_repo, spell_repo)
		columns = DashboardRunner.HEATMAP_COLUMNS
	else:
		result = DashboardRunner.run_sweep(config, balance_dict, base_monsters, spell_repo)
		columns = DashboardRunner.SWEEP_COLUMNS
	if not result["ok"]:
		printerr("balance_dashboard_cli: %s" % String(result["error"]))
		return 1

	var rows: Array = result["rows"]
	if mode == "heatmap":
		print(_format_heatmap_grids(config, rows))
	else:
		print(_format_sweep_table(rows))
	if not SimulationCsvWriter.write_table(
		csv_path, columns, DashboardRunner.format_cells(rows, columns)
	):
		printerr("balance_dashboard_cli: failed to write CSV to '%s'" % csv_path)
		return 1
	print("csv: %s" % csv_path)
	return 0


# --- argument parsing ---

# Returns {"ok": bool, "args": Dictionary, "error": String}. `args` holds
# "config" and "mode" (Strings) plus optional "balance" / "csv" (Strings).
# Sweep mode without --balance is a usage error here (spec: the knob needs a
# base definition to modify).
static func _parse_args(user_args: PackedStringArray) -> Dictionary:
	var args := {}
	for arg in user_args:
		if arg.begins_with("--config="):
			args["config"] = arg.trim_prefix("--config=")
		elif arg.begins_with("--mode="):
			args["mode"] = arg.trim_prefix("--mode=")
		elif arg.begins_with("--balance="):
			args["balance"] = arg.trim_prefix("--balance=")
		elif arg.begins_with("--csv="):
			args["csv"] = arg.trim_prefix("--csv=")
		else:
			return _usage_error("balance_dashboard_cli: unknown argument '%s'" % arg)
	if not args.has("config") or String(args["config"]).is_empty():
		return _usage_error("balance_dashboard_cli: --config=<path> is required")
	if not args.has("mode") or String(args["mode"]).is_empty():
		return _usage_error("balance_dashboard_cli: --mode=<heatmap|sweep> is required")
	var mode := String(args["mode"])
	if not VALID_MODES.has(mode):
		return _usage_error(
			"balance_dashboard_cli: unknown mode '%s' (expected \"heatmap\" or \"sweep\")" % mode
		)
	if mode == "sweep" and (not args.has("balance") or String(args["balance"]).is_empty()):
		return _usage_error("balance_dashboard_cli: sweep mode requires --balance=<path>")
	return {"ok": true, "args": args, "error": ""}


static func _usage_error(message: String) -> Dictionary:
	return {"ok": false, "args": {}, "error": message}


# --- console rendering ---

# Survival grid (levels as rows, floors as columns); a second grid with
# stalled rates is appended only when at least one cell stalled, so the
# survival numbers can never be misread as including stalls.
static func _format_heatmap_grids(config: DashboardConfig, rows: Array) -> String:
	var by_cell := {}
	var any_stalled := false
	for row_variant in rows:
		var row: Dictionary = row_variant
		by_cell[[int(row["level"]), int(row["floor"])]] = row
		if float(row["stalled_rate"]) > 0.0:
			any_stalled = true
	var lines: Array[String] = []
	lines.append("survival_rate (rows: party level, columns: floor)")
	lines.append_array(_grid_lines(config, by_cell, "survival_rate"))
	if any_stalled:
		lines.append("stalled_rate (not counted as survival)")
		lines.append_array(_grid_lines(config, by_cell, "stalled_rate"))
	return "\n".join(lines)


static func _grid_lines(config: DashboardConfig, by_cell: Dictionary, key: String) -> Array[String]:
	var lines: Array[String] = []
	var header := "lv\\fl".rpad(GRID_LABEL_WIDTH)
	for floor_number in config.floors:
		header += ("F%d" % int(floor_number)).lpad(GRID_CELL_WIDTH)
	lines.append(header)
	for level in config.levels:
		var line := ("L%d" % int(level)).rpad(GRID_LABEL_WIDTH)
		for floor_number in config.floors:
			var row: Dictionary = by_cell.get([int(level), int(floor_number)], {})
			var cell := "-" if row.is_empty() else "%.2f" % float(row[key])
			line += cell.lpad(GRID_CELL_WIDTH)
		lines.append(line)
	return lines


static func _format_sweep_table(rows: Array) -> String:
	var lines: Array[String] = []
	lines.append("knob_value  level  floor  survival  stalled")
	for row_variant in rows:
		var row: Dictionary = row_variant
		lines.append("%10.6f  %5d  %5d  %8.3f  %7.3f" % [
			float(row["knob_value"]), int(row["level"]), int(row["floor"]),
			float(row["survival_rate"]), float(row["stalled_rate"]),
		])
	return "\n".join(lines)


# --- helpers ---

static func _load_json_dict(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data
