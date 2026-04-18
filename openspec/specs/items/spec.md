## Purpose
ItemData リソースと ItemInstance（個別の所持アイテム）のデータモデルを規定する。装備可否・消費型・価格・使用効果・職業制限などメタデータを対象とする。

## Requirements

### Requirement: Item defines a static item template
The system SHALL provide an `Item` Custom Resource (`class_name Item extends Resource`) that defines a static, immutable item template loaded from `.tres` files under `data/items/`.

An `Item` SHALL expose the following fields: `item_id: StringName`, `item_name: String`, `unidentified_name: String`, `category: ItemCategory` (enum: WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY, OTHER), `equip_slot: EquipSlot` (enum: NONE, WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY), `allowed_jobs: Array[StringName]`, `attack_bonus: int`, `defense_bonus: int`, `agility_bonus: int`, `price: int`.

#### Scenario: Item carries required fields
- **WHEN** an `Item` resource is created with all declared fields set
- **THEN** every field SHALL be readable and typed consistently with its declaration

#### Scenario: Non-equippable items use EquipSlot.NONE
- **WHEN** an `Item` has `category == OTHER`
- **THEN** `equip_slot` SHALL be `EquipSlot.NONE`

#### Scenario: Equippable items have a matching equip_slot
- **WHEN** an `Item` has `category == WEAPON`
- **THEN** `equip_slot` SHALL be `EquipSlot.WEAPON`

### Requirement: ItemRepository loads and exposes items by id
The system SHALL provide an `ItemRepository` (RefCounted) that exposes item lookup by `item_id` via `find(item_id: StringName) -> Item` and a full listing via `all() -> Array[Item]`. A factory `DataLoader.load_all_items() -> ItemRepository` SHALL populate the repository from every `.tres` file under `data/items/`.

#### Scenario: Lookup existing item
- **WHEN** an ItemRepository is populated with an Item whose `item_id == &"long_sword"`
- **THEN** `find(&"long_sword")` SHALL return that Item

#### Scenario: Lookup missing item
- **WHEN** ItemRepository is queried for an `item_id` not present
- **THEN** `find(item_id)` SHALL return `null`

#### Scenario: Bulk load from data directory
- **WHEN** `DataLoader.load_all_items()` is invoked
- **THEN** every `.tres` file under `data/items/` SHALL be present in the returned ItemRepository

#### Scenario: ItemRepository is accessible via GameState
- **WHEN** any script references `GameState.item_repository`
- **THEN** it SHALL resolve to the singleton ItemRepository populated at startup

### Requirement: ItemInstance represents a runtime item with identification state
The system SHALL provide `ItemInstance` (RefCounted) that wraps an `Item` definition with per-instance runtime state. An `ItemInstance` SHALL expose `item: Item` and `identified: bool`.

In the MVP, all `ItemInstance` objects SHALL be created with `identified = true` by production code paths (shop purchase, initial equipment, save restore). The `identified` flag SHALL be preserved and restored by serialization to support future unidentified-item features without a data migration.

#### Scenario: ItemInstance created from Item
- **WHEN** an `ItemInstance` is constructed with a given `Item` and `identified = true`
- **THEN** `instance.item` SHALL return the given Item and `instance.identified` SHALL be `true`

#### Scenario: Multiple instances of the same Item are distinct
- **WHEN** two `ItemInstance` are created from the same `Item`
- **THEN** they SHALL be distinct objects (different RefCounted references)

#### Scenario: Shop purchases create identified instances
- **WHEN** the shop creates an ItemInstance through purchase
- **THEN** the created instance SHALL have `identified == true`

### Requirement: ItemInstance serializes via item_id and identified flag
The system SHALL serialize an `ItemInstance` through `to_dict() -> Dictionary` emitting at least `{"item_id": <StringName>, "identified": <bool>}`, and SHALL restore an instance via `ItemInstance.from_dict(data: Dictionary, repository: ItemRepository) -> ItemInstance` that resolves the `Item` reference from the repository.

#### Scenario: to_dict emits item_id and identified
- **WHEN** an ItemInstance wrapping an Item with `item_id == &"long_sword"` and `identified = true` is serialized
- **THEN** the returned Dictionary SHALL contain `item_id == &"long_sword"` and `identified == true`

#### Scenario: from_dict resolves Item via repository
- **WHEN** `ItemInstance.from_dict({"item_id": &"long_sword", "identified": true}, repository)` is called and the repository contains `long_sword`
- **THEN** the returned ItemInstance SHALL have `instance.item` equal to that Item and `instance.identified == true`

#### Scenario: from_dict returns null for missing item_id
- **WHEN** `ItemInstance.from_dict({"item_id": &"unknown"}, repository)` is called and the repository does not contain `unknown`
- **THEN** the method SHALL return `null` (caller handles missing data)

### Requirement: Item data directory contains at least one item per equip slot for MVP
The system SHALL ship initial `.tres` item definitions covering at minimum one item per `EquipSlot` (WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY) so that the shop, initial equipment, and equipment UI are functional.

#### Scenario: Each equip slot has at least one item
- **WHEN** `DataLoader.load_all_items()` is invoked on the shipped `data/items/` directory
- **THEN** the resulting ItemRepository SHALL return at least one Item for each of the six equip slots (WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY)
