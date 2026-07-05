# expedition-simulator Specification

## Purpose
TBD - created by archiving change add-combat-expedition-simulator. Update Purpose after archive.
## Requirements
### Requirement: ExpeditionRunner runs consecutive battles until an end condition
`ExpeditionRunner` SHALL run battles back-to-back for one expedition: generate an encounter, run the battle to completion using `TurnEngine` with `PartyAi`-selected commands, apply rewards, heal between battles, and repeat. The expedition SHALL end when the party is wiped (`WIPED`), when `max_battles` battles have been cleared, or when a single battle exceeds the safety turn limit (`STALLED`).

#### Scenario: Expedition ends on party wipe
- **WHEN** the party is wiped in battle 7 of a 50-battle expedition
- **THEN** the expedition result records 7 battles, end cause `WIPED`, and no further battles run

#### Scenario: Expedition ends at the battle cap
- **WHEN** the party clears `max_battles` battles without wiping
- **THEN** the expedition result records `max_battles` battles and end cause `MAX_BATTLES`

#### Scenario: Runaway battle is cut off
- **WHEN** a battle reaches the safety turn limit (default 100) without finishing
- **THEN** the expedition ends with end cause `STALLED`

### Requirement: Party state persists across battles within an expedition
Character HP, MP, statuses committed as persistent, experience, and levels SHALL carry over from one battle to the next within an expedition. Cleared battles SHALL apply experience and gold via the existing `BattleResolver.resolve_rewards` path so level-ups occur as in real play.

#### Scenario: Damage carries into the next battle
- **WHEN** a character ends battle 1 at 40% HP and between-battle healing cannot restore them (no MP)
- **THEN** they begin battle 2 at 40% HP

#### Scenario: Experience accumulates and can level up characters
- **WHEN** cleared battles push a character past a level threshold
- **THEN** the character's level, HP/MP maximums, and newly learned spells reflect the level-up in subsequent battles

### Requirement: Between-battle healing uses OUTSIDE_OK healing spells while MP lasts
After each cleared battle, the runner SHALL repeatedly pick the living member with the lowest HP ratio and cast the affordable `OUTSIDE_OK` healing spell that minimizes overheal, until every living member is at full HP or no caster can afford any healing spell.

#### Scenario: Healing stops when MP runs out
- **WHEN** two members are injured and the party's casters have MP for only one `heal`
- **THEN** the most-injured member is healed once and healing stops

#### Scenario: No healing needed
- **WHEN** every living member is at full HP after a battle
- **THEN** no MP is spent between battles

### Requirement: Encounters come from a configurable source
The runner SHALL obtain each battle's `MonsterParty` from an `EncounterSource`. A `fixed` source SHALL cycle through configured composition patterns in order; a `table` source SHALL generate compositions from the `EncounterTableData` of a configured floor using the existing generation logic (encounter *trigger* probability is not used — every iteration produces a battle).

#### Scenario: Fixed patterns cycle in order
- **WHEN** the config lists patterns [goblin×3, slime×2] and 3 battles run
- **THEN** the encounters are goblin×3, slime×2, goblin×3

#### Scenario: Table source respects floor configuration
- **WHEN** the config selects `table` mode with floor 3
- **THEN** every generated composition is producible from `floor_3.tres` tier weights and count ranges

### Requirement: Expeditions are reproducible from a master seed
Given the same config (including `master_seed`), repeated executions SHALL produce identical per-run results. The RNG seed of run *i* SHALL be derived deterministically from `master_seed` and *i*.

#### Scenario: Same seed, same outcome
- **WHEN** the simulator is executed twice with an identical config file
- **THEN** the CSV outputs are byte-identical

### Requirement: Party is built from a JSON config through production creation paths
The simulator SHALL load party definitions (name, race, job, level, row) and AI knobs from a JSON config file, and SHALL build characters through the production creation/level-up paths so that HP/MP growth and `spell_progression`-derived known spells match real play. Initial equipment SHALL be the job's standard initial equipment.

#### Scenario: Config produces a leveled caster with spells
- **WHEN** the config contains a level-3 priest
- **THEN** the created character knows all priest spells granted through level 3 and has HP/MP consistent with the job's growth

#### Scenario: Invalid config fails fast
- **WHEN** the config references an unknown job or race
- **THEN** the simulator exits with a non-zero status and an error message naming the invalid field

### Requirement: Headless CLI entry point
The simulator SHALL be runnable as `godot --headless -s src/simulation/expedition_cli.gd -- --config=<path>` and SHALL exit with status 0 on success and non-zero on configuration or runtime failure.

#### Scenario: Successful headless run
- **WHEN** the CLI is invoked with a valid config
- **THEN** it prints the summary table to stdout, writes the CSV, and exits 0

