## MODIFIED Requirements

### Requirement: ResultPanel shows outcome and level-ups before resolving
The system SHALL, upon battle termination, display a ResultPanel before emitting `encounter_resolved`; the panel's content depends on the outcome.

#### Scenario: CLEARED shows gained experience, gold, and level-up notifications
- **WHEN** the battle ends with `CLEARED` and any Character leveled up
- **THEN** the ResultPanel SHALL display the per-member gained experience, the party-total gained gold, and a line for each Character whose level increased, including the new level

#### Scenario: CLEARED with no level-ups still shows experience and gold
- **WHEN** the battle ends with `CLEARED` and no Character leveled up
- **THEN** the ResultPanel SHALL still display the per-member gained experience and the party-total gained gold

#### Scenario: WIPED shows a defeat message
- **WHEN** the battle ends with `WIPED`
- **THEN** the ResultPanel SHALL display a defeat message and SHALL NOT display gained experience or gold

#### Scenario: ESCAPED shows an escape message
- **WHEN** the battle ends with `ESCAPED`
- **THEN** the ResultPanel SHALL display an escape confirmation message and SHALL NOT display gained experience or gold

#### Scenario: Confirm input resolves the encounter
- **WHEN** the user presses Enter/Space on the ResultPanel
- **THEN** CombatOverlay SHALL hide itself and SHALL emit `encounter_resolved` with the populated EncounterOutcome

## ADDED Requirements

### Requirement: CombatOverlay computes gained_gold from dead monsters on CLEARED
The system SHALL, on a CLEARED outcome, compute `gained_gold` as the sum over every dead MonsterCombatant of `rng.randi_range(monster.data.gold_min, monster.data.gold_max)`, using the same injected RandomNumberGenerator as the turn engine for determinism under a fixed seed.

#### Scenario: Gold drop sums per-monster rolls
- **WHEN** a CLEARED battle ends with one slime dead (`gold_min=1, gold_max=3`) and one goblin dead (`gold_min=5, gold_max=15`), under a fixed RNG seed producing rolls of `2` and `10` respectively
- **THEN** the EncounterOutcome's `gained_gold` SHALL equal `12`

#### Scenario: Gold drop is zero for WIPED
- **WHEN** a battle ends with `WIPED`
- **THEN** the EncounterOutcome's `gained_gold` SHALL equal `0`

#### Scenario: Gold drop is zero for ESCAPED
- **WHEN** a battle ends with `ESCAPED`
- **THEN** the EncounterOutcome's `gained_gold` SHALL equal `0`

#### Scenario: Gold is credited to party inventory on encounter_resolved
- **WHEN** `encounter_resolved(outcome)` is emitted with `outcome.result == CLEARED` and `outcome.gained_gold == 30`
- **THEN** the caller (main.gd or equivalent wiring) SHALL invoke `GameState.inventory.add_gold(30)` and subsequent `GameState.inventory.gold` SHALL reflect the addition
