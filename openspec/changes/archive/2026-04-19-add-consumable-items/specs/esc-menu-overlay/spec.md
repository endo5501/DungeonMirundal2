## MODIFIED Requirements

### Requirement: アイテム一覧ビューは所持品を閲覧できる
The system SHALL provide an item-list view under ESC メニュー > パーティ > アイテム that displays the entries of `GameState.inventory` (items and gold). Consumable items (`item.category == CONSUMABLE`) in the list SHALL be usable via a "使う" action on the currently highlighted row. Non-consumable (equipment) items SHALL remain read-only in this view.

Using a consumable SHALL invoke the use flow defined by the consumable-items capability:

1. Build an `ItemUseContext` reflecting the current game state (`is_in_dungeon`, `is_in_combat = false` for this view, and the active party).
2. Check every `item.context_conditions` entry. If any returns `false`, the row SHALL be displayed in a grayed / disabled style with the failing condition's `reason()` visible or surfaced on attempt; the use action SHALL NOT proceed.
3. If `item.target_conditions` is non-empty, the view SHALL open a target-selection sub-UI listing the party members. Members failing any `target_conditions.is_satisfied(member, ctx)` SHALL be grayed out and non-selectable; the corresponding `reason()` SHALL be surfaced on attempt.
4. If `item.target_conditions` is empty, the view SHALL prompt a "使いますか？" yes/no confirmation and skip target selection.
5. On confirmation, `Inventory.use_item(instance, targets, ctx)` SHALL be called.
6. On `result.success == true`, the inventory list SHALL refresh (the used instance removed), and any effect-specific follow-up (e.g., town transition for `EscapeToTownEffect`) SHALL occur.
7. On `result.success == false`, the inventory SHALL be unchanged and the result `message` SHALL be displayed to the player.

#### Scenario: 所持ゴールドを表示
- **WHEN** アイテム一覧ビューを開く
- **THEN** 画面上部に `GameState.inventory.gold` の値が表示される

#### Scenario: 所持アイテムを一覧表示
- **WHEN** アイテム一覧ビューを開き、インベントリに3個のアイテムが入っている
- **THEN** すべての3個のアイテムが名前と分類（武器/鎧/消費アイテム/... など）と共に表示される

#### Scenario: 装備中のアイテムに印を付ける
- **WHEN** 所持アイテムのうち1つが何らかのキャラに装備されている
- **THEN** 該当アイテムの行に装備中であることを示す印（例: 「装」マーク、装備者名）が表示される

#### Scenario: ESCで前画面に戻る
- **WHEN** アイテム一覧ビュー表示中にESCキーを押す
- **THEN** パーティサブメニューに戻る

#### Scenario: 消費アイテム行に使用アクションがある
- **WHEN** インベントリに `potion` (CONSUMABLE) が含まれる状態でアイテム一覧ビューを開き、その行にカーソルを合わせる
- **THEN** 「使う」アクションが提示される（例: 決定キーで発動する）

#### Scenario: 装備アイテム行に使用アクションはない
- **WHEN** インベントリに `long_sword` (WEAPON) が含まれる状態でアイテム一覧ビューを開き、その行にカーソルを合わせる
- **THEN** 「使う」アクションは提示されない（読み取り専用）

#### Scenario: Context 条件を満たさない消費アイテムはグレーアウト
- **WHEN** 町画面で ESC → アイテム一覧ビューを開き、`escape_scroll` (InDungeonOnly) が存在する
- **THEN** その行はグレー表示となり、使用を試みるとコンテキスト失敗の理由が表示され、インベントリは変化しない

#### Scenario: HP 満タンのメンバーは対象選択でグレーアウト
- **WHEN** ダンジョン内で `potion` を使用し、対象選択画面に HP 満タンのメンバーが存在する
- **THEN** 該当メンバー行はグレー表示となり、選択しても「NotFullHp」の理由が表示され、ポーションは消費されない

#### Scenario: 対象条件を持たない消費アイテムは確認のみで使える
- **WHEN** ダンジョン内で `escape_scroll` を使用する
- **THEN** 対象選択は表示されず、「使いますか？」の確認のみが表示され、確定後に町への帰還が発動する

#### Scenario: 使用成功でインスタンスが除去される
- **WHEN** ポーションを HP 不足のメンバーに使用して成功する
- **THEN** 使用した `ItemInstance` が `GameState.inventory.list()` から除去される
