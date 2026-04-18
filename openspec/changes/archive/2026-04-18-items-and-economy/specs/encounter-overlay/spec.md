## MODIFIED Requirements

### Requirement: EncounterOutcome is populated with battle results
The system SHALL provide an `EncounterOutcome` (RefCounted) with:
- `result: { ESCAPED, CLEARED, WIPED }`
- `gained_experience: int` (per-member distributed experience; `0` unless `result == CLEARED`)
- `gained_gold: int` (party-total gold awarded; `0` unless `result == CLEARED`)
- `drops: Array` (reserved for future drop changes; SHALL always be an empty array until a later change populates it)

`EncounterOutcome` SHALL be populated by the concrete overlay implementation to reflect the actual battle outcome (stub: always `CLEARED` with `gained_experience = 0` and `gained_gold = 0`; combat: real values).

#### Scenario: Stub sets result to CLEARED with zero experience and zero gold
- **WHEN** the stub overlay constructs an EncounterOutcome
- **THEN** the outcome SHALL have `result == CLEARED` and `gained_experience == 0` and `gained_gold == 0` and `drops.is_empty() == true`

#### Scenario: CombatOverlay populates CLEARED outcome with experience and gold
- **WHEN** the `CombatOverlay` ends a battle with all monsters dead, distributes `25` experience per member, and the monsters yielded a total of `30` gold
- **THEN** the emitted EncounterOutcome SHALL have `result == CLEARED`, `gained_experience == 25`, and `gained_gold == 30`

#### Scenario: CombatOverlay populates WIPED outcome with zero experience and zero gold
- **WHEN** the `CombatOverlay` ends a battle with all party members dead
- **THEN** the emitted EncounterOutcome SHALL have `result == WIPED`, `gained_experience == 0`, and `gained_gold == 0`

#### Scenario: CombatOverlay populates ESCAPED outcome with zero experience and zero gold
- **WHEN** the `CombatOverlay` ends a battle with a successful escape
- **THEN** the emitted EncounterOutcome SHALL have `result == ESCAPED`, `gained_experience == 0`, and `gained_gold == 0`

#### Scenario: drops is always empty in items-and-economy MVP
- **WHEN** any EncounterOutcome is emitted during the items-and-economy MVP scope
- **THEN** `drops` SHALL be an empty array (drop/chest systems are a later change)
