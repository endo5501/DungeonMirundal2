## Why

ダンジョンからの帰還動線が壊れている。入口 (START) タイルは 3D ビューにもミニマップにも視覚的な区別がなく、広いダンジョンで帰り道を失いやすい。さらに、全滅・脱出の巻物・緊急脱出の巻物で町へ戻った後、再度ダンジョンに入ると `DungeonData.player_state` が最後の位置を保持しているため、入口ではなく「死亡/脱出地点」から再開されてしまう。

## What Changes

- `WizMap` の各セルが持つ `tile` 種別 (START 等) を 3D メッシュ生成に伝達し、START タイル上に簡易な上り階段メッシュを描画する。
- ミニマップで START タイルの上に専用マーカー (記号) を重ね描きし、床色とは別の識別を与える。
- `DungeonData` に入口へ戻す `reset_to_start()` を追加し、町→ダンジョン入場のハンドラから呼ぶことで、全滅・脱出の巻物・緊急脱出の巻物・自発帰還のすべての再入場ケースで入口から再開するようにする。
- セーブからのロード経路は本処理を経由しない (保存地点で再開する挙動を維持する)。

## Capabilities

### New Capabilities
<!-- なし: すべて既存 spec の修正で完結する -->

### Modified Capabilities
- `dungeon-3d-rendering`: START タイルに視覚的な表現 (上り階段メッシュ) を追加する要件を加える
- `minimap-renderer`: START タイルにマーカー記号を重ね描きする要件を加える
- `dungeon-management`: `DungeonData` に `reset_to_start()` メソッドを追加する要件を加える
- `screen-navigation`: 町→ダンジョン入場遷移時にパーティ位置を入口へリセットする要件を加える (ロード経路は対象外)

## Impact

- 影響コード:
  - `src/dungeon/cell_mesh_builder.gd` — `Cell.tile` を参照し、START タイル時に階段メッシュを追加
  - `src/dungeon/minimap_renderer.gd` — 描画中セルの `tile` を見て START マーカーを重ね描き
  - `src/dungeon/dungeon_data.gd` — `reset_to_start()` メソッドを追加
  - `src/main.gd` — `_on_enter_dungeon()` から `reset_to_start()` を呼ぶ
- 影響しない範囲:
  - `EscapeToTownEffect` の効果自体 (町へ帰還するだけの挙動は変更なし)
  - 全滅ペナルティ (ゴールド減・装備ロスト等) は本件対象外
  - セーブ/ロードの挙動 (ロード時は `_on_enter_dungeon` を経由しないため影響なし)
  - ダンジョン生成ロジック (`WizMap.generate`) と START タイル配置ルール
- 新規依存は無し。
