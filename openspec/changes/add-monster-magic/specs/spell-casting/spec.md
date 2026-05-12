## MODIFIED Requirements

### Requirement: Target resolution depends on target_type

The system SHALL resolve cast targets at resolution time according to `spell.target_type`, interpreting the `ENEMY_*` and `ALLY_*` enums **relative to the caster's side**:

- `ENEMY_ONE`: a single specified opposing CombatActor. "Opposing" means the side opposite to the caster — for a party caster the opposing pool is `monsters`; for a monster caster the opposing pool is `party`.
- `ENEMY_GROUP`: every living opposing combatant whose `species_id` matches the specified species. When the opposing side is party (i.e., a monster is casting at the party), species is undefined for party members and the resolution SHALL fan out to every living opposing combatant.
- `ALLY_ONE`: a single specified CombatActor from the caster's own side. For a party caster the ally pool is `party`; for a monster caster the ally pool is `monsters`.
- `ALLY_ALL`: every living combatant from the caster's own side.

If at resolution time the originally specified single target (`ENEMY_ONE` / `ALLY_ONE`) is no longer alive, the system SHALL retarget to another living member of the same side (preferring the same species for `ENEMY_ONE`); if no living member exists on that side, the cast SHALL be skipped without consuming MP. Side membership SHALL be determined the same way regardless of whether the caster is party or monster.

#### Scenario: Party caster ENEMY_ONE targets one specific monster
- **WHEN** a Mage casts a fire spell with `target_type = ENEMY_ONE` at "Slime A"
- **THEN** the resolved target list SHALL contain exactly `["Slime A"]` (assuming alive)

#### Scenario: Monster caster ENEMY_ONE targets one specific party member
- **WHEN** a witch casts a fire spell with `target_type = ENEMY_ONE` at Fighter
- **THEN** the resolved target list SHALL contain exactly `[Fighter]` (assuming alive)

#### Scenario: Party caster ENEMY_GROUP targets all living monsters of one species
- **WHEN** a flame spell with `target_type = ENEMY_GROUP` is cast by a Mage at the "Slime" group, where 2 slimes and 1 goblin are alive
- **THEN** the resolved target list SHALL contain both slimes and SHALL NOT contain the goblin

#### Scenario: Monster caster ENEMY_GROUP fans out to all living party members
- **WHEN** a lich casts a flame spell with `target_type = ENEMY_GROUP` and all 4 party members are alive
- **THEN** the resolved target list SHALL contain all 4 party members (party has no species concept)

#### Scenario: ENEMY_GROUP omits dead members of the group
- **WHEN** a group spell is cast at "Slime" group with 3 slimes alive at command time, but 1 slime dies before the cast resolves
- **THEN** the resolved target list SHALL contain only the 2 still-living slimes

#### Scenario: Party caster ALLY_ALL targets every living party member
- **WHEN** an allheal spell is cast by a Priest on a party of 4, where 1 member is dead at resolution time
- **THEN** the resolved target list SHALL contain exactly the 3 living party members

#### Scenario: Monster caster ALLY_ALL targets every living monster
- **WHEN** an allheal spell is cast by a dark_priest with 4 monsters alive (including caster) and 1 monster dead
- **THEN** the resolved target list SHALL contain exactly the 4 living monsters (caster included)

#### Scenario: Monster caster ALLY_ONE heal targets a same-side monster
- **WHEN** a dark_priest casts a heal spell with `target_type = ALLY_ONE` at Imp (a same-side monster)
- **THEN** the resolved target list SHALL contain exactly `[Imp]` (assuming alive)

#### Scenario: Single-target retarget when party-side target is dead (party caster)
- **WHEN** a Mage casts a fire spell at "Slime A", but "Slime A" dies before resolution and "Slime B" (same species) is still alive
- **THEN** the cast SHALL retarget to "Slime B" and apply the effect there

#### Scenario: Single-target retarget when party-side target is dead (monster caster)
- **WHEN** a witch casts a fire spell at Fighter, but Fighter dies before resolution and Mage is still alive
- **THEN** the cast SHALL retarget to Mage and apply the effect there

#### Scenario: Cast is skipped when no valid target remains
- **WHEN** any caster (party or monster) casts a fire spell at the only remaining living member of the opposing side, but that target dies before resolution and no other opposing member is alive
- **THEN** the cast SHALL be skipped, MP SHALL NOT be consumed, and a log entry SHALL note the cancellation

### Requirement: Casting consumes MP via the caster's spend_mp interface

The system SHALL, before applying any spell effect, attempt to consume `spell.mp_cost` from the caster via `caster.spend_mp(spell.mp_cost)`. If the call returns `false` (insufficient MP), the cast SHALL be aborted and SHALL NOT apply any effect. The `caster` argument SHALL be any `CombatActor` — `PartyCombatant` or `MonsterCombatant` — and the call site SHALL NOT branch on caster type. Monster casters obey the same MP semantics as party casters.

#### Scenario: Sufficient MP allows the cast (party)
- **WHEN** a party caster with `current_mp = 5` casts a spell with `mp_cost = 2`
- **THEN** `spend_mp(2)` SHALL return `true`, the caster's `current_mp` SHALL become `3`, and the spell effect SHALL be applied to the resolved targets

#### Scenario: Sufficient MP allows the cast (monster)
- **WHEN** a monster caster with `current_mp = 5` casts a spell with `mp_cost = 2`
- **THEN** `spend_mp(2)` SHALL return `true`, the caster's `current_mp` SHALL become `3`, and the spell effect SHALL be applied to the resolved targets

#### Scenario: Insufficient MP aborts the cast (any caster)
- **WHEN** any caster with `current_mp = 1` attempts to cast a spell with `mp_cost = 2`
- **THEN** `spend_mp(2)` SHALL return `false`, the caster's `current_mp` SHALL remain `1`, and the spell effect SHALL NOT be applied to any target

## ADDED Requirements

### Requirement: Effect application is caster-side-agnostic

The system SHALL ensure that every `SpellEffect` subclass (`DamageSpellEffect`, `HealSpellEffect`, `StatusInflictSpellEffect`, `DamageWithStatusSpellEffect`, `CureStatusSpellEffect`, `StatModSpellEffect`) accepts any `CombatActor` as caster and any `Array` of `CombatActor` as targets without branching on whether the caster is a `PartyCombatant` or a `MonsterCombatant`. Effect resolution SHALL produce a `SpellResolution` whose `entries` reference the targets as supplied; the producer SHALL NOT special-case targets by side.

The existing event shapes (`damage`, `heal`, `inflict`, `cure`, `resist`, `stat_mod`, `tick_damage`, `wake`) SHALL be emitted with the same semantics regardless of caster side. Status inflicts produced by monster casters SHALL consult `target.get_resist(...)` exactly as for party casters.

#### Scenario: DamageSpellEffect applied by a monster damages party targets
- **WHEN** `DamageSpellEffect.apply(witch, [Fighter], spell_rng)` is called
- **THEN** Fighter SHALL take damage per the standard formula AND the SpellResolution entry SHALL contain `actor == Fighter` and a `damage` event with the rolled amount

#### Scenario: HealSpellEffect applied by a monster heals monster targets
- **WHEN** `HealSpellEffect.apply(dark_priest, [Imp], spell_rng)` is called with Imp at `current_hp = 5, max_hp = 16`
- **THEN** Imp's `current_hp` SHALL increase by the heal amount (clamped at `max_hp`) AND the SpellResolution entry SHALL contain a `heal` event

#### Scenario: StatusInflictSpellEffect applied by a monster consults party resists
- **WHEN** `StatusInflictSpellEffect.apply(witch, [Fighter], spell_rng)` is called with `status_id = &"sleep"`, and Fighter has `get_resist(&"sleep") == 0.4`
- **THEN** the effective inflict chance SHALL be `clamp(chance - 0.4, 0.0, 1.0)`, and the resulting entry SHALL contain `inflict` or `resist` per the roll
