## ADDED Requirements

### Requirement: MonsterAi exposes a static command-selection entry point

The system SHALL provide a `MonsterAi` (RefCounted) class with a static method:

```
static func choose(
    monster: MonsterCombatant,
    ctx: MonsterAiContext,
    rng: RandomNumberGenerator
) -> RefCounted
```

The return value SHALL be either:
- an `AttackCommand` referencing one living, reachable `PartyCombatant` (when the AI elects to attack),
- a `CastCommand` referencing one of the monster's `known_spells` with a fully-resolved target descriptor (when the AI elects to cast), or
- `null` (when the AI elects to take no action this turn, e.g., MELEE BACK monster with no reachable target).

`MonsterAi` SHALL have no instance state. All inputs SHALL come through arguments so the same `MonsterAi.choose(...)` call with identical inputs returns identical output (RNG seed equality implies output equality).

#### Scenario: MonsterAi.choose is callable as a static method
- **WHEN** test code calls `MonsterAi.choose(monster, ctx, rng)` without instantiating `MonsterAi`
- **THEN** the call SHALL succeed and return a value of one of the documented types

#### Scenario: Deterministic output under fixed seed
- **WHEN** `MonsterAi.choose(monster, ctx, rng)` is called twice with two RNGs seeded with the same value, the same monster instance, and an equivalent context
- **THEN** the two calls SHALL return commands of the same type with identical target identity (or both return `null`)

### Requirement: MonsterAiContext carries battle state for AI decisions

The system SHALL provide a `MonsterAiContext` (RefCounted) DTO with the following fields:

- `party: Array` — array of `PartyCombatant` (the engine's `party` array reference).
- `monsters: Array` — array of `MonsterCombatant` (the engine's `monsters` array reference).
- `spell_repo: SpellRepository` — for resolving `known_spells` ids to `SpellData`.
- `turn_engine: TurnEngine` — used by AI for `can_reach(...)` queries and side-membership tests. (The AI SHALL NOT mutate engine state through this reference.)

Status-effect checks (silence, target affliction) SHALL be performed through `CombatActor` methods (`has_silence_flag()`, `statuses.has(sid)`), so no `StatusRepository` reference is required on the context.

`MonsterAiContext` SHALL be constructed once per turn (or per AI call) by `TurnEngine` and passed by reference. No defensive copy is required since the AI SHALL NOT mutate any field.

#### Scenario: MonsterAiContext exposes required fields
- **WHEN** a `MonsterAiContext` is constructed with `party`, `monsters`, `spell_repo`, `turn_engine`
- **THEN** every field SHALL be readable

### Requirement: MonsterAi selects an attack when no spell candidate exists

The system SHALL, when `MonsterAi.choose(...)` finds no eligible spell candidate (empty after filtering — see "Spell candidate filtering" requirement), fall back to the attack-or-wait policy:

1. Compute the candidate target set as living party members `p` such that `ctx.turn_engine.can_reach(monster, p) == true`.
2. If the set is non-empty: select one uniformly at random using `rng` and return `AttackCommand.new(target)`.
3. If the set is empty AND `monster.monster.data.attack_range == WeaponRange.MELEE` AND at least one party member is alive: return `null` (TurnEngine SHALL interpret this as wait).
4. If no party member is alive at all: return `null` (TurnEngine SHALL skip the action naturally).

#### Scenario: Monster without spells attacks a reachable target
- **WHEN** `MonsterAi.choose` is called on a monster whose `known_spells` is empty and a reachable party member is alive
- **THEN** the return value SHALL be an `AttackCommand` whose `target` is a reachable party member

#### Scenario: MELEE BACK monster with no reach returns null
- **WHEN** `MonsterAi.choose` is called on a MELEE BACK monster with all FRONT party members alive (no reachable target)
- **THEN** the return value SHALL be `null`

#### Scenario: All party dead returns null
- **WHEN** `MonsterAi.choose` is called and every party member has `is_alive() == false`
- **THEN** the return value SHALL be `null`

### Requirement: MonsterAi filters known_spells before casting

The system SHALL, before considering any cast, filter `monster.monster.data.known_spells` to produce a candidate spell list using the following criteria. A spell SHALL be a candidate only if ALL conditions hold:

1. `ctx.spell_repo.find(spell_id)` returns a non-null `SpellData`.
2. `monster.current_mp >= spell.mp_cost`.
3. `monster.has_silence_flag()` is `false` (the silence flag blocks the entire cast at AI level — if silenced, the candidate list SHALL be empty, and the AI SHALL fall through to attack/wait).
4. The spell's `target_type`-specific precondition holds:
   - `ENEMY_ONE`: at least one living opposing-side combatant exists (party from a monster caster's perspective).
   - `ENEMY_GROUP`: at least two living opposing-side combatants share a `species_id` (so group damage actually beats single-target damage). For party-side targets, species is undefined; in that case the precondition SHALL require ≥2 living party members regardless of species.
   - `ALLY_ONE`: depends on effect type:
     - `HealSpellEffect`: at least one living same-side combatant has `current_hp < max_hp`.
     - `CureStatusSpellEffect`: at least one living same-side combatant has the named status active.
     - `StatModSpellEffect` with `delta > 0`: at least one living same-side combatant exists (positive buff).
     - Otherwise: at least one living same-side combatant exists.
   - `ALLY_ALL`: at least one living same-side combatant exists.

#### Scenario: Spell with insufficient MP is filtered out
- **WHEN** a monster has `current_mp = 1` and `known_spells = [&"fire"]` with `fire.mp_cost = 2`
- **THEN** the candidate list SHALL be empty and the AI SHALL fall through to attack

#### Scenario: Silence empties the candidate list
- **WHEN** a monster has `known_spells = [&"fire", &"frost"]` with sufficient MP and `has_silence_flag() == true`
- **THEN** the candidate list SHALL be empty and the AI SHALL fall through to attack

#### Scenario: Heal candidate excluded when no ally is wounded
- **WHEN** a monster's `known_spells` includes `&"heal"` and every living same-side combatant has `current_hp == max_hp`
- **THEN** `&"heal"` SHALL NOT appear in the candidate list

#### Scenario: ENEMY_GROUP candidate requires two same-species enemies
- **WHEN** a monster's `known_spells` includes `&"flame"` (ENEMY_GROUP) and only one party member is alive
- **THEN** `&"flame"` SHALL NOT appear in the candidate list

### Requirement: MonsterAi picks a candidate uniformly at random

The system SHALL, when the candidate spell list is non-empty, select one spell id from it uniformly at random using `rng.randi_range(0, candidates.size() - 1)`. The selection MAY be replaced in future iterations with a weighted/heuristic policy without breaking the calling contract.

#### Scenario: Single candidate is always chosen
- **WHEN** the candidate list contains exactly one spell `&"fire"`
- **THEN** the AI SHALL return a `CastCommand` for `&"fire"`

#### Scenario: Uniform selection across multiple candidates
- **WHEN** the candidate list contains `[&"fire", &"frost", &"katino"]` and the AI is invoked many times with independently-seeded RNGs
- **THEN** the empirical distribution SHALL approach 1/3 per candidate (deterministic under any single fixed seed)

### Requirement: MonsterAi builds a CastCommand with a resolved target

The system SHALL, after selecting a spell from the candidate list, construct a `CastCommand` whose target descriptor matches the spell's `target_type`:

- `ENEMY_ONE`: target SHALL be one living party member chosen uniformly at random from the **full** living-party set (reach is NOT applied to cast targets — spells have no melee/ranged distinction).
- `ENEMY_GROUP`: target SHALL be one representative living party member of the chosen group. When the opposing side is party (no species concept), target SHALL be any one living party member; `_resolve_cast_targets` is expected to fan out to all living party members per `spell-casting` semantics.
- `ALLY_ONE` with `HealSpellEffect` or `CureStatusSpellEffect`: target SHALL be the living same-side combatant most in need (HP minimum for heal; arbitrary first-eligible for cure).
- `ALLY_ONE` with other effects: target SHALL be one living same-side combatant chosen uniformly at random.
- `ALLY_ALL`: target SHALL be `null` (resolution is implicit per `spell-casting` semantics).

The `CastCommand` SHALL carry `caster_index = -1` for monster casters (party_index is meaningful only for `PartyCombatant`), or an equivalent sentinel established by `combat-engine`.

#### Scenario: ENEMY_ONE cast targets a random living party member
- **WHEN** a monster casts `fire` (ENEMY_ONE) and 3 party members are alive
- **THEN** the `CastCommand.target` SHALL be one of those 3 party members (chosen via `rng`)

#### Scenario: Heal targets the lowest-HP living ally
- **WHEN** a monster with `known_spells = [&"heal"]` is in a monster party where Witch has `current_hp = 5/20` and Imp has `current_hp = 15/16`
- **THEN** the `CastCommand.target` SHALL be Witch

#### Scenario: ALLY_ALL cast leaves target null
- **WHEN** a monster casts `allheal` (ALLY_ALL) and any same-side combatant is alive
- **THEN** the `CastCommand.target` SHALL be `null`

### Requirement: MonsterAi does not apply reach gating to cast targets

The system SHALL NOT apply `can_reach(caster, target)` when selecting cast targets. Casts have no melee/ranged distinction; only physical attacks consult reach.

#### Scenario: BACK MELEE-attack monster can still cast a spell
- **WHEN** a BACK-row monster with `attack_range == MELEE` has `known_spells = [&"fire"]` and a living FRONT party member is alive
- **THEN** the AI SHALL be free to return a `CastCommand` targeting that FRONT party member regardless of the monster's reach for attacks

#### Scenario: BACK MELEE-attack monster falls back to wait only when no spell candidate exists
- **WHEN** a BACK-row monster with `attack_range == MELEE` has empty `known_spells` (or all spells filtered out by candidate filter) and only BACK party members are alive
- **THEN** the AI SHALL return `null` (wait)
