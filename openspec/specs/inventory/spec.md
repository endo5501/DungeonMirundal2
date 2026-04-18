## ADDED Requirements

### Requirement: Inventory is a party-shared bag of ItemInstance
The system SHALL provide an `Inventory` (RefCounted) that holds a single list of `ItemInstance` shared across the entire party. Items are added via `add(instance: ItemInstance)`, removed via `remove(instance: ItemInstance) -> bool`, queried for presence via `contains(instance: ItemInstance) -> bool`, and enumerated via `list() -> Array[ItemInstance]` (returning a defensive copy).

#### Scenario: add appends to the list
- **WHEN** `inventory.add(instance)` is called on an empty inventory
- **THEN** `inventory.list()` SHALL contain exactly that `instance`

#### Scenario: remove returns true for existing items
- **WHEN** `inventory.remove(instance)` is called for an instance that was previously added
- **THEN** the method SHALL return `true` and `inventory.contains(instance)` SHALL be `false`

#### Scenario: remove returns false for missing items
- **WHEN** `inventory.remove(instance)` is called for an instance that is not present
- **THEN** the method SHALL return `false` and the inventory SHALL be unchanged

#### Scenario: list returns a defensive copy
- **WHEN** `inventory.list()` is called and the returned array is mutated
- **THEN** subsequent calls to `inventory.list()` SHALL NOT reflect the external mutation

### Requirement: Inventory has no capacity limit in MVP
The system SHALL impose no upper bound on the number of items stored in `Inventory` during the MVP phase. `add` SHALL always succeed and SHALL NOT raise or reject.

#### Scenario: Large additions do not fail
- **WHEN** 100 ItemInstance are added to an Inventory in sequence
- **THEN** every call SHALL succeed and `inventory.list().size()` SHALL equal 100

### Requirement: Inventory holds party-shared gold
The system SHALL expose `Inventory.gold: int` representing a party-shared currency pool. `add_gold(amount: int)` SHALL increment `gold`. `spend_gold(amount: int) -> bool` SHALL decrement `gold` by `amount` and return `true` only if the balance was sufficient; otherwise it SHALL leave `gold` unchanged and return `false`.

#### Scenario: add_gold increases balance
- **WHEN** an Inventory with `gold == 100` receives `add_gold(50)`
- **THEN** `inventory.gold` SHALL equal `150`

#### Scenario: spend_gold succeeds when balance is sufficient
- **WHEN** an Inventory with `gold == 100` receives `spend_gold(40)`
- **THEN** the method SHALL return `true` and `inventory.gold` SHALL equal `60`

#### Scenario: spend_gold fails when balance is insufficient
- **WHEN** an Inventory with `gold == 30` receives `spend_gold(50)`
- **THEN** the method SHALL return `false` and `inventory.gold` SHALL still equal `30`

#### Scenario: Negative amount is rejected
- **WHEN** `add_gold(-10)` or `spend_gold(-10)` is called
- **THEN** the method SHALL leave `gold` unchanged (spend_gold returning `false`)

### Requirement: Inventory is accessible via GameState
The system SHALL hold the party-shared Inventory as `GameState.inventory`, populated at `new_game()` and persisted/restored via save/load.

#### Scenario: New game resets inventory
- **WHEN** `GameState.new_game()` is called
- **THEN** `GameState.inventory` SHALL be a new empty Inventory with `gold == 500`

#### Scenario: Inventory persists across screens
- **WHEN** an item is added to `GameState.inventory` in TownScreen and the player navigates to DungeonScreen and back
- **THEN** the item SHALL still be present in `GameState.inventory`

### Requirement: Inventory serializes to and restores from a Dictionary
The system SHALL provide `Inventory.to_dict() -> Dictionary` that emits `{"gold": <int>, "items": <Array[Dictionary]>}` where each item entry is the result of `ItemInstance.to_dict()`. The system SHALL provide `Inventory.from_dict(data: Dictionary, repository: ItemRepository) -> Inventory` that restores gold and items, preserving the array order so index-based equipment references remain valid.

#### Scenario: Round-trip preserves gold
- **WHEN** an Inventory with `gold == 250` is serialized and restored
- **THEN** the restored Inventory SHALL have `gold == 250`

#### Scenario: Round-trip preserves item order
- **WHEN** an Inventory contains items A, B, C in that order and is serialized and restored
- **THEN** `inventory.list()` after restore SHALL return items in the same order (A, B, C)

#### Scenario: Missing inventory key defaults to empty
- **WHEN** `Inventory.from_dict({}, repository)` is called with no keys
- **THEN** the returned Inventory SHALL have `gold == 0` and `list().is_empty() == true`
