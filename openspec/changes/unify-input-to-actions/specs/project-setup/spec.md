## ADDED Requirements

### Requirement: project.godot defines custom InputMap actions for game-specific input
SHALL: `project.godot` SHALL contain an `[input]` section that defines the following custom actions in addition to Godot's default `ui_*` actions:

- `move_forward`: bound to KEY_W and KEY_UP
- `move_back`: bound to KEY_S and KEY_DOWN
- `strafe_left`: bound to KEY_A
- `strafe_right`: bound to KEY_D
- `turn_left`: bound to KEY_LEFT
- `turn_right`: bound to KEY_RIGHT
- `toggle_full_map`: bound to KEY_M

These actions SHALL be the canonical source of truth for in-game movement and game-specific UI inputs. Source code SHALL NOT compare against `event.keycode == KEY_*` for these inputs; instead, code SHALL use `event.is_action_pressed("<action_name>")`.

#### Scenario: Custom actions exist in project.godot
- **WHEN** `project.godot` is loaded by Godot 4.x
- **THEN** `InputMap.has_action("move_forward")` SHALL return `true` for each of the seven custom actions

#### Scenario: WASD and arrow keys both trigger move_forward
- **WHEN** a KEY_W or KEY_UP press event is dispatched
- **THEN** `event.is_action_pressed("move_forward")` SHALL return `true`

#### Scenario: M key triggers toggle_full_map
- **WHEN** a KEY_M press event is dispatched
- **THEN** `event.is_action_pressed("toggle_full_map")` SHALL return `true`

### Requirement: All _unhandled_input handlers use action-based input
SHALL: Source files under `src/` containing `_unhandled_input(event)` MUST use `event.is_action_pressed("<action_name>")` for input matching. Direct keycode comparisons (`event.keycode == KEY_*`) SHALL NOT appear in any `_unhandled_input` body in `src/`. Exceptions: text input handlers (typing a character name) MAY still inspect keycode/unicode for letter input.

#### Scenario: No keycode comparisons in _unhandled_input under src/
- **WHEN** the codebase is grepped for `event.keycode == KEY_` within `_unhandled_input` bodies
- **THEN** the search SHALL return no matches in `src/` (text-input character entry handlers are excepted)

#### Scenario: Action-based pattern is followed
- **WHEN** a screen handles ESC input
- **THEN** it SHALL use `event.is_action_pressed("ui_cancel")` rather than `event.keycode == KEY_ESCAPE`
