## ADDED Requirements

### Requirement: Consumable item triggers the same return path as the START-tile dialog

The system SHALL accept `EscapeToTownEffect` (from an `escape_scroll` or `emergency_escape_scroll` use) as an alternative trigger for returning the party to the town menu entry. The transition destination and downstream handling (e.g., clearing dungeon exploration state) SHALL be identical to the START-tile return flow.

The START-tile return flow SHALL remain fully functional and unchanged in behavior.

#### Scenario: Scroll-based return reaches town menu entry
- **WHEN** `escape_scroll` is used from outside combat in the dungeon and its `EscapeToTownEffect.apply` succeeds
- **THEN** the same `return_to_town` path that the START-tile dialog triggers SHALL fire, and the player SHALL end up at the town menu entry

#### Scenario: Combat scroll-based return reaches town menu entry after ESCAPED
- **WHEN** `emergency_escape_scroll` resolves during combat and the battle ends with `ESCAPED` (per the combat-overlay spec)
- **THEN** the subsequent transition SHALL use the `return_to_town` path and deliver the player to the town menu entry

#### Scenario: START-tile return remains unchanged
- **WHEN** the player moves onto the START tile and confirms 「はい」
- **THEN** the return dialog flow SHALL still emit `return_to_town` with no behavioral regression from the previous specification

#### Scenario: Scroll outside dungeon does not fire return
- **WHEN** an `escape_scroll` is attempted from town (or any non-dungeon context)
- **THEN** its `InDungeonOnly` context condition SHALL fail, no `return_to_town` signal SHALL fire, and the instance SHALL remain in inventory
