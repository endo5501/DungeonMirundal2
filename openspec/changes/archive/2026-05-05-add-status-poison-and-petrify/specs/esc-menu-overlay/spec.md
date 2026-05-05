## ADDED Requirements

### Requirement: EscMenuStatus shows a status line per character

`EscMenuStatus` (the character detail panel under the ESC menu's status sub-flow) SHALL render a one-line summary of the selected character's `persistent_statuses`. The format SHALL be:

- When `persistent_statuses` is empty: `"状態: 通常"`
- Otherwise: `"状態: " + names.join(", ")` where each `name` is the StatusData's `display_name` (or `String(status_id)` when the lookup fails).

The line SHALL be rendered in the standard status-detail font/style and SHALL be visible without additional navigation.

#### Scenario: Clean character shows 通常
- **WHEN** the ESC menu status panel is shown for a character with empty `persistent_statuses`
- **THEN** a label SHALL render reading "状態: 通常"

#### Scenario: Single-status character shows its display name
- **WHEN** the panel is shown for a character whose `persistent_statuses == [&"poison"]`
- **THEN** a label SHALL render reading "状態: 毒"

#### Scenario: Multi-status character shows comma-separated names
- **WHEN** the panel is shown for a character whose `persistent_statuses == [&"poison", &"petrify"]`
- **THEN** a label SHALL render reading "状態: 毒, 石化"
