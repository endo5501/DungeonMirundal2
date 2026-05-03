## Purpose
ダンジョン入口画面の一覧表示・新規生成・破棄および入場フローを規定する。DungeonRegistry との連携、空状態時の誘導表示、パーティ未編成時の入場抑止を対象とする。
## Requirements
### Requirement: Dungeon entrance displays dungeon list
DungeonEntrance SHALL display a list of all dungeons from DungeonRegistry, showing each dungeon's name, map size (e.g. "16x16"), and exploration percentage. When DungeonRegistry is empty, the list area SHALL display the guidance message "まず「新規生成」でダンジョンを作成してください" in the normal enabled text color.

#### Scenario: Empty list shows guidance message
- **WHEN** DungeonRegistry has no dungeons
- **THEN** the list area SHALL display "まず「新規生成」でダンジョンを作成してください" in the enabled (non-grayed) color

#### Scenario: Multiple dungeons listed
- **WHEN** DungeonRegistry has 3 dungeons
- **THEN** all 3 dungeons SHALL be displayed with name, size, and exploration rate

#### Scenario: Exploration rate display format
- **WHEN** a dungeon has exploration rate 0.4
- **THEN** it SHALL be displayed as "40%"

### Requirement: Dungeon entrance has cursor selection
`DungeonEntrance` SHALL provide keyboard-based cursor navigation that starts on the button row. The button row SHALL use Up/Down to move between `潜入する` / `新規生成` / `破棄` / `戻る`. The dungeon list SHALL be displayed alongside the buttons at all times as read-only information, and SHALL receive cursor focus only when the user activates `潜入する` or `破棄`. Up/Down keys SHALL move the cursor between dungeon entries while the list has focus. ESC while the dungeon list has focus SHALL return focus to the button row without triggering an action.

#### Scenario: Initial focus is on the button row
- **WHEN** `DungeonEntrance` is shown with at least one registered dungeon
- **THEN** the focus SHALL be on the button row (not the dungeon list), and the dungeon list SHALL still be visible as information

#### Scenario: Activating 潜入 moves focus to the dungeon list
- **WHEN** the user activates `潜入する` from the button row
- **THEN** focus SHALL move to the dungeon list and Up/Down keys SHALL move the list cursor

#### Scenario: Activating 破棄 moves focus to the dungeon list
- **WHEN** the user activates `破棄` from the button row
- **THEN** focus SHALL move to the dungeon list and Up/Down keys SHALL move the list cursor

#### Scenario: ESC in list focus returns to the button row
- **WHEN** the dungeon list has focus (after activating `潜入する` or `破棄`) and the user presses ESC
- **THEN** focus SHALL return to the button row with the same button still selected, and no action SHALL be executed

### Requirement: Enter dungeon with selected dungeon
`DungeonEntrance` SHALL emit an `enter_dungeon` signal with the selected `DungeonData` index after the user activates `潜入する`, moves the cursor to the desired dungeon entry in the dungeon list, and confirms with Enter. `潜入する` SHALL be disabled when `DungeonRegistry` is empty or when the party has no members.

#### Scenario: Enter selected dungeon
- **WHEN** the user activates `潜入する`, moves the cursor to a dungeon entry, and presses Enter, with at least one member in the party
- **THEN** the `enter_dungeon` signal SHALL be emitted with the index of the cursor-pointed dungeon

#### Scenario: 潜入 disabled with empty registry
- **WHEN** `DungeonRegistry` is empty
- **THEN** `潜入する` SHALL be disabled and activating it SHALL have no effect

#### Scenario: 潜入 disabled with empty party
- **WHEN** `DungeonRegistry` has at least one dungeon but the party has no members assigned
- **THEN** `潜入する` SHALL be disabled

### Requirement: Create new dungeon via dialog
DungeonEntrance SHALL display a DungeonCreateDialog when "新規生成" is activated. The dialog SHALL allow selecting a size category (小/中/大) and editing a randomly generated name. Confirming the dialog SHALL create a new dungeon via DungeonRegistry.

#### Scenario: Open create dialog
- **WHEN** "新規生成" is activated
- **THEN** DungeonCreateDialog SHALL be displayed with a random name and size selection defaulting to 中

#### Scenario: Create dialog has editable name
- **WHEN** DungeonCreateDialog is shown
- **THEN** a text field SHALL contain a randomly generated name that the user can edit

#### Scenario: Confirm creation adds dungeon
- **WHEN** the user sets size to "大" and name to "試練の回廊" and confirms
- **THEN** a new dungeon SHALL be added to DungeonRegistry with size_category LARGE and name "試練の回廊"

#### Scenario: Cancel creation returns to list
- **WHEN** the user cancels the create dialog
- **THEN** no dungeon SHALL be created and the dungeon list SHALL be shown

### Requirement: Delete selected dungeon with confirmation
`DungeonEntrance` SHALL require the user to first activate `破棄`, then move the cursor to the target dungeon entry in the dungeon list, then confirm with Enter. Upon Enter it SHALL display a confirmation dialog; confirming SHALL remove the dungeon from `DungeonRegistry`. After a confirmed deletion, focus SHALL return to the button row so that the `破棄` action must be explicitly re-selected to delete another dungeon. Cancelling the confirmation dialog SHALL leave the focus on the dungeon list so the user can pick a different target without re-selecting the action. `破棄` SHALL be disabled when `DungeonRegistry` is empty.

#### Scenario: Delete with confirmation
- **WHEN** the user activates `破棄`, moves the cursor to a dungeon entry, presses Enter, and confirms the dialog with `はい`
- **THEN** the selected dungeon SHALL be removed from `DungeonRegistry`

#### Scenario: Focus returns to buttons after confirmed delete
- **WHEN** the user completes a confirmed deletion via `破棄`
- **THEN** the focus SHALL be on the button row (not the dungeon list), so that a subsequent Enter does NOT trigger another delete confirmation

#### Scenario: Focus remains on list after cancelled delete
- **WHEN** the user activates `破棄`, opens the confirmation dialog for a dungeon, and cancels it with `いいえ`
- **THEN** the focus SHALL remain on the dungeon list (LIST_FOR_DELETE) so the user can pick a different dungeon to delete without re-selecting `破棄`

#### Scenario: Delete cancelled via confirmation dialog
- **WHEN** the user activates `破棄`, moves the cursor to a dungeon entry, presses Enter, and selects `いいえ` in the confirmation dialog
- **THEN** the dungeon SHALL NOT be removed

#### Scenario: 破棄 disabled with empty registry
- **WHEN** `DungeonRegistry` is empty
- **THEN** `破棄` SHALL be disabled and activating it SHALL have no effect

#### Scenario: Deleting the last dungeon does not leave list-for-delete focus
- **WHEN** `DungeonRegistry` has exactly one dungeon and the user deletes it via the `破棄` flow
- **THEN** after the confirmation dialog closes, the focus SHALL be on the button row, and a subsequent Enter SHALL NOT reopen the delete confirmation dialog

### Requirement: Back button returns to town screen
DungeonEntrance SHALL emit a `back_requested` signal when "戻る" is activated.

#### Scenario: Back to town
- **WHEN** the user activates "戻る"
- **THEN** the `back_requested` signal SHALL be emitted

### Requirement: Initial focus adapts to empty dungeon registry
When `setup()` is called with an empty `DungeonRegistry`, `DungeonEntrance` SHALL initialize the input focus on the button row with the cursor placed on `新規生成`, because `潜入する` and `破棄` are disabled in the empty state and `新規生成` is the first enabled button. When the registry has at least one dungeon, the initial cursor SHALL be placed on `潜入する` (the first button, which is enabled when the party has members).

#### Scenario: Empty registry starts with cursor on 新規生成
- **WHEN** `DungeonEntrance` is shown with an empty `DungeonRegistry`
- **THEN** the focus SHALL be on the button row and the cursor SHALL be on `新規生成`

#### Scenario: Enter opens create dialog directly when registry is empty
- **WHEN** `DungeonEntrance` is shown with an empty `DungeonRegistry` and the user presses Enter without any prior input
- **THEN** `DungeonCreateDialog` SHALL open

#### Scenario: Non-empty registry starts with cursor on 潜入する
- **WHEN** `DungeonEntrance` is shown with at least one registered dungeon
- **THEN** the focus SHALL be on the button row and the cursor SHALL be on `潜入する`

### Requirement: ダンジョン削除確認ダイアログは ConfirmDialog で構築される
SHALL: ダンジョン入口画面で「削除」を選択した時の確認ダイアログは、`ConfirmDialog` の子インスタンスを利用して構築される。`DungeonEntrance` 内でインライン実装する確認 UI コードは存在しない。

#### Scenario: 削除確認ダイアログ表示時に ConfirmDialog が使われる
- **WHEN** ダンジョン入口で削除アクションがトリガされる
- **THEN** `_delete_dialog.setup("削除しますか？", 1)` が呼ばれ、ConfirmDialog が visible になる

#### Scenario: 「はい」確定でダンジョンが削除される
- **WHEN** ConfirmDialog が `confirmed` シグナルを発行
- **THEN** 対応するダンジョンが `DungeonRegistry` から削除される

#### Scenario: 「いいえ」または ESC で削除がキャンセルされる
- **WHEN** ConfirmDialog が `cancelled` シグナルを発行
- **THEN** ダイアログが閉じ、ダンジョンは削除されずに入口画面に戻る

