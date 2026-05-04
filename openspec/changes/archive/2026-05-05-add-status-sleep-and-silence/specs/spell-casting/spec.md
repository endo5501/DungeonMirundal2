## ADDED Requirements

### Requirement: ENEMY_GROUP status spells roll inflict per living member

When a `StatusInflictSpellEffect` is invoked from a spell whose `target_type == ENEMY_GROUP` (e.g. katino), the system SHALL perform an independent inflict roll for each living member resolved by the existing target-resolution rules. Each member SHALL produce its own `inflict` or `resist` event in the SpellResolution.

#### Scenario: katino rolls per slime
- **WHEN** katino is cast at a slime group with 3 living slimes, and the spell rng yields rolls `(20, 80, 40)` against a target whose `effective == 0.6`
- **THEN** the resulting SpellResolution SHALL contain 3 entries: 2 `inflict` events (rolls 20 and 40 succeed) and 1 `resist` event (roll 80 fails), with the corresponding slime statuses updated

### Requirement: OUTSIDE_OK CureStatusSpellEffect on a non-afflicted target produces no event

When a `CureStatusSpellEffect` is cast on a target that does not currently hold the named status (whether in battle on `CombatActor.statuses` or out of battle on `Character.persistent_statuses`), the system SHALL append no event for that target's entry in the SpellResolution. The cast SHALL still consume MP (the same as an existing `HealSpellEffect` cast on a fully-healed ally).

#### Scenario: dios on a clean ally consumes MP without event
- **WHEN** dios is cast on a non-sleeping ally
- **THEN** the caster's MP SHALL decrease by 2 and the SpellResolution entry's `events` SHALL be empty

#### Scenario: dios on a sleeping ally produces a cure event
- **WHEN** dios is cast on a sleeping ally
- **THEN** the entry SHALL contain `[{type: "cure", status_id: &"sleep"}]` and the ally's `statuses.has(&"sleep")` SHALL become `false`
