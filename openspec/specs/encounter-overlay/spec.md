## Purpose
エンカウント発生時に表示される UI オーバーレイの振る舞いを規定する。モンスター出現演出、先制判定結果、戦闘開始ボタンまでの遷移タイミングを対象とする。
## Requirements
### Requirement: EncounterOverlay presents a monster party and blocks dungeon input
`EncounterOverlay` SHALL be an abstract base class for encounter UIs. It SHALL declare the `encounter_resolved(outcome: EncounterOutcome)` signal and the abstract `start_encounter(monster_party)` API, but SHALL NOT build any UI itself. Concrete subclasses (`SimpleEncounterOverlay` for text-only encounters and `CombatOverlay` for the full combat UI) SHALL present the monster party and SHALL consume input until dismissed.

#### Scenario: Direct base instantiation rejects start_encounter
- **WHEN** `EncounterOverlay.new()` is instantiated and `start_encounter` is called on it directly
- **THEN** the base class SHALL emit an error (`push_error("EncounterOverlay.start_encounter must be overridden")` or equivalent warning)

#### Scenario: Subclasses provide the UI
- **WHEN** `SimpleEncounterOverlay` or `CombatOverlay` is instantiated and `_ready()` runs
- **THEN** each subclass SHALL build its own UI; the base class SHALL NOT add any UI children

#### Scenario: encounter_resolved is declared on the base
- **WHEN** the `EncounterOverlay` class is inspected
- **THEN** `encounter_resolved(outcome: EncounterOutcome)` SHALL be declared on the base and available to all subclasses

### Requirement: EncounterOverlay resolves via signal contract
The system SHALL ensure that `EncounterOverlay` emits `encounter_resolved(outcome: EncounterOutcome)` exactly once when the overlay is dismissed, regardless of whether the concrete implementation is the stub or the full combat UI. The signal contract and function signature SHALL NOT change.

#### Scenario: Confirm input dismisses the stub overlay
- **WHEN** the stub overlay is visible and the user presses the confirm key (Enter/Space)
- **THEN** the overlay SHALL hide itself and SHALL emit `encounter_resolved` exactly once

#### Scenario: Dungeon input resumes after resolution
- **WHEN** `encounter_resolved` has been emitted
- **THEN** subsequent keyboard events SHALL reach the DungeonScreen again

#### Scenario: Combat overlay emits resolved only after the result panel confirm
- **WHEN** the `CombatOverlay` subclass reaches a terminal battle state
- **THEN** it SHALL display a ResultPanel first, and SHALL emit `encounter_resolved` exactly once upon the user's confirm input on that panel

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

