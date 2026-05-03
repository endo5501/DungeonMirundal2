## MODIFIED Requirements

### Requirement: Equipment provides six slots per character
The system SHALL provide an `Equipment` (RefCounted) object attached to each `Character` via `character.equipment`. `Equipment` SHALL manage six named slots identified by the `Item.EquipSlot` enum values WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY (i.e., all `Item.EquipSlot` values EXCEPT `NONE`). Each slot SHALL hold at most one `ItemInstance` or `null` when empty. The previously separate `Equipment.EquipSlot` enum SHALL no longer exist; `Item.EquipSlot` is the single source of truth for slot identification.

#### Scenario: Fresh equipment has all slots empty
- **WHEN** a new `Equipment` is created
- **THEN** `get_equipped(slot)` SHALL return `null` for every one of the six slots in `Equipment.ALL_SLOTS`

#### Scenario: Character exposes equipment
- **WHEN** a `Character` is instantiated
- **THEN** `character.equipment` SHALL be a non-null `Equipment` object

#### Scenario: ALL_SLOTS uses Item.EquipSlot values
- **WHEN** code references `Equipment.ALL_SLOTS`
- **THEN** the array SHALL contain exactly `[Item.EquipSlot.WEAPON, Item.EquipSlot.ARMOR, Item.EquipSlot.HELMET, Item.EquipSlot.SHIELD, Item.EquipSlot.GAUNTLET, Item.EquipSlot.ACCESSORY]`

### Requirement: equip places an ItemInstance into a slot if allowed
The system SHALL provide `Equipment.equip(slot: int, instance: ItemInstance, character: Character) -> EquipResult` that places `instance` into `slot` only when the following are all true:
- `slot` is one of `Item.EquipSlot.WEAPON` ... `Item.EquipSlot.ACCESSORY` (i.e., NOT `NONE`)
- `instance.item.equip_slot == slot` (the item's declared slot matches the target slot)
- `character.job.job_name` is in `instance.item.allowed_jobs`

On success, the method SHALL return an `EquipResult` with `success == true` and `previous == <ItemInstance that was previously in the slot, or null>`. On failure, it SHALL return `success == false` with `reason` set to one of `SLOT_MISMATCH`, `JOB_NOT_ALLOWED`. Passing `slot == Item.EquipSlot.NONE` SHALL be treated as `SLOT_MISMATCH`.

#### Scenario: Equip succeeds when slot and job match
- **WHEN** a Fighter character equips an Item whose `equip_slot == Item.EquipSlot.WEAPON` and whose `allowed_jobs` contains `Fighter`
- **THEN** the result SHALL have `success == true` and `get_equipped(Item.EquipSlot.WEAPON)` SHALL return that instance

#### Scenario: Caller can pass item.equip_slot directly
- **WHEN** the caller invokes `equipment.equip(item.equip_slot, instance, character)` where `item.equip_slot` is `Item.EquipSlot.WEAPON`
- **THEN** the call SHALL succeed equivalently to passing `Item.EquipSlot.WEAPON` as a literal (no conversion helper is required)

#### Scenario: Previous item is returned on replacement
- **WHEN** the WEAPON slot already holds instance A and `equip(Item.EquipSlot.WEAPON, B, character)` succeeds
- **THEN** the result SHALL have `success == true` and `previous == A`

#### Scenario: Equip fails when slot mismatches item type
- **WHEN** an Item with `equip_slot == Item.EquipSlot.WEAPON` is equipped into `Item.EquipSlot.ARMOR` slot
- **THEN** the result SHALL have `success == false` and `reason == SLOT_MISMATCH`, and the ARMOR slot SHALL remain unchanged

#### Scenario: Equip fails when slot is NONE
- **WHEN** `equip(Item.EquipSlot.NONE, instance, character)` is called
- **THEN** the result SHALL have `success == false` and `reason == SLOT_MISMATCH`

#### Scenario: Equip fails when job is not allowed
- **WHEN** a Mage character attempts to equip an Item whose `allowed_jobs` does not contain `Mage`
- **THEN** the result SHALL have `success == false` and `reason == JOB_NOT_ALLOWED`, and the targeted slot SHALL remain unchanged

## REMOVED Requirements

### Requirement: Equipment provides slot_from_item_slot conversion helper
**Reason**: With `Item.EquipSlot` as the single source of truth, `Equipment.EquipSlot` no longer exists, so no conversion helper between two enums is needed. Callers pass `Item.EquipSlot` values directly to `Equipment.equip` / `unequip` / `get_equipped`.

**Migration**: All call sites of `Equipment.slot_from_item_slot(item.equip_slot)` SHALL be replaced with `item.equip_slot` directly.
