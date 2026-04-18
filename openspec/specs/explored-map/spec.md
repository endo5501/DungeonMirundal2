## Purpose
ダンジョン内で既に訪れたセルの記録と永続化を規定する。訪問済みフラグ、探索率計算、ミニマップ描画との連携、セーブファイルへの格納を対象とする。

## Requirements

### Requirement: ExploredMap tracks visited cells
ExploredMap (RefCounted) SHALL maintain a set of explored cell positions. A cell is marked as explored when the player visits it or when it enters the player's visible range.

#### Scenario: Initially no cells are explored
- **WHEN** ExploredMap is newly created
- **THEN** get_visited_cells() SHALL return an empty array

#### Scenario: Mark a single cell as visited
- **WHEN** mark_visited(Vector2i(3, 4)) is called
- **THEN** is_visited(Vector2i(3, 4)) SHALL return true

#### Scenario: Unvisited cell returns false
- **WHEN** mark_visited(Vector2i(3, 4)) is called
- **THEN** is_visited(Vector2i(5, 5)) SHALL return false

#### Scenario: Mark multiple cells as visible
- **WHEN** mark_visible([Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1)]) is called
- **THEN** is_visited(Vector2i(1, 1)) SHALL return true AND is_visited(Vector2i(1, 2)) SHALL return true AND is_visited(Vector2i(2, 1)) SHALL return true

#### Scenario: Duplicate marking is idempotent
- **WHEN** mark_visited(Vector2i(3, 4)) is called twice
- **THEN** get_visited_cells() SHALL contain Vector2i(3, 4) exactly once

#### Scenario: Clear resets all explored state
- **WHEN** mark_visited(Vector2i(3, 4)) is called and then clear() is called
- **THEN** is_visited(Vector2i(3, 4)) SHALL return false AND get_visited_cells() SHALL return an empty array

#### Scenario: get_visited_cells returns all explored cells
- **WHEN** mark_visited(Vector2i(1, 1)) and mark_visited(Vector2i(2, 3)) are called
- **THEN** get_visited_cells() SHALL return an array containing both Vector2i(1, 1) and Vector2i(2, 3)
