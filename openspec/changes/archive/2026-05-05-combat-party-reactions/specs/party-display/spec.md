## ADDED Requirements

### Requirement: PartyMemberPanel shakes on damage via hp_changed delta

`PartyMemberPanel` SHALL trigger a horizontal shake animation when its bound `Character`'s HP decreases (i.e., the new `current_hp` is less than the previously observed `current_hp`). The shake SHALL displace the panel's `position.x` by approximately ±4 pixels with a total duration of approximately 0.2 seconds and SHALL restore the panel to its layout position when complete. If a previous animation is still active, it SHALL be killed before the new shake starts.

#### Scenario: HP decrease starts a shake

- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 20`, and the Character's `current_hp` is then assigned `15`
- **THEN** the panel SHALL initiate a shake animation (a Tween acting on `position.x`)

#### Scenario: HP increase does not start a shake

- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 10`, and the Character's `current_hp` is then assigned `15`
- **THEN** the panel SHALL NOT initiate a shake animation

#### Scenario: Consecutive damage overrides the previous shake

- **WHEN** a `PartyMemberPanel` has an active shake Tween from a prior damage, and the bound Character's `current_hp` decreases again
- **THEN** the previous Tween SHALL be killed and a new shake Tween SHALL be created

#### Scenario: Shake restores the panel position

- **WHEN** a shake animation completes (or is killed)
- **THEN** the panel's `position.x` SHALL be restored to the layout x value assigned by `PartyDisplay`

### Requirement: PartyMemberPanel flashes green on heal via hp_changed delta

`PartyMemberPanel` SHALL trigger a green flash overlay when its bound `Character`'s HP increases. The flash SHALL be a semi-transparent green overlay drawn over the entire panel, with an alpha that starts around 0.5 and fades to 0 over approximately 0.3 seconds. If a previous flash is still active, it SHALL be killed before the new flash starts.

#### Scenario: HP increase starts a flash

- **WHEN** a `PartyMemberPanel` is bound to a Character with `current_hp = 5`, and the Character's `current_hp` is then assigned `12`
- **THEN** the panel SHALL initiate a heal flash animation (a Tween acting on `_flash_alpha`)

#### Scenario: Heal flash overlay is drawn while alpha > 0

- **WHEN** a `PartyMemberPanel` has `_flash_alpha > 0` and `_draw()` runs
- **THEN** a semi-transparent green rectangle covering the panel area SHALL be drawn

#### Scenario: Heal flash hidden when alpha is 0

- **WHEN** the heal flash Tween completes and `_flash_alpha = 0`
- **THEN** no green overlay SHALL be drawn on the next `_draw()` call

### Requirement: PartyMemberPanel lifts on actor_action_started

`PartyMemberPanel` SHALL provide a method `play_lift_animation()` that displaces the panel upward by approximately 8 pixels for 0.15 seconds and returns it to the layout position over another 0.15 seconds (total 0.3 seconds). The HUD layer (PartyHud) SHALL invoke this method when the `actor_action_started` signal fires from the attached `TurnEngine` for an actor whose Character matches the panel's bound Character. If a previous lift is still active, it SHALL be killed before starting a new lift.

#### Scenario: actor_action_started triggers panel lift

- **WHEN** the attached `TurnEngine` emits `actor_action_started(actor, &"attack")` and `actor.character` matches `PartyMemberPanel._character`
- **THEN** the panel's `play_lift_animation()` SHALL be invoked AND a Tween acting on `position.y` SHALL be created

#### Scenario: Lift kind is uniform regardless of action_kind

- **WHEN** `actor_action_started` fires with any of `&"attack"`, `&"defend"`, `&"cast"`, `&"item"`, `&"escape"`
- **THEN** the same lift animation SHALL be played (no kind-specific differentiation in this version)

#### Scenario: Lift restores y position

- **WHEN** a lift animation completes (or is killed)
- **THEN** the panel's `position.y` SHALL be restored to the layout y value assigned by `PartyDisplay`

### Requirement: PartyMemberPanel fades on actor_died

`PartyMemberPanel` SHALL provide a method `play_die_animation()` that fades `modulate.a` from `1.0` to `0.7` over approximately 0.4 seconds. The HUD layer SHALL invoke this method when `actor_died` fires for an actor whose Character matches the panel's bound Character. The fade SHALL be removed (modulate.a restored to `1.0`) automatically when the bound Character's `current_hp` becomes positive again (revival).

#### Scenario: actor_died fades the panel

- **WHEN** the attached `TurnEngine` emits `actor_died(actor)` and `actor.character` matches `PartyMemberPanel._character`
- **THEN** the panel's `modulate.a` SHALL transition toward `0.7`

#### Scenario: Revival restores modulate

- **WHEN** the bound Character's `current_hp` was `0` (panel faded), and the Character's `current_hp` is later assigned a positive value
- **THEN** the panel's `modulate.a` SHALL be set back to `1.0`

### Requirement: PartyMemberPanel renders stat modifier icons during combat

When `PartyMemberPanel` has been bound to a `CombatActor` (via `bind_combat_actor()`), it SHALL render an icon for each entry in `combat_actor.stat_modifier_stack` (positive deltas as buffs, negative deltas as debuffs). The icons SHALL use a colored rectangle plus a 2- to 3-character label such as `A+`, `A-`, `D+`, `D-`. The icon row SHALL be drawn within the panel and MUST NOT collide with the existing name/LV/HP/MP text or the persistent_status icon row.

When `PartyMemberPanel` has not been bound to a `CombatActor` (outside combat), no stat modifier icons SHALL be rendered.

#### Scenario: Single buff renders an icon

- **WHEN** a `PartyMemberPanel` is bound to a `CombatActor` whose `stat_modifier_stack` contains one entry `(stat = &"attack", delta = +2, duration = 3)` and `_draw()` runs
- **THEN** at least one stat modifier icon (e.g., a green-tinted rectangle with label `A+`) SHALL be drawn

#### Scenario: Single debuff renders an icon

- **WHEN** the stack contains one entry `(stat = &"defense", delta = -1, duration = 2)`
- **THEN** at least one stat modifier icon (e.g., a red-tinted rectangle with label `D-`) SHALL be drawn

#### Scenario: Empty stack renders no icons

- **WHEN** the bound CombatActor's `stat_modifier_stack.is_empty() == true`
- **THEN** no stat modifier icon SHALL be drawn

#### Scenario: Without CombatActor binding, no icons

- **WHEN** a `PartyMemberPanel` has not been bound to a `CombatActor` (only to a `Character`)
- **THEN** no stat modifier icon SHALL be drawn even if persistent statuses exist

#### Scenario: Stat modifiers update on signal

- **WHEN** a `PartyMemberPanel` is bound to a `CombatActor` and the actor's `stat_modifiers_changed` signal fires
- **THEN** the panel SHALL `queue_redraw()` so the next frame reflects the updated stack
