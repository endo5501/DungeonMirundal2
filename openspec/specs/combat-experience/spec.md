## ADDED Requirements

### Requirement: Experience is the sum of defeated monster experience values
The system SHALL compute post-battle experience by summing the `experience` field of every `MonsterData` whose corresponding `MonsterCombatant` is dead at the end of the battle.

#### Scenario: Sum across multiple monsters
- **WHEN** a battle ends with two dead monsters whose `MonsterData.experience` values are `40` and `60`
- **THEN** the total experience SHALL be `100`

#### Scenario: No experience from a WIPED battle
- **WHEN** the battle ends with `outcome().result == WIPED`
- **THEN** the total experience awarded SHALL be `0` regardless of how many monsters were killed before the wipe

#### Scenario: No experience from an ESCAPED battle
- **WHEN** the battle ends with `outcome().result == ESCAPED`
- **THEN** the total experience awarded SHALL be `0`

### Requirement: Experience is distributed equally to all participating members
The system SHALL distribute the total experience equally (integer floor division) to every PartyCombatant that participated in the battle, including members whose `is_alive() == false` at battle end (Wizardry 1 rule).

#### Scenario: Equal split including dead members
- **WHEN** total experience is `100` and the party had 4 participants (2 alive, 2 dead)
- **THEN** each of the 4 Characters SHALL receive `25` experience

#### Scenario: Remainder is discarded
- **WHEN** total experience is `10` and the party has `3` participants
- **THEN** each Character SHALL receive `3` experience and the remainder `1` SHALL be discarded

### Requirement: Character.gain_experience accumulates EXP and triggers level-up
The system SHALL provide `Character.gain_experience(amount: int)` that accumulates experience and automatically triggers `level_up()` once for every level threshold crossed, consuming the accumulated experience accordingly.

#### Scenario: Sub-threshold gain only accumulates
- **WHEN** a level-1 Character with `0` accumulated EXP gains `100` and the threshold to reach level 2 is `1000`
- **THEN** the Character SHALL remain at level 1 and SHALL retain `100` EXP toward the next level

#### Scenario: Threshold-crossing gain triggers one level-up
- **WHEN** a level-1 Character with `900` accumulated EXP gains `200` and the threshold is `1000`
- **THEN** the Character SHALL become level 2

#### Scenario: Multi-level gain triggers multiple level-ups
- **WHEN** a level-1 Character gains an amount that exceeds two level thresholds simultaneously
- **THEN** `gain_experience` SHALL apply both level-ups in a single call, in order

### Requirement: Level-up increases max HP and, if magic-capable, max MP
The system SHALL, on each `level_up()`, increase `max_hp` by `job.hp_per_level + base_stats[&"VIT"] / 3` (integer division, minimum gain `1`) and SHALL increase `current_hp` by the same amount; if the job has `has_magic == true`, it SHALL also increase `max_mp` and `current_mp` by `job.mp_per_level`.

#### Scenario: HP growth uses VIT contribution
- **WHEN** a Character with `base_stats[&"VIT"] = 15` and `job.hp_per_level = 4` levels up
- **THEN** both `max_hp` and `current_hp` SHALL increase by `4 + 15 / 3 == 9`

#### Scenario: Minimum HP growth is 1
- **WHEN** the computed HP growth would be `0` or negative
- **THEN** the growth SHALL be exactly `1`

#### Scenario: MP growth only for magic-capable jobs
- **WHEN** a Mage (`has_magic == true`, `job.mp_per_level = 2`) levels up
- **THEN** both `max_mp` and `current_mp` SHALL increase by `2`
- **WHEN** a Fighter (`has_magic == false`) levels up
- **THEN** `max_mp` and `current_mp` SHALL remain unchanged

#### Scenario: Stats do not grow
- **WHEN** a Character levels up
- **THEN** `base_stats` (STR/INT/PIE/VIT/AGI/LUC) SHALL remain unchanged

### Requirement: EncounterOutcome carries gained experience
The system SHALL populate `EncounterOutcome.gained_experience` with the per-member experience that was distributed, so that UI can display the awarded amount without re-computing it.

#### Scenario: gained_experience matches per-member share
- **WHEN** a CLEARED battle awards `25` experience to each of 4 party members
- **THEN** `EncounterOutcome.gained_experience` SHALL equal `25`

#### Scenario: gained_experience is zero on non-CLEARED outcomes
- **WHEN** the outcome is `WIPED` or `ESCAPED`
- **THEN** `EncounterOutcome.gained_experience` SHALL equal `0`
