## MODIFIED Requirements

### Requirement: パーティサブメニュー項目の表示
パーティメニューは以下のサブ項目 SHALL を表示する:「ステータス」「アイテム」「装備」。MVP ではすべての項目が選択可能である（旧仕様で無効化されていた「アイテム」「装備」を有効化する）。

#### Scenario: パーティメニュー項目一覧
- **WHEN** メインメニューから「パーティ」を選択する
- **THEN** 以下の項目が表示される: 「ステータス」「アイテム」「装備」

#### Scenario: すべての項目が選択可能
- **WHEN** パーティメニューを開く
- **THEN** 「ステータス」「アイテム」「装備」すべてが有効状態で表示され、選択できる

#### Scenario: ステータスを選択
- **WHEN** 「ステータス」にカーソルを合わせてEnterキーを押す
- **THEN** パーティステータス表示画面が表示される

#### Scenario: アイテムを選択
- **WHEN** 「アイテム」にカーソルを合わせてEnterキーを押す
- **THEN** アイテム一覧表示画面（パーティ共有インベントリ）が表示される

#### Scenario: 装備を選択
- **WHEN** 「装備」にカーソルを合わせてEnterキーを押す
- **THEN** 装備変更画面が表示される（キャラクター選択から開始）

## ADDED Requirements

### Requirement: アイテム一覧ビューは所持品を閲覧できる
The system SHALL provide an item-list view under ESC メニュー > パーティ > アイテム that displays the entries of `GameState.inventory` (items and gold). The MVP view SHALL be read-only: it SHALL NOT provide any use/consume action on items.

#### Scenario: 所持ゴールドを表示
- **WHEN** アイテム一覧ビューを開く
- **THEN** 画面上部に `GameState.inventory.gold` の値が表示される

#### Scenario: 所持アイテムを一覧表示
- **WHEN** アイテム一覧ビューを開き、インベントリに3個のアイテムが入っている
- **THEN** すべての3個のアイテムが名前と分類（武器/鎧/... など）と共に表示される

#### Scenario: 装備中のアイテムに印を付ける
- **WHEN** 所持アイテムのうち1つが何らかのキャラに装備されている
- **THEN** 該当アイテムの行に装備中であることを示す印（例: 「装」マーク、装備者名）が表示される

#### Scenario: 使用ボタンは存在しない
- **WHEN** アイテム一覧ビューを表示する
- **THEN** 「使用」「使う」「Use」といったアクションは画面上に提供されない（MVP）

#### Scenario: ESCで前画面に戻る
- **WHEN** アイテム一覧ビュー表示中にESCキーを押す
- **THEN** パーティサブメニューに戻る

### Requirement: 装備ビューで装備の変更ができる
The system SHALL provide an equipment view under ESC メニュー > パーティ > 装備 that SHALL allow the player to pick a character, see their six slots (武器 / 鎧 / 兜 / 盾 / 籠手 / 装身具), and equip or unequip items from `GameState.inventory`. The view SHALL enforce the equip rules (slot type match and `allowed_jobs` match) defined by the equipment capability.

#### Scenario: キャラクター選択
- **WHEN** 装備ビューを開く
- **THEN** パーティメンバーの一覧が表示され、いずれかを選択できる

#### Scenario: スロット一覧の表示
- **WHEN** キャラクターを選択する
- **THEN** 6スロット（武器 / 鎧 / 兜 / 盾 / 籠手 / 装身具）が表示され、各スロットに現在装備しているアイテム名または「なし」が表示される

#### Scenario: 装備候補の表示（職業制限を反映）
- **WHEN** スロットを選択する
- **THEN** インベントリから「対応する equip_slot を持ち、`allowed_jobs` に対象キャラの職業を含むアイテム」が候補として表示され、それ以外はグレーアウトまたは非表示となる

#### Scenario: 装備変更の反映
- **WHEN** 候補からアイテムを選んで確定する
- **THEN** `character.equipment.equip(slot, instance, character)` が呼ばれ、該当スロットのアイテムが更新される（既存アイテムはインベントリに残る）

#### Scenario: 装備解除
- **WHEN** スロット選択時に「はずす」を選択する
- **THEN** `character.equipment.unequip(slot)` が呼ばれ、スロットは空になる（アイテムはインベントリに残る）

#### Scenario: ESCで1階層戻る
- **WHEN** 装備ビューのいずれかの階層（キャラクター選択 / スロット選択 / 候補選択）でESCを押す
- **THEN** 1階層上に戻る（最上位ではパーティサブメニューに戻る）
