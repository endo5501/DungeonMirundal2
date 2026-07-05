extends GutTest

const EXPECTED_HEADER := "run,battle,encounter,turns,hp_pct_before_heal,party_hp_pct,party_mp_pct,deaths_cum,outcome"
const TMP_REL := "tmp/test_csv_writer_tmp"


func _tmp_abs() -> String:
	return ProjectSettings.globalize_path("res://").path_join(TMP_REL)


func after_each() -> void:
	_remove_recursive(_tmp_abs())


func _remove_recursive(abs_path: String) -> void:
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var child := abs_path.path_join(entry)
		if dir.current_is_dir():
			_remove_recursive(child)
		else:
			DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(abs_path)


func _sample_rows() -> Array:
	return [
		{
			"run": 1, "battle": 1, "encounter": "floor_3", "turns": 5,
			"hp_pct_before_heal": 0.25, "party_hp_pct": 0.5, "party_mp_pct": 0.123456,
			"deaths_cum": 0, "outcome": "CLEARED",
		},
		{
			"run": 1, "battle": 2, "encounter": "floor_3", "turns": 7,
			"hp_pct_before_heal": 1.0, "party_hp_pct": 1.0, "party_mp_pct": 0.9,
			"deaths_cum": 1, "outcome": "WIPED",
		},
	]


func _read_lines(abs_path: String) -> PackedStringArray:
	if not FileAccess.file_exists(abs_path):
		return PackedStringArray()
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var text := file.get_as_text()
	file.close()
	while text.ends_with("\n") or text.ends_with("\r"):
		text = text.substr(0, text.length() - 1)
	return text.split("\n")


func test_write_returns_true() -> void:
	var ok := SimulationCsvWriter.write(TMP_REL + "/out.csv", _sample_rows())
	assert_true(ok, "write should return true on success")


func test_relative_path_resolves_against_project_root() -> void:
	SimulationCsvWriter.write(TMP_REL + "/out.csv", _sample_rows())
	assert_true(
		FileAccess.file_exists(_tmp_abs().path_join("out.csv")),
		"project-relative path should land under the project root"
	)


func test_writes_exact_header_row() -> void:
	SimulationCsvWriter.write(TMP_REL + "/out.csv", _sample_rows())
	var lines := _read_lines(_tmp_abs().path_join("out.csv"))
	assert_gt(lines.size(), 0, "file should have at least the header")
	if lines.size() > 0:
		assert_eq(lines[0], EXPECTED_HEADER)


func test_writes_one_line_per_row_plus_header() -> void:
	SimulationCsvWriter.write(TMP_REL + "/out.csv", _sample_rows())
	var lines := _read_lines(_tmp_abs().path_join("out.csv"))
	assert_eq(lines.size(), 3, "header + 2 data rows")


func test_row_values_in_column_order_with_three_decimal_pcts() -> void:
	SimulationCsvWriter.write(TMP_REL + "/out.csv", _sample_rows())
	var lines := _read_lines(_tmp_abs().path_join("out.csv"))
	assert_eq(lines.size(), 3)
	if lines.size() == 3:
		assert_eq(lines[1], "1,1,floor_3,5,0.250,0.500,0.123,0,CLEARED")
		assert_eq(lines[2], "1,2,floor_3,7,1.000,1.000,0.900,1,WIPED")


func test_creates_missing_parent_directories() -> void:
	var rel := TMP_REL + "/nested/deep/out.csv"
	var ok := SimulationCsvWriter.write(rel, _sample_rows())
	assert_true(ok, "write should succeed even when parent dirs are missing")
	assert_true(
		FileAccess.file_exists(_tmp_abs().path_join("nested/deep/out.csv")),
		"nested parent directories should be created"
	)


# --- RFC 4180 quoting of string cells -----------------------------------------

func test_encounter_with_comma_is_quoted() -> void:
	var row: Dictionary = _sample_rows()[0]
	row["encounter"] = "a,b"
	SimulationCsvWriter.write(TMP_REL + "/quoted.csv", [row])
	var lines := _read_lines(_tmp_abs().path_join("quoted.csv"))
	assert_eq(lines.size(), 2)
	if lines.size() == 2:
		assert_eq(lines[1], "1,1,\"a,b\",5,0.250,0.500,0.123,0,CLEARED")


func test_encounter_with_embedded_quote_is_escaped() -> void:
	var row: Dictionary = _sample_rows()[0]
	row["encounter"] = "say \"hi\""
	SimulationCsvWriter.write(TMP_REL + "/quoted.csv", [row])
	var lines := _read_lines(_tmp_abs().path_join("quoted.csv"))
	assert_eq(lines.size(), 2)
	if lines.size() == 2:
		assert_eq(lines[1], "1,1,\"say \"\"hi\"\"\",5,0.250,0.500,0.123,0,CLEARED")


func test_plain_cells_are_written_without_quotes() -> void:
	# Reproducibility guarantee: rows without special characters must remain
	# byte-identical to the pre-quoting output.
	SimulationCsvWriter.write(TMP_REL + "/plain.csv", _sample_rows())
	var lines := _read_lines(_tmp_abs().path_join("plain.csv"))
	assert_eq(lines.size(), 3)
	for line in lines:
		assert_false(String(line).contains("\""), "plain cells must not be quoted: " + String(line))


func test_empty_rows_writes_header_only() -> void:
	var ok := SimulationCsvWriter.write(TMP_REL + "/empty.csv", [])
	assert_true(ok)
	var lines := _read_lines(_tmp_abs().path_join("empty.csv"))
	assert_eq(lines.size(), 1, "only the header row")
	if lines.size() == 1:
		assert_eq(lines[0], EXPECTED_HEADER)
