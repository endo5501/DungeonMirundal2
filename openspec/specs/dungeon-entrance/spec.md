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
DungeonEntrance SHALL provide keyboard-based cursor navigation for the dungeon list. Up/Down keys SHALL move the cursor between dungeon entries.

#### Scenario: Cursor navigates dungeon list
- **WHEN** the cursor is on the first dungeon and Down is pressed
- **THEN** the cursor SHALL move to the second dungeon

### Requirement: Enter dungeon with selected dungeon
DungeonEntrance SHALL emit an `enter_dungeon` signal with the selected DungeonData index when "潜入する" is activated. This button SHALL be disabled when no dungeon is selected or when the party has no members.

#### Scenario: Enter selected dungeon
- **WHEN** a dungeon is selected in the list and the party has members and "潜入する" is activated
- **THEN** the `enter_dungeon` signal SHALL be emitted with the selected dungeon index

#### Scenario: Enter disabled with no selection
- **WHEN** no dungeon is selected in the list
- **THEN** "潜入する" SHALL be disabled

#### Scenario: Enter disabled with empty party
- **WHEN** a dungeon is selected but the party has no members assigned
- **THEN** "潜入する" SHALL be disabled

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
DungeonEntrance SHALL display a confirmation dialog when "破棄" is activated with a dungeon selected. Confirming SHALL remove the dungeon from DungeonRegistry. "破棄" SHALL be disabled when no dungeon is selected.

#### Scenario: Delete with confirmation
- **WHEN** a dungeon is selected and "破棄" is activated and the user confirms
- **THEN** the selected dungeon SHALL be removed from DungeonRegistry

#### Scenario: Delete cancelled
- **WHEN** a dungeon is selected and "破棄" is activated and the user cancels
- **THEN** the dungeon SHALL NOT be removed

#### Scenario: Delete disabled with no selection
- **WHEN** no dungeon is selected
- **THEN** "破棄" SHALL be disabled

### Requirement: Back button returns to town screen
DungeonEntrance SHALL emit a `back_requested` signal when "戻る" is activated.

#### Scenario: Back to town
- **WHEN** the user activates "戻る"
- **THEN** the `back_requested` signal SHALL be emitted

### Requirement: Initial focus adapts to empty dungeon registry
When `setup()` is called with an empty DungeonRegistry, DungeonEntrance SHALL initialize the input focus on the button row with the cursor placed on "新規生成", so that pressing Enter immediately opens the dungeon creation dialog without requiring a preparatory key press. When the registry has at least one dungeon, the initial focus SHALL remain on the dungeon list (unchanged from prior behavior).

#### Scenario: Empty registry starts with button focus on 新規生成
- **WHEN** DungeonEntrance is shown with an empty DungeonRegistry
- **THEN** the focus SHALL be on the button row and the cursor SHALL be on "新規生成"

#### Scenario: Enter opens create dialog directly when registry is empty
- **WHEN** DungeonEntrance is shown with an empty DungeonRegistry and the user presses Enter without any prior input
- **THEN** DungeonCreateDialog SHALL open

#### Scenario: Non-empty registry keeps list focus
- **WHEN** DungeonEntrance is shown with at least one registered dungeon
- **THEN** the focus SHALL be on the dungeon list with the cursor on the first dungeon
