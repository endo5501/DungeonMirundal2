## ADDED Requirements

### Requirement: Item resources have category and equip_slot fields that match by convention
The shipped `.tres` Item resources SHALL declare `category` and `equip_slot` such that:
- `category == ItemCategory.WEAPON` ⟹ `equip_slot == Item.EquipSlot.WEAPON`
- `category == ItemCategory.ARMOR` ⟹ `equip_slot == Item.EquipSlot.ARMOR`
- `category == ItemCategory.HELMET` ⟹ `equip_slot == Item.EquipSlot.HELMET`
- `category == ItemCategory.SHIELD` ⟹ `equip_slot == Item.EquipSlot.SHIELD`
- `category == ItemCategory.GAUNTLET` ⟹ `equip_slot == Item.EquipSlot.GAUNTLET`
- `category == ItemCategory.ACCESSORY` ⟹ `equip_slot == Item.EquipSlot.ACCESSORY`
- `category == ItemCategory.CONSUMABLE` ⟹ `equip_slot == Item.EquipSlot.NONE`
- `category == ItemCategory.OTHER` ⟹ `equip_slot == Item.EquipSlot.NONE`

Validation of this invariant SHALL be performed by an asset-validation test that loads all `.tres` files under `data/items/` and asserts the relationship. The runtime SHALL NOT carry a `Item.is_slot_consistent()` method (removed) — instead, the invariant is enforced at data-load time during testing.

#### Scenario: Item ships with consistent category and equip_slot
- **WHEN** all `.tres` files under `data/items/` are loaded into ItemRepository
- **THEN** every Item's `(category, equip_slot)` SHALL match one of the pairings listed above

#### Scenario: No runtime is_slot_consistent method
- **WHEN** code attempts to call `item.is_slot_consistent()`
- **THEN** the method SHALL NOT exist on Item (the invariant is enforced at data-load time, not at runtime)
