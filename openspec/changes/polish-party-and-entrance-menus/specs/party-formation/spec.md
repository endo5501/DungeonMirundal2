## MODIFIED Requirements

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

## ADDED Requirements

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
