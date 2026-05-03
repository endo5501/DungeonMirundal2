## Purpose
CursorMenu によるメニュー表示の行レイアウト契約を規定する。固定幅のカーソル列・テキスト位置の不変性・disabled の視覚表現・マルチカラム行の扱いを対象とし、選択カーソル移動時にテキスト開始位置がずれない描画方式を保証する。
## Requirements
### Requirement: Cursor displayed in a fixed-width column
CursorMenu-backed rows SHALL present the selection cursor in a dedicated fixed-width column placed to the left of the row's text content. The text content column SHALL NOT contain the cursor character or any padding that depends on selection state.

#### Scenario: Cursor column has fixed width regardless of selection
- **WHEN** a row is rendered selected and then re-rendered unselected
- **THEN** the cursor column SHALL retain the same width (in pixels) in both states

#### Scenario: Text column x-position is unchanged when cursor moves
- **WHEN** the cursor moves from one row to another
- **THEN** the x-coordinate of the text column on every row SHALL remain identical before and after the move

### Requirement: Cursor indicator visible only on the selected row
CursorMenu SHALL show a visible cursor indicator (icon or character) in the cursor column of the currently selected row, and SHALL hide the indicator on all non-selected rows.

#### Scenario: Only the selected row shows the indicator
- **WHEN** selected_index is 2 in a 4-row menu
- **THEN** the cursor column of row 2 SHALL show the indicator and rows 0, 1, 3 SHALL NOT show it

#### Scenario: Indicator follows cursor movement
- **WHEN** the cursor moves from row 0 to row 1
- **THEN** row 0's cursor column SHALL hide the indicator and row 1's cursor column SHALL show it

### Requirement: Disabled rows visually distinguished in text column only
CursorMenu SHALL apply a disabled color to the text column (and any extra content columns) of rows whose index is in `disabled_indices`. The cursor column visibility SHALL be governed solely by selection state, not by disabled state.

#### Scenario: Disabled row uses disabled color on text
- **WHEN** row 0 is in disabled_indices and is rendered
- **THEN** its text label SHALL use the `DISABLED_COLOR` theme override

#### Scenario: Enabled row uses enabled color
- **WHEN** row 1 is not in disabled_indices
- **THEN** its text label SHALL use the `ENABLED_COLOR`

### Requirement: Multi-column row preserves cursor column position
CursorMenuRow SHALL support attaching additional labels to the right of the main text label via `add_extra_label(label)`, for rows that need multiple content columns (e.g., dungeon list with name, size, exploration rate). The cursor column SHALL remain the leftmost fixed-width column regardless of how many extra labels are attached.

#### Scenario: Extra labels sit to the right of the text label
- **WHEN** a row has main text "名前" and two extra labels "16x16" and "探索40%" attached
- **THEN** the column order from left to right SHALL be: cursor column, main text label, "16x16" label, "探索40%" label

#### Scenario: Cursor column width unaffected by extra labels
- **WHEN** extra labels are added to a row
- **THEN** the cursor column SHALL retain its original fixed width

### Requirement: `update_rows` API drives row rendering
CursorMenu SHALL expose `update_rows(rows: Array[CursorMenuRow])` that, for each row, sets selection state from `selected_index` and disabled state from `disabled_indices`.

#### Scenario: update_rows applies selection and disabled state
- **WHEN** a CursorMenu with selected_index=1 and disabled_indices=[0] calls update_rows on 3 rows
- **THEN** row 0 SHALL be disabled and unselected, row 1 SHALL be selected and enabled, row 2 SHALL be unselected and enabled

### Requirement: Prefix-string API removed
The string-based cursor API (`CURSOR_PREFIX`, `NO_CURSOR_PREFIX`, and `update_labels(Array[Label])`) SHALL be removed once all consumer screens have migrated to `update_rows`. New code SHALL NOT read or reference these symbols.

#### Scenario: Legacy prefix constants are absent
- **WHEN** the migration is complete
- **THEN** grepping the repository for `CURSOR_PREFIX` or `NO_CURSOR_PREFIX` SHALL return no matches in `src/`

### Requirement: MenuController routes standard menu actions to CursorMenu
The system SHALL provide a `MenuController` (RefCounted) class with a static method `route(event, menu, rows, on_accept, on_back, on_cursor_changed) -> bool` that routes the four standard menu input actions (`ui_up`, `ui_down`, `ui_accept`, `ui_cancel`) into operations on a `CursorMenu` and `Array[CursorMenuRow]`. The method SHALL return `true` if the event was consumed (matched and dispatched), `false` otherwise. Callers SHALL be responsible for calling `get_viewport().set_input_as_handled()` based on the return value.

#### Scenario: ui_down moves cursor forward and updates rows
- **WHEN** `route(event_ui_down, menu, rows, on_accept)` is called with `event_ui_down` matching `is_action_pressed("ui_down")`
- **THEN** `menu.move_cursor(1)` SHALL be invoked, `menu.update_rows(rows)` SHALL be invoked, and the method SHALL return `true`

#### Scenario: ui_up moves cursor backward and updates rows
- **WHEN** `route(event_ui_up, menu, rows, on_accept)` is called
- **THEN** `menu.move_cursor(-1)` SHALL be invoked, `menu.update_rows(rows)` SHALL be invoked, and the method SHALL return `true`

#### Scenario: ui_accept invokes the accept callback
- **WHEN** `route(event_ui_accept, menu, rows, on_accept)` is called and `on_accept` is a valid `Callable`
- **THEN** `on_accept.call()` SHALL be invoked exactly once and the method SHALL return `true`

#### Scenario: ui_cancel invokes the back callback when registered
- **WHEN** `route(event_ui_cancel, menu, rows, on_accept, on_back)` is called and `on_back` is a valid `Callable`
- **THEN** `on_back.call()` SHALL be invoked exactly once and the method SHALL return `true`

#### Scenario: ui_cancel is ignored when back callback is not registered
- **WHEN** `route(event_ui_cancel, menu, rows, on_accept)` is called with no `on_back` (default `Callable()`)
- **THEN** no callback SHALL be invoked and the method SHALL return `false`

#### Scenario: on_cursor_changed fires after move_cursor when registered
- **WHEN** `route(event_ui_down, menu, rows, on_accept, on_back, on_cursor_changed)` is called and `on_cursor_changed` is valid
- **THEN** `on_cursor_changed.call()` SHALL be invoked exactly once after `menu.update_rows(rows)`

#### Scenario: Unrecognized event returns false
- **WHEN** `route(some_other_event, menu, rows, on_accept)` is called with an event that is none of ui_up/ui_down/ui_accept/ui_cancel
- **THEN** no callback SHALL be invoked, no method SHALL be invoked on `menu`, and the method SHALL return `false`

### Requirement: MenuController uses action-based input convention
SHALL: `MenuController.route` MUST use `event.is_action_pressed(action_name)` for matching, NOT keycode comparison. The four standard actions SHALL be `ui_up`, `ui_down`, `ui_accept`, `ui_cancel` as defined in `project.godot`.

#### Scenario: keycode-based events trigger only via their bound actions
- **WHEN** a KEY_W InputEventKey is dispatched and `ui_up` is bound to KEY_W in InputMap
- **THEN** `MenuController.route` SHALL detect it via `is_action_pressed("ui_up")` and route as ui_up

#### Scenario: events not bound to a menu action are ignored
- **WHEN** a key event is received that does not match any of the four ui_ actions
- **THEN** the method SHALL return `false`

### Requirement: MenuController does not call set_input_as_handled
The `route` method SHALL NOT call `get_viewport().set_input_as_handled()` itself. The caller SHALL inspect the boolean return value and call it if appropriate. This SHALL keep `MenuController` viewport-independent and unit-testable.

#### Scenario: route does not consume input via the viewport
- **WHEN** `MenuController.route(event_ui_down, menu, rows, on_accept)` is invoked outside a SceneTree context
- **THEN** the method SHALL complete without throwing or accessing `get_viewport()`

