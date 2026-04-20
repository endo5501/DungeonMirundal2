## MODIFIED Requirements

### Requirement: Illustration area updates on cursor movement
The right-side illustration area SHALL display a `TextureRect` showing the facility image associated with the currently highlighted facility, with an overlay `Label` presenting the facility name on a semi-transparent backdrop for readability. When the image resource for a facility cannot be loaded, the system SHALL fall back to displaying a `ColorRect` whose color corresponds to that facility and keep the name label visible.

#### Scenario: Illustration shows current selection image
- **WHEN** the cursor is on "冒険者ギルド"
- **THEN** the right area SHALL display the guild image (`assets/images/facilities/guild.png`) with a "冒険者ギルド" label overlaid

#### Scenario: Illustration changes on cursor move
- **WHEN** the cursor moves from "冒険者ギルド" to "ダンジョン入口"
- **THEN** the right area SHALL update to show the dungeon image (`assets/images/facilities/dungeon.png`) with a "ダンジョン入口" label overlaid

#### Scenario: Image load failure falls back to color
- **WHEN** the facility image resource for the currently highlighted facility fails to load
- **THEN** the right area SHALL display a `ColorRect` using the facility's fallback color and SHALL still display the facility name label

#### Scenario: Facility name label stays visible over the image
- **WHEN** any facility is highlighted and its image is displayed
- **THEN** the facility name label SHALL be visible on top of the image against a semi-transparent backdrop
