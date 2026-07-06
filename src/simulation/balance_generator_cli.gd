extends SceneTree

# Headless CLI that regenerates the five combat stat lines of every monster
# .tres under data/monsters/ from the balance definition (design D5).
#
# Usage:
#   godot --headless -s src/simulation/balance_generator_cli.gd -- \
#       --balance=<path> [--check]
#
# Everything after "--" is read via OS.get_cmdline_user_args(). Exit codes
# follow the expedition CLI convention:
#   0  success (files rewritten, or --check preview printed)
#   1  balance definition / rewrite failure (invalid definition, unreadable
#      file, missing stat/tier lines) — nothing is written
#   2  command-line usage error (missing --balance, unknown argument)
#
# Species listed in neither `species` nor `overrides` are skipped with a
# warning (exit stays 0) so stale values never linger silently. Writes are
# all-or-nothing: rewrites are planned for every file first and flushed to
# disk only when no file produced an error.

const USAGE := """Usage: godot --headless -s src/simulation/balance_generator_cli.gd -- --balance=<path> [--check]
Options:
  --balance=<path>  monster balance definition JSON (required)
  --check           print pending changes without writing any file"""

const DEFAULT_MONSTERS_DIR := "res://data/monsters"


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var parsed := _parse_args(OS.get_cmdline_user_args())
	if not parsed["ok"]:
		printerr(String(parsed["error"]))
		printerr(USAGE)
		return 2
	var args: Dictionary = parsed["args"]
	var result := run_generator(String(args["balance"]), bool(args["check"]))
	for line in result["lines"]:
		print(line)
	for error in result["errors"]:
		printerr(String(error))
	return int(result["exit_code"])


# Returns {"ok": bool, "args": Dictionary, "error": String}. `args` holds
# "balance" (String) and "check" (bool, default false).
static func _parse_args(user_args: PackedStringArray) -> Dictionary:
	var args := {"check": false}
	for arg in user_args:
		if arg.begins_with("--balance="):
			args["balance"] = arg.trim_prefix("--balance=")
		elif arg == "--check":
			args["check"] = true
		else:
			return _usage_error("balance_generator: unknown argument '%s'" % arg)
	if not args.has("balance") or String(args["balance"]).is_empty():
		return _usage_error("balance_generator: --balance=<path> is required")
	return {"ok": true, "args": args, "error": ""}


static func _usage_error(message: String) -> Dictionary:
	return {"ok": false, "args": {}, "error": message}


# Full generator flow over `monsters_dir`, injectable for tests. Returns
# {"exit_code": int, "lines": Array[String], "errors": Array[String]};
# `lines` is stdout material (warnings, per-file status, --check diffs),
# `errors` is stderr material.
static func run_generator(
	balance_path: String, check_mode: bool, monsters_dir: String = DEFAULT_MONSTERS_DIR
) -> Dictionary:
	var lines: Array[String] = []
	var errors: Array[String] = []

	var curve := MonsterCurve.load_from_file(balance_path)
	if curve == null:
		errors.append(
			"balance_generator: cannot read balance definition '%s' (missing file or invalid JSON)"
			% balance_path
		)
		return _result(1, lines, errors)
	if not curve.errors.is_empty():
		for error in curve.errors:
			errors.append("balance_generator: balance error: %s" % error)
		return _result(1, lines, errors)
	for warning in curve.warnings:
		lines.append("warning: %s" % warning)

	var file_names := _list_tres_files(monsters_dir)
	if file_names.is_empty():
		errors.append("balance_generator: no .tres files found in '%s'" % monsters_dir)
		return _result(1, lines, errors)

	# Phase 1: plan every rewrite in memory (no partial writes on error).
	var pending: Array[Dictionary] = []
	var diff_count := 0
	for file_name in file_names:
		var path := monsters_dir.path_join(file_name)
		var content := FileAccess.get_file_as_string(path)
		var id := _extract_monster_id(content, file_name)
		if not curve.species.has(id) and not curve.overrides.has(id):
			lines.append("warning: %s: not in balance definition (species/overrides); skipped" % id)
			continue
		var tier := TresStatRewriter.extract_tier(content)
		if tier < 1:
			errors.append("balance_generator: %s: tier line not found" % path)
			continue
		var target := _stats_to_fields(curve.compute_stats(id, tier))
		if check_mode:
			var extracted := TresStatRewriter.extract_stats(content)
			if not extracted["ok"]:
				for error in extracted["errors"]:
					errors.append("balance_generator: %s: %s" % [path, error])
				continue
			for diff in TresStatRewriter.diff_stats(extracted["stats"], target):
				lines.append(
					"%s: %s %d -> %d" % [id, diff["field"], diff["current"], diff["new"]]
				)
				diff_count += 1
		else:
			var rewritten := TresStatRewriter.rewrite(content, target)
			if not rewritten["ok"]:
				for error in rewritten["errors"]:
					errors.append("balance_generator: %s: %s" % [path, error])
				continue
			if String(rewritten["content"]) == content:
				lines.append("%s: unchanged" % id)
			else:
				pending.append({"path": path, "content": rewritten["content"], "id": id})

	if not errors.is_empty():
		if not check_mode:
			errors.append("balance_generator: errors detected; no files were written")
		return _result(1, lines, errors)

	if check_mode:
		if diff_count == 0:
			lines.append("balance_generator: no changes pending")
		return _result(0, lines, errors)

	# Phase 2: flush the planned rewrites.
	for entry in pending:
		var file := FileAccess.open(String(entry["path"]), FileAccess.WRITE)
		if file == null:
			errors.append("balance_generator: cannot write '%s'" % entry["path"])
			return _result(1, lines, errors)
		file.store_string(String(entry["content"]))
		file.close()
		lines.append("%s: updated" % entry["id"])
	return _result(0, lines, errors)


static func _result(exit_code: int, lines: Array[String], errors: Array[String]) -> Dictionary:
	return {"exit_code": exit_code, "lines": lines, "errors": errors}


static func _list_tres_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if file_name.get_extension() == "tres":
			result.append(file_name)
	result.sort()
	return result


# The species id is read from the `monster_id = &"..."` line; the file name
# is only a fallback so a renamed copy still resolves to its real species.
static func _extract_monster_id(content: String, file_name: String) -> String:
	var found := RegEx.create_from_string("(?m)^monster_id = &\"([^\"]+)\"").search(content)
	if found != null:
		return found.get_string(1)
	return file_name.get_basename()


# Maps calculator keys (hp_min/hp_max) to .tres field names (max_hp_min/...).
static func _stats_to_fields(stats: Dictionary) -> Dictionary:
	return {
		"max_hp_min": int(stats["hp_min"]),
		"max_hp_max": int(stats["hp_max"]),
		"attack": int(stats["attack"]),
		"defense": int(stats["defense"]),
		"agility": int(stats["agility"]),
	}
