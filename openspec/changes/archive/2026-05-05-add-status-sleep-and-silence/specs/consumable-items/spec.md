## ADDED Requirements

### Requirement: Wake powder cures sleep

The system SHALL ship `data/items/wake_powder.tres` (`ItemData` with category `consumable`) with the following properties:
- `item_name = "覚醒の粉"`
- `description = "眠っている仲間を目覚めさせる粉。"`
- `consumable = true`
- `stack_max = 5`
- `effect`: `CureStatusItemEffect` with `status_id = &"sleep"`
- `target_condition`: `alive_only` (cannot be used on a dead character)
- Usable both in battle and outside battle (`ItemUseContext.in_battle` either value)
- Target type: single ally

#### Scenario: wake_powder is loaded as a consumable item
- **WHEN** the item repository is loaded
- **THEN** `wake_powder.tres` SHALL be present and `effect` SHALL be a `CureStatusItemEffect` with `status_id == &"sleep"`

#### Scenario: wake_powder removes sleep in battle
- **WHEN** wake_powder is used on a sleeping PartyCombatant during battle
- **THEN** the combatant's `statuses.has(&"sleep")` SHALL become `false` and the inventory SHALL decrement the consumable count

#### Scenario: wake_powder on a clean target fails gracefully
- **WHEN** wake_powder is used on a target that is not sleeping
- **THEN** the use SHALL fail (no consumption) and the message SHALL indicate "効果がない"
