## Purpose
エンカウント発生時に表示される UI オーバーレイの振る舞いを規定する。モンスター出現演出、先制判定結果、戦闘開始ボタンまでの遷移タイミングを対象とする。
## Requirements
### Requirement: EncounterOverlay presents a monster party and blocks dungeon input
The system SHALL provide an `EncounterOverlay` (CanvasLayer) that, when started with a MonsterParty, is displayed on top of the dungeon screen and consumes keyboard input until dismissed. A concrete implementation (`CombatOverlay`, ADDED by combat-system) SHALL extend `EncounterOverlay` and present a full Wizardry-style battle UI; the base stub (text-only confirmation) is retained only as a testing baseline for the contract.

#### Scenario: Overlay appears with monster names
- **WHEN** `EncounterOverlay.start_encounter(monster_party)` is called with a party of 2 slimes and 1 goblin
- **THEN** the overlay SHALL become visible and SHALL display the monster names (e.g., "スライム x2", "ゴブリン x1")

#### Scenario: Dungeon input is blocked while overlay is visible
- **WHEN** the EncounterOverlay is visible
- **THEN** keyboard events for movement SHALL NOT reach the DungeonScreen

#### Scenario: Overlay is hidden before start
- **WHEN** an EncounterOverlay is instantiated but `start_encounter` has not been called
- **THEN** the overlay SHALL NOT be visible

#### Scenario: Combat overlay subclass replaces stub in production wiring
- **WHEN** the application is running in production wiring
- **THEN** the overlay instance received by `EncounterCoordinator` SHALL be a `CombatOverlay` (a subclass of `EncounterOverlay`), not the raw stub

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

### Requirement: EncounterOverlay は ui_accept action で確認入力を受ける
SHALL: `EncounterOverlay._unhandled_input` は `is_action_pressed("ui_accept")` でモンスター遭遇画面の確認操作を受け付ける。`event.keycode == KEY_*` の直接マッチは使わない。

#### Scenario: ui_accept で遭遇確認が完了する
- **WHEN** encounter overlay が表示されている状態で `is_action_pressed("ui_accept")` がディスパッチされる
- **THEN** `encounter_resolved` シグナルが発行され、戦闘 phase または通常移動に遷移する

