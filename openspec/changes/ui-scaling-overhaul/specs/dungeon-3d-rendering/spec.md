## ADDED Requirements

### Requirement: DungeonScreen refreshes the SubViewport on window resize

`DungeonScreen` (Control) SHALL detect window/control resize events and re-trigger a single SubViewport update so that the dungeon 3D rendering remains visible after the user resizes the game window. The existing optimization of using `SubViewport.UPDATE_DISABLED` between explicit refreshes (driven by player movement and rotation) SHALL be preserved; only one additional `UPDATE_ONCE` SHALL be issued per resize event.

The detection SHALL be implemented via Godot's `_notification(NOTIFICATION_RESIZED)` (or an equivalent resize signal) on `DungeonScreen` itself. Re-triggering SHALL use the existing `_refresh_all()` path so that the SubViewport, the camera transform, and the visible-cell mesh are reconstructed coherently.

When the resize notification fires before the dungeon dependencies have been initialized (`_wiz_map` or `_player_state` is null), the handler SHALL be a no-op.

#### Scenario: Resizing the window re-renders the dungeon
- **WHEN** the player is in a dungeon room and resizes the OS window from one size to another
- **THEN** the dungeon 3D view SHALL remain visible after the resize completes (the SubViewport SHALL NOT be left blank/black)

#### Scenario: Resize before dungeon setup is a no-op
- **WHEN** `DungeonScreen` receives a `NOTIFICATION_RESIZED` notification before `setup()` has been called (so `_wiz_map` is null)
- **THEN** the handler SHALL return early without invoking `_refresh_all()` and without crashing

#### Scenario: Movement-driven refresh is unchanged
- **WHEN** the player moves forward, backward, sideways, or rotates
- **THEN** `_refresh_all()` SHALL still set `_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE` exactly as before, with no behavioral change for non-resize updates
