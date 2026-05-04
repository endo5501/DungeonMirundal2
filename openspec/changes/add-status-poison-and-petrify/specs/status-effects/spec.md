## MODIFIED Requirements

### Requirement: StatusData defines a status effect template

The system SHALL provide a `StatusData` Custom Resource that defines a status effect template. `StatusData` SHALL expose the following fields:

- `id: StringName` — unique identifier matching the `.tres` filename basename.
- `display_name: String` — Japanese display name shown in UI.
- `scope: int` — `StatusData.Scope`: `BATTLE_ONLY (0)` or `PERSISTENT (1)`.
- `prevents_action: bool`
- `randomizes_target: bool`
- `blocks_cast: bool`
- `hit_penalty: float`
- `default_duration: int` — turns granted at inflict for `BATTLE_ONLY`.
- `tick_in_battle: int` — flat HP damage at the head of each battle turn. `0` means no battle tick.
- `tick_in_dungeon: int` — flat HP damage at every dungeon step (used when `tick_in_dungeon_ratio == 0`). Only meaningful for `PERSISTENT`.
- `tick_in_dungeon_ratio: int` — when `> 0`, dungeon step damage SHALL equal `maxi(1, character.max_hp / tick_in_dungeon_ratio)` (integer division, minimum 1). When `> 0`, this value takes precedence over `tick_in_dungeon`.
- `cures_on_damage: bool`
- `cures_on_battle_end: bool`
- `resist_key: StringName`

#### Scenario: StatusData carries required fields including dungeon_ratio
- **WHEN** a StatusData resource is created
- **THEN** it SHALL expose all listed fields including `tick_in_dungeon_ratio`

#### Scenario: id matches filename
- **WHEN** `data/statuses/poison.tres` is loaded
- **THEN** the loaded StatusData's `id` SHALL equal `&"poison"`

#### Scenario: scope is one of the recognized values
- **WHEN** any StatusData file is loaded
- **THEN** `scope` SHALL be either `0 (BATTLE_ONLY)` or `1 (PERSISTENT)`

#### Scenario: Both tick fields default to zero
- **WHEN** a StatusData is created without overriding tick fields
- **THEN** `tick_in_battle == 0`, `tick_in_dungeon == 0`, `tick_in_dungeon_ratio == 0` (no tick at all)

### Requirement: StatusTickService applies dungeon ticks to a Character with HP floor

The system SHALL provide a static helper `StatusTickService.tick_character_step(character: Character, repo: StatusRepository) -> Dictionary` that:

1. Returns immediately if `character.is_dead()`.
2. Iterates `character.persistent_statuses`, looks up each in `repo`.
3. For each StatusData with `scope == PERSISTENT`, computes the requested damage:
   - If `tick_in_dungeon_ratio > 0`, `requested = maxi(1, character.max_hp / tick_in_dungeon_ratio)`.
   - Else if `tick_in_dungeon > 0`, `requested = tick_in_dungeon`.
   - Else: skip this status (no tick).
4. Applies `loss = mini(requested, max(0, character.current_hp - 1))` and decrements `current_hp` by that amount.
5. The character's HP SHALL NOT drop below `1` due to dungeon ticks.
6. Returns `{ "total_loss": int, "ticks": [{ "status_id": StringName, "amount": int }] }`.

#### Scenario: Ratio-based dungeon tick
- **WHEN** a character with `current_hp = 32`, `max_hp = 32` holds a PERSISTENT status with `tick_in_dungeon_ratio = 16` (and `tick_in_dungeon = 0`)
- **THEN** `tick_character_step` SHALL apply `loss = 32 / 16 = 2`, `current_hp` SHALL become `30`, and the result SHALL include the tick of amount 2

#### Scenario: Ratio with low max_hp floors at 1
- **WHEN** `max_hp = 10`, `current_hp = 10`, status `tick_in_dungeon_ratio = 16`
- **THEN** `requested = maxi(1, 10 / 16) = maxi(1, 0) = 1`, the loss SHALL be 1

#### Scenario: Ratio takes precedence over flat amount
- **WHEN** a status has both `tick_in_dungeon = 5` and `tick_in_dungeon_ratio = 16`, applied to a character with `max_hp = 32, current_hp = 32`
- **THEN** the loss SHALL be `2` (ratio wins) not `5`

#### Scenario: Both tick fields zero is a no-op
- **WHEN** a status has `tick_in_dungeon = 0` and `tick_in_dungeon_ratio = 0`
- **THEN** `tick_character_step` SHALL produce no entry for that status

#### Scenario: Dungeon tick floors at HP=1 when tick would kill
- **WHEN** a character with `current_hp = 2, max_hp = 32` holds poison with `tick_in_dungeon_ratio = 16` (requested loss 2)
- **THEN** the loss SHALL be capped at `1` (HP floor) and `current_hp` SHALL become `1`

#### Scenario: Dead character is skipped
- **WHEN** a character with `is_dead() == true` is passed to `tick_character_step`
- **THEN** no HP change SHALL occur and the result SHALL contain `total_loss == 0` with empty `ticks`

#### Scenario: BATTLE_ONLY statuses are ignored in dungeon ticks
- **WHEN** a character has `&"sleep"` (BATTLE_ONLY) listed in `persistent_statuses` somehow
- **THEN** `tick_character_step` SHALL ignore it (no damage applied)
