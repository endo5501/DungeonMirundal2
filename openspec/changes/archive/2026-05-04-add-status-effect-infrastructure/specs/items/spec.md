## ADDED Requirements

### Requirement: CureStatusItemEffect cures a single status id

The system SHALL provide a `CureStatusItemEffect` Resource (extends `ItemEffect`) with `@export status_id: StringName`. Its `apply(targets, ctx) -> ItemEffectResult` SHALL, for each target whose `is_alive()` is true, call:

- For `PartyCombatant` targets: `target.statuses.cure(status_id)`.
- For `Character` targets (out-of-battle context): if `character.persistent_statuses` contains `status_id`, remove it; otherwise no-op.

The result SHALL succeed when at least one target was actually cured. The result message SHALL describe the cure outcome (e.g. "Alice の毒を治療した").

#### Scenario: CureStatusItemEffect removes from a CombatActor's StatusTrack
- **WHEN** a CureStatusItemEffect with `status_id = &"poison"` is applied to a PartyCombatant whose `statuses.has(&"poison") == true`
- **THEN** the effect SHALL succeed and `statuses.has(&"poison")` SHALL be `false`

#### Scenario: CureStatusItemEffect removes from Character.persistent_statuses out of battle
- **WHEN** a CureStatusItemEffect is used on a Character whose `persistent_statuses` contains the id
- **THEN** the id SHALL be removed from `persistent_statuses`

#### Scenario: CureStatusItemEffect on a clean target fails
- **WHEN** the effect is applied to a target that does not hold the status
- **THEN** the result SHALL have `success == false`

### Requirement: CureAllStatusItemEffect cures every status of a chosen scope

The system SHALL provide a `CureAllStatusItemEffect` Resource (extends `ItemEffect`) with `@export scope: int` (matching `StatusData.Scope`: `BATTLE_ONLY = 0`, `PERSISTENT = 1`, with sentinel `2 = ALL` meaning both). For each target, the effect SHALL:

- For `PartyCombatant` targets: query the StatusRepository, iterate `statuses.active_ids()`, and `cure(id)` every entry whose StatusData scope matches the configured scope (or all when `scope == 2`).
- For `Character` targets out of battle: filter `persistent_statuses` similarly. (BATTLE_ONLY scope SHALL be a no-op out of battle since BATTLE_ONLY ids are never persisted.)

The result SHALL succeed when at least one target had at least one entry cured.

#### Scenario: ALL scope removes everything
- **WHEN** a CureAllStatusItemEffect with `scope = 2 (ALL)` is applied to a target holding `&"sleep"` and `&"poison"`
- **THEN** both ids SHALL be cured and the result SHALL succeed

#### Scenario: PERSISTENT scope only touches persistent statuses
- **WHEN** a CureAllStatusItemEffect with `scope = PERSISTENT` is applied to a target holding `&"sleep"` (BATTLE_ONLY) and `&"poison"` (PERSISTENT)
- **THEN** `&"poison"` SHALL be cured and `&"sleep"` SHALL remain active
