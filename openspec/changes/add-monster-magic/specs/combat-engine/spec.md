## MODIFIED Requirements

### Requirement: Monster actions target a random living PartyCombatant

The system SHALL invoke `MonsterAi.choose(monster, ctx, rng)` for every acting `MonsterCombatant` and SHALL route the returned command through the appropriate resolver. The MonsterAi return values map to engine behavior as follows:

- `AttackCommand`: resolve via the existing `_resolve_attack` path with the same reach gating as before (`can_reach` check + `attack_unreachable` fallback).
- `CastCommand`: resolve via the existing `_resolve_cast` path with the same silence / no-target / no-MP guards used for party casts.
- `null`: behave as the existing "wait" path when `attack_range == MELEE` and at least one party member remains alive (emit `actor_action_started(monster, &"wait")` and append a `wait` report entry); otherwise (no party alive) skip the action.

`TurnEngine` SHALL construct a `MonsterAiContext` once per turn (or once per monster turn — both are acceptable) and pass it to `MonsterAi.choose`. The context SHALL expose `party`, `monsters`, `spell_repo`, `status_repo`, and a reference to the engine itself (for `can_reach` queries). Monster AI SHALL NOT mutate engine state through this reference.

The deterministic-tiebreak property SHALL be preserved: identical RNG seed and identical battle state SHALL produce identical command selection.

#### Scenario: Monster without spells attacks a reachable living PartyCombatant
- **WHEN** a `MonsterCombatant` whose `MonsterData.known_spells == []` acts during `resolve_turn(rng)` with one reachable party member alive
- **THEN** the engine SHALL invoke `_resolve_attack` against that party member

#### Scenario: Monster with castable spells may cast or attack
- **WHEN** a `MonsterCombatant` with non-empty `known_spells` and sufficient MP acts
- **THEN** the engine SHALL either resolve a `CastCommand` (when AI selects one) or fall back to `_resolve_attack` (when AI selects none), and SHALL NOT bypass the MonsterAi entry point

#### Scenario: Cast routed through monster reuses _resolve_cast guards
- **WHEN** a silenced `MonsterCombatant` is invoked and AI returns a `CastCommand` despite silence (defense-in-depth — AI normally filters this, but engine SHALL not assume)
- **THEN** the engine SHALL append a `cast_silenced` report entry and SHALL NOT consume MP

#### Scenario: Cast with insufficient MP at resolution time is rejected
- **WHEN** a `MonsterCombatant` has `current_mp` reduced between AI decision and cast resolution (e.g., by a status effect) so that `spend_mp(spell.mp_cost)` returns `false`
- **THEN** the engine SHALL append a `cast_skipped_no_mp` report entry and SHALL NOT apply the spell effect

#### Scenario: Monster skips its action when no party member is alive
- **WHEN** every PartyCombatant has `is_alive() == false` at the moment a monster would act
- **THEN** the monster SHALL NOT take an action (resolution proceeds to termination check)

#### Scenario: MELEE BACK monster with no reachable target waits
- **WHEN** a MELEE BACK monster with empty `known_spells` (or all spells filtered out) acts while only BACK party members are alive
- **THEN** the engine SHALL emit `actor_action_started(monster, &"wait")` and append a `wait` report entry

#### Scenario: Target choice is deterministic under fixed seed
- **WHEN** a monster's command is selected twice with identically-seeded RNGs and the same battle state
- **THEN** both runs SHALL produce commands of the same type with identical target identity

## ADDED Requirements

### Requirement: TurnEngine routes monster cast commands through _resolve_cast

The system SHALL extend `TurnEngine._resolve_cast(caster, cmd, rng, report)` to accept a `MonsterCombatant` as `caster` without behavioral special-casing. The flow (resolve SpellData → resolve targets → check MP → apply effect → report) SHALL be identical for party and monster casters. The existing signals (`actor_action_started`, `actor_spent_mp`, `actor_dealt_damage`, `actor_healed`, `actor_died`, `actor_status_inflicted`) SHALL fire with monster casters as the `actor` / `source` parameters under the same conditions as for party casters.

The existing `actor_action_started.emit(actor, &"cast")` SHALL fire for monster casters during the monster branch of the action loop, before MP is consumed.

#### Scenario: Witch's cast emits actor_action_started with kind "cast"
- **WHEN** a `MonsterCombatant` (witch) acts and `MonsterAi.choose` returns a `CastCommand` for `&"fire"`
- **THEN** `actor_action_started` SHALL fire with `(witch, &"cast")` before MP is consumed

#### Scenario: Successful monster cast emits actor_spent_mp
- **WHEN** a `MonsterCombatant` successfully casts a spell with `mp_cost = 2` and `spend_mp(2)` returns `true`
- **THEN** `actor_spent_mp` SHALL fire exactly once with `(monster, 2)` before the cast report entry is appended

#### Scenario: Monster cast damage emits actor_dealt_damage with monster as source
- **WHEN** a witch casts `fire` on Fighter and deals 6 damage
- **THEN** `actor_dealt_damage` SHALL fire with `(Fighter, 6, witch)`

#### Scenario: Monster heal emits actor_healed with monster as source
- **WHEN** a dark_priest casts `heal` on Imp restoring 5 HP
- **THEN** `actor_healed` SHALL fire with `(Imp, 5, dark_priest)`

#### Scenario: Monster cast inflicting a new status emits actor_status_inflicted
- **WHEN** a witch successfully casts `katino` on a party member who had no sleep status
- **THEN** `actor_status_inflicted` SHALL fire with `(party_member, &"sleep")` for each newly-affected party member

### Requirement: TurnEngine handles monster cast retargeting symmetrically with party casts

The system SHALL apply the existing target-resolution rules (`spell-casting` capability) to monster casts. When a monster casts `ENEMY_ONE` and the originally-selected party member dies before resolution, the engine SHALL retarget to another living party member. When a monster casts `ALLY_ONE` (heal/cure/buff) and the originally-selected ally dies before resolution, the engine SHALL retarget to another living same-side ally. The retarget SHALL be recorded in the cast report entry's `retargeted_from` field per existing semantics.

#### Scenario: Monster ENEMY_ONE retargets when original party target dies mid-turn
- **WHEN** a witch submits `CastCommand` for `fire` against Fighter, but Fighter dies (e.g., from a fellow monster's attack) before the witch's turn resolves, while Mage is still alive
- **THEN** the cast SHALL retarget to Mage and the cast report entry SHALL record `retargeted_from = "Fighter"`

#### Scenario: Monster ALLY_ONE heal retargets when ally dies mid-turn
- **WHEN** a dark_priest submits `CastCommand` for `heal` against Imp, but Imp dies before resolution while another monster ally is alive
- **THEN** the cast SHALL retarget to the surviving ally and the cast report entry SHALL record the retargeting
