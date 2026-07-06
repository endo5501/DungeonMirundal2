# balance-dashboard Specification

## Purpose
バランス調整用の計器盤ヘッドレス CLI を規定する。標準パーティ(レベル別)× フロアの生存率ヒートマップと、曲線ノブの感度スイープをメモリ上の曲線適用・決定的シードで算出し、コンソール表と CSV で出力する。
## Requirements

### Requirement: Dashboard CLI with heatmap and sweep modes

The system SHALL provide a headless CLI (`godot --headless -s src/simulation/balance_dashboard_cli.gd -- --config=<path> --mode=<heatmap|sweep> [--balance=<path>] [--csv=<path>]`) that evaluates expedition survival under the current or curve-adjusted monster stats.

- `--config` points to a dashboard configuration JSON (required)
- `--mode` selects `heatmap` or `sweep` (required)
- `--balance` optionally applies a balance definition in memory; when omitted, the shipped `.tres` values are used as-is
- Exit codes: 0 = success, 1 = config / balance / runtime failure, 2 = usage error

#### Scenario: Unknown mode is a usage error

- **WHEN** the CLI is invoked with `--mode=optimize`
- **THEN** it SHALL print usage and exit with code 2

#### Scenario: Config validation failure aborts

- **WHEN** the dashboard config has validation errors
- **THEN** every error SHALL be printed and the exit code SHALL be 1

### Requirement: Dashboard configuration defines the standard party and evaluation grid

The dashboard configuration JSON SHALL define:

- `party_template`: an array of member objects (`race`, `job`, `row`), defaulting in the shipped sample config to fighter×3 (front), priest, mage, thief (back)
- `levels`: array of party levels to evaluate (each level is applied to every template member)
- `floors`: array of dungeon floors to evaluate (encounter tables in `table` mode)
- `runs`: expeditions per cell (positive int), `max_battles`: battles to survive (positive int), `master_seed`: int

Party construction SHALL reuse `PartyFactory.build` so race/job validation and leveling match the expedition simulator.

#### Scenario: Template expands to leveled parties

- **WHEN** a config declares a 6-member `party_template` and `levels: [2, 6]`
- **THEN** evaluation SHALL build the same 6-member composition at level 2 and at level 6

#### Scenario: Invalid template member is reported

- **WHEN** `party_template` contains a member with an unknown job
- **THEN** the CLI SHALL print the `PartyFactory` error and exit with code 1

### Requirement: Heatmap mode outputs a survival-rate grid

In heatmap mode the system SHALL, for every (level, floor) cell, run `runs` expeditions of up to `max_battles` battles against the floor's encounter table and compute:

- `survival_rate`: fraction of runs whose end cause is `MAX_BATTLES` (the party completed all battles without wiping)
- `stalled_rate`: fraction of runs whose end cause is `STALLED`, reported separately and never counted as survival

The CLI SHALL print the survival grid as a console table (levels as rows, floors as columns) and SHALL write a CSV with one row per cell containing at least: `level`, `floor`, `runs`, `survival_rate`, `stalled_rate`, `median_battles_survived`.

#### Scenario: Survival counts only completed runs

- **WHEN** a cell's runs end with 80 × `MAX_BATTLES`, 15 × `WIPED`, 5 × `STALLED` out of 100
- **THEN** `survival_rate` SHALL be 0.80 AND `stalled_rate` SHALL be 0.05

#### Scenario: CSV row per cell

- **WHEN** heatmap mode evaluates `levels: [2, 4]` × `floors: [1, 2, 3]`
- **THEN** the CSV SHALL contain exactly 6 data rows, one per (level, floor) pair

### Requirement: Sweep mode evaluates one knob across a range

In sweep mode the configuration SHALL additionally define:

- `knob`: a dotted path into the balance definition (e.g., `curves.attack.growth`, `hp_spread`)
- `from`, `to` (floats) and `steps` (int >= 2): the inclusive value range sampled at `steps` evenly spaced points
- `scenarios`: array of `{ "level": int, "floor": int }` pairs to evaluate at each step

For each sampled knob value the system SHALL apply the modified balance definition in memory and compute the same survival metrics as heatmap mode for every scenario. The CSV SHALL contain one row per (knob value, scenario) with at least: `knob`, `knob_value`, `level`, `floor`, `survival_rate`, `stalled_rate`.

Sweep mode SHALL require `--balance` (the knob must have a base definition to modify); invoking sweep mode without it SHALL be a usage error.

#### Scenario: Knob range is sampled inclusively

- **WHEN** a sweep declares `from: 1.4, to: 2.0, steps: 4`
- **THEN** the evaluated knob values SHALL be 1.4, 1.6, 1.8, 2.0

#### Scenario: Unknown knob path is a config error

- **WHEN** a sweep declares `knob: "curves.luck.growth"`
- **THEN** the CLI SHALL report the unknown path and exit with code 1

#### Scenario: Sweep without balance definition is a usage error

- **WHEN** sweep mode is invoked without `--balance`
- **THEN** the CLI SHALL print usage and exit with code 2

### Requirement: Dashboard never modifies .tres files and is deterministic

The dashboard SHALL apply balance definitions by building in-memory copies of the loaded `MonsterData` resources with recomputed combat stats; no file under `data/monsters/` SHALL be written. Monster and spell repositories SHALL be loaded once per process.

Run seeding SHALL follow the expedition CLI derivation (`hash(str(master_seed) + ":" + str(run_index))`) with an independent, deterministic run-index series per cell (or per knob step × scenario), so that identical config + balance inputs reproduce identical output byte-for-byte.

#### Scenario: Data files are untouched

- **WHEN** heatmap mode runs with a `--balance` definition that changes every monster's stats
- **THEN** every file under `data/monsters/` SHALL be byte-identical before and after the run

#### Scenario: Identical inputs reproduce identical CSV

- **WHEN** the dashboard runs twice with the same config, mode, and balance definition
- **THEN** both CSV outputs SHALL be byte-identical
