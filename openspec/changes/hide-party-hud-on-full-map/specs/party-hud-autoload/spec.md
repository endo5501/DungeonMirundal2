## MODIFIED Requirements

### Requirement: HUD remains visible during ESC menu and full-map overlays

When the ESC menu overlay is opened on top of a screen where the HUD is visible, the HUD SHALL remain visible (its visibility SHALL NOT be toggled by ESC menu open/close). The ESC menu MAY visually cover parts of the HUD via Z order without explicit hide.

When the full-map overlay (`FullMapOverlay`) is opened on top of `DungeonScreen`, the HUD SHALL be hidden so that the player can see the entire dungeon map without obstruction. Closing the full-map overlay (via M or ESC) SHALL restore HUD visibility. This hide/restore SHALL be performed by `FullMapOverlay` itself via dependency-injected reference to `PartyHud`, not by `PartyHud.hide_hud()` / `show_hud()` calls from screen-transition code.

#### Scenario: ESC menu does not hide the HUD
- **WHEN** ESC menu is opened on top of TownScreen or DungeonScreen
- **THEN** `PartyHud.visible` SHALL remain `true`

#### Scenario: Full-map overlay hides the HUD while open
- **WHEN** the full-map overlay is opened on top of DungeonScreen
- **THEN** `PartyHud.visible` SHALL be `false`

#### Scenario: Closing the full-map overlay restores the HUD
- **WHEN** the full-map overlay is opened and then closed (either via M or ESC)
- **THEN** `PartyHud.visible` SHALL be `true` after the close
