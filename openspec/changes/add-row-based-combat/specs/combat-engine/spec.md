## ADDED Requirements

### Requirement: TurnEngine exposes effective_row computed from current side liveness

The system SHALL provide `TurnEngine.effective_row(actor: CombatActor) -> Row` returning:

- `Row.FRONT` if `actor.original_row == Row.FRONT`.
- `Row.BACK` if `actor.original_row == Row.BACK` AND at least one same-side actor exists with `original_row == Row.FRONT` AND that FRONT actor `is_alive() == true` (no promotion needed).
- `Row.FRONT` if `actor.original_row == Row.BACK` AND no same-side living FRONT actor exists (promotion case).

"Same side" SHALL be determined by membership in the engine's `party` array (party side) or `monsters` array (monster side).

The function SHALL evaluate the current state at call time. The result SHALL NOT be cached for the duration of a turn — repeated calls within `resolve_turn` MAY return different values as combatants die.

#### Scenario: FRONT-row actor stays FRONT
- **WHEN** an actor whose `original_row == Row.FRONT` is queried via `effective_row`
- **THEN** the result SHALL be `Row.FRONT` regardless of liveness of others

#### Scenario: BACK-row actor stays BACK while a same-side FRONT lives
- **WHEN** a BACK-row party member is queried while at least one FRONT-row party member is alive
- **THEN** `effective_row` SHALL return `Row.BACK`

#### Scenario: BACK-row actor promotes to FRONT after all same-side FRONT die
- **WHEN** a BACK-row party member is queried after every FRONT-row party member has `is_alive() == false`
- **THEN** `effective_row` SHALL return `Row.FRONT`

#### Scenario: Promotion rule applies to monsters identically
- **WHEN** a BACK-row monster is queried after every FRONT-row monster in the same `monsters` array has died
- **THEN** `effective_row` SHALL return `Row.FRONT`

#### Scenario: Mid-turn re-evaluation reflects intra-turn deaths
- **WHEN** during a single `resolve_turn`, a FRONT-row party member dies at action index N, and `effective_row` is called for a BACK-row party member at action index N+1
- **THEN** the call at N+1 SHALL return `Row.FRONT` (promotion is observed mid-turn)

### Requirement: TurnEngine exposes can_reach for attack reachability

The system SHALL provide `TurnEngine.can_reach(attacker: CombatActor, target: CombatActor) -> bool` returning:

- `true` if `weapon_range_of(attacker) == WeaponRange.RANGED`.
- `true` if `weapon_range_of(attacker) == WeaponRange.MELEE` AND `effective_row(attacker) == Row.FRONT` AND `effective_row(target) == Row.FRONT`.
- `false` otherwise.

`weapon_range_of(attacker)` SHALL be:
- For a `PartyCombatant`: the value returned by `attacker.equipment_provider.get_weapon_range(attacker.character)`.
- For a `MonsterCombatant`: `attacker.monster.data.attack_range`.
- Fallback for either: `WeaponRange.MELEE` when no source resolves.

#### Scenario: RANGED attacker reaches any target
- **WHEN** `can_reach(attacker, target)` is called with `weapon_range_of(attacker) == RANGED`
- **THEN** the result SHALL be `true` regardless of either side's row

#### Scenario: MELEE FRONT vs FRONT reaches
- **WHEN** a MELEE attacker with `effective_row == FRONT` queries reach against a target with `effective_row == FRONT`
- **THEN** the result SHALL be `true`

#### Scenario: MELEE FRONT vs BACK does not reach
- **WHEN** a MELEE attacker with `effective_row == FRONT` queries reach against a target with `effective_row == BACK`
- **THEN** the result SHALL be `false`

#### Scenario: MELEE BACK vs anything does not reach
- **WHEN** a MELEE attacker with `effective_row == BACK` queries reach against any target
- **THEN** the result SHALL be `false`

#### Scenario: MELEE BACK promoted to FRONT can reach FRONT
- **WHEN** a MELEE attacker whose `original_row == BACK` queries reach AFTER same-side FRONT members are all dead, against a target with `effective_row == FRONT`
- **THEN** the result SHALL be `true` (the attacker's `effective_row` is now FRONT)

### Requirement: AttackCommand resolution gates on can_reach as a defense-in-depth check

`TurnEngine._resolve_attack` SHALL, before calling `DamageCalculator.calculate`, evaluate `can_reach(attacker, effective_target)`. When the check fails:

- The attack SHALL NOT roll for hit or damage.
- The attack SHALL NOT mutate target HP.
- A `TurnReport` action of `type == "attack_unreachable"` SHALL be appended with at minimum `{ type, attacker_name, target_name }`. (UI rendering: "<attacker> の攻撃は届かなかった" or equivalent.)

The UI is expected to prevent unreachable attacks from being submitted (CombatCommandMenu disable + CombatTargetSelector gray-out), but this engine-side gate exists so that direct API calls or debug-console submissions cannot bypass the rule.

The `attack_unreachable` action SHALL also have a corresponding `add_attack_unreachable(attacker, target)` method on `TurnReport`.

#### Scenario: Reachable MELEE attack proceeds normally
- **WHEN** a MELEE attacker FRONT vs FRONT submits AttackCommand and reach passes
- **THEN** `DamageCalculator.calculate` SHALL be invoked and a normal `attack` or `miss` log entry SHALL be appended

#### Scenario: Unreachable attack is blocked at engine level
- **WHEN** a MELEE attacker submits AttackCommand against a target where `can_reach` returns false (e.g., direct API call bypassing UI)
- **THEN** target HP SHALL NOT change, no hit roll SHALL occur, and the report SHALL contain a single `attack_unreachable` action entry naming attacker and target

#### Scenario: TurnReport.add_attack_unreachable produces the documented entry
- **WHEN** `report.add_attack_unreachable(attacker, target)` is called with `attacker.actor_name = "Bob"` and `target.actor_name = "Witch"`
- **THEN** the appended entry SHALL equal `{ type: "attack_unreachable", attacker_name: "Bob", target_name: "Witch" }`

### Requirement: Monster AI selects targets from the reachable subset

The system SHALL replace the existing `_pick_living_party(rng)` call site for monster attack resolution with a reachable-aware variant. For each acting `MonsterCombatant`:

1. Compute the candidate target set as living party members `p` such that `can_reach(monster, p) == true`.
2. If the set is non-empty, choose one uniformly at random using the injected RNG.
3. If the set is empty (no reachable target):
   - If the monster's `attack_range == MELEE` and at least one party member is still alive, the monster SHALL fall through to the "wait" branch (see next requirement).
   - If no party member is alive at all, the monster SHALL skip its action (existing behavior preserved).

The deterministic-tiebreak property SHALL be preserved: identical RNG seed and identical reachable set SHALL produce identical target selection.

#### Scenario: MELEE monster picks only from FRONT party while FRONT lives
- **WHEN** a MELEE monster's reachable-target computation runs with party `[FrontFighter (alive), BackMage (alive)]`
- **THEN** only FrontFighter SHALL be a candidate; BackMage SHALL NOT

#### Scenario: MELEE monster targets promoted BACK after FRONT dies
- **WHEN** a MELEE monster's reachable-target computation runs after FrontFighter died and only BackMage remains alive
- **THEN** BackMage SHALL be the candidate (BackMage's `effective_row` is now FRONT)

#### Scenario: RANGED monster targets any living party member
- **WHEN** a RANGED monster's reachable-target computation runs with a mixed-row living party
- **THEN** every living party member SHALL be a candidate

### Requirement: Back-row MELEE monster waits when no reachable target exists

The system SHALL, when an acting `MonsterCombatant` has `attack_range == MELEE` AND its reachable-target set is empty AND at least one party member is still alive, treat the monster's turn as a "wait" action:

1. Emit `actor_action_started.emit(monster, &"wait")`.
2. Append a `TurnReport` action of `type == "wait"` with `{ type, actor_name }` via `TurnReport.add_wait(monster)`.
3. Skip damage rolls and HP mutation.
4. Apply NO defensive bonus (the monster is NOT in defending posture; subsequent damage is taken at full).
5. End the monster's turn.

Status tick handling at turn boundaries SHALL be unchanged — the wait branch only short-circuits the attack action, not the engine's normal end-of-turn cleanup.

#### Scenario: Back-row MELEE monster waits while FRONT party blocks
- **WHEN** a BACK-row MELEE monster's turn arrives with FRONT-row party members alive
- **THEN** the engine SHALL emit `actor_action_started(monster, &"wait")`, append a `wait` report entry, and SHALL NOT roll damage

#### Scenario: Wait does not grant damage halving
- **WHEN** a monster has waited this turn and is then attacked
- **THEN** the incoming damage SHALL be at full value (no defending posture is applied by wait)

#### Scenario: Wait does not interrupt status ticks
- **WHEN** a monster with an active poison-style tick effect waits
- **THEN** the tick SHALL still be applied during the engine's per-turn tick pass (the wait branch only affects the action loop)

### Requirement: TurnReport supports the wait action type

`TurnReport` SHALL provide `add_wait(actor: CombatActor)` that appends an action of shape `{ type: "wait", actor_name: String }`. Existing TurnReport entries SHALL be unaffected.

#### Scenario: add_wait produces the documented entry
- **WHEN** `report.add_wait(actor)` is called with `actor.actor_name = "Bat"`
- **THEN** the appended entry SHALL equal `{ type: "wait", actor_name: "Bat" }`
