## MODIFIED Requirements

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

## ADDED Requirements

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
