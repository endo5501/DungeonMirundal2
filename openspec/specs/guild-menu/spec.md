## ADDED Requirements

### Requirement: Guild menu displays selectable options
The guild menu screen SHALL display a text-based menu with the following options: "キャラクターを作成する", "パーティ編成", "キャラクター一覧", "立ち去る".

#### Scenario: Menu displays all options
- **WHEN** the guild menu screen is shown
- **THEN** all 4 menu options SHALL be displayed in order

#### Scenario: Menu has cursor selection
- **WHEN** the guild menu is displayed
- **THEN** one menu item SHALL be highlighted as the current selection

#### Scenario: Menu is centered on screen
- **WHEN** the guild menu is displayed
- **THEN** the menu content SHALL be centered both horizontally and vertically within the screen

### Requirement: Guild menu navigates to character creation
The guild menu SHALL navigate to the character creation wizard when "キャラクターを作成する" is selected.

#### Scenario: Select character creation
- **WHEN** the user selects "キャラクターを作成する"
- **THEN** the character creation wizard screen SHALL be displayed

### Requirement: Guild menu navigates to party formation
The guild menu SHALL navigate to the party formation screen when "パーティ編成" is selected.

#### Scenario: Select party formation
- **WHEN** the user selects "パーティ編成"
- **THEN** the party formation screen SHALL be displayed

### Requirement: Guild menu navigates to character list
The guild menu SHALL navigate to the character list screen when "キャラクター一覧" is selected.

#### Scenario: Select character list
- **WHEN** the user selects "キャラクター一覧"
- **THEN** the character list screen SHALL be displayed

### Requirement: Guild menu allows leaving
The guild menu SHALL emit a signal to leave when "立ち去る" is selected.

#### Scenario: Select leave
- **WHEN** the user selects "立ち去る"
- **THEN** the guild screen SHALL emit a leave signal

### Requirement: Guild screen manages view switching
GuildScreen SHALL manage switching between child views (menu, creation, formation, list) by instantiating the target scene and replacing the current view.

#### Scenario: Switch from menu to creation
- **WHEN** navigation to character creation is requested
- **THEN** the current view SHALL be freed and replaced with CharacterCreation scene

#### Scenario: Return to menu from any child view
- **WHEN** a child view emits back_requested signal
- **THEN** the current view SHALL be freed and replaced with GuildMenu scene
