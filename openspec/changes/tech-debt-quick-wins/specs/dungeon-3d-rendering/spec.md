## ADDED Requirements

### Requirement: DungeonScene.refresh は visible_cells を必ず受け取る
SHALL: `DungeonScene.refresh(visible_cells: Array[Vector2i])` は呼び出し側から `visible_cells` を必ず渡される前提で動作する。空配列での fallback として内部で `DungeonView` を保持する仕組みは存在しない。`_dungeon_view: DungeonView` フィールドおよび `refresh` 内の null/empty fallback 分岐は削除される。

#### Scenario: refresh は呼び出し側のセル情報を必ず使う
- **WHEN** `DungeonScreen.refresh()` が `DungeonScene.refresh(cells)` を呼ぶ
- **THEN** `cells` の内容で 3D シーンが再構築され、`_dungeon_view` を経由した fallback はない

#### Scenario: 旧 _dungeon_view フィールドは存在しない
- **WHEN** `dungeon_scene.gd` を grep する
- **THEN** `_dungeon_view: DungeonView` フィールドおよび関連の fallback ロジックは存在しない
