## MODIFIED Requirements

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

### Requirement: Delete selected dungeon with confirmation
`DungeonEntrance` SHALL require the user to first activate `破棄`, then move the cursor to the target dungeon entry in the dungeon list, then confirm with Enter. Upon Enter it SHALL display a confirmation dialog; confirming SHALL remove the dungeon from `DungeonRegistry`. `破棄` SHALL be disabled when `DungeonRegistry` is empty.

#### Scenario: Delete with confirmation
- **WHEN** the user activates `破棄`, moves the cursor to a dungeon entry, presses Enter, and confirms the dialog with `はい`
- **THEN** the selected dungeon SHALL be removed from `DungeonRegistry`

#### Scenario: Delete cancelled via confirmation dialog
- **WHEN** the user activates `破棄`, moves the cursor to a dungeon entry, presses Enter, and selects `いいえ` in the confirmation dialog
- **THEN** the dungeon SHALL NOT be removed

#### Scenario: 破棄 disabled with empty registry
- **WHEN** `DungeonRegistry` is empty
- **THEN** `破棄` SHALL be disabled and activating it SHALL have no effect

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
