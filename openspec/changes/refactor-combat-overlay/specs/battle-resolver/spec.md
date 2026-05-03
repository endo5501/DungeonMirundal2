## ADDED Requirements

### Requirement: BattleResolver computes battle rewards as a value object
SHALL: `BattleResolver` (RefCounted) SHALL provide a static method `resolve_rewards(turn_engine: TurnEngine, rng: RandomNumberGenerator) -> BattleSummary` that computes experience share, gold drop, and per-character level-up information for a finished battle. The method SHALL return a `BattleSummary` value object containing `gained_experience: int`, `gained_gold: int`, `level_ups: Array[Dictionary]`. When the battle did not result in `EncounterOutcome.Result.CLEARED`, the method SHALL return `BattleSummary.empty()`.

#### Scenario: Cleared battle yields experience and gold
- **WHEN** `resolve_rewards(engine, rng)` is called on a TurnEngine whose `outcome().result == CLEARED` with 1 dead monster of type Slime (gold_min=10, gold_max=20)
- **THEN** the returned `BattleSummary.gained_experience` SHALL be > 0 and `gained_gold` SHALL be in [10, 20]

#### Scenario: Level-up is detected
- **WHEN** a participating character's level rises during `ExperienceCalculator.award`
- **THEN** the BattleSummary's `level_ups` array SHALL contain `{name: "<character_name>", new_level: <new_level>}`

#### Scenario: Escaped battle yields no rewards
- **WHEN** `resolve_rewards(engine, rng)` is called on a TurnEngine whose `outcome().result == ESCAPED`
- **THEN** the returned `BattleSummary` SHALL be `empty()` (zero experience, zero gold, empty level_ups)

#### Scenario: Defeated battle yields no rewards
- **WHEN** `resolve_rewards(engine, rng)` is called on a TurnEngine whose `outcome().result == DEFEATED`
- **THEN** the returned `BattleSummary` SHALL be `empty()`

#### Scenario: BattleSummary is independent of CombatOverlay
- **WHEN** unit tests construct a TurnEngine without instantiating CombatOverlay
- **THEN** `BattleResolver.resolve_rewards(engine, rng)` SHALL succeed and return correct values
