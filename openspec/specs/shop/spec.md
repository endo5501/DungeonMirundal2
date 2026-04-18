## ADDED Requirements

### Requirement: ShopScreen is a town sub-screen with a fixed single-shop catalog
The system SHALL provide a `ShopScreen` (Control) that the player enters from TownScreen by selecting 「商店」. ShopScreen SHALL present a fixed, single-shop catalog sourced from a `ShopInventory` (RefCounted) that returns the same list of `Item` definitions for every visit.

#### Scenario: Entering the shop from town
- **WHEN** the player selects 「商店」 on TownScreen
- **THEN** ShopScreen SHALL be displayed

#### Scenario: Shop catalog is fixed across visits
- **WHEN** the player opens ShopScreen twice in a single game session with no purchases in between
- **THEN** the listed items SHALL be identical in both visits

### Requirement: ShopScreen offers Buy, Sell, and Exit modes
The system SHALL provide a top-level menu on ShopScreen with three entries: 「購入する」, 「売却する」, 「出る」. The player SHALL freely switch between Buy and Sell, and SHALL return to TownScreen via 「出る」 or ESC.

#### Scenario: Exit returns to town
- **WHEN** the player selects 「出る」 on the shop top menu
- **THEN** ShopScreen SHALL close and TownScreen SHALL be displayed

### Requirement: Buy transaction deducts gold and adds a fresh ItemInstance
The system SHALL allow the player to purchase any item listed in `ShopInventory` whose `price` is less than or equal to `GameState.inventory.gold`. A successful purchase SHALL:
- spend exactly `item.price` gold via `Inventory.spend_gold`
- create a new `ItemInstance` with `identified == true` wrapping the selected `Item`
- add that instance to `GameState.inventory`

Items with price greater than current gold SHALL be visually marked as unaffordable and SHALL NOT be purchasable (selection attempt produces an informational message, no state change).

#### Scenario: Successful purchase
- **WHEN** the party has 500G and the player buys an item with `price == 100`
- **THEN** `GameState.inventory.gold` SHALL equal `400` and a new `ItemInstance` for that Item SHALL be in `GameState.inventory.list()`

#### Scenario: Insufficient gold blocks purchase
- **WHEN** the party has 50G and the player selects an item with `price == 100`
- **THEN** the shop SHALL display a "ゴールドが足りません" (or equivalent) message and SHALL NOT change gold or inventory

#### Scenario: Purchased instance is identified
- **WHEN** any purchase succeeds
- **THEN** the newly added `ItemInstance` SHALL have `identified == true`

### Requirement: Sell transaction pays half the item price and removes the instance
The system SHALL allow the player to sell any `ItemInstance` currently in `GameState.inventory` that is NOT equipped on any party character. A successful sale SHALL:
- remove the instance from `GameState.inventory`
- add `floor(item.price / 2)` gold to `GameState.inventory.gold`

Items that are currently equipped on any party member SHALL NOT be listed as sellable (or SHALL be filtered out of the sell menu), and selection attempts SHALL be prevented.

#### Scenario: Sell pays half the buy price
- **WHEN** the player sells an ItemInstance of an Item with `price == 100`
- **THEN** `GameState.inventory.gold` SHALL increase by exactly `50`

#### Scenario: Sell floors on odd prices
- **WHEN** the player sells an ItemInstance of an Item with `price == 25`
- **THEN** `GameState.inventory.gold` SHALL increase by exactly `12`

#### Scenario: Equipped items are not sellable
- **WHEN** an ItemInstance is currently equipped in any party member's Equipment
- **THEN** the sell list SHALL NOT include that instance

#### Scenario: Sold instance is removed from inventory
- **WHEN** a sale succeeds for instance `X`
- **THEN** `GameState.inventory.contains(X)` SHALL return `false`

### Requirement: ShopScreen has no identify service in MVP
The system SHALL NOT provide an identify / 鑑定 action on ShopScreen during the MVP phase. All items in the shop SHALL be sold as already-identified.

#### Scenario: No identify option is shown
- **WHEN** ShopScreen is displayed
- **THEN** the top menu SHALL NOT include an identify option

#### Scenario: Shop items are pre-identified
- **WHEN** any item is purchased from the shop
- **THEN** the resulting ItemInstance SHALL have `identified == true`
