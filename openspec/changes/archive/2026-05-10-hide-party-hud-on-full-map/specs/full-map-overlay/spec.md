## ADDED Requirements

### Requirement: FullMapOverlay hides the party HUD while visible

FullMapOverlay SHALL hide the `PartyHud` (CanvasLayer autoload) while the overlay is visible, and SHALL restore the HUD's visibility when the overlay is closed. The reference SHALL be supplied via dependency injection through `setup()` rather than via direct global autoload access, mirroring the existing `MinimapDisplay` injection pattern. The injected reference parameter SHALL default to `null` so existing callers remain compatible; when null the overlay SHALL skip HUD visibility manipulation.

#### Scenario: Party HUD is hidden when overlay opens

- **WHEN** the overlay is opened
- **THEN** the injected `PartyHud` `CanvasLayer` SHALL have `visible == false`

#### Scenario: Party HUD is restored when overlay closes

- **WHEN** the overlay is closed (either via M or ESC)
- **THEN** the injected `PartyHud` `CanvasLayer` SHALL have `visible == true`

#### Scenario: Setup accepts a party HUD layer parameter

- **WHEN** `FullMapOverlay.setup(wiz_map, explored_map, player_state, dungeon_data, minimap_display, party_hud_layer)` is called with a `CanvasLayer` reference as the sixth argument
- **THEN** the overlay SHALL store the reference and SHALL use it in subsequent `open()` / `close()` calls to toggle visibility

#### Scenario: Setup is backward compatible when party HUD layer is omitted

- **WHEN** `FullMapOverlay.setup(...)` is called without the `party_hud_layer` argument (or with `null`)
- **THEN** `open()` and `close()` SHALL NOT raise an error AND SHALL skip HUD visibility manipulation
