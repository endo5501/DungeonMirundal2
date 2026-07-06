extends GutTest

# Flow tests for the balance generator CLI (design D5). The script extends
# SceneTree, so it is never instantiated here: _parse_args/run_generator are
# static and exercised directly on the preloaded script. All file fixtures
# live under user:// so the real res://data/monsters/ files are never touched.

const BalanceGeneratorCliScript := preload("res://src/simulation/balance_generator_cli.gd")

const FIXTURE_ROOT := "user://test_balance_generator"
const MONSTERS_DIR := FIXTURE_ROOT + "/monsters"
const BALANCE_PATH := FIXTURE_ROOT + "/balance.json"


func before_each():
	_remove_dir_recursive(FIXTURE_ROOT)
	DirAccess.make_dir_recursive_absolute(MONSTERS_DIR)


func after_all():
	_remove_dir_recursive(FIXTURE_ROOT)


# --- helpers ---

func _remove_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	for d in dir.get_directories():
		_remove_dir_recursive(path.path_join(d))
	DirAccess.remove_absolute(path)


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _monster_path(id: String) -> String:
	return MONSTERS_DIR.path_join("%s.tres" % id)


func _monster_tres(
	id: String,
	tier: int,
	hp_min: int = 8,
	hp_max: int = 12,
	atk: int = 5,
	def: int = 2,
	agi: int = 4
) -> String:
	return """[gd_resource type="Resource" script_class="MonsterData" load_steps=3 format=3]

[ext_resource type="Script" path="res://src/dungeon/data/monster_data.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/images/monsters/%s.png" id="2"]

[resource]
script = ExtResource("1")
monster_id = &"%s"
monster_name = "%s"
max_hp_min = %d
max_hp_max = %d
attack = %d
defense = %d
agility = %d
experience = 7
gold_min = 5
gold_max = 15
battle_texture = ExtResource("2")
resists = {}
default_row = 1
attack_range = 1
tier = %d
""" % [id, id, id.capitalize(), hp_min, hp_max, atk, def, agi, tier]


func _write_monster(id: String, tier: int) -> void:
	_write_text(_monster_path(id), _monster_tres(id, tier))


# Curve chosen for hand-checkable results: goblin (tier 2, modifiers 1.0)
# -> hp_mid 20, spread 0.5 -> hp 10..30, attack 4, defense 1, agility 4.
# slime (tier 1) -> hp 5..15, attack 2, defense 1, agility 4.
func _valid_balance_dict() -> Dictionary:
	return {
		"curves": {
			"hp": {"base": 10.0, "growth": 2.0},
			"attack": {"base": 2.0, "growth": 2.0},
			"defense": {"base": 1.0, "growth": 1.0},
			"agility": {"base": 4.0, "growth": 1.0},
		},
		"hp_spread": 0.5,
		"species": {"goblin": {}, "slime": {}},
	}


func _write_balance(dict: Dictionary) -> void:
	_write_text(BALANCE_PATH, JSON.stringify(dict))


func _parse(args: Array) -> Dictionary:
	return BalanceGeneratorCliScript._parse_args(PackedStringArray(args))


func _generate(check_mode: bool) -> Dictionary:
	return BalanceGeneratorCliScript.run_generator(BALANCE_PATH, check_mode, MONSTERS_DIR)


func _joined(items: Array) -> String:
	var parts := PackedStringArray()
	for item in items:
		parts.append(String(item))
	return "\n".join(parts)


# --- _parse_args ---

func test_parse_args_balance_and_check():
	var parsed := _parse(["--balance=data/balance/monster_curve.json", "--check"])
	assert_true(bool(parsed["ok"]), "got error: %s" % String(parsed["error"]))
	var args: Dictionary = parsed["args"]
	assert_eq(String(args.get("balance", "")), "data/balance/monster_curve.json")
	assert_true(bool(args.get("check", false)))


func test_parse_args_check_defaults_to_false():
	var parsed := _parse(["--balance=b.json"])
	assert_true(bool(parsed["ok"]), "got error: %s" % String(parsed["error"]))
	assert_false(bool((parsed["args"] as Dictionary).get("check", true)))


func test_parse_args_missing_balance_is_rejected():
	var parsed := _parse(["--check"])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed["error"]), "--balance")


func test_parse_args_empty_balance_is_rejected():
	var parsed := _parse(["--balance="])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed["error"]), "--balance")


func test_parse_args_unknown_argument_is_rejected():
	var parsed := _parse(["--balance=b.json", "--bogus"])
	assert_false(bool(parsed["ok"]))
	assert_string_contains(String(parsed["error"]), "--bogus")


# --- generate mode ---

func test_generate_rewrites_stats_from_curve():
	_write_balance(_valid_balance_dict())
	_write_monster("goblin", 2)
	var result := _generate(false)
	assert_eq(int(result["exit_code"]), 0, "errors: %s" % _joined(result["errors"]))
	var content := _read_text(_monster_path("goblin"))
	assert_string_contains(content, "max_hp_min = 10")
	assert_string_contains(content, "max_hp_max = 30")
	assert_string_contains(content, "attack = 4")
	assert_string_contains(content, "defense = 1")
	assert_string_contains(content, "agility = 4")


func test_generate_preserves_non_combat_fields():
	_write_balance(_valid_balance_dict())
	_write_monster("goblin", 2)
	_generate(false)
	var content := _read_text(_monster_path("goblin"))
	assert_string_contains(content, "experience = 7")
	assert_string_contains(content, "gold_min = 5")
	assert_string_contains(content, "attack_range = 1")
	assert_string_contains(content, "tier = 2")
	assert_string_contains(content, "monster_id = &\"goblin\"")
	assert_string_contains(content, "battle_texture = ExtResource(\"2\")")


func test_species_only_in_overrides_is_generated():
	var balance := _valid_balance_dict()
	balance["overrides"] = {
		"dragon": {"hp_min": 60, "hp_max": 100, "attack": 25, "defense": 10, "agility": 8},
	}
	_write_balance(balance)
	_write_monster("dragon", 5)
	var result := _generate(false)
	assert_eq(int(result["exit_code"]), 0, "errors: %s" % _joined(result["errors"]))
	var content := _read_text(_monster_path("dragon"))
	assert_string_contains(content, "max_hp_min = 60")
	assert_string_contains(content, "max_hp_max = 100")
	assert_string_contains(content, "attack = 25")
	assert_string_contains(content, "defense = 10")
	assert_string_contains(content, "agility = 8")
	assert_false(
		_joined(result["lines"]).to_lower().contains("skipped"),
		"override-only species must not be skipped"
	)


# --- skipped species ---

func test_uncovered_species_is_skipped_with_warning_and_exit_zero():
	_write_balance(_valid_balance_dict())
	_write_monster("goblin", 2)
	_write_monster("wraith", 4)
	var wraith_before := _read_text(_monster_path("wraith"))
	var result := _generate(false)
	assert_eq(int(result["exit_code"]), 0, "skipped species must not fail the run")
	assert_eq(
		_read_text(_monster_path("wraith")),
		wraith_before,
		"skipped file must stay byte-identical"
	)
	assert_string_contains(_joined(result["lines"]), "wraith")
	assert_string_contains(
		_read_text(_monster_path("goblin")), "max_hp_min = 10"
	)


# --- invalid definition / missing balance file ---

func test_invalid_definition_exits_one_and_writes_nothing():
	var balance := _valid_balance_dict()
	balance["curves"]["hp"]["growth"] = -1.0
	balance["hp_spread"] = 2.0
	_write_balance(balance)
	_write_monster("goblin", 2)
	var before := _read_text(_monster_path("goblin"))
	var result := _generate(false)
	assert_eq(int(result["exit_code"]), 1)
	var errors := _joined(result["errors"])
	assert_string_contains(errors, "growth")
	assert_string_contains(errors, "hp_spread")
	assert_eq(_read_text(_monster_path("goblin")), before, "invalid definition must write nothing")


func test_missing_balance_file_exits_one():
	_write_monster("goblin", 2)
	var result: Dictionary = BalanceGeneratorCliScript.run_generator(
		FIXTURE_ROOT + "/does_not_exist.json", false, MONSTERS_DIR
	)
	assert_eq(int(result["exit_code"]), 1)
	assert_false((result["errors"] as Array).is_empty(), "missing balance file must be reported")


# --- check mode ---

func test_check_lists_diffs_and_writes_nothing():
	_write_balance(_valid_balance_dict())
	_write_monster("goblin", 2)
	var before := _read_text(_monster_path("goblin"))
	var result := _generate(true)
	assert_eq(int(result["exit_code"]), 0, "errors: %s" % _joined(result["errors"]))
	var lines := _joined(result["lines"])
	assert_string_contains(lines, "goblin: max_hp_min 8 -> 10")
	assert_string_contains(lines, "goblin: max_hp_max 12 -> 30")
	assert_string_contains(lines, "goblin: attack 5 -> 4")
	assert_string_contains(lines, "goblin: defense 2 -> 1")
	assert_eq(_read_text(_monster_path("goblin")), before, "--check must not modify files")


func test_check_reports_when_no_changes_pending():
	_write_balance(_valid_balance_dict())
	_write_text(_monster_path("goblin"), _monster_tres("goblin", 2, 10, 30, 4, 1, 4))
	var before := _read_text(_monster_path("goblin"))
	var result := _generate(true)
	assert_eq(int(result["exit_code"]), 0, "errors: %s" % _joined(result["errors"]))
	assert_string_contains(_joined(result["lines"]).to_lower(), "no changes")
	assert_eq(_read_text(_monster_path("goblin")), before)


# --- malformed monster files ---

func test_missing_stat_line_fails_that_file_and_writes_nothing():
	_write_balance(_valid_balance_dict())
	var goblin_broken := _monster_tres("goblin", 2).replace("attack = 5\n", "")
	_write_text(_monster_path("goblin"), goblin_broken)
	_write_monster("slime", 1)
	var slime_before := _read_text(_monster_path("slime"))
	var result := _generate(false)
	assert_eq(int(result["exit_code"]), 1)
	assert_string_contains(_joined(result["errors"]), "goblin")
	assert_eq(
		_read_text(_monster_path("goblin")),
		goblin_broken,
		"malformed file must not be partially written"
	)
	assert_eq(
		_read_text(_monster_path("slime")),
		slime_before,
		"no file is written when any file fails"
	)


func test_missing_tier_line_is_an_error():
	_write_balance(_valid_balance_dict())
	_write_text(_monster_path("goblin"), _monster_tres("goblin", 2).replace("tier = 2\n", ""))
	var result := _generate(false)
	assert_eq(int(result["exit_code"]), 1)
	assert_string_contains(_joined(result["errors"]), "tier line not found")


func test_tier_zero_is_reported_as_out_of_range():
	_write_balance(_valid_balance_dict())
	_write_text(
		_monster_path("goblin"), _monster_tres("goblin", 2).replace("tier = 2\n", "tier = 0\n")
	)
	var result := _generate(false)
	assert_eq(int(result["exit_code"]), 1)
	var errors := _joined(result["errors"])
	assert_string_contains(errors, "must be >= 1")
	assert_string_contains(errors, "got 0")


# --- unreadable monster files ---
# A file that is listed by DirAccess but fails to open cannot be fixtured
# reliably on Windows (Godot opens files with permissive sharing), so the
# read guard is unit-tested through the _read_monster_file helper instead.

func test_read_monster_file_reports_unreadable_path():
	var result: Dictionary = BalanceGeneratorCliScript._read_monster_file(
		FIXTURE_ROOT + "/does_not_exist.tres"
	)
	assert_false(bool(result["ok"]), "unreadable file must not be reported as empty content")


func test_read_monster_file_directory_path_is_unreadable():
	var result: Dictionary = BalanceGeneratorCliScript._read_monster_file(MONSTERS_DIR)
	assert_false(bool(result["ok"]), "a directory path must not read as empty content")


func test_read_monster_file_reads_existing_file():
	_write_monster("goblin", 2)
	var result: Dictionary = BalanceGeneratorCliScript._read_monster_file(_monster_path("goblin"))
	assert_true(bool(result["ok"]))
	assert_string_contains(String(result["content"]), "monster_id = &\"goblin\"")
