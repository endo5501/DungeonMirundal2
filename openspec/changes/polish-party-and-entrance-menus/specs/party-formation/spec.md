## MODIFIED Requirements

### Requirement: Party formation displays party grid and waiting list
The party formation screen SHALL display the current party composition (front row 3 slots, back row 3 slots) and a list of unassigned (waiting) characters. The waiting list SHALL be rendered using `CursorMenuRow`-based entries so that the selection cursor is drawn in a fixed-width column with the `"▶"` glyph, consistent with other cursor menus across the game. The party grid MAY remain an inline 2D layout where slots are rendered as `"[<prefix><name>]"` within composed labels; the `<prefix>` SHALL use `"▶ "` for the currently selected slot and `"  "` (two spaces) otherwise.

#### Scenario: Display party grid with members
- **WHEN** the party formation screen is shown with 2 characters assigned (front row positions 0 and 1)
- **THEN** front row slots 0 and 1 SHALL show character names, and all other slots SHALL show as empty

#### Scenario: Display waiting characters
- **WHEN** the party formation screen is shown with 3 unassigned characters
- **THEN** the waiting list SHALL display all 3 characters with name, level, race, and job, each rendered as a `CursorMenuRow`

#### Scenario: Waiting list cursor uses fixed-width ▶ column
- **WHEN** the waiting list has 3 characters and the second entry is the selected waiting-list cursor position
- **THEN** only the second entry SHALL show the `"▶"` indicator in its cursor column, and the text x-position of every waiting row SHALL remain identical between selected and unselected states

#### Scenario: Party grid selected slot uses ▶ prefix
- **WHEN** the party grid cursor is on front row position 0
- **THEN** that slot SHALL render with the `"▶ "` prefix inside its `[ ... ]` brackets, and all other slots SHALL render with a `"  "` (two spaces) prefix

#### Scenario: Empty state
- **WHEN** the party formation screen is shown with no characters registered
- **THEN** all party slots SHALL be empty and the waiting list SHALL be empty

## ADDED Requirements

### Requirement: Party formation prohibits legacy cursor prefix string
The `PartyFormation` screen SHALL NOT define or use a `CURSOR` string constant whose value is `"> "` or any other glyph other than `"▶ "`. Waiting-list entries SHALL NOT embed the cursor glyph directly in their label text; the glyph SHALL be managed by `CursorMenuRow`'s cursor column.

#### Scenario: No legacy "> " constant remains
- **WHEN** the repository is searched for `"> "` as a cursor constant in `src/guild_scene/party_formation.gd`
- **THEN** no such constant SHALL be found

#### Scenario: Waiting list text does not include the glyph
- **WHEN** a waiting-list row is rendered selected
- **THEN** the text label of the row SHALL NOT contain `"▶"`; the glyph SHALL appear only in the `CursorMenuRow` cursor column
