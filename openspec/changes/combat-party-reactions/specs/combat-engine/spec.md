## ADDED Requirements

### Requirement: TurnEngine emits actor_action_started during resolution

`TurnEngine` SHALL define a signal `actor_action_started(actor: CombatActor, action_kind: StringName)` and SHALL emit it once for each actor immediately before that actor's command resolution begins, while the engine is in the `RESOLVING` state. The `action_kind` SHALL be one of: `&"attack"`, `&"defend"`, `&"cast"`, `&"item"`, `&"escape"`.

#### Scenario: Attack command emits actor_action_started with kind "attack"

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant has submitted an `Attack` command
- **THEN** the signal `actor_action_started` SHALL fire with `(actor, &"attack")` for that PartyCombatant before any damage is computed

#### Scenario: Defend command emits actor_action_started with kind "defend"

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant has submitted a `Defend` command
- **THEN** the signal `actor_action_started` SHALL fire with `(actor, &"defend")` for that PartyCombatant

#### Scenario: Cast command emits actor_action_started with kind "cast"

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant has submitted a `Cast` command
- **THEN** the signal `actor_action_started` SHALL fire with `(actor, &"cast")` for that PartyCombatant before MP is spent

#### Scenario: Item command emits actor_action_started with kind "item"

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant has submitted an `Item` command
- **THEN** the signal `actor_action_started` SHALL fire with `(actor, &"item")` for that PartyCombatant

#### Scenario: Escape command emits actor_action_started with kind "escape"

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant has submitted an `Escape` command
- **THEN** the signal `actor_action_started` SHALL fire with `(actor, &"escape")` for that PartyCombatant

#### Scenario: Dead actors are not signaled

- **WHEN** `resolve_turn(rng)` is called and a PartyCombatant whose `is_alive() == false` would have a command in `_pending_commands`
- **THEN** `actor_action_started` SHALL NOT fire for that PartyCombatant

### Requirement: TurnEngine emits actor_dealt_damage when a target takes damage

`TurnEngine` SHALL define a signal `actor_dealt_damage(target: CombatActor, amount: int, source: CombatActor)` and SHALL emit it whenever a `take_damage` call within `resolve_turn(rng)` actually reduces a target's HP. The signal SHALL fire once per target per damage application. The `amount` SHALL be the actual HP reduction applied to the target (after defense halving etc.).

#### Scenario: Attack hit emits actor_dealt_damage

- **WHEN** an attack from actor A hits actor B for 5 HP and B's HP is reduced from 10 to 5
- **THEN** `actor_dealt_damage` SHALL fire once with `(B, 5, A)`

#### Scenario: Attack miss does not emit actor_dealt_damage

- **WHEN** an attack from actor A misses actor B
- **THEN** `actor_dealt_damage` SHALL NOT fire for that miss

#### Scenario: Defend halving reduces the emitted amount

- **WHEN** an actor B is defending and takes a hit that would deal 8 damage at full, but actually applies 4
- **THEN** `actor_dealt_damage` SHALL fire with `amount = 4`

### Requirement: TurnEngine emits actor_healed when a target receives healing

`TurnEngine` SHALL define a signal `actor_healed(target: CombatActor, amount: int, source: CombatActor)` and SHALL emit it whenever a heal effect within `resolve_turn(rng)` actually increases a target's HP. The signal SHALL fire once per target per heal application. The `amount` SHALL be the actual HP gain applied (capped at `max_hp - prev_hp`).

#### Scenario: Heal spell on a damaged target emits actor_healed

- **WHEN** caster A casts a healing spell on target B with `current_hp = 5`, `max_hp = 20`, restoring 7 HP, and B's HP becomes 12
- **THEN** `actor_healed` SHALL fire once with `(B, 7, A)`

#### Scenario: Heal capped at max_hp emits actual delta

- **WHEN** caster A casts heal on target B with `current_hp = 18`, `max_hp = 20`, restoring 5 HP nominally, but actual gain is 2 (capped)
- **THEN** `actor_healed` SHALL fire with `amount = 2`

#### Scenario: Heal on a target already at max does not emit

- **WHEN** caster A casts heal on target B with `current_hp = 20` and `max_hp = 20` (no actual gain)
- **THEN** `actor_healed` SHALL NOT fire

### Requirement: TurnEngine emits actor_died when an actor's HP reaches zero

`TurnEngine` SHALL define a signal `actor_died(actor: CombatActor)` and SHALL emit it once when an actor's `is_alive()` transitions from `true` to `false` during `resolve_turn(rng)`, regardless of cause (damage, status tick, etc.).

#### Scenario: Damage that kills emits actor_died

- **WHEN** a hit reduces target B's HP from 3 to 0
- **THEN** `actor_died` SHALL fire once with `(B,)` after `actor_dealt_damage` for the same hit

#### Scenario: Status tick that kills emits actor_died

- **WHEN** a poison battle tick reduces target B's HP from 1 to 0
- **THEN** `actor_died` SHALL fire once with `(B,)`

#### Scenario: Already-dead actors do not emit actor_died

- **WHEN** an actor is already dead at the start of `resolve_turn(rng)` and remains dead
- **THEN** `actor_died` SHALL NOT fire for that actor in this turn

### Requirement: TurnEngine emits actor_status_inflicted when a new status is applied

`TurnEngine` SHALL define a signal `actor_status_inflicted(actor: CombatActor, status_id: StringName)` and SHALL emit it whenever a status effect is applied to an actor that did NOT already have that status active during `resolve_turn(rng)`. Re-applying an already-active status SHALL NOT emit.

#### Scenario: Sleep inflicted on a non-sleeping actor

- **WHEN** a sleep-inducing spell hits actor B who has no sleep status, and sleep is applied
- **THEN** `actor_status_inflicted` SHALL fire with `(B, &"sleep")`

#### Scenario: Already-inflicted status is not re-emitted

- **WHEN** actor B already has `&"poison"` and a poison-inflicting attack lands again on B
- **THEN** `actor_status_inflicted` SHALL NOT fire (no transition)
