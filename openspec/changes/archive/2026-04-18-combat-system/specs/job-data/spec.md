## ADDED Requirements

### Requirement: JobData declares per-level HP and MP growth
`JobData` SHALL declare per-level growth fields `hp_per_level: int` and `mp_per_level: int`, so that level-up can apply job-specific HP (and, for magic jobs, MP) gains. `mp_per_level` SHALL only take effect for jobs with `has_magic == true`.

#### Scenario: Fighter has non-zero HP growth
- **WHEN** `fighter.tres` is loaded
- **THEN** `hp_per_level` SHALL be greater than `0`

#### Scenario: Mage has both HP and MP growth
- **WHEN** `mage.tres` is loaded
- **THEN** `hp_per_level` SHALL be greater than `0` and `mp_per_level` SHALL be greater than `0`

#### Scenario: Non-magic job has zero MP growth
- **WHEN** `fighter.tres` or `thief.tres` is loaded
- **THEN** `mp_per_level` SHALL be `0`

### Requirement: JobData declares an experience table for level-ups
`JobData` SHALL declare a monotonically-increasing `exp_table: PackedInt64Array` such that index `i` stores the cumulative experience required to reach level `i + 2` (i.e., to advance from level `i + 1` to level `i + 2`). The table SHALL cover at least levels up to `13` (12 thresholds: level 2 through level 13), allowing the system to extrapolate beyond if needed in a later change.

#### Scenario: exp_table exists and is non-empty
- **WHEN** any job `.tres` file is loaded
- **THEN** `exp_table.size()` SHALL be at least `12`

#### Scenario: exp_table is monotonically increasing
- **WHEN** `exp_table` is inspected for any job
- **THEN** for every index `i >= 1`, `exp_table[i] > exp_table[i - 1]` SHALL hold

#### Scenario: Jobs can have different experience tables
- **WHEN** the Fighter and Mage tables are compared
- **THEN** they MAY differ at any index (job-specific growth curves are allowed)

### Requirement: JobData exposes a helper to resolve the next-level threshold
`JobData` SHALL provide `exp_to_reach_level(target_level: int) -> int` that returns `exp_table[target_level - 2]` for `target_level >= 2`, and SHALL return `0` for `target_level <= 1`.

#### Scenario: Threshold for level 2 is the first table entry
- **WHEN** `exp_to_reach_level(2)` is called on any job
- **THEN** the returned value SHALL equal `exp_table[0]`

#### Scenario: Threshold for level 1 is zero
- **WHEN** `exp_to_reach_level(1)` or `exp_to_reach_level(0)` is called
- **THEN** the returned value SHALL be `0`

#### Scenario: Out-of-range lookup clamps to last entry
- **WHEN** `exp_to_reach_level(target_level)` is called with `target_level - 2 >= exp_table.size()`
- **THEN** the returned value SHALL equal the last element of `exp_table` (no interpolation in combat-system scope)
