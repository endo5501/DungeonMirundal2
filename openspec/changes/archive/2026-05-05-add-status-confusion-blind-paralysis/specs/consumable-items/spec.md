## ADDED Requirements

### Requirement: Holy water cures every status

The system SHALL ship `data/items/holy_water.tres` (`ItemData`) with:
- `item_name = "聖水"`
- `description = "全ての状態異常を癒す聖なる水。"`
- `consumable = true`, `stack_max = 3`, `price = 600`
- `effect`: `CureAllStatusItemEffect` with `scope = 2 (ALL)`
- `target_condition`: `alive_only`

#### Scenario: holy_water loads correctly
- **WHEN** the item repository is queried for `&"holy_water"`
- **THEN** the resource SHALL exist with the documented fields and `effect.scope == 2`

#### Scenario: holy_water removes every status from a target
- **WHEN** holy_water is used on a PartyCombatant holding `&"sleep"` and `&"poison"` and `&"blind"`
- **THEN** all three SHALL be cured and the inventory count SHALL decrement

#### Scenario: holy_water on a clean target fails
- **WHEN** holy_water is used on a target with no statuses
- **THEN** the use SHALL fail (no consumption)
