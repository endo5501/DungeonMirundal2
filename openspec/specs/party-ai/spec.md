# party-ai Specification

## Purpose
TBD - created by archiving change add-combat-expedition-simulator. Update Purpose after archive.
## Requirements
### Requirement: PartyAi selects a command for each living party member
`PartyAi` SHALL provide a stateless `choose()` entry point that, given a `PartyCombatant`, a context (party, monsters, spell repository, turn engine), an AI config, and an RNG, returns exactly one command (`AttackCommand`, `CastCommand`, or `DefendCommand`) without mutating any combat state.

#### Scenario: Front-line fighter attacks a living enemy
- **WHEN** a party member with no spell school and at least one reachable living enemy is evaluated
- **THEN** `choose()` returns an `AttackCommand` targeting a living enemy

#### Scenario: No reachable enemy falls back to defend
- **WHEN** a MELEE party member has no reachable living enemy (e.g. only BACK-row enemies remain behind a living FRONT row)
- **THEN** `choose()` returns a `DefendCommand`

### Requirement: Priest-school members prioritize healing below the HP threshold
When a priest-school member is evaluated and any living ally's HP ratio is at or below `heal_hp_threshold`, and the member has enough MP for at least one healing spell, `choose()` SHALL return a `CastCommand` for a healing spell targeting the living ally with the lowest HP ratio.

#### Scenario: Ally below threshold triggers heal
- **WHEN** `heal_hp_threshold` is 0.6 and an ally is at 50% HP and the priest has MP for `heal`
- **THEN** `choose()` returns a `CastCommand` with a healing spell targeting that ally

#### Scenario: All allies above threshold means no heal
- **WHEN** every living ally is above `heal_hp_threshold`
- **THEN** the priest-school member does not return a healing `CastCommand` and instead follows the attack rules

#### Scenario: Insufficient MP skips healing
- **WHEN** an ally is below the threshold but the priest lacks MP for every known healing spell
- **THEN** the member follows the attack rules instead of returning a healing `CastCommand`

### Requirement: Healing spell choice minimizes overheal
When multiple healing spells are affordable, `PartyAi` SHALL choose the spell whose expected heal amount most closely covers the target's missing HP without unnecessary excess (smallest sufficient spell, or the largest available when none is sufficient).

#### Scenario: Small deficit picks the cheap spell
- **WHEN** the target is missing 8 HP and both `heal` (expected ~10) and `heala` (expected ~30) are affordable
- **THEN** `choose()` selects `heal`

### Requirement: Mage-school members cast attack magic only when the MP-conservation knobs allow
A mage-school member SHALL return an attack `CastCommand` only when it has enough MP for the spell AND at least one knob condition holds: the number of living enemies is >= `attack_magic_min_enemies`, or `attack_magic_min_tier` > 0 and the maximum `MonsterData.tier` among living enemies is >= `attack_magic_min_tier`. Otherwise the member follows the physical attack rules.

#### Scenario: Enough enemies triggers attack magic
- **WHEN** `attack_magic_min_enemies` is 2 and three enemies are alive and the mage has MP for an attack spell
- **THEN** `choose()` returns an attack `CastCommand`

#### Scenario: Single weak enemy conserves MP
- **WHEN** `attack_magic_min_enemies` is 2, `attack_magic_min_tier` is 0, and only one enemy is alive
- **THEN** `choose()` returns an `AttackCommand` (or `DefendCommand` if unreachable), not a `CastCommand`

#### Scenario: High-tier enemy overrides the enemy-count condition
- **WHEN** `attack_magic_min_tier` is 3 and a single tier-4 enemy is alive and the mage has MP
- **THEN** `choose()` returns an attack `CastCommand`

### Requirement: Attack spell targeting prefers groups when multiple enemies are alive
When casting attack magic, `PartyAi` SHALL prefer an `ENEMY_GROUP` spell if one is known and affordable and two or more enemies are alive; otherwise it SHALL use an `ENEMY_ONE` spell targeting a living enemy.

#### Scenario: Group spell against a group
- **WHEN** the mage knows both a group attack spell and a single-target attack spell with sufficient MP and three enemies are alive
- **THEN** the returned `CastCommand` uses the group spell

#### Scenario: Single-target spell against one enemy
- **WHEN** only one enemy is alive and the tier knob permits casting
- **THEN** the returned `CastCommand` uses a single-target attack spell aimed at that enemy

### Requirement: AI knobs are provided via a config object with defaults
`PartyAiConfig` SHALL expose `heal_hp_threshold` (default 0.6), `attack_magic_min_enemies` (default 2), and `attack_magic_min_tier` (default 0, meaning disabled), and `PartyAi.choose()` SHALL honor the values passed in rather than hardcoding behavior.

#### Scenario: Raising the heal threshold changes behavior
- **WHEN** an ally is at 70% HP and `heal_hp_threshold` is raised from 0.6 to 0.8
- **THEN** the priest-school member returns a healing `CastCommand` where it previously followed attack rules

