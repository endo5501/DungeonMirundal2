## MODIFIED Requirements

### Requirement: PartyMemberPanel dims the panel for incapacitated members

When the bound `Character` is incapacitated, `PartyMemberPanel` SHALL render a semi-transparent dark overlay covering the entire panel area (drawn after all other content) so that the panel appears visually "dimmed". A character is incapacitated if any of the following hold:

- (combat mode, i.e. `_combat_actor != null`) `_combat_displayed_hp <= 0`, OR
- (non-combat mode, i.e. `_combat_actor == null`) `current_hp <= 0`, OR
- `persistent_statuses` contains `&"sleep"`, OR
- `persistent_statuses` contains `&"paralysis"`, OR
- `persistent_statuses` contains `&"petrify"`

`confusion`, `silence`, `blind`, and `poison` SHALL NOT trigger the dim overlay (the character is still able to act).

In combat mode, the HP-zero condition SHALL be evaluated against `_combat_displayed_hp` rather than the live `Character.current_hp`, so that the dim overlay appears in the same flush step as the corresponding death log line.

#### Scenario: HP zero dims the panel out of combat
- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 0` and is NOT bound to a CombatActor
- **THEN** a semi-transparent dark overlay SHALL be drawn covering the panel area

#### Scenario: HP zero in combat dims based on displayed HP
- **WHEN** a `PartyMemberPanel` is bound to a CombatActor whose live `current_hp = 0` but `_combat_displayed_hp = 5` (no flush yet)
- **THEN** the dim overlay SHALL NOT be drawn
- **AND** when the panel later receives `set_combat_displayed_hp(0)` and re-draws, the dim overlay SHALL be drawn

#### Scenario: Sleep dims the panel
- **WHEN** a `PartyMemberPanel` is bound to a Character with `persistent_statuses = [&"sleep"]` and `current_hp > 0`
- **THEN** the dim overlay SHALL be drawn

#### Scenario: Paralysis dims the panel
- **WHEN** a `PartyMemberPanel` is bound to a Character with `persistent_statuses = [&"paralysis"]` and `current_hp > 0`
- **THEN** the dim overlay SHALL be drawn

#### Scenario: Petrify dims the panel
- **WHEN** a `PartyMemberPanel` is bound to a Character with `persistent_statuses = [&"petrify"]` and `current_hp > 0`
- **THEN** the dim overlay SHALL be drawn

#### Scenario: Poison alone does not dim
- **WHEN** a `PartyMemberPanel` is bound to a Character with `persistent_statuses = [&"poison"]` and `current_hp > 0`
- **THEN** the dim overlay SHALL NOT be drawn

#### Scenario: Confusion alone does not dim
- **WHEN** a `PartyMemberPanel` is bound to a Character with `persistent_statuses = [&"confusion"]` and `current_hp > 0`
- **THEN** the dim overlay SHALL NOT be drawn

#### Scenario: Recovery removes the dim
- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 0` (out of combat), then the Character's `current_hp` is assigned a positive value
- **THEN** the panel SHALL re-render AND the dim overlay SHALL no longer be drawn

### Requirement: PartyMemberPanel renders HP and MP as bars with numeric values

`PartyMemberPanel` SHALL render HP and MP using color-coded bars plus numeric current/max values. HP SHALL use the existing HP color family and MP SHALL use the existing MP color family. Bar fill ratios SHALL be computed from `current / max` and clamped to a safe range.

When the panel is bound to a `CombatActor` (`_combat_actor != null`), the `current` value used for HP rendering SHALL be `_combat_displayed_hp` and the `current` value used for MP rendering SHALL be `_combat_displayed_mp`. When not bound to a `CombatActor`, the `current` values SHALL come from the live `_data.current_hp` / `_data.current_mp` as before.

#### Scenario: HP bar reflects current HP ratio out of combat
- **WHEN** a member out of combat has `current_hp = 8` and `max_hp = 10`
- **THEN** the HP bar SHALL render approximately 80 percent filled and the numeric HP value SHALL display `8 / 10` or equivalent text

#### Scenario: MP bar reflects current MP ratio out of combat
- **WHEN** a member out of combat has `current_mp = 5` and `max_mp = 20`
- **THEN** the MP bar SHALL render approximately 25 percent filled and the numeric MP value SHALL display `5 / 20` or equivalent text

#### Scenario: HP bar in combat reflects displayed HP, not live HP
- **WHEN** a panel is bound to a CombatActor whose live `current_hp = 3`, but `_combat_displayed_hp = 8` and `max_hp = 10`
- **THEN** the HP bar SHALL render approximately 80 percent filled and the numeric HP value SHALL display `8 / 10` or equivalent text

#### Scenario: MP bar in combat reflects displayed MP, not live MP
- **WHEN** a panel is bound to a CombatActor whose live `current_mp = 1`, but `_combat_displayed_mp = 5` and `max_mp = 20`
- **THEN** the MP bar SHALL render approximately 25 percent filled and the numeric MP value SHALL display `5 / 20` or equivalent text

#### Scenario: Zero maximum value is safe
- **WHEN** a member has `max_mp = 0`
- **THEN** the MP bar ratio calculation SHALL NOT divide by zero and SHALL still render a numeric MP value

## ADDED Requirements

### Requirement: PartyMemberPanel maintains combat-displayed HP and MP that lag behind live values

`PartyMemberPanel` SHALL maintain integer fields `_combat_displayed_hp` and `_combat_displayed_mp` that represent the values currently shown on the HP and MP bars during combat. The sentinel value `-1` indicates that the panel is not in combat mode.

`bind_combat_actor(actor)` SHALL set `_combat_displayed_hp = actor.current_hp` and `_combat_displayed_mp = actor.current_mp` when `actor` is non-null. `bind_combat_actor(null)` SHALL reset both to `-1`.

`PartyMemberPanel` SHALL provide three public methods:
- `apply_combat_hp_delta(delta: int)`: assigns `_combat_displayed_hp = clampi(_combat_displayed_hp + delta, 0, max_hp)` and queues a redraw.
- `apply_combat_mp_delta(delta: int)`: assigns `_combat_displayed_mp = clampi(_combat_displayed_mp + delta, 0, max_mp)` and queues a redraw.
- `set_combat_displayed_hp(value: int)`: assigns `_combat_displayed_hp = clampi(value, 0, max_hp)` and queues a redraw.

While in combat mode, `_on_character_hp_changed` and `_on_character_mp_changed` SHALL still refresh `_data` from the live Character (so non-bar fields such as level/name stay current) and SHALL still call `queue_redraw()`, but they SHALL NOT modify `_combat_displayed_hp` / `_combat_displayed_mp`.

#### Scenario: bind_combat_actor latches displayed values from live actor
- **WHEN** a panel is bound to a CombatActor with `current_hp = 12`, `current_mp = 5`
- **THEN** `_combat_displayed_hp` SHALL equal `12` and `_combat_displayed_mp` SHALL equal `5`

#### Scenario: bind_combat_actor(null) resets displayed values to -1
- **WHEN** a panel is currently in combat mode and `bind_combat_actor(null)` is called
- **THEN** `_combat_displayed_hp` SHALL equal `-1` and `_combat_displayed_mp` SHALL equal `-1`

#### Scenario: apply_combat_hp_delta clamps to 0 and max_hp
- **WHEN** a panel has `_combat_displayed_hp = 3` and `max_hp = 10`, and `apply_combat_hp_delta(-7)` is called
- **THEN** `_combat_displayed_hp` SHALL equal `0` (not negative)
- **WHEN** the same panel then receives `apply_combat_hp_delta(+15)`
- **THEN** `_combat_displayed_hp` SHALL equal `10` (clamped to max_hp)

#### Scenario: apply_combat_mp_delta clamps to 0 and max_mp
- **WHEN** a panel has `_combat_displayed_mp = 4` and `max_mp = 10`, and `apply_combat_mp_delta(-6)` is called
- **THEN** `_combat_displayed_mp` SHALL equal `0`

#### Scenario: set_combat_displayed_hp forces an exact value
- **WHEN** a panel has `_combat_displayed_hp = 5` and `set_combat_displayed_hp(0)` is called
- **THEN** `_combat_displayed_hp` SHALL equal `0`

#### Scenario: live hp_changed during combat does not move displayed HP
- **WHEN** a panel is bound to a CombatActor with `_combat_displayed_hp = 10`, and the live `Character.current_hp` is then assigned `2` (e.g. by mid-resolve mutation)
- **THEN** `_combat_displayed_hp` SHALL still equal `10`
- **AND** `_data.current_hp` SHALL be refreshed to reflect the live value
- **AND** `queue_redraw()` SHALL still be called

#### Scenario: After combat ends, hp_changed drives the bar again
- **WHEN** `bind_combat_actor(null)` resets the panel to non-combat mode, then the live `Character.current_hp` changes
- **THEN** the HP bar SHALL render the new live value (existing non-combat behavior is preserved)
