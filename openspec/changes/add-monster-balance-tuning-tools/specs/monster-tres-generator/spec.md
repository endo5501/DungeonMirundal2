# monster-tres-generator

## ADDED Requirements

### Requirement: Generator CLI rewrites combat stats from the balance definition

The system SHALL provide a headless CLI (`godot --headless -s src/simulation/balance_generator_cli.gd -- --balance=<path> [--check]`) that, for every monster `.tres` file under `data/monsters/`, computes the combat stats (`max_hp_min`, `max_hp_max`, `attack`, `defense`, `agility`) from the balance definition using the monster's `tier`, and rewrites those field values in the `.tres` file.

Exit codes SHALL follow the expedition CLI convention: 0 = success, 1 = balance file / rewrite failure, 2 = command-line usage error.

#### Scenario: Combat stats are regenerated from the curve

- **WHEN** the generator runs with a valid balance definition covering `goblin` (tier 2)
- **THEN** `data/monsters/goblin.tres` SHALL contain `max_hp_min`, `max_hp_max`, `attack`, `defense`, `agility` values equal to the calculator's output for goblin at tier 2

#### Scenario: Invalid balance definition aborts with exit code 1

- **WHEN** the generator runs with a balance definition whose `errors` array is non-empty
- **THEN** the generator SHALL print every error, write no files, and exit with code 1

#### Scenario: Missing --balance argument is a usage error

- **WHEN** the generator is invoked without `--balance=<path>`
- **THEN** it SHALL print usage and exit with code 2

### Requirement: Generator preserves all non-combat fields byte-for-byte

The rewrite SHALL be a text-level replacement of only the five combat stat value lines. All other file content — including `experience`, `gold_min`, `gold_max`, `resists`, `known_spells`, `battle_texture` references, `tier`, `default_row`, `attack_range`, `max_mp_min`, `max_mp_max`, ext_resource declarations, and formatting — SHALL remain byte-identical to the input.

When any of the five combat stat lines cannot be located in a file, the generator SHALL report an error for that file and SHALL NOT write it (no partial rewrites).

#### Scenario: Non-combat fields are untouched

- **WHEN** the generator rewrites `skeleton.tres`
- **THEN** the output file with its five combat stat lines restored to their previous values SHALL be byte-identical to the original file

#### Scenario: Malformed file is not partially written

- **WHEN** a `.tres` file is missing an `attack = ` line
- **THEN** the generator SHALL report an error naming the file and leave the file unmodified

### Requirement: Species missing from the balance definition are skipped with a warning

When a loaded monster's id appears neither in `species` nor in `overrides` of the balance definition, the generator SHALL leave that monster's `.tres` file unmodified and SHALL print a warning naming the monster id. Skipped species SHALL NOT cause a non-zero exit code.

#### Scenario: Uncovered monster is skipped loudly

- **WHEN** the balance definition has no entry for `wraith`
- **THEN** `wraith.tres` SHALL be unmodified AND a warning naming `wraith` SHALL be printed AND the exit code SHALL be 0

### Requirement: Check mode previews changes without writing

The system SHALL support a `--check` flag that performs the full computation and prints, for every monster, the current and newly computed values of each combat stat that would change, without modifying any file. When no values would change, the output SHALL state so.

#### Scenario: Check mode lists pending changes

- **WHEN** the generator runs with `--check` and the curve output differs from current values for `goblin.attack`
- **THEN** the output SHALL include the monster id, the stat name, the current value, and the new value AND no `.tres` file SHALL be modified

#### Scenario: Check mode with no differences

- **WHEN** the generator runs with `--check` and every computed value equals the current value
- **THEN** the output SHALL state that no changes are pending AND the exit code SHALL be 0
