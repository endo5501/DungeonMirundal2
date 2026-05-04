## ADDED Requirements

### Requirement: TurnEngine ticks status at the head of every turn before any action

The system SHALL invoke `actor.statuses.tick_battle_turn(actor, status_repo)` for every party member and every monster as the very first step of `resolve_turn(rng)` (before Defend application, Escape rolling, and the action order walk). For each returned tick entry, the system SHALL append a `tick_damage` action to the TurnReport. If the tick reduces an actor to `is_alive() == false`, the action entry SHALL include a `killed_by_tick == true` flag.

If after all ticks `_all_party_dead()` or `_all_monsters_dead()` returns true, the system SHALL terminate the battle (`WIPED` or `CLEARED`) **without** walking the action order, while still running the battle-end cleanup (battle-only status cure, persistent status commit, `clear_battle_only` for the modifier stack).

#### Scenario: Tick damage is applied before any actor acts
- **WHEN** a party member holds a `tick_in_battle = 2` status and `resolve_turn` is called
- **THEN** the party member SHALL take 2 damage *before* the action order resolves any commands

#### Scenario: Tick can wipe the party and ends the battle
- **WHEN** every living party member's HP equals their tick damage and `resolve_turn` runs
- **THEN** all party members SHALL die from ticks, no actions SHALL resolve this turn, and `outcome().result` SHALL become `WIPED`

#### Scenario: Tick damage produces TurnReport entries
- **WHEN** `tick_battle_turn` returns one entry for one actor
- **THEN** the TurnReport SHALL contain one action with `type == "tick_damage"`, the actor's name, the status id, the HP loss, and `killed_by_tick`

### Requirement: TurnEngine respects action_lock during action resolution

The system SHALL, before resolving any actor's command, check `actor.has_action_lock()`. When `true`, the system SHALL skip the actor's action and append an `action_locked` action to the TurnReport. No damage, healing, or status effect SHALL be applied for that actor in that turn.

#### Scenario: Action-locked actor's command is skipped
- **WHEN** an actor with `has_action_lock() == true` has an `AttackCommand` queued
- **THEN** during resolution the attack SHALL NOT execute and the TurnReport SHALL contain an `action_locked` entry for the actor

#### Scenario: Action-locked monster does not attack
- **WHEN** a monster with `has_action_lock() == true` reaches its turn slot
- **THEN** no attack SHALL be performed and the TurnReport SHALL contain an `action_locked` entry

### Requirement: TurnEngine intercepts CastCommand under silence

The system SHALL, when an actor with `has_silence_flag() == true` has a `CastCommand` to resolve, abort the cast without consuming MP and append a `cast_silenced` action entry to the TurnReport (with `caster_name` and `spell_id`). Silence SHALL NOT block other command types (Attack, Defend, Escape, Item).

#### Scenario: Silenced cast is squelched
- **WHEN** a Mage with `has_silence_flag() == true` submits a Cast for `&"fire"` (mp_cost=2)
- **THEN** the Mage's MP SHALL be unchanged and the TurnReport SHALL contain `{ type: "cast_silenced", caster_name, spell_id: &"fire" }`

#### Scenario: Silence does not block attack
- **WHEN** a silenced actor submits an `AttackCommand`
- **THEN** the attack SHALL resolve normally

#### Scenario: Silence does not block item use
- **WHEN** a silenced actor submits an `ItemCommand`
- **THEN** the item SHALL resolve normally

### Requirement: TurnEngine retargets confused commands to a random living actor

The system SHALL, when an actor with `has_confusion_flag() == true` has any of `AttackCommand`, `CastCommand`, or `ItemCommand` queued, replace the resolved command with an `AttackCommand` whose `target` is a uniformly random living combatant chosen from **the union of all party members and all monsters that are alive at resolution time, excluding the confused actor itself**. The resulting attack SHALL go through the normal `_resolve_attack` path. The TurnReport SHALL include a `confusion_swap` annotation on the resulting attack action so callers can render the explanation.

#### Scenario: Confused attack picks a random living actor including allies
- **WHEN** a confused party member with `AttackCommand(target=monster_A)` resolves and the random pick is an ally
- **THEN** `_resolve_attack` SHALL run with the ally as the effective target, the TurnReport SHALL include the resulting attack/miss action, and the action SHALL be marked with `confusion_swap == true`

#### Scenario: Confused cast becomes attack on a random living actor
- **WHEN** a confused Mage with `CastCommand(spell_id=fire, target=monster_A)` resolves
- **THEN** the cast SHALL be replaced by a single `AttackCommand` with a randomly chosen living target, no MP SHALL be consumed, and the resulting attack action SHALL be marked with `confusion_swap == true`

#### Scenario: Confused item becomes attack on a random living actor
- **WHEN** a confused actor with `ItemCommand(item=potion, target=ally_B)` resolves
- **THEN** the item SHALL NOT be consumed, the action SHALL become an `AttackCommand` against a random living combatant, and the action SHALL be marked with `confusion_swap == true`

### Requirement: TurnEngine performs status cleanup at battle end

The system SHALL define a private helper `_finish_with_battle_end_cleanup(report, result)` that:

1. For every party member and every monster, calls `statuses.cure_all_battle_only(status_repo)` and appends a `cure` action to the TurnReport for each returned id.
2. For every party member, calls `commit_persistent_to_character(status_repo)` so the wrapped Character's `persistent_statuses` reflects the post-battle persistent set.
3. For every party member and every monster, calls `modifier_stack.clear_battle_only()`.
4. Calls `_finish(result)` to set the outcome and state.

Every existing path that previously called `_finish(...)` directly (CLEARED, WIPED, ESCAPED, ESCAPED via item) SHALL be routed through `_finish_with_battle_end_cleanup`.

#### Scenario: Battle-only statuses are cured at battle end
- **WHEN** a battle ends with a party member holding a BATTLE_ONLY status `&"sleep"`
- **THEN** after the cleanup, the party member's `statuses.has(&"sleep")` SHALL be `false` and the TurnReport SHALL contain a `cure` entry for `&"sleep"`

#### Scenario: Persistent statuses are committed back to Character
- **WHEN** a battle ends with a party member holding a PERSISTENT status `&"poison"`
- **THEN** the wrapped `Character.persistent_statuses` SHALL contain `&"poison"` after cleanup

#### Scenario: Battle-only modifier_stack is cleared at battle end
- **WHEN** a battle ends and a combatant has `modifier_stack.sum(&"attack") == +2` (BATTLE_ONLY)
- **THEN** after cleanup the combatant's `modifier_stack.sum(&"attack")` SHALL be `0`

### Requirement: TurnEngine triggers cures_on_damage after each damage application

The system SHALL invoke `actor.statuses.handle_damage_taken(actor, status_repo)` immediately after every `take_damage` call originating from the engine (Attack hits, Cast damage, tick damage). Every cured status id SHALL be appended to the TurnReport as a `wake` action.

The system is NOT required to hook this for damage paths originating outside the engine (e.g. items used out of battle in this change's scope).

#### Scenario: Damage wakes a sleeping actor when StatusData has cures_on_damage
- **WHEN** a party member holding a status with `cures_on_damage == true` takes damage during action resolution
- **THEN** the status SHALL be cured immediately and the TurnReport SHALL contain a `wake` entry naming the cured status id and the actor

#### Scenario: Damage with cures_on_damage == false leaves status alone
- **WHEN** a party member holds a status with `cures_on_damage == false` (e.g. poison) and takes damage
- **THEN** the status SHALL remain active

### Requirement: TurnEngine surfaces a status_repo dependency on top of spell_repo

The system SHALL provide on `TurnEngine` a property `status_repo: StatusRepository` that is lazily loaded via `DataLoader.new().load_status_repository()` if unset. This mirrors the existing `spell_repo` pattern.

#### Scenario: status_repo lazy-loads on first access
- **WHEN** a TurnEngine without an explicit `status_repo` reaches the first turn
- **THEN** `status_repo` SHALL be populated via DataLoader on the first access

#### Scenario: Caller can inject a custom status_repo
- **WHEN** a test sets `engine.status_repo = my_repo` before `resolve_turn`
- **THEN** the engine SHALL use the injected repository

## ADDED Requirements

### Requirement: TurnReport records new status-related action entries

The system SHALL extend `TurnReport` with the following action shapes (all new types, no modifications to existing types):

- `tick_damage`: `{ type, actor_name, status_id, amount, killed_by_tick }`
- `wake`: `{ type, actor_name, status_id }`
- `inflict`: `{ type, target_name, status_id, success }`
- `cure`: `{ type, actor_name, status_id }`
- `resist`: `{ type, target_name, status_id }`
- `stat_mod`: `{ type, target_name, stat, delta, turns }`
- `action_locked`: `{ type, actor_name }`
- `cast_silenced`: `{ type, caster_name, spell_id }`

Each shape SHALL have a corresponding `add_*` method on `TurnReport`.

#### Scenario: add_tick_damage produces the documented entry
- **WHEN** `report.add_tick_damage(actor, &"poison", 2, false)` is called with `actor.actor_name == "Alice"`
- **THEN** the appended entry SHALL equal `{ type: "tick_damage", actor_name: "Alice", status_id: &"poison", amount: 2, killed_by_tick: false }`

#### Scenario: add_action_locked produces the documented entry
- **WHEN** `report.add_action_locked(actor)` is called
- **THEN** the appended entry SHALL have `type == "action_locked"` and `actor_name == actor.actor_name`

#### Scenario: Existing action types are unchanged
- **WHEN** any of `add_attack`, `add_defend`, `add_escape`, `add_cast`, `add_item_use`, `add_defeated`, `add_miss` is called
- **THEN** the appended entry SHALL keep its existing structure (no new mandatory fields)
