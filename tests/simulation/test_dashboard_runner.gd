extends GutTest

# Tests for DashboardRunner (tasks 4.3 / 4.4): heatmap aggregation
# (survival_rate = MAX_BATTLES fraction, stalled_rate separate, one CSV row per
# cell, pinned seed derivation), sweep aggregation (inclusive evenly spaced
# knob sampling, one row per knob value x scenario, unknown knob path error)
# and deterministic CSV formatting. Battles use the real combat engine, so
# runs / max_battles are kept tiny.

const MASTER_SEED := 4242

var _loader := DataLoader.new()
var _real_repo: MonsterRepository = null
var _spell_repo: SpellRepository = null


func before_all():
	_real_repo = MonsterRepository.new()
	_real_repo.register_all(_loader.load_all_monsters())
	_spell_repo = _loader.load_spell_repository()


func _make_config(
	levels: Array, floors: Array, runs: int, max_battles: int
) -> DashboardConfig:
	var cfg := DashboardConfig.new()
	cfg.party_template = [{"race": "human", "job": "fighter", "row": "front"}]
	cfg.levels = levels
	cfg.floors = floors
	cfg.runs = runs
	cfg.max_battles = max_battles
	cfg.master_seed = MASTER_SEED
	return cfg


func _add_sweep(cfg: DashboardConfig, knob: String, from_value: float, to_value: float,
		steps: int, scenarios: Array) -> DashboardConfig:
	cfg.sweep_defined = true
	cfg.sweep_knob = knob
	cfg.sweep_from = from_value
	cfg.sweep_to = to_value
	cfg.sweep_steps = steps
	cfg.sweep_scenarios = scenarios
	return cfg


func _shipped_balance_dict() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://data/balance/monster_curve.json")
	var data: Variant = JSON.parse_string(text)
	assert_true(data is Dictionary, "shipped balance JSON must parse")
	return data if data is Dictionary else {}


# --- knob sampling (spec: Knob range is sampled inclusively) ---

func test_sample_knob_values_is_inclusive_and_evenly_spaced():
	var values := DashboardRunner.sample_knob_values(1.4, 2.0, 4)
	assert_eq(values.size(), 4)
	if values.size() != 4:
		return
	assert_almost_eq(float(values[0]), 1.4, 0.000001, "range start is included")
	assert_almost_eq(float(values[1]), 1.6, 0.000001)
	assert_almost_eq(float(values[2]), 1.8, 0.000001)
	assert_eq(float(values[3]), 2.0, "range end is included exactly")


func test_sample_knob_values_two_steps_are_the_endpoints():
	var values := DashboardRunner.sample_knob_values(0.1, 0.5, 2)
	assert_eq(values.size(), 2)
	if values.size() != 2:
		return
	assert_eq(float(values[0]), 0.1)
	assert_eq(float(values[1]), 0.5)


# --- knob application ---

func test_apply_knob_sets_nested_path_without_mutating_input():
	var balance := _shipped_balance_dict()
	var attack_growth_before := float(balance["curves"]["attack"]["growth"])
	var applied := DashboardRunner.apply_knob(balance, "curves.attack.growth", 1.9)
	assert_true(bool(applied.get("ok", false)), "error: %s" % str(applied.get("error", "")))
	if not bool(applied.get("ok", false)):
		return
	var modified: Dictionary = applied["dict"]
	assert_almost_eq(float(modified["curves"]["attack"]["growth"]), 1.9, 0.000001)
	assert_almost_eq(
		float(balance["curves"]["attack"]["growth"]), attack_growth_before, 0.000001,
		"the input dictionary must not be mutated"
	)


func test_apply_knob_sets_top_level_path():
	var applied := DashboardRunner.apply_knob(_shipped_balance_dict(), "hp_spread", 0.4)
	assert_true(bool(applied.get("ok", false)), "error: %s" % str(applied.get("error", "")))
	if not bool(applied.get("ok", false)):
		return
	assert_almost_eq(float((applied["dict"] as Dictionary)["hp_spread"]), 0.4, 0.000001)


func test_apply_knob_unknown_path_is_error():
	var applied := DashboardRunner.apply_knob(_shipped_balance_dict(), "curves.luck.growth", 1.5)
	assert_false(bool(applied.get("ok", true)))
	assert_string_contains(String(applied.get("error", "")), "curves.luck.growth")


func test_apply_knob_non_numeric_leaf_is_error():
	var applied := DashboardRunner.apply_knob(_shipped_balance_dict(), "curves.attack", 1.5)
	assert_false(bool(applied.get("ok", true)), "a non-numeric leaf is not a tunable knob")


# --- cell aggregation (spec: Survival counts only completed runs) ---

func test_summarize_cell_separates_survival_and_stalled():
	var run_stats: Array = []
	for i in range(80):
		run_stats.append({"battles_survived": 10, "end_cause": "MAX_BATTLES"})
	for i in range(15):
		run_stats.append({"battles_survived": 4, "end_cause": "WIPED"})
	for i in range(5):
		run_stats.append({"battles_survived": 6, "end_cause": "STALLED"})
	var summary := DashboardRunner.summarize_cell(run_stats)
	assert_almost_eq(float(summary.get("survival_rate", -1.0)), 0.80, 0.000001)
	assert_almost_eq(float(summary.get("stalled_rate", -1.0)), 0.05, 0.000001)
	assert_eq(int(summary.get("median_battles_survived", -1)), 10, "nearest-rank p50 of battles")


func test_summarize_cell_stalled_never_counts_as_survival():
	var run_stats: Array = [
		{"battles_survived": 3, "end_cause": "STALLED"},
		{"battles_survived": 3, "end_cause": "STALLED"},
	]
	var summary := DashboardRunner.summarize_cell(run_stats)
	assert_almost_eq(float(summary.get("survival_rate", -1.0)), 0.0, 0.000001)
	assert_almost_eq(float(summary.get("stalled_rate", -1.0)), 1.0, 0.000001)


# --- heatmap (spec: CSV row per cell, determinism, seed derivation) ---

func test_run_heatmap_produces_one_row_per_cell_in_grid_order():
	var cfg := _make_config([2, 3], [1, 2], 2, 1)
	var out := DashboardRunner.run_heatmap(cfg, _real_repo, _spell_repo)
	assert_true(bool(out.get("ok", false)), "error: %s" % str(out.get("error", "")))
	var rows: Array = out.get("rows", [])
	assert_eq(rows.size(), 4, "levels x floors = 2 x 2 cells")
	if rows.size() != 4:
		return
	var expected_cells := [[2, 1], [2, 2], [3, 1], [3, 2]]
	for i in range(4):
		var row: Dictionary = rows[i]
		assert_eq(int(row.get("level", -1)), int(expected_cells[i][0]), "row %d level" % i)
		assert_eq(int(row.get("floor", -1)), int(expected_cells[i][1]), "row %d floor" % i)
		assert_eq(int(row.get("runs", -1)), 2)
		var survival := float(row.get("survival_rate", -1.0))
		var stalled := float(row.get("stalled_rate", -1.0))
		assert_between(survival, 0.0, 1.0)
		assert_between(stalled, 0.0, 1.0)
		assert_eq(int(row.get("median_battles_survived", -1)), 1,
			"max_battles=1: every run records exactly 1 battle entered")


func test_run_heatmap_is_deterministic():
	var cfg := _make_config([3], [1], 2, 1)
	var first := DashboardRunner.run_heatmap(cfg, _real_repo, _spell_repo)
	var second := DashboardRunner.run_heatmap(cfg, _real_repo, _spell_repo)
	assert_true(bool(first.get("ok", false)), "error: %s" % str(first.get("error", "")))
	assert_true(bool(second.get("ok", false)))
	assert_eq(first.get("rows", []), second.get("rows", []),
		"identical config -> identical rows")


# Pins the documented seed scheme: the RNG for run i of a heatmap cell is
# seeded with hash(str(master_seed) + ":L<level>:F<floor>:" + str(i)). If the
# derivation changes, byte-identical CSV reproduction silently breaks, so this
# test replicates the cell manually through ExpeditionRunner and compares.
func test_run_heatmap_seed_derivation_is_pinned():
	var cfg := _make_config([3], [1], 3, 2)
	var out := DashboardRunner.run_heatmap(cfg, _real_repo, _spell_repo)
	assert_true(bool(out.get("ok", false)), "error: %s" % str(out.get("error", "")))
	if not bool(out.get("ok", false)):
		return
	var rows: Array = out.get("rows", [])
	assert_eq(rows.size(), 1)
	if rows.size() != 1:
		return
	var expedition_config := ExpeditionConfig.new()
	expedition_config.party = cfg.party_specs_at_level(3)
	expedition_config.max_battles = 2
	expedition_config.encounter_mode = "table"
	expedition_config.encounter_floor = 1
	var run_stats: Array = []
	for i in range(3):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(MASTER_SEED) + ":L3:F1:" + str(i))
		var result := ExpeditionRunner.run_expedition(
			expedition_config, i, rng, ExpeditionRunner.DEFAULT_TURN_LIMIT,
			_real_repo, _spell_repo
		)
		assert_not_null(result, "manual replication run %d must succeed" % i)
		if result == null:
			return
		run_stats.append(result.to_run_stats())
	var expected := DashboardRunner.summarize_cell(run_stats)
	var row: Dictionary = rows[0]
	assert_almost_eq(
		float(row.get("survival_rate", -1.0)), float(expected.get("survival_rate", -2.0)),
		0.000001, "heatmap cell must reproduce the documented per-run seeds"
	)
	assert_almost_eq(
		float(row.get("stalled_rate", -1.0)), float(expected.get("stalled_rate", -2.0)), 0.000001
	)
	assert_eq(
		int(row.get("median_battles_survived", -1)),
		int(expected.get("median_battles_survived", -2))
	)


# The dashboard loads the encounter tables once per invocation and injects
# them into every run (no per-run directory rescans). Floor 99 exists only in
# the injected array, so this cell can succeed only through the seam.
func test_run_heatmap_uses_injected_encounter_tables():
	var table := EncounterTableData.new()
	table.floor = 99
	table.tier_weights = {1: 1}
	table.species_count_min = 1
	table.species_count_max = 1
	table.count_per_species_min = 1
	table.count_per_species_max = 1
	var cfg := _make_config([3], [99], 2, 1)
	var out := DashboardRunner.run_heatmap(cfg, _real_repo, _spell_repo, [table])
	assert_true(bool(out.get("ok", false)), "error: %s" % str(out.get("error", "")))
	var rows: Array = out.get("rows", [])
	assert_eq(rows.size(), 1)
	if rows.size() == 1:
		assert_eq(int((rows[0] as Dictionary).get("floor", -1)), 99)


# --- sweep (spec: one row per knob value x scenario) ---

func test_run_sweep_produces_rows_per_knob_value_and_scenario():
	var cfg := _add_sweep(
		_make_config([3], [1], 2, 1),
		"curves.attack.growth", 1.2, 1.4, 2,
		[{"level": 3, "floor": 1}]
	)
	var out := DashboardRunner.run_sweep(cfg, _shipped_balance_dict(), _loader.load_all_monsters(), _spell_repo)
	assert_true(bool(out.get("ok", false)), "error: %s" % str(out.get("error", "")))
	var rows: Array = out.get("rows", [])
	assert_eq(rows.size(), 2, "2 knob values x 1 scenario")
	if rows.size() != 2:
		return
	var first: Dictionary = rows[0]
	var second: Dictionary = rows[1]
	assert_eq(String(first.get("knob", "")), "curves.attack.growth")
	assert_almost_eq(float(first.get("knob_value", -1.0)), 1.2, 0.000001)
	assert_almost_eq(float(second.get("knob_value", -1.0)), 1.4, 0.000001)
	for row_variant in rows:
		var row: Dictionary = row_variant
		assert_eq(int(row.get("level", -1)), 3)
		assert_eq(int(row.get("floor", -1)), 1)
		assert_between(float(row.get("survival_rate", -1.0)), 0.0, 1.0)
		assert_between(float(row.get("stalled_rate", -1.0)), 0.0, 1.0)


func test_run_sweep_is_deterministic():
	var cfg := _add_sweep(
		_make_config([3], [1], 2, 1),
		"hp_spread", 0.1, 0.3, 2,
		[{"level": 3, "floor": 1}]
	)
	var balance := _shipped_balance_dict()
	var base_monsters := _loader.load_all_monsters()
	var first := DashboardRunner.run_sweep(cfg, balance, base_monsters, _spell_repo)
	var second := DashboardRunner.run_sweep(cfg, balance, base_monsters, _spell_repo)
	assert_true(bool(first.get("ok", false)), "error: %s" % str(first.get("error", "")))
	assert_eq(first.get("rows", []), second.get("rows", []))


# A steps value below 2 cannot sample a range; returning ok with zero rows
# would silently produce an empty CSV, so it must fail like other config
# problems instead.
func test_run_sweep_steps_below_two_fails():
	var cfg := _add_sweep(
		_make_config([3], [1], 1, 1),
		"hp_spread", 0.1, 0.3, 1,
		[{"level": 3, "floor": 1}]
	)
	var out := DashboardRunner.run_sweep(
		cfg, _shipped_balance_dict(), _loader.load_all_monsters(), _spell_repo
	)
	assert_false(bool(out.get("ok", true)), "steps < 2 must fail, not return empty rows")
	assert_string_contains(String(out.get("error", "")), "steps")


func test_run_sweep_unknown_knob_path_fails():
	var cfg := _add_sweep(
		_make_config([3], [1], 1, 1),
		"curves.luck.growth", 1.0, 2.0, 2,
		[{"level": 3, "floor": 1}]
	)
	var out := DashboardRunner.run_sweep(cfg, _shipped_balance_dict(), _loader.load_all_monsters(), _spell_repo)
	assert_false(bool(out.get("ok", true)), "unknown knob path must fail")
	assert_string_contains(String(out.get("error", "")), "curves.luck.growth")


# --- CSV formatting (spec: identical inputs reproduce identical CSV) ---

func test_csv_columns_match_spec():
	assert_eq(DashboardRunner.HEATMAP_COLUMNS, PackedStringArray([
		"level", "floor", "runs", "survival_rate", "stalled_rate", "median_battles_survived",
	]))
	assert_eq(DashboardRunner.SWEEP_COLUMNS, PackedStringArray([
		"knob", "knob_value", "level", "floor", "survival_rate", "stalled_rate",
	]))


func test_format_cells_uses_fixed_precision():
	var heatmap_rows := [{
		"level": 2, "floor": 1, "runs": 3,
		"survival_rate": 2.0 / 3.0, "stalled_rate": 0.0, "median_battles_survived": 2,
	}]
	var cells: Array = DashboardRunner.format_cells(heatmap_rows, DashboardRunner.HEATMAP_COLUMNS)
	assert_eq(cells.size(), 1)
	if cells.size() != 1:
		return
	var cell: Dictionary = cells[0]
	assert_eq(String(cell.get("survival_rate", "")), "0.667")
	assert_eq(String(cell.get("stalled_rate", "")), "0.000")
	assert_eq(String(cell.get("level", "")), "2")
	assert_eq(String(cell.get("median_battles_survived", "")), "2")
	var sweep_rows := [{
		"knob": "curves.attack.growth", "knob_value": 1.4, "level": 3, "floor": 1,
		"survival_rate": 1.0, "stalled_rate": 0.0,
	}]
	var sweep_cells: Array = DashboardRunner.format_cells(sweep_rows, DashboardRunner.SWEEP_COLUMNS)
	assert_eq(sweep_cells.size(), 1)
	if sweep_cells.size() != 1:
		return
	var sweep_cell: Dictionary = sweep_cells[0]
	assert_eq(String(sweep_cell.get("knob", "")), "curves.attack.growth")
	assert_eq(String(sweep_cell.get("knob_value", "")), "1.400000")


func test_write_table_output_is_byte_identical_for_identical_rows():
	var rows := [{
		"level": 2, "floor": 1, "runs": 3,
		"survival_rate": 0.5, "stalled_rate": 0.0, "median_battles_survived": 2,
	}]
	var cells: Array = DashboardRunner.format_cells(rows, DashboardRunner.HEATMAP_COLUMNS)
	var relative_paths := ["tmp/test_dashboard_csv_a.csv", "tmp/test_dashboard_csv_b.csv"]
	var absolute_paths: Array[String] = []
	for relative_path in relative_paths:
		assert_true(
			SimulationCsvWriter.write_table(relative_path, DashboardRunner.HEATMAP_COLUMNS, cells),
			"write_table must succeed"
		)
		absolute_paths.append(ProjectSettings.globalize_path("res://").path_join(relative_path))
	var bytes_a := FileAccess.get_file_as_bytes(absolute_paths[0])
	var bytes_b := FileAccess.get_file_as_bytes(absolute_paths[1])
	for absolute_path in absolute_paths:
		DirAccess.remove_absolute(absolute_path)
	assert_gt(bytes_a.size(), 0, "CSV must not be empty")
	assert_eq(bytes_a, bytes_b, "identical rows -> byte-identical CSV")
	var text := bytes_a.get_string_from_utf8()
	assert_string_contains(text, ",".join(DashboardRunner.HEATMAP_COLUMNS))
	assert_string_contains(text, "2,1,3,0.500,0.000,2")
