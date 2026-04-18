## MODIFIED Requirements

### Requirement: Title screen displays menu options
TitleScreen SHALL display a text-based menu with 4 options in this order: "前回から", "新規ゲーム", "ロード", "ゲーム終了".

#### Scenario: All options are displayed
- **WHEN** the title screen is shown
- **THEN** all 4 menu options SHALL be displayed in the order "前回から", "新規ゲーム", "ロード", "ゲーム終了"

### Requirement: Title screen has cursor selection
TitleScreen SHALL provide keyboard-based cursor navigation. Up/Down arrow keys SHALL move the cursor between options. Enter/Space SHALL select the current option. The initial cursor position SHALL be on the first enabled option, determined after `setup_save_state()` has applied the disabled state.

#### Scenario: Cursor starts on 前回から when save exists and last_slot is valid
- **WHEN** the title screen is shown and SaveManager has a valid last_slot
- **THEN** the cursor SHALL be on "前回から"

#### Scenario: Cursor skips to 新規ゲーム when no save exists
- **WHEN** the title screen is shown and SaveManager has no saves
- **THEN** "前回から" and "ロード" SHALL be disabled and the cursor SHALL be on "新規ゲーム"

#### Scenario: Cursor skips to 新規ゲーム when last_slot is invalid but saves exist
- **WHEN** the title screen is shown and SaveManager has saves but last_slot is invalid
- **THEN** "前回から" SHALL be disabled and the cursor SHALL be on "新規ゲーム"

#### Scenario: Cursor moves down
- **WHEN** the cursor is on "前回から" and the Down key is pressed
- **THEN** the cursor SHALL move to "新規ゲーム"

#### Scenario: Cursor wraps around
- **WHEN** the cursor is on "ゲーム終了" and the Down key is pressed
- **THEN** the cursor SHALL wrap to "前回から" (or skip to the next enabled option if "前回から" is disabled)
