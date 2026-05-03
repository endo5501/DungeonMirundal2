## Purpose
ダンジョンから地上（町）へ帰還するフローとトリガ条件を規定する。帰還時のセーブ状態更新、パーティ全滅／撤退コマンド／階段復帰など複数ルートを対象とする。
## Requirements
### Requirement: START tile triggers return dialog
DungeonScreen SHALL detect when the player moves onto the START tile and display a confirmation dialog asking "地上に戻りますか？" with options "はい" and "いいえ".

#### Scenario: Moving onto START tile shows dialog
- **WHEN** the player moves onto the START tile
- **THEN** a confirmation dialog SHALL be displayed with text "地上に戻りますか？"

#### Scenario: Dialog has yes and no options
- **WHEN** the return confirmation dialog is displayed
- **THEN** it SHALL show "はい" and "いいえ" as selectable options

### Requirement: Confirming return emits signal
DungeonScreen SHALL emit a `return_to_town` signal when the player selects "はい" on the return confirmation dialog.

#### Scenario: Select yes to return
- **WHEN** the player selects "はい" on the return dialog
- **THEN** the `return_to_town` signal SHALL be emitted

### Requirement: Canceling return continues exploration
DungeonScreen SHALL close the return dialog and resume normal exploration when the player selects "いいえ".

#### Scenario: Select no to continue
- **WHEN** the player selects "いいえ" on the return dialog
- **THEN** the dialog SHALL close and the player SHALL remain on the START tile with normal controls restored

### Requirement: Dialog pauses exploration input
While the return confirmation dialog is displayed, DungeonScreen SHALL NOT process movement or turn input.

#### Scenario: Movement blocked during dialog
- **WHEN** the return dialog is displayed and the player presses a movement key
- **THEN** the player SHALL NOT move

### Requirement: Dialog appears each time START tile is entered
The return dialog SHALL appear every time the player moves onto the START tile, not just the first time.

#### Scenario: Repeated visits show dialog
- **WHEN** the player moves onto the START tile, selects "いいえ", moves away, and returns to the START tile
- **THEN** the return dialog SHALL appear again

### Requirement: Consumable item triggers the same return path as the START-tile dialog

The system SHALL accept `EscapeToTownEffect` (from an `escape_scroll` or `emergency_escape_scroll` use) as an alternative trigger for returning the party to the town menu entry. The transition destination and downstream handling (e.g., clearing dungeon exploration state) SHALL be identical to the START-tile return flow.

The START-tile return flow SHALL remain fully functional and unchanged in behavior.

#### Scenario: Scroll-based return reaches town menu entry
- **WHEN** `escape_scroll` is used from outside combat in the dungeon and its `EscapeToTownEffect.apply` succeeds
- **THEN** the same `return_to_town` path that the START-tile dialog triggers SHALL fire, and the player SHALL end up at the town menu entry

#### Scenario: Combat scroll-based return reaches town menu entry after ESCAPED
- **WHEN** `emergency_escape_scroll` resolves during combat and the battle ends with `ESCAPED` (per the combat-overlay spec)
- **THEN** the subsequent transition SHALL use the `return_to_town` path and deliver the player to the town menu entry

#### Scenario: START-tile return remains unchanged
- **WHEN** the player moves onto the START tile and confirms 「はい」
- **THEN** the return dialog flow SHALL still emit `return_to_town` with no behavioral regression from the previous specification

#### Scenario: Scroll outside dungeon does not fire return
- **WHEN** an `escape_scroll` is attempted from town (or any non-dungeon context)
- **THEN** its `InDungeonOnly` context condition SHALL fail, no `return_to_town` signal SHALL fire, and the instance SHALL remain in inventory

### Requirement: ダンジョン帰還ダイアログは ConfirmDialog で構築される
SHALL: ダンジョンスクリーンで START タイル上で起動される帰還確認ダイアログは、`ConfirmDialog` の子インスタンスを利用して構築される。`DungeonScreen` 内でインライン実装する `_build_return_dialog` のような per-screen UI 構築コードは存在しない。`DungeonScreen` は `_return_dialog: ConfirmDialog` フィールドを保持し、`_show_return_dialog()` で `setup("町に戻りますか？", default_index)` を呼ぶ。

#### Scenario: 帰還ダイアログ表示時に ConfirmDialog が使われる
- **WHEN** プレイヤーが START タイル上で `check_start_tile_return()` をトリガする
- **THEN** `_return_dialog.setup("町に戻りますか？", ...)` が呼ばれ、ConfirmDialog が visible になる

#### Scenario: 「はい」確定で町に戻る
- **WHEN** ConfirmDialog が `confirmed` シグナルを発行
- **THEN** ダンジョンスクリーンが町画面に遷移する

#### Scenario: 「いいえ」または ESC でダイアログが閉じてダンジョンに残る
- **WHEN** ConfirmDialog が `cancelled` シグナルを発行
- **THEN** ダイアログが閉じ、ダンジョンスクリーンに残る(プレイヤーは START タイル上のまま)

