## ADDED Requirements

### Requirement: JobData holds job configuration
JobData SHALL store the job name, base HP, magic capability (has_magic), base MP, and stat requirements for all six stats.

#### Scenario: Create Fighter job with no requirements
- **WHEN** a JobData is created with job_name="Fighter", base_hp=10, has_magic=false, and all required stats set to 0
- **THEN** job_name SHALL be "Fighter", base_hp SHALL be 10, has_magic SHALL be false, and all required stat thresholds SHALL be 0

#### Scenario: Create Mage job with INT requirement
- **WHEN** a JobData is created with job_name="Mage", has_magic=true, base_mp=5, required_int=11
- **THEN** has_magic SHALL be true, base_mp SHALL be 5, required_int SHALL be 11

### Requirement: JobData can check stat qualification
JobData SHALL provide a method `can_qualify(stats: Dictionary) -> bool` that returns true only when all stat values meet or exceed the corresponding required thresholds.

#### Scenario: Fighter qualifies with any stats
- **WHEN** can_qualify is called with all stats at 8
- **THEN** the result SHALL be true (Fighter has no requirements)

#### Scenario: Mage qualifies with sufficient INT
- **WHEN** can_qualify is called with INT=11 on a Mage (required_int=11)
- **THEN** the result SHALL be true

#### Scenario: Mage does not qualify with insufficient INT
- **WHEN** can_qualify is called with INT=10 on a Mage (required_int=11)
- **THEN** the result SHALL be false

#### Scenario: Lord requires all six stats to meet thresholds
- **WHEN** can_qualify is called with STR=15, INT=12, PIE=12, VIT=15, AGI=14, LUC=15 on a Lord
- **THEN** the result SHALL be true

#### Scenario: Lord fails if any single stat is below threshold
- **WHEN** can_qualify is called with STR=15, INT=12, PIE=12, VIT=14, AGI=14, LUC=15 on a Lord (required_vit=15)
- **THEN** the result SHALL be false

### Requirement: Eight jobs are defined as .tres resources
The system SHALL provide .tres resource files for exactly eight jobs: Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja.

#### Scenario: All job files exist
- **WHEN** the data/jobs/ directory is scanned
- **THEN** exactly eight .tres files SHALL exist

#### Scenario: Fighter has no stat requirements
- **WHEN** fighter.tres is loaded
- **THEN** all required stat thresholds SHALL be 0

#### Scenario: Mage requires INT >= 11
- **WHEN** mage.tres is loaded
- **THEN** required_int SHALL be 11 and all other required stats SHALL be 0

#### Scenario: Priest requires PIE >= 11
- **WHEN** priest.tres is loaded
- **THEN** required_pie SHALL be 11 and all other required stats SHALL be 0

#### Scenario: Thief requires AGI >= 11
- **WHEN** thief.tres is loaded
- **THEN** required_agi SHALL be 11 and all other required stats SHALL be 0

#### Scenario: Bishop requires INT >= 12 and PIE >= 12
- **WHEN** bishop.tres is loaded
- **THEN** required_int SHALL be 12, required_pie SHALL be 12, and all other required stats SHALL be 0

#### Scenario: Samurai requires multiple stats
- **WHEN** samurai.tres is loaded
- **THEN** required_str SHALL be 15, required_int SHALL be 11, required_pie SHALL be 10, required_vit SHALL be 14, required_agi SHALL be 10, required_luc SHALL be 0

#### Scenario: Lord requires all stats at high thresholds
- **WHEN** lord.tres is loaded
- **THEN** required_str SHALL be 15, required_int SHALL be 12, required_pie SHALL be 12, required_vit SHALL be 15, required_agi SHALL be 14, required_luc SHALL be 15

#### Scenario: Ninja requires all stats at 15
- **WHEN** ninja.tres is loaded
- **THEN** all required stats SHALL be 15

#### Scenario: Magic jobs
- **WHEN** job data files are loaded
- **THEN** Mage, Priest, Bishop, Samurai, Lord, Ninja SHALL have has_magic=true and Fighter, Thief SHALL have has_magic=false

### Requirement: DataLoader loads all jobs
DataLoader SHALL provide a method to load all job resources from the data/jobs/ directory.

#### Scenario: Load all jobs
- **WHEN** DataLoader.load_all_jobs() is called
- **THEN** an array of 8 JobData instances SHALL be returned

#### Scenario: Loaded jobs have correct names
- **WHEN** DataLoader.load_all_jobs() is called
- **THEN** the returned array SHALL contain jobs named Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja

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
