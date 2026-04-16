## MODIFIED Requirements

### Requirement: Guild menu displays selectable options
The guild menu screen SHALL display a text-based menu with the following options: "キャラクターを作成する", "パーティ編成", "キャラクター一覧", "立ち去る". The menu SHALL be centered both horizontally and vertically on the screen.

#### Scenario: Menu displays all options
- **WHEN** the guild menu screen is shown
- **THEN** all 4 menu options SHALL be displayed in order

#### Scenario: Menu has cursor selection
- **WHEN** the guild menu is displayed
- **THEN** one menu item SHALL be highlighted as the current selection

#### Scenario: Menu is centered on screen
- **WHEN** the guild menu is displayed
- **THEN** the menu content SHALL be centered both horizontally and vertically within the screen
