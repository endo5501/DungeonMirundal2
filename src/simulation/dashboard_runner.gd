class_name DashboardRunner
extends RefCounted

# Pure orchestration for the balance dashboard (design D6): evaluates the
# heatmap / sweep grids and aggregates row dictionaries. No printing and no
# file writing — console rendering and CSV output belong to
# balance_dashboard_cli (via SimulationCsvWriter.write_table). The encounter
# tables are read from disk at most once per invocation and injected into
# every run.
#
# Seed scheme (pinned by test_dashboard_runner): the RNG for run i of a cell
# is seeded with
#   hash(str(master_seed) + ":" + cell_key + ":" + str(i))
# where cell_key is "L<level>:F<floor>" in heatmap mode and
# "<knob>=<value %.6f>:L<level>:F<floor>" in sweep mode. Every cell (and every
# knob step) therefore gets an independent deterministic run-index series, so
# identical config + balance inputs reproduce identical rows — and identical
# CSV bytes once formatted through format_cells.

const HEATMAP_COLUMNS: PackedStringArray = [
	"level", "floor", "runs", "survival_rate", "stalled_rate", "median_battles_survived",
]
const SWEEP_COLUMNS: PackedStringArray = [
	"knob", "knob_value", "level", "floor", "survival_rate", "stalled_rate",
]
const RATE_COLUMNS: PackedStringArray = ["survival_rate", "stalled_rate"]


# Runs the (levels x floors) survival grid. Returns {"ok": bool,
# "error": String, "rows": Array}; rows are ordered level-major and carry
# exactly the HEATMAP_COLUMNS keys. `encounter_tables` is an optional
# injection seam for tests; when empty, the tables are loaded from disk once
# here and reused by every run (no per-run directory rescans).
static func run_heatmap(
	config: DashboardConfig,
	monster_repo: MonsterRepository,
	spell_repo: SpellRepository,
	encounter_tables: Array = [],
) -> Dictionary:
	var tables := _resolve_encounter_tables(encounter_tables)
	var rows: Array = []
	for level in config.levels:
		for floor_number in config.floors:
			var cell_key := "L%d:F%d" % [int(level), int(floor_number)]
			var cell := _run_cell(
				config, int(level), int(floor_number), cell_key, monster_repo, spell_repo, tables
			)
			if not cell["ok"]:
				return {"ok": false, "error": cell["error"], "rows": []}
			var summary: Dictionary = cell["summary"]
			rows.append({
				"level": int(level),
				"floor": int(floor_number),
				"runs": config.runs,
				"survival_rate": summary["survival_rate"],
				"stalled_rate": summary["stalled_rate"],
				"median_battles_survived": summary["median_battles_survived"],
			})
	return {"ok": true, "error": "", "rows": rows}


# Runs the knob sweep: for every sampled knob value the balance definition is
# modified in memory, re-validated through MonsterCurve.parse, applied to a
# fresh repository and evaluated for every scenario. Returns {"ok", "error",
# "rows"} with SWEEP_COLUMNS keys per row.
static func run_sweep(
	config: DashboardConfig,
	balance: Dictionary,
	base_monsters: Array,
	spell_repo: SpellRepository,
	encounter_tables: Array = [],
) -> Dictionary:
	if not config.sweep_defined:
		return {"ok": false, "error": "sweep: config declares no sweep block", "rows": []}
	if config.sweep_steps < 2:
		# sample_knob_values would yield nothing; failing here keeps a bad
		# steps value from silently producing an empty (yet "successful") CSV.
		return {
			"ok": false,
			"error": "sweep.steps: must be >= 2 (got %d)" % config.sweep_steps,
			"rows": [],
		}
	var tables := _resolve_encounter_tables(encounter_tables)
	var rows: Array = []
	for value_variant in sample_knob_values(config.sweep_from, config.sweep_to, config.sweep_steps):
		var value := float(value_variant)
		var applied := apply_knob(balance, config.sweep_knob, value)
		if not applied["ok"]:
			return {"ok": false, "error": applied["error"], "rows": []}
		# Re-parsing the modified dictionary re-runs the full MonsterCurve
		# validation, so out-of-range knob values fail loudly instead of
		# producing nonsense stats.
		var curve := MonsterCurve.parse(applied["dict"])
		if not curve.errors.is_empty():
			return {
				"ok": false,
				"error": "balance invalid at %s=%s: %s"
					% [config.sweep_knob, str(value), "; ".join(curve.errors)],
				"rows": [],
			}
		var repo := BalanceRepoBuilder.build(base_monsters, curve)
		for scenario_variant in config.sweep_scenarios:
			var scenario: Dictionary = scenario_variant
			var level := int(scenario["level"])
			var floor_number := int(scenario["floor"])
			var cell_key := "%s=%s:L%d:F%d" % [
				config.sweep_knob, "%.6f" % value, level, floor_number,
			]
			var cell := _run_cell(config, level, floor_number, cell_key, repo, spell_repo, tables)
			if not cell["ok"]:
				return {"ok": false, "error": cell["error"], "rows": []}
			var summary: Dictionary = cell["summary"]
			rows.append({
				"knob": config.sweep_knob,
				"knob_value": value,
				"level": level,
				"floor": floor_number,
				"survival_rate": summary["survival_rate"],
				"stalled_rate": summary["stalled_rate"],
			})
	return {"ok": true, "error": "", "rows": rows}


# Samples `steps` evenly spaced values from the inclusive [from, to] range.
# The last sample is `to` itself (not from + (to-from), which could drift by
# one ulp and change the sweep's cell keys / CSV bytes).
static func sample_knob_values(from_value: float, to_value: float, steps: int) -> Array:
	var values: Array = []
	if steps < 2:
		return values
	for i in range(steps):
		if i == steps - 1:
			values.append(to_value)
		else:
			values.append(from_value + (to_value - from_value) * float(i) / float(steps - 1))
	return values


# Sets the dotted `knob` path (e.g. "curves.attack.growth", "hp_spread") in a
# deep copy of `balance`. Every path segment must already exist and the leaf
# must be a number — anything else is an unknown-knob error (spec: unknown
# knob path is a config error). Returns {"ok", "error", "dict"}.
static func apply_knob(balance: Dictionary, knob: String, value: float) -> Dictionary:
	var result: Dictionary = balance.duplicate(true)
	var segments := knob.split(".")
	var node: Dictionary = result
	for i in range(segments.size() - 1):
		var segment := segments[i]
		if not node.has(segment) or not (node[segment] is Dictionary):
			return _knob_error(knob, segment)
		node = node[segment]
	var leaf := segments[segments.size() - 1]
	if not node.has(leaf) or not _is_number(node[leaf]):
		return _knob_error(knob, leaf)
	node[leaf] = value
	return {"ok": true, "error": "", "dict": result}


# Aggregates one cell's run stats ({"battles_survived", "end_cause"} each).
# survival_rate counts only MAX_BATTLES runs; STALLED is reported separately
# and never counted as survival (spec: Heatmap mode outputs a survival grid).
# The median uses the nearest-rank method, matching ResultAggregator.
static func summarize_cell(run_stats: Array) -> Dictionary:
	var survived := 0
	var stalled := 0
	var battles: Array[int] = []
	for stat_variant in run_stats:
		var stat: Dictionary = stat_variant
		battles.append(int(stat["battles_survived"]))
		match String(stat["end_cause"]):
			"MAX_BATTLES":
				survived += 1
			"STALLED":
				stalled += 1
	battles.sort()
	var count := run_stats.size()
	var median := -1
	if count > 0:
		var rank := clampi(int(ceil(0.5 * count)), 1, count)
		median = battles[rank - 1]
	return {
		"survival_rate": float(survived) / float(count) if count > 0 else 0.0,
		"stalled_rate": float(stalled) / float(count) if count > 0 else 0.0,
		"median_battles_survived": median,
	}


# Converts result rows into pre-formatted String cells for
# SimulationCsvWriter.write_table. Fixed precision ("%.3f" rates, "%.6f" knob
# values) keeps identical inputs byte-identical in the CSV.
static func format_cells(rows: Array, columns: PackedStringArray) -> Array:
	var formatted: Array = []
	for row_variant in rows:
		var row: Dictionary = row_variant
		var cells := {}
		for column in columns:
			var value: Variant = row[column]
			if column in RATE_COLUMNS:
				cells[column] = "%.3f" % float(value)
			elif column == "knob_value":
				cells[column] = "%.6f" % float(value)
			elif column == "knob":
				cells[column] = String(value)
			else:
				cells[column] = str(int(value))
		formatted.append(cells)
	return formatted


# --- internals ---

# Runs config.runs expeditions for one (level, floor) cell against the given
# repository and summarizes them. The per-run ExpeditionConfig mirrors what
# expedition_cli builds: template party at the cell's level, encounter table
# of the cell's floor, config.max_battles, DEFAULT ai knobs.
static func _run_cell(
	config: DashboardConfig,
	level: int,
	floor_number: int,
	cell_key: String,
	monster_repo: MonsterRepository,
	spell_repo: SpellRepository,
	encounter_tables: Array,
) -> Dictionary:
	var expedition_config := ExpeditionConfig.new()
	expedition_config.party = config.party_specs_at_level(level)
	expedition_config.max_battles = config.max_battles
	expedition_config.encounter_mode = "table"
	expedition_config.encounter_floor = floor_number
	var run_stats: Array = []
	for i in range(config.runs):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(config.master_seed) + ":" + cell_key + ":" + str(i))
		var result := ExpeditionRunner.run_expedition(
			expedition_config, i, rng, ExpeditionRunner.DEFAULT_TURN_LIMIT,
			monster_repo, spell_repo, encounter_tables
		)
		if result == null:
			return {
				"ok": false,
				"error": "cell %s run %d failed (see errors above)" % [cell_key, i],
				"summary": {},
			}
		run_stats.append(result.to_run_stats())
	return {"ok": true, "error": "", "summary": summarize_cell(run_stats)}


# Loads the encounter tables from disk exactly once per dashboard invocation
# when the caller did not inject a set. ExpeditionRunner treats a non-empty
# injected array as authoritative, so passing the loaded set through avoids
# one directory rescan per run (6,000 scans for the shipped 5x12x100 config).
static func _resolve_encounter_tables(encounter_tables: Array) -> Array:
	if not encounter_tables.is_empty():
		return encounter_tables
	return DataLoader.new().load_all_encounter_tables()


static func _knob_error(knob: String, segment: String) -> Dictionary:
	return {
		"ok": false,
		"error": "sweep.knob: unknown knob path '%s' (segment '%s' does not resolve to a tunable number)"
			% [knob, segment],
		"dict": {},
	}


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
