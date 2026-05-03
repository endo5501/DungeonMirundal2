## Purpose
商店画面の購入・売却 UI と取引ルールを規定する。固定カタログ表示、所持ゴールドとの突合、購入確認・売却価格計算の挙動を対象とする。
## Requirements
### Requirement: ShopScreen is a town sub-screen with a fixed single-shop catalog
The system SHALL provide a `ShopScreen` (Control) that the player enters from TownScreen by selecting 「商店」. ShopScreen SHALL present a fixed, single-shop catalog sourced from a `ShopInventory` (RefCounted) that returns the same list of `Item` definitions for every visit. The catalog SHALL include both equipment items and consumable items. Equipment items SHALL be those Items whose `equip_slot != EquipSlot.NONE`; consumable items SHALL be those Items whose `category == ItemCategory.CONSUMABLE`. Items with `category == OTHER` and `equip_slot == NONE` SHALL be excluded.

#### Scenario: Entering the shop from town
- **WHEN** the player selects 「商店」 on TownScreen
- **THEN** ShopScreen SHALL be displayed

#### Scenario: Shop catalog is fixed across visits
- **WHEN** the player opens ShopScreen twice in a single game session with no purchases in between
- **THEN** the listed items SHALL be identical in both visits

#### Scenario: ShopInventory includes consumables
- **WHEN** `ShopInventory.get_stock()` is invoked on a repository containing `potion` (CONSUMABLE) and `long_sword` (WEAPON)
- **THEN** the returned list SHALL contain both items

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

This rule SHALL apply identically to equipment items and to consumable items.

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

#### Scenario: Consumable purchase creates identified consumable
- **WHEN** the player buys a `potion` (CONSUMABLE) with sufficient gold
- **THEN** the added ItemInstance SHALL have `identified == true` and its `item.category` SHALL be `CONSUMABLE`

### Requirement: Sell transaction pays half the item price and removes the instance
The system SHALL allow the player to sell any `ItemInstance` currently in `GameState.inventory` that is NOT equipped on any party character. A successful sale SHALL:
- remove the instance from `GameState.inventory`
- add `floor(item.price / 2)` gold to `GameState.inventory.gold`

Consumable items SHALL always be sellable (they cannot be equipped). Equipped checks SHALL apply only to equipment items.

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

#### Scenario: Consumables are always sellable
- **WHEN** a consumable ItemInstance exists in `GameState.inventory`
- **THEN** the sell list SHALL include that instance regardless of any party member's Equipment state

### Requirement: ShopScreen has no identify service in MVP
The system SHALL NOT provide an identify / 鑑定 action on ShopScreen during the MVP phase. All items in the shop SHALL be sold as already-identified.

#### Scenario: No identify option is shown
- **WHEN** ShopScreen is displayed
- **THEN** the top menu SHALL NOT include an identify option

#### Scenario: Shop items are pre-identified
- **WHEN** any item is purchased from the shop
- **THEN** the resulting ItemInstance SHALL have `identified == true`

### Requirement: ShopScreen categorizes the catalog via tabs

The system SHALL display the shop catalog under two category tabs: **[装備品]** and **[消費アイテム]**. The active tab SHALL determine which items are listed below. Switching tabs SHALL change only the displayed item list; it SHALL NOT alter gold, inventory, or the selected sub-mode (Buy/Sell).

#### Scenario: Buy mode shows tab bar
- **WHEN** the player enters Buy mode
- **THEN** the screen SHALL display a tab bar with `[装備品]` and `[消費アイテム]`, with one tab marked active

#### Scenario: Equipment tab shows only equippable items
- **WHEN** the player selects the `[装備品]` tab in Buy mode
- **THEN** the listed items SHALL be exactly those from `ShopInventory.get_stock()` whose `equip_slot != EquipSlot.NONE`

#### Scenario: Consumable tab shows only consumable items
- **WHEN** the player selects the `[消費アイテム]` tab in Buy mode
- **THEN** the listed items SHALL be exactly those from `ShopInventory.get_stock()` whose `category == ItemCategory.CONSUMABLE`

#### Scenario: Sell mode also uses the tab bar
- **WHEN** the player enters Sell mode
- **THEN** the tab bar SHALL be displayed, and each tab SHALL list only inventory items of its corresponding kind (equippable vs. consumable)

#### Scenario: Tab selection is input-driven
- **WHEN** the player presses the tab-switch input (e.g., Left/Right on the tab bar, or Tab key) on the shop
- **THEN** the active tab SHALL toggle and the item list below SHALL refresh accordingly

### Requirement: shop_screen はリスト操作を _handle_list_input ヘルパーで統合する
SHALL: `ShopScreen` の `_input_buy` と `_input_sell` は、共通ヘルパー `_handle_list_input(event, count, on_accept)` を介してリスト操作(ui_up/ui_down/ui_left/ui_right/ui_accept/ui_cancel)を処理する。`_input_buy` と `_input_sell` は `on_accept` のみが異なる薄いラッパーである。

#### Scenario: _input_buy と _input_sell の重複が解消される
- **WHEN** `shop_screen.gd` を grep で確認する
- **THEN** `_input_buy` および `_input_sell` の本体行数は それぞれ概ね 5〜10 行程度であり、共通の `_handle_list_input` ヘルパーを呼んでいる

#### Scenario: ui_left/ui_right で tab 切替
- **WHEN** Buy または Sell モード中に ui_left または ui_right が押される
- **THEN** `_toggle_tab()` が呼ばれ、_rebuild が走る(buy / sell どちらでも同じ挙動)

#### Scenario: ui_accept で対応する処理が走る
- **WHEN** Buy モード中に ui_accept が押される
- **THEN** `buy(catalog[_selected_index])` が呼ばれる

#### Scenario: ui_cancel で TOP_MENU に戻る
- **WHEN** Buy または Sell モード中に ui_cancel が押される
- **THEN** `_mode = Mode.TOP_MENU` となり、`_selected_index = 0` にリセット

