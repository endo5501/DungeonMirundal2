## Purpose
前衛／後衛スロットの構成とキャラクターの割り当てを規定する。スロット上限・入替え操作・空スロットの扱いなど編成ルールを対象とする。

## Requirements

### Requirement: Party formation displays party grid and waiting list
The party formation screen SHALL display the current party composition (front row 3 slots, back row 3 slots) and a list of unassigned (waiting) characters. Both the waiting list AND the party grid SHALL use fixed-width cursor columns so that the cursor glyph position does not alter surrounding layout when selection moves. The waiting list SHALL render each entry via `CursorMenuRow`. Each party grid slot SHALL render as an `HBoxContainer` containing an opening bracket label, a fixed-width cursor slot `Control`, the character name label, and a closing bracket label; the cursor slot width SHALL be identical across all 6 grid slots and SHALL NOT depend on whether that slot is currently selected.

#### Scenario: Display party grid with members
- **WHEN** the party formation screen is shown with 2 characters assigned (front row positions 0 and 1)
- **THEN** front row slots 0 and 1 SHALL show character names, and all other slots SHALL show as empty

#### Scenario: Display waiting characters
- **WHEN** the party formation screen is shown with 3 unassigned characters
- **THEN** the waiting list SHALL display all 3 characters with name, level, race, and job, each rendered as a `CursorMenuRow`

#### Scenario: Waiting list cursor uses fixed-width ▶ column
- **WHEN** the waiting list has 3 characters and the second entry is the selected waiting-list cursor position
- **THEN** only the second entry SHALL show the `"▶"` indicator in its cursor column, and the text x-position of every waiting row SHALL remain identical between selected and unselected states

#### Scenario: Party grid slots share a fixed cursor column width
- **WHEN** the party grid is rendered
- **THEN** every one of the 6 slot containers SHALL have a cursor slot `Control` with the same `custom_minimum_size.x`, regardless of which slot is currently selected

#### Scenario: Only the selected grid slot shows the cursor glyph
- **WHEN** the party grid cursor is on front row position 2 and the screen is in party-grid mode
- **THEN** the cursor label on slot index 2 SHALL be visible and display `CursorMenuRow.CURSOR_GLYPH`, and the cursor labels on the other 5 slots SHALL be hidden

#### Scenario: Grid cursor is hidden when focus is on the waiting list
- **WHEN** the screen is in waiting-list mode
- **THEN** no grid slot SHALL show a visible cursor glyph

#### Scenario: Empty state
- **WHEN** the party formation screen is shown with no characters registered
- **THEN** all party slots SHALL be empty and the waiting list SHALL be empty

### Requirement: Party formation allows adding characters to slots
When an empty party slot is selected, the user SHALL be able to choose a character from the waiting list to assign to that slot.

#### Scenario: Add character to empty slot
- **WHEN** the user selects an empty slot and chooses a waiting character
- **THEN** Guild.assign_to_party() SHALL be called and the slot SHALL display the character

#### Scenario: No action on empty slot when no waiting characters
- **WHEN** the user selects an empty slot but no characters are waiting
- **THEN** no assignment action SHALL be available

### Requirement: Party formation allows removing characters from slots
When an occupied party slot is selected, the user SHALL be able to remove the character, returning them to the waiting list.

#### Scenario: Remove character from slot
- **WHEN** the user selects an occupied slot and confirms removal
- **THEN** Guild.remove_from_party() SHALL be called and the character SHALL appear in the waiting list

#### Scenario: Slot becomes empty after removal
- **WHEN** a character is removed from front row position 1
- **THEN** front row position 1 SHALL display as empty

### Requirement: Party formation supports party name editing
The party name SHALL be displayed at the top of the screen. Selecting it SHALL allow the user to edit the name inline.

#### Scenario: Display party name
- **WHEN** the party formation screen is shown
- **THEN** the current party name SHALL be displayed at the top

#### Scenario: Edit party name
- **WHEN** the user selects the party name and enters "勇者たち"
- **THEN** the party name SHALL be updated to "勇者たち"

### Requirement: Party formation allows returning to menu
The party formation screen SHALL provide a "戻る" option to return to the guild menu.

#### Scenario: Return to menu
- **WHEN** the user selects "戻る"
- **THEN** the back_requested signal SHALL be emitted and the guild menu SHALL be displayed

### Requirement: Party formation prohibits legacy cursor prefix string
The `PartyFormation` screen SHALL NOT define or use a `CURSOR` string constant whose value is `"> "`. Waiting-list entries SHALL NOT embed the cursor glyph directly in their label text; the glyph SHALL be managed by `CursorMenuRow`'s cursor column. Party-grid slots SHALL NOT embed the cursor glyph in their text labels either; the glyph SHALL appear only in the fixed-width cursor slot `Control`.

#### Scenario: No legacy "> " constant remains
- **WHEN** the repository is searched for `"> "` as a cursor constant in `src/guild_scene/party_formation.gd`
- **THEN** no such constant SHALL be found

#### Scenario: Waiting list text does not include the glyph
- **WHEN** a waiting-list row is rendered selected
- **THEN** the text label of the row SHALL NOT contain `"▶"`; the glyph SHALL appear only in the `CursorMenuRow` cursor column

#### Scenario: Grid slot text does not include the glyph
- **WHEN** a party grid slot is rendered selected
- **THEN** none of the slot's text labels (bracket labels, name label) SHALL contain `"▶"`; the glyph SHALL appear only in the cursor slot `Control`
