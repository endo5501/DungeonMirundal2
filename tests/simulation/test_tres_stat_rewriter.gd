extends GutTest

# Text-level tests for TresStatRewriter (design D5). The rewriter operates on
# in-memory strings, so the byte-for-byte guarantees are asserted with plain
# string equality; no file I/O is involved.

const ORIGINAL_STATS := {
	"max_hp_min": 8,
	"max_hp_max": 12,
	"attack": 5,
	"defense": 2,
	"agility": 4,
}

const NEW_STATS := {
	"max_hp_min": 9,
	"max_hp_max": 14,
	"attack": 6,
	"defense": 3,
	"agility": 5,
}


func _sample_tres() -> String:
	return """[gd_resource type="Resource" script_class="MonsterData" load_steps=3 format=3]

[ext_resource type="Script" path="res://src/dungeon/data/monster_data.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/images/monsters/goblin.png" id="2"]

[resource]
script = ExtResource("1")
monster_id = &"goblin"
monster_name = "Goblin"
max_hp_min = 8
max_hp_max = 12
attack = 5
defense = 2
agility = 4
experience = 7
gold_min = 5
gold_max = 15
battle_texture = ExtResource("2")
resists = {
&"sleep": 0.30,
}
default_row = 1
attack_range = 1
tier = 2
"""


func _joined(items: Array) -> String:
	var parts := PackedStringArray()
	for item in items:
		parts.append(String(item))
	return "\n".join(parts)


# --- rewrite: replacement of the five combat value lines ---

func test_rewrite_replaces_all_five_value_lines():
	var result := TresStatRewriter.rewrite(_sample_tres(), NEW_STATS)
	assert_true(bool(result["ok"]), "got errors: %s" % _joined(result["errors"]))
	var content := String(result["content"])
	assert_string_contains(content, "max_hp_min = 9")
	assert_string_contains(content, "max_hp_max = 14")
	assert_string_contains(content, "attack = 6")
	assert_string_contains(content, "defense = 3")
	assert_string_contains(content, "agility = 5")
	assert_false(content.contains("max_hp_min = 8"), "old max_hp_min value must be gone")
	assert_false(content.contains("agility = 4"), "old agility value must be gone")


func test_rewrite_touches_only_the_five_value_lines():
	var forward := TresStatRewriter.rewrite(_sample_tres(), NEW_STATS)
	var back := TresStatRewriter.rewrite(String(forward["content"]), ORIGINAL_STATS)
	assert_eq(
		String(back["content"]),
		_sample_tres(),
		"restoring the five values must reproduce the original byte-for-byte"
	)


func test_rewrite_preserves_similarly_named_and_other_fields():
	var result := TresStatRewriter.rewrite(_sample_tres(), NEW_STATS)
	var content := String(result["content"])
	assert_string_contains(content, "attack_range = 1")
	assert_string_contains(content, "gold_min = 5")
	assert_string_contains(content, "gold_max = 15")
	assert_string_contains(content, "experience = 7")
	assert_string_contains(content, "tier = 2")
	assert_string_contains(content, "monster_name = \"Goblin\"")


func test_rewrite_with_current_values_is_identity():
	var result := TresStatRewriter.rewrite(_sample_tres(), ORIGINAL_STATS)
	assert_true(bool(result["ok"]), "got errors: %s" % _joined(result["errors"]))
	assert_eq(String(result["content"]), _sample_tres())


func test_rewrite_preserves_crlf_line_endings():
	var crlf := _sample_tres().replace("\n", "\r\n")
	var result := TresStatRewriter.rewrite(crlf, NEW_STATS)
	assert_true(bool(result["ok"]), "got errors: %s" % _joined(result["errors"]))
	assert_string_contains(String(result["content"]), "attack = 6\r\n")
	var back := TresStatRewriter.rewrite(String(result["content"]), ORIGINAL_STATS)
	assert_eq(String(back["content"]), crlf)


# --- rewrite: missing value lines ---

func test_missing_attack_line_errors_and_keeps_content():
	var broken := _sample_tres().replace("attack = 5\n", "")
	var result := TresStatRewriter.rewrite(broken, NEW_STATS)
	assert_false(bool(result["ok"]), "missing attack line must fail the rewrite")
	assert_string_contains(_joined(result["errors"]), "attack")
	assert_eq(String(result["content"]), broken, "failed rewrite must not alter the content")


func test_all_missing_lines_are_reported():
	var broken := _sample_tres().replace("attack = 5\n", "").replace("defense = 2\n", "")
	var result := TresStatRewriter.rewrite(broken, NEW_STATS)
	assert_false(bool(result["ok"]))
	var joined := _joined(result["errors"])
	assert_string_contains(joined, "attack")
	assert_string_contains(joined, "defense")


func test_rewrite_duplicated_attack_line_is_an_error():
	var duplicated := _sample_tres().replace("attack = 5\n", "attack = 5\nattack = 5\n")
	var result := TresStatRewriter.rewrite(duplicated, NEW_STATS)
	assert_false(bool(result["ok"]), "duplicated attack line must fail the rewrite")
	assert_string_contains(_joined(result["errors"]), "more than once")
	assert_eq(String(result["content"]), duplicated, "failed rewrite must not alter the content")


# --- extract_stats ---

func test_extract_stats_reads_current_values():
	var result := TresStatRewriter.extract_stats(_sample_tres())
	assert_true(bool(result["ok"]), "got errors: %s" % _joined(result["errors"]))
	var stats: Dictionary = result["stats"]
	assert_eq(int(stats.get("max_hp_min", -1)), 8)
	assert_eq(int(stats.get("max_hp_max", -1)), 12)
	assert_eq(int(stats.get("attack", -1)), 5)
	assert_eq(int(stats.get("defense", -1)), 2)
	assert_eq(int(stats.get("agility", -1)), 4)


func test_extract_stats_missing_line_is_an_error():
	var broken := _sample_tres().replace("agility = 4\n", "")
	var result := TresStatRewriter.extract_stats(broken)
	assert_false(bool(result["ok"]))
	assert_string_contains(_joined(result["errors"]), "agility")


func test_extract_stats_duplicated_line_is_an_error():
	# extract_stats must reject duplicates exactly like rewrite does, so that
	# --check and generate mode agree on what counts as a malformed file.
	var duplicated := _sample_tres().replace("attack = 5\n", "attack = 5\nattack = 5\n")
	var result := TresStatRewriter.extract_stats(duplicated)
	assert_false(bool(result["ok"]), "duplicated attack line must fail extraction")
	assert_string_contains(_joined(result["errors"]), "more than once")


# --- extract_tier ---

func test_extract_tier_reads_tier_line():
	assert_eq(TresStatRewriter.extract_tier(_sample_tres()), 2)


func test_extract_tier_missing_returns_negative():
	var broken := _sample_tres().replace("tier = 2\n", "")
	assert_lt(TresStatRewriter.extract_tier(broken), 1)


# --- diff_stats ---

func test_diff_stats_lists_only_changed_fields():
	var current := {"max_hp_min": 8, "max_hp_max": 12, "attack": 5, "defense": 2, "agility": 4}
	var target := {"max_hp_min": 8, "max_hp_max": 13, "attack": 6, "defense": 2, "agility": 4}
	var diffs := TresStatRewriter.diff_stats(current, target)
	assert_eq(diffs.size(), 2, "only max_hp_max and attack changed")
	if diffs.size() != 2:
		return
	assert_eq(String(diffs[0]["field"]), "max_hp_max")
	assert_eq(int(diffs[0]["current"]), 12)
	assert_eq(int(diffs[0]["new"]), 13)
	assert_eq(String(diffs[1]["field"]), "attack")
	assert_eq(int(diffs[1]["current"]), 5)
	assert_eq(int(diffs[1]["new"]), 6)


func test_diff_stats_empty_when_all_values_equal():
	var diffs := TresStatRewriter.diff_stats(ORIGINAL_STATS.duplicate(), ORIGINAL_STATS.duplicate())
	assert_eq(diffs.size(), 0)
