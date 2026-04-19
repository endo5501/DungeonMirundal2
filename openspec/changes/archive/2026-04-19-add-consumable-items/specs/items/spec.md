## MODIFIED Requirements

### Requirement: Item defines a static item template
The system SHALL provide an `Item` Custom Resource (`class_name Item extends Resource`) that defines a static, immutable item template loaded from `.tres` files under `data/items/`.

An `Item` SHALL expose the following fields: `item_id: StringName`, `item_name: String`, `unidentified_name: String`, `category: ItemCategory` (enum: WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY, **CONSUMABLE**, OTHER), `equip_slot: EquipSlot` (enum: NONE, WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY), `allowed_jobs: Array[StringName]`, `attack_bonus: int`, `defense_bonus: int`, `agility_bonus: int`, `price: int`, `effect: ItemEffect` (may be null), `context_conditions: Array[ContextCondition]` (may be empty), `target_conditions: Array[TargetCondition]` (may be empty).

The `CONSUMABLE` category SHALL be used for items that can be used (consumed) to produce a runtime effect. Consumable items SHALL have `equip_slot == EquipSlot.NONE` and SHALL have a non-null `effect`. Non-consumable items MAY leave `effect` null and `context_conditions` / `target_conditions` empty.

#### Scenario: Item carries required fields
- **WHEN** an `Item` resource is created with all declared fields set
- **THEN** every field SHALL be readable and typed consistently with its declaration

#### Scenario: Non-equippable items use EquipSlot.NONE
- **WHEN** an `Item` has `category == OTHER` or `category == CONSUMABLE`
- **THEN** `equip_slot` SHALL be `EquipSlot.NONE`

#### Scenario: Equippable items have a matching equip_slot
- **WHEN** an `Item` has `category == WEAPON`
- **THEN** `equip_slot` SHALL be `EquipSlot.WEAPON`

#### Scenario: Consumable items have a non-null effect
- **WHEN** an `Item` has `category == CONSUMABLE`
- **THEN** its `effect` field SHALL be a non-null `ItemEffect` instance

#### Scenario: Non-consumable items may omit effect and conditions
- **WHEN** an `Item` has `category == WEAPON`
- **THEN** `effect` MAY be null, `context_conditions` SHALL be an empty array, and `target_conditions` SHALL be an empty array

### Requirement: Item data directory contains at least one item per equip slot for MVP
The system SHALL ship initial `.tres` item definitions covering at minimum one item per `EquipSlot` (WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY) so that the shop, initial equipment, and equipment UI are functional. Additionally, the system SHALL ship at least one `CONSUMABLE` item so that the consumable-items flow is exercisable from a fresh game.

#### Scenario: Each equip slot has at least one item
- **WHEN** `DataLoader.load_all_items()` is invoked on the shipped `data/items/` directory
- **THEN** the resulting ItemRepository SHALL return at least one Item for each of the six equip slots (WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY)

#### Scenario: At least one consumable ships
- **WHEN** `DataLoader.load_all_items()` is invoked on the shipped `data/items/` directory
- **THEN** the resulting ItemRepository SHALL return at least one Item with `category == CONSUMABLE`
