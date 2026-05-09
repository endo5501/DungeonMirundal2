## ADDED Requirements

### Requirement: DungeonScreen refreshes the SubViewport on window resize

`DungeonScreen` (Control) SHALL detect window/control resize events and re-trigger a single SubViewport update so that the dungeon 3D rendering remains visible after the user resizes the game window. The existing optimization of using `SubViewport.UPDATE_DISABLED` between explicit refreshes (driven by player movement and rotation) SHALL be preserved; only one additional `UPDATE_ONCE` SHALL be issued per resize event.

The detection SHALL be implemented via Godot's `_notification(NOTIFICATION_RESIZED)` (or an equivalent resize signal) on `DungeonScreen` itself. The handler SHALL re-arm the SubViewport directly by setting `_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE`. The handler SHALL NOT call `_refresh_all()` on resize: the existing `ImmediateMesh` and camera transform remain valid (the player has not moved), so a re-render of the existing geometry into the new framebuffer is sufficient. Calling `_refresh_all()` would additionally re-mark explored cells (semantically incorrect — a resize is not exploration), rebuild the mesh, and refresh the minimap, which is unnecessary work.

When the resize notification fires before `_ready()` has constructed `_sub_viewport` (e.g. during a parent layout pass that fires earlier in the lifecycle), the handler SHALL be a no-op.

#### Scenario: Resizing the window re-renders the dungeon
- **WHEN** the player is in a dungeon room and resizes the OS window from one size to another
- **THEN** the dungeon 3D view SHALL remain visible after the resize completes (the SubViewport SHALL NOT be left blank/black)

#### Scenario: Resize before SubViewport construction is a no-op
- **WHEN** `DungeonScreen` receives a `NOTIFICATION_RESIZED` notification before `_ready()` has run (so `_sub_viewport` is null)
- **THEN** the handler SHALL return early without touching `_sub_viewport` and without crashing

#### Scenario: Resize after _ready does not invoke _refresh_all
- **WHEN** `DungeonScreen` receives a `NOTIFICATION_RESIZED` notification after `_ready()` has run
- **THEN** the handler SHALL set `_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE` directly
- **AND** the handler SHALL NOT call `_refresh_all()` (no `_explored_map.mark_visible` mutation, no mesh rebuild, no minimap refresh)

#### Scenario: Movement-driven refresh is unchanged
- **WHEN** the player moves forward, backward, sideways, or rotates
- **THEN** `_refresh_all()` SHALL still set `_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE` exactly as before, with no behavioral change for non-resize updates
