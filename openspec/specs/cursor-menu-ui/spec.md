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
