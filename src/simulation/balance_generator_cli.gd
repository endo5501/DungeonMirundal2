extends SceneTree

# Stub for the red phase of TDD: shapes are correct so tests fail on
# assertions instead of parse/runtime errors. Real implementation follows.

const DEFAULT_MONSTERS_DIR := "res://data/monsters"


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	return 2


static func _parse_args(_user_args: PackedStringArray) -> Dictionary:
	return {"ok": false, "args": {}, "error": ""}


static func run_generator(
	_balance_path: String, _check_mode: bool, _monsters_dir: String = DEFAULT_MONSTERS_DIR
) -> Dictionary:
	return {"exit_code": -1, "lines": [] as Array[String], "errors": [] as Array[String]}
