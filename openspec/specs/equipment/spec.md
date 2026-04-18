## ADDED Requirements

### Requirement: Equipment provides six slots per character
The system SHALL provide an `Equipment` (RefCounted) object attached to each `Character` via `character.equipment`. `Equipment` SHALL manage six named slots identified by the `EquipSlot` enum (WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY). Each slot SHALL hold at most one `ItemInstance` or `null` when empty.

#### Scenario: Fresh equipment has all slots empty
- **WHEN** a new `Equipment` is created
- **THEN** `get_equipped(slot)` SHALL return `null` for every one of the six slots

#### Scenario: Character exposes equipment
- **WHEN** a `Character` is instantiated
- **THEN** `character.equipment` SHALL be a non-null `Equipment` object

### Requirement: equip places an ItemInstance into a slot if allowed
The system SHALL provide `Equipment.equip(slot: EquipSlot, instance: ItemInstance, character: Character) -> EquipResult` that places `instance` into `slot` only when the following are all true:
- `instance.item.equip_slot == slot`
- `character.job.job_name` is in `instance.item.allowed_jobs`

On success, the method SHALL return an `EquipResult` with `success == true` and `previous == <ItemInstance that was previously in the slot, or null>`. On failure, it SHALL return `success == false` with `reason` set to one of `SLOT_MISMATCH`, `JOB_NOT_ALLOWED`.

#### Scenario: Equip succeeds when slot and job match
- **WHEN** a Fighter character equips an Item whose `equip_slot == WEAPON` and whose `allowed_jobs` contains `Fighter`
- **THEN** the result SHALL have `success == true` and `get_equipped(WEAPON)` SHALL return that instance

#### Scenario: Previous item is returned on replacement
- **WHEN** the WEAPON slot already holds instance A and `equip(WEAPON, B, character)` succeeds
- **THEN** the result SHALL have `success == true` and `previous == A`

#### Scenario: Equip fails when slot mismatches item type
- **WHEN** an Item with `equip_slot == WEAPON` is equipped into `ARMOR` slot
- **THEN** the result SHALL have `success == false` and `reason == SLOT_MISMATCH`, and the ARMOR slot SHALL remain unchanged

#### Scenario: Equip fails when job is not allowed
- **WHEN** a Mage character attempts to equip an Item whose `allowed_jobs` does not contain `Mage`
- **THEN** the result SHALL have `success == false` and `reason == JOB_NOT_ALLOWED`, and the targeted slot SHALL remain unchanged

### Requirement: unequip clears a slot and returns the previous item
The system SHALL provide `Equipment.unequip(slot: EquipSlot) -> ItemInstance` that removes and returns whatever was in `slot`, or `null` if the slot was empty.

#### Scenario: Unequip returns the previously equipped item
- **WHEN** a slot holds instance `X` and `unequip(slot)` is called
- **THEN** the method SHALL return `X` and `get_equipped(slot)` SHALL return `null`

#### Scenario: Unequip on empty slot returns null
- **WHEN** a slot is empty and `unequip(slot)` is called
- **THEN** the method SHALL return `null`

### Requirement: all_equipped enumerates non-null slots
The system SHALL provide `Equipment.all_equipped() -> Array[ItemInstance]` that returns every non-null `ItemInstance` currently placed in any of the six slots.

#### Scenario: Returns only non-null slots
- **WHEN** a character has WEAPON and ARMOR equipped and the other four slots empty
- **THEN** `all_equipped()` SHALL return an array of exactly those two instances

### Requirement: Equipment serializes via inventory indices
The system SHALL provide `Equipment.to_dict(inventory: Inventory) -> Dictionary` that emits `{<slot_name_string>: <index_in_inventory_or_null>}` where each index refers to the position of the equipped ItemInstance within `inventory.list()`. The system SHALL provide `Equipment.from_dict(data: Dictionary, inventory: Inventory) -> Equipment` that restores slots by resolving indices into the inventory.

Equipped items SHALL be stored in the party inventory in the MVP (i.e., equipping an item does NOT remove it from the inventory list; it only marks which `ItemInstance` occupies which slot).

#### Scenario: Round-trip preserves slot assignments
- **WHEN** an Equipment with WEAPON == inventory[0], ARMOR == inventory[2] is serialized and restored
- **THEN** the restored Equipment SHALL have WEAPON pointing to the same ItemInstance at inventory[0] and ARMOR at inventory[2]

#### Scenario: Missing equipment key defaults to empty
- **WHEN** `Equipment.from_dict({}, inventory)` is called with no slots set
- **THEN** every slot SHALL be `null`

#### Scenario: Equipped items remain in inventory list
- **WHEN** an ItemInstance is equipped to a character's WEAPON slot
- **THEN** `inventory.contains(instance)` SHALL still return `true`
