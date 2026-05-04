## Purpose
キャラクター装備スロット（武器・鎧・兜・盾・篭手・装飾品）と ItemInstance の装着／解除を規定する。スロット制約・職業制限・装備変更時の戻り値を対象とする。
## Requirements
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

### Requirement: Equipment.equip は can_equip を内部で呼んで重複を排除する
SHALL: `Equipment.equip(slot, instance, character)` の slot match と job allowed の check は、`Equipment.can_equip(item, slot, character)` を内部で呼ぶ形で実装される。`equip` は `can_equip` の結果が false の場合に詳細な FailReason を判定して返す。

#### Scenario: equip が can_equip を呼ぶ
- **WHEN** `equip(slot, instance, character)` が呼ばれる
- **THEN** 内部で `can_equip(instance.item, slot, character)` 相当のチェックロジックが共有され、重複したスロット/ジョブ判定コードは存在しない

#### Scenario: equip と can_equip の判定が一致する
- **WHEN** `can_equip` が false を返す任意の組み合わせで `equip` を呼ぶ
- **THEN** `equip` は失敗(success == false)を返す

#### Scenario: equip の FailReason は失敗事由を区別する
- **WHEN** slot mismatch で equip が失敗する
- **THEN** `EquipResult.reason == SLOT_MISMATCH`

#### Scenario: job not allowed で equip が失敗する
- **WHEN** job が allowed_jobs に含まれない状態で equip が呼ばれる
- **THEN** `EquipResult.reason == JOB_NOT_ALLOWED`

