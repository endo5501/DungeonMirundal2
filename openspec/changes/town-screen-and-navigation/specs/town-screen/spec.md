## ADDED Requirements

### Requirement: Town screen displays facility selection
TownScreen SHALL display a left column with facility buttons and a right column with an illustration placeholder area.

#### Scenario: Facility buttons are displayed
- **WHEN** the town screen is shown
- **THEN** buttons for "冒険者ギルド", "商店", "教会", "ダンジョン入口" SHALL be displayed in the left column

### Requirement: Town screen has cursor selection for facilities
TownScreen SHALL provide keyboard-based cursor navigation for facility selection. Up/Down keys SHALL move the cursor. Enter/Space SHALL select the facility.

#### Scenario: Cursor navigates between facilities
- **WHEN** the cursor is on "冒険者ギルド" and Down is pressed
- **THEN** the cursor SHALL move to "商店"

### Requirement: Illustration area updates on cursor movement
The right-side illustration area SHALL display a ColorRect with a Label showing the name of the currently highlighted facility. The background color SHALL change per facility.

#### Scenario: Illustration shows current selection
- **WHEN** the cursor is on "冒険者ギルド"
- **THEN** the right area SHALL display "冒険者ギルド" text with the associated background color

#### Scenario: Illustration changes on cursor move
- **WHEN** the cursor moves from "冒険者ギルド" to "ダンジョン入口"
- **THEN** the right area SHALL update to show "ダンジョン入口" with its associated background color

### Requirement: Guild facility opens GuildScreen
TownScreen SHALL emit an `open_guild` signal when "冒険者ギルド" is selected.

#### Scenario: Select guild
- **WHEN** the user selects "冒険者ギルド"
- **THEN** the `open_guild` signal SHALL be emitted

### Requirement: Dungeon entrance facility opens DungeonEntrance
TownScreen SHALL emit an `open_dungeon_entrance` signal when "ダンジョン入口" is selected.

#### Scenario: Select dungeon entrance
- **WHEN** the user selects "ダンジョン入口"
- **THEN** the `open_dungeon_entrance` signal SHALL be emitted

### Requirement: Shop and Church are disabled placeholders
"商店" and "教会" SHALL be visually grayed out and SHALL NOT be selectable. The cursor SHALL skip over disabled items.

#### Scenario: Shop is not selectable
- **WHEN** the user moves the cursor to "商店" and presses Enter
- **THEN** nothing SHALL happen

#### Scenario: Cursor skips disabled items
- **WHEN** the cursor is on "冒険者ギルド" and Down is pressed
- **THEN** the cursor SHALL skip "商店" and "教会" and move to "ダンジョン入口"
