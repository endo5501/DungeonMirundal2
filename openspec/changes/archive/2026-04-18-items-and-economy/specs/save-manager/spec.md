## ADDED Requirements

### Requirement: SaveManager persists party inventory including gold and items
The system SHALL include the party-shared `Inventory` (gold and item list) in every save file and SHALL restore it on load. The save JSON SHALL contain an `"inventory"` object with `"gold": <int>` and `"items": Array[Dictionary]`, where each item dictionary is the result of `ItemInstance.to_dict()` (at least `{"item_id": ..., "identified": ...}`).

#### Scenario: Save writes inventory gold
- **WHEN** `save(1)` is called with `GameState.inventory.gold == 750`
- **THEN** `save_001.json` SHALL contain `inventory.gold == 750`

#### Scenario: Save writes inventory items in order
- **WHEN** `save(1)` is called with an inventory containing items A, B, C in that order
- **THEN** the `inventory.items` array in the saved JSON SHALL contain three dictionaries in that same order (A, B, C)

#### Scenario: Load restores inventory gold and items
- **WHEN** `load(1)` is called on a file with `inventory.gold == 750` and items A, B, C
- **THEN** `GameState.inventory.gold` SHALL equal `750` and `inventory.list()` SHALL return the restored ItemInstances in order A, B, C

#### Scenario: Load tolerates missing inventory key
- **WHEN** `load(1)` is called on a legacy save file that has no `inventory` key
- **THEN** the load SHALL succeed with `GameState.inventory.gold == 0` and an empty item list (no error)

### Requirement: SaveManager persists per-character equipment
The system SHALL include each Character's `Equipment` in the save file as part of the Character's serialized dictionary. Equipment SHALL be stored as a mapping of `slot_name: String -> index: int | null`, where `index` refers to the position in `inventory.items` of the equipped ItemInstance.

#### Scenario: Save writes equipment slot indices
- **WHEN** `save(1)` is called with a Character whose WEAPON slot holds the ItemInstance at `inventory.list()[0]` and whose ARMOR slot holds the one at `inventory.list()[2]`, other slots empty
- **THEN** the saved Character's `equipment` SHALL be `{"weapon": 0, "armor": 2, "helmet": null, "shield": null, "gauntlet": null, "accessory": null}`

#### Scenario: Load restores equipment slot references
- **WHEN** `load(1)` is called on a file with a Character having `equipment.weapon == 0`
- **THEN** the restored Character's `equipment.get_equipped(WEAPON)` SHALL point to the restored `inventory.list()[0]` ItemInstance (same object reference after restore)

#### Scenario: Load tolerates missing equipment key
- **WHEN** `load(1)` is called on a legacy save file where a Character lacks the `equipment` key
- **THEN** the load SHALL succeed with that Character having all six slots empty (no error)

### Requirement: SaveManager load order ensures inventory exists before character equipment
The system SHALL deserialize inventory before per-character equipment so that equipment indices can resolve into `inventory.list()`.

#### Scenario: Inventory is deserialized before Guild
- **WHEN** `load(slot)` processes the save JSON
- **THEN** the inventory SHALL be populated before any Character's equipment is restored, ensuring slot-index lookups succeed
