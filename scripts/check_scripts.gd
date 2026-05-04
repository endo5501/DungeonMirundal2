extends SceneTree

# Pre-flight script: walks res://src and res://tests, attempts to load every
# .gd file via ResourceLoader. Files that fail to parse return null from load()
# and Godot prints the SCRIPT ERROR / Failed to load script lines to stderr.
#
# Exit code is 1 if any file failed to load, 0 otherwise. Used by
# scripts/run_tests.ps1 / scripts/run_tests.sh to fail-fast before invoking GUT
# (so that silent parse-error skips like the magic-system regression cannot hide
# behind GUT's "Ignoring script ... because it does not extend GutTest" warning).
#
# Intentionally does NOT check addons/ (third-party code we do not own) or
# generated dirs.

const DIRS_TO_CHECK: Array[String] = [
	"res://src",
	"res://tests",
]


func _initialize() -> void:
	var failed: Array[String] = []
	var checked: int = 0
	for d in DIRS_TO_CHECK:
		checked += _walk(d, failed)
	if not failed.is_empty():
		push_error("--- check_scripts.gd: %d parse failure(s) out of %d files ---" % [failed.size(), checked])
		for f in failed:
			push_error("  PARSE_FAIL: " + f)
		quit(1)
		return
	print("--- check_scripts.gd: all %d .gd files parsed cleanly ---" % checked)
	quit(0)


func _walk(dir_path: String, failed: Array[String]) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("check_scripts.gd: cannot open %s" % dir_path)
		return 0
	var count := 0
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path + "/" + name
		if dir.current_is_dir():
			count += _walk(full, failed)
		elif name.ends_with(".gd"):
			count += 1
			var script: Variant = ResourceLoader.load(full)
			# Parse-error GDScripts: load() returns a partial GDScript whose
			# get_instance_base_type() is "" (valid scripts always have a base
			# such as Node / RefCounted / Resource). Use that as the failure
			# signal rather than null, since load() does not return null on
			# parse error.
			if script == null:
				failed.append(full)
			elif script is GDScript and (script as GDScript).get_instance_base_type() == StringName(""):
				failed.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return count
