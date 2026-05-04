## ADDED Requirements

### Requirement: DamageCalculator returns a DamageResult with hit and amount

The system SHALL provide `DamageCalculator.calculate(attacker: CombatActor, target: CombatActor, rng: RandomNumberGenerator) -> DamageResult`, where `DamageResult` is a small `RefCounted` value object exposing `hit: bool` and `amount: int`. When `hit == true`, `amount` SHALL be a positive integer (minimum 1). When `hit == false`, `amount` SHALL be `0`.

#### Scenario: DamageResult on a hit carries the computed damage
- **WHEN** `DamageCalculator.calculate(attacker, target, rng)` is invoked and the hit roll succeeds
- **THEN** the returned `DamageResult` SHALL satisfy `hit == true` and `amount >= 1`

#### Scenario: DamageResult on a miss carries zero damage
- **WHEN** the hit roll fails
- **THEN** the returned `DamageResult` SHALL satisfy `hit == false` and `amount == 0`

### Requirement: DamageCalculator computes hit chance from base, modifiers, AGI, and blind

The system SHALL compute the hit chance for an attack as:

```
raw =
    BASE_HIT (= 0.85)
  + clamp(attacker.get_hit_modifier_total(),       -0.4, +0.4)
  - clamp(target.get_evasion_modifier_total(),     -0.4, +0.4)
  + clamp((attacker.get_agility() - target.get_agility()) * AGI_K, -0.30, +0.30)
  - (BLIND_PENALTY if attacker.has_blind_flag() else 0.0)
final_hit_chance = clamp(raw, 0.05, 0.99)
```

with `AGI_K = 0.02` and `BLIND_PENALTY = 0.0` in this change (the value is fixed by `StatusData` in a later change). The system SHALL roll `rng.randf()` and SHALL set `hit = true` when the roll is strictly less than `final_hit_chance`.

#### Scenario: Equal stats yield base hit chance
- **WHEN** attacker and target both have AGI 5, no hit/evasion modifiers, and attacker has no blind flag
- **THEN** the computed `final_hit_chance` SHALL equal `0.85`

#### Scenario: AGI advantage adds to hit chance with cap
- **WHEN** attacker has AGI 20 and target has AGI 5 (difference 15) with no other modifiers
- **THEN** the AGI bonus SHALL be capped at `+0.30` and `final_hit_chance` SHALL equal `min(0.99, 0.85 + 0.30) == 0.99` (hit clamp also applies)

#### Scenario: AGI disadvantage subtracts from hit chance with cap
- **WHEN** attacker has AGI 5 and target has AGI 30 (difference -25)
- **THEN** the AGI penalty SHALL be capped at `-0.30` and `final_hit_chance` SHALL equal `max(0.05, 0.85 - 0.30) == 0.55`

#### Scenario: Hit modifier and evasion modifier each cap at ±0.4
- **WHEN** an attacker's raw hit modifier is `+0.7` and target's raw evasion modifier is `+0.6` (no AGI difference, no blind)
- **THEN** the contributions SHALL be `+0.4 - +0.4 = 0.0` and `final_hit_chance` SHALL equal `0.85`

#### Scenario: Final hit chance clamps to [0.05, 0.99]
- **WHEN** the raw computation yields `1.20` (e.g., huge AGI gap + max hit modifier)
- **THEN** `final_hit_chance` SHALL equal `0.99`
- **WHEN** the raw computation yields `-0.10` (e.g., max evasion + max AGI deficit)
- **THEN** `final_hit_chance` SHALL equal `0.05`

#### Scenario: Hit roll uses rng.randf() strictly less than final_hit_chance
- **WHEN** `final_hit_chance == 0.85` and `rng.randf()` returns `0.84`
- **THEN** `DamageResult.hit` SHALL be `true`
- **WHEN** `rng.randf()` returns `0.85`
- **THEN** `DamageResult.hit` SHALL be `false`
- **WHEN** `rng.randf()` returns `0.90`
- **THEN** `DamageResult.hit` SHALL be `false`

## MODIFIED Requirements

### Requirement: Attack command resolves damage via DamageCalculator
The system SHALL provide an `Attack` command that targets exactly one opposing `CombatActor`, and SHALL compute damage through a `DamageCalculator` that uses attacker and target stats plus an RNG for both a hit roll and a damage spread. When the hit roll fails, no damage SHALL be applied and a miss action entry SHALL be appended to the TurnReport.

#### Scenario: Basic damage formula on a hit
- **WHEN** damage is calculated for attacker with `get_attack() = 10`, target with `get_defense() = 4`, RNG yielding a successful hit roll, and the spread roll producing `+1`
- **THEN** the returned `DamageResult` SHALL satisfy `hit == true` and `amount == max(1, 10 - 4 / 2 + 1) == 9`, and the target SHALL take that damage via `take_damage`

#### Scenario: Minimum damage floor on a hit
- **WHEN** the computed damage on a hit would be `0` or negative (e.g., attack well below defense)
- **THEN** the applied damage SHALL be exactly `1`

#### Scenario: Miss does not apply damage and records a miss action
- **WHEN** the hit roll fails
- **THEN** `take_damage` SHALL NOT be called on the target and the TurnReport SHALL contain a single action entry with `type == "miss"`, attacker name, and target name

#### Scenario: Attack on a dead target is skipped
- **WHEN** the selected target has `is_alive() == false` at the time the attacker acts
- **THEN** the attack SHALL either be retargeted to another living enemy of the same side, or SHALL be skipped if no living target remains; in neither case SHALL damage be dealt to a dead target and the hit roll SHALL only happen on a valid (living) target

## ADDED Requirements

### Requirement: TurnReport records miss action entries

The system SHALL provide `TurnReport.add_miss(attacker, target)` and SHALL append an action entry of the form `{ type: "miss", attacker_name: String, target_name: String }`. Existing `add_attack` entries SHALL keep their current shape and SHALL only be created when an attack hits.

#### Scenario: add_miss produces the documented entry
- **WHEN** `report.add_miss(attacker, target)` is called with `attacker.actor_name = "Alice"` and `target.actor_name = "Slime A"`
- **THEN** the appended action SHALL have `type == "miss"`, `attacker_name == "Alice"`, and `target_name == "Slime A"`

#### Scenario: add_attack is unchanged for hits
- **WHEN** an attack lands and the engine calls `report.add_attack(attacker, target, damage, defended, retargeted_from)`
- **THEN** the appended action SHALL keep its existing shape (`type == "attack"`, plus damage/defended/retargeted_from fields)

### Requirement: TurnEngine ticks modifier stacks at end-of-turn cleanup

The system SHALL invoke `modifier_stack.tick_battle_turn()` for every party member and every monster as part of `_end_turn_cleanup()`, so that battle-only stat modifiers decay one turn per resolved turn. The system SHALL NOT clear battle-only modifiers at the end of an individual turn — only `clear_battle_only()` (called at battle end by a later change) does that.

#### Scenario: A 2-turn modifier survives one turn end and expires after the second
- **WHEN** an actor has `modifier_stack.add(&"attack", +2, 2)` set before turn N, and turn N completes
- **THEN** at the start of turn N+1 the actor's `modifier_stack.sum(&"attack")` SHALL still be `+2`
- **WHEN** turn N+1 also completes
- **THEN** at the start of turn N+2 the actor's `modifier_stack.sum(&"attack")` SHALL be `0`

#### Scenario: Tick is invoked for every actor including dead ones
- **WHEN** `_end_turn_cleanup()` runs at the end of a turn where one party member died
- **THEN** every party member (alive or dead) and every monster SHALL have `tick_battle_turn()` called once
