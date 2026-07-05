extends GutTest


func _run_stat(battles: int, turns: int, first_death: int, mp_exhausted: int, cause: String) -> Dictionary:
	return {
		"battles_survived": battles,
		"total_turns": turns,
		"first_death_battle": first_death,
		"mp_exhausted_battle": mp_exhausted,
		"end_cause": cause,
	}


# --- nearest-rank percentiles -----------------------------------------------
# rank = ceil(p/100 * N) clamped to [1, N]; value = sorted[rank - 1]

func test_odd_n_percentiles() -> void:
	# N=5, sorted [1,2,3,4,5]: p50 rank=ceil(2.5)=3 -> 3, p10 rank=ceil(0.5)=1 -> 1,
	# p90 rank=ceil(4.5)=5 -> 5
	var stats: Array = []
	for v in [5, 1, 3, 2, 4]:
		stats.append(_run_stat(v, 1, 1, 1, "WIPED"))
	var m: Dictionary = ResultAggregator.aggregate(stats)["metrics"]["battles_survived"]
	assert_eq(int(m["median"]), 3, "median of [1..5] should be 3")
	assert_eq(int(m["p10"]), 1, "p10 of [1..5] should be 1")
	assert_eq(int(m["p90"]), 5, "p90 of [1..5] should be 5")


func test_even_n_percentiles() -> void:
	# N=4, sorted [10,20,30,40]: p50 rank=ceil(2.0)=2 -> 20, p10 rank=ceil(0.4)=1 -> 10,
	# p90 rank=ceil(3.6)=4 -> 40
	var stats: Array = []
	for v in [40, 10, 30, 20]:
		stats.append(_run_stat(1, v, -1, -1, "WIPED"))
	var m: Dictionary = ResultAggregator.aggregate(stats)["metrics"]["total_turns"]
	assert_eq(int(m["median"]), 20, "median of [10,20,30,40] should be 20")
	assert_eq(int(m["p10"]), 10, "p10 of [10,20,30,40] should be 10")
	assert_eq(int(m["p90"]), 40, "p90 of [10,20,30,40] should be 40")


func test_single_run_percentiles() -> void:
	# N=1: every rank clamps to 1, so median/p10/p90 are all the single value
	var stats: Array = [_run_stat(7, 33, 2, 5, "MAX_BATTLES")]
	var metrics: Dictionary = ResultAggregator.aggregate(stats)["metrics"]
	var battles: Dictionary = metrics["battles_survived"]
	assert_eq(int(battles["median"]), 7)
	assert_eq(int(battles["p10"]), 7)
	assert_eq(int(battles["p90"]), 7)
	var turns: Dictionary = metrics["total_turns"]
	assert_eq(int(turns["median"]), 33)
	assert_eq(int(turns["p10"]), 33)
	assert_eq(int(turns["p90"]), 33)


# --- -1 exclusion and never_count -------------------------------------------

func test_first_death_excludes_never_occurred_runs() -> void:
	# first_death values [3, -1, 5, -1, 4] -> valid sorted [3,4,5], N=3:
	# p50 rank=ceil(1.5)=2 -> 4, p10 rank=ceil(0.3)=1 -> 3, p90 rank=ceil(2.7)=3 -> 5
	var stats: Array = [
		_run_stat(10, 40, 3, -1, "WIPED"),
		_run_stat(10, 40, -1, -1, "MAX_BATTLES"),
		_run_stat(10, 40, 5, -1, "WIPED"),
		_run_stat(10, 40, -1, -1, "MAX_BATTLES"),
		_run_stat(10, 40, 4, -1, "WIPED"),
	]
	var m: Dictionary = ResultAggregator.aggregate(stats)["metrics"]["first_death_battle"]
	assert_eq(int(m["median"]), 4, "median should exclude -1 values")
	assert_eq(int(m["p10"]), 3)
	assert_eq(int(m["p90"]), 5)
	assert_eq(int(m["never_count"]), 2, "two runs never had a death")


func test_mp_exhausted_all_never_occurred() -> void:
	var stats: Array = [
		_run_stat(10, 40, 1, -1, "WIPED"),
		_run_stat(10, 40, 1, -1, "WIPED"),
		_run_stat(10, 40, 1, -1, "WIPED"),
	]
	var m: Dictionary = ResultAggregator.aggregate(stats)["metrics"]["mp_exhausted_battle"]
	assert_eq(int(m["median"]), -1, "all -1 -> median is -1")
	assert_eq(int(m["p10"]), -1)
	assert_eq(int(m["p90"]), -1)
	assert_eq(int(m["never_count"]), 3)


func test_mp_exhausted_never_count_zero_when_always_occurred() -> void:
	var stats: Array = [
		_run_stat(10, 40, 1, 2, "WIPED"),
		_run_stat(10, 40, 1, 6, "WIPED"),
	]
	var m: Dictionary = ResultAggregator.aggregate(stats)["metrics"]["mp_exhausted_battle"]
	assert_eq(int(m["never_count"]), 0)
	assert_eq(int(m["median"]), 2, "N=2: p50 rank=ceil(1.0)=1 -> 2")


# --- end-cause fractions -----------------------------------------------------

func test_end_cause_fractions() -> void:
	var stats: Array = [
		_run_stat(10, 40, -1, -1, "WIPED"),
		_run_stat(10, 40, -1, -1, "WIPED"),
		_run_stat(10, 40, -1, -1, "MAX_BATTLES"),
		_run_stat(10, 40, -1, -1, "STALLED"),
	]
	var causes: Dictionary = ResultAggregator.aggregate(stats)["end_causes"]
	assert_almost_eq(float(causes["WIPED"]), 0.5, 0.0001)
	assert_almost_eq(float(causes["MAX_BATTLES"]), 0.25, 0.0001)
	assert_almost_eq(float(causes["STALLED"]), 0.25, 0.0001)
	var total := 0.0
	for cause in causes:
		total += float(causes[cause])
	assert_almost_eq(total, 1.0, 0.0001, "end-cause fractions should sum to 1.0")


func test_end_causes_include_absent_causes_as_zero() -> void:
	var stats: Array = [
		_run_stat(10, 40, -1, -1, "WIPED"),
		_run_stat(10, 40, -1, -1, "WIPED"),
	]
	var causes: Dictionary = ResultAggregator.aggregate(stats)["end_causes"]
	assert_true(causes.has("MAX_BATTLES"), "absent cause should still be present")
	assert_almost_eq(float(causes["MAX_BATTLES"]), 0.0, 0.0001)
	assert_true(causes.has("STALLED"))
	assert_almost_eq(float(causes["STALLED"]), 0.0, 0.0001)
	assert_almost_eq(float(causes["WIPED"]), 1.0, 0.0001)


# --- SummaryFormatter ---------------------------------------------------------

func _sample_summary() -> Dictionary:
	return {
		"metrics": {
			"battles_survived": {"median": 12, "p10": 7, "p90": 23},
			"total_turns": {"median": 41, "p10": 25, "p90": 77},
			"first_death_battle": {"median": 9, "p10": 5, "p90": 18, "never_count": 3},
			"mp_exhausted_battle": {"median": 6, "p10": 4, "p90": 10, "never_count": 0},
		},
		"end_causes": {"WIPED": 0.84, "MAX_BATTLES": 0.16, "STALLED": 0.0},
	}


func _sample_meta() -> Dictionary:
	return {"runs": 100, "master_seed": 12345, "encounters": "floor_3"}


func _line_containing(text: String, needle: String) -> String:
	for line in text.split("\n"):
		if line.contains(needle):
			return line
	return ""


func test_format_header_line() -> void:
	var text := SummaryFormatter.format(_sample_summary(), _sample_meta())
	assert_string_contains(text, "runs=100")
	assert_string_contains(text, "seed=12345")
	assert_string_contains(text, "encounters=floor_3")


func test_format_column_headers() -> void:
	var text := SummaryFormatter.format(_sample_summary(), _sample_meta())
	assert_string_contains(text, "median")
	assert_string_contains(text, "p10")
	assert_string_contains(text, "p90")


func test_format_metric_rows() -> void:
	var text := SummaryFormatter.format(_sample_summary(), _sample_meta())
	var battles_line := _line_containing(text, "battles survived")
	assert_ne(battles_line, "", "should have a 'battles survived' row")
	assert_string_contains(battles_line, "12")
	assert_string_contains(battles_line, "7")
	assert_string_contains(battles_line, "23")
	var turns_line := _line_containing(text, "total turns")
	assert_ne(turns_line, "", "should have a 'total turns' row")
	assert_string_contains(turns_line, "41")
	assert_string_contains(turns_line, "25")
	assert_string_contains(turns_line, "77")
	assert_ne(_line_containing(text, "first death"), "", "should have a first-death row")
	assert_ne(_line_containing(text, "MP exhausted"), "", "should have an MP-exhausted row")


func test_format_never_count_note() -> void:
	var text := SummaryFormatter.format(_sample_summary(), _sample_meta())
	var death_line := _line_containing(text, "first death")
	assert_string_contains(death_line, "never in 3 runs")
	var mp_line := _line_containing(text, "MP exhausted")
	assert_false(mp_line.contains("never"), "never_count=0 should not print a note")


func test_format_end_cause_percentages() -> void:
	var text := SummaryFormatter.format(_sample_summary(), _sample_meta())
	assert_string_contains(text, "WIPED 84%")
	assert_string_contains(text, "MAX_BATTLES 16%")
	assert_string_contains(text, "STALLED 0%")


func test_format_is_deterministic() -> void:
	var first := SummaryFormatter.format(_sample_summary(), _sample_meta())
	var second := SummaryFormatter.format(_sample_summary(), _sample_meta())
	assert_eq(first, second)
