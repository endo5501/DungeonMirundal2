## ADDED Requirements

### Requirement: Title screen displays menu options
TitleScreen SHALL display a text-based menu with 4 options: "新規ゲーム", "前回から", "ロード", "ゲーム終了".

#### Scenario: All options are displayed
- **WHEN** the title screen is shown
- **THEN** all 4 menu options SHALL be displayed in order

### Requirement: Title screen has cursor selection
TitleScreen SHALL provide keyboard-based cursor navigation. Up/Down arrow keys SHALL move the cursor between options. Enter/Space SHALL select the current option.

#### Scenario: Cursor starts at first option
- **WHEN** the title screen is first shown
- **THEN** the cursor SHALL be on "新規ゲーム"

#### Scenario: Cursor moves down
- **WHEN** the cursor is on "新規ゲーム" and the Down key is pressed
- **THEN** the cursor SHALL move to "前回から"

#### Scenario: Cursor wraps around
- **WHEN** the cursor is on "ゲーム終了" and the Down key is pressed
- **THEN** the cursor SHALL wrap to "新規ゲーム"

### Requirement: New game starts a fresh game
TitleScreen SHALL emit a `start_new_game` signal when "新規ゲーム" is selected.

#### Scenario: Select new game
- **WHEN** the user selects "新規ゲーム"
- **THEN** the `start_new_game` signal SHALL be emitted

### Requirement: Continue and Load are disabled
"前回から" and "ロード" SHALL be visually grayed out and SHALL NOT be selectable. These options serve as UI placeholders for the save-load change.

#### Scenario: Continue is not selectable
- **WHEN** the user moves the cursor to "前回から" and presses Enter
- **THEN** nothing SHALL happen

#### Scenario: Load is not selectable
- **WHEN** the user moves the cursor to "ロード" and presses Enter
- **THEN** nothing SHALL happen

#### Scenario: Disabled options appear grayed out
- **WHEN** the title screen is shown
- **THEN** "前回から" and "ロード" SHALL be displayed with a dimmed/gray color

### Requirement: Quit game exits the application
TitleScreen SHALL call `get_tree().quit()` when "ゲーム終了" is selected.

#### Scenario: Select quit
- **WHEN** the user selects "ゲーム終了"
- **THEN** the application SHALL exit
