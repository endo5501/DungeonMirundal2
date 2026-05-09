## ADDED Requirements

### Requirement: project.godot configures viewport stretch for window resize support

`project.godot` SHALL contain a `[display]` section that configures the viewport-based stretch system so that the entire UI scales uniformly when the user resizes the window. The configuration SHALL set:

- `window/size/viewport_width = 1600` and `window/size/viewport_height = 900` as the design canvas
- `window/stretch/mode = "canvas_items"` so each Control node re-rasterizes at the actual window resolution
- `window/stretch/aspect = "expand"` so the design canvas extends naturally on aspect ratios that differ from 16:9 (no letterboxing, no distortion)

These settings SHALL be loaded by Godot 4.x at engine startup so that all subsequent scene rendering operates under the configured stretch system.

#### Scenario: Display section exists in project.godot
- **WHEN** `project.godot` is opened
- **THEN** it SHALL contain a `[display]` section with `window/size/viewport_width = 1600`, `window/size/viewport_height = 900`, `window/stretch/mode = "canvas_items"`, and `window/stretch/aspect = "expand"`

#### Scenario: Window content scales when resized larger
- **WHEN** the game is launched at the default window size and the user resizes the window from the design size to twice as large in each dimension
- **THEN** the rendered Control content (fonts, panels, sprites) SHALL appear approximately twice as large on screen

#### Scenario: Aspect ratio is preserved without distortion
- **WHEN** the user resizes the window to an aspect ratio different from the design (e.g., 21:9 ultrawide)
- **THEN** the rendered fonts and sprites SHALL NOT distort horizontally or vertically; instead, the additional viewport area SHALL extend the design canvas so anchored Control nodes redistribute proportionally

### Requirement: project.godot defines a default launch window size

`project.godot` SHALL configure the initial OS window size at game launch to match the design viewport (1600×900) so that the default launch state shows the UI at unscaled, designer-intended density. This is achieved by relying on Godot's default behavior where `window/size/viewport_width` and `window/size/viewport_height` also drive the initial window size when no `window_width_override` / `window_height_override` are provided, OR by explicitly setting them to the same values.

#### Scenario: Default window dimensions match design canvas
- **WHEN** the game is launched without command-line size overrides
- **THEN** the initial OS window SHALL be 1600 pixels wide by 900 pixels tall (subject to the host OS window decorations and DPI scaling)
