## ADDED Requirements

### Requirement: Antidote cures poison

The system SHALL ship `data/items/antidote.tres` (`ItemData`) with:
- `item_name = "解毒草"`
- `description = "毒を中和する薬草。"`
- `consumable = true`, `stack_max = 5`, `price = 100`
- `effect`: `CureStatusItemEffect` with `status_id = &"poison"`
- `target_condition`: `alive_only`
- Usable both in battle (target a PartyCombatant) and outside battle (target a Character via persistent_statuses)

#### Scenario: antidote loads correctly
- **WHEN** the item repository is queried for `&"antidote"`
- **THEN** the resource SHALL exist with the documented fields

#### Scenario: antidote in battle removes poison from a PartyCombatant
- **WHEN** antidote is used on a PartyCombatant whose `statuses.has(&"poison") == true`
- **THEN** the entry SHALL be cured and the inventory count SHALL decrement

#### Scenario: antidote out of battle removes poison from Character
- **WHEN** antidote is used on a Character whose `persistent_statuses` contains `&"poison"`
- **THEN** the id SHALL be removed and the inventory count SHALL decrement

#### Scenario: antidote on a clean target fails gracefully
- **WHEN** antidote is used on a target without poison
- **THEN** the use SHALL fail (no consumption, message indicates "効果がない")

### Requirement: Golden Needle cures petrify

The system SHALL ship `data/items/golden_needle.tres` (`ItemData`) with:
- `item_name = "金の針"`
- `description = "石化した仲間を元に戻す貴重な針。"`
- `consumable = true`, `stack_max = 1`, `price = 1500`
- `effect`: `CureStatusItemEffect` with `status_id = &"petrify"`
- `target_condition`: `alive_only`

#### Scenario: golden_needle loads correctly
- **WHEN** the item repository is queried for `&"golden_needle"`
- **THEN** the resource SHALL exist with the documented fields

#### Scenario: golden_needle removes petrify
- **WHEN** golden_needle is used on a petrified party member
- **THEN** the petrify status SHALL be removed and the inventory count SHALL decrement
