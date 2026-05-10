## Why

現状の 3D ダンジョン描画は壁が厚さ 0 の単一クワッドで構成されており、壁の角や交差部を斜めから見ると「紙が浮いている」ように見えて没入感を著しく損なっている。ドアも単なる色違い・シェーダ模様違いのクワッドであり、扉として認識しづらい。本変更では壁・ドア・コーナー部分にジオメトリ的なディテールを追加して、ダンジョン空間の建築物としての説得力を引き上げる。

## What Changes

- 壁エッジを厚さ 0.20m の直方体(box)として描画する
- セルごとに壁を二重描画していた挙動を、エッジ単位で一度ずつ描画する方式へリファクタする
- 壁同士のコーナー (壁が 1 本以上接する四隅) に、0.25m 角・天井までの**柱**を立てる
- 床と壁の接合部に高さ 0.08m の**幅木 (skirting)** を追加する
- 天井と壁の接合部に高さ 0.08m の**笠木 (cornice)** を追加する
- DOOR エッジを「上枠 (lintel) + 左右ジャム (jamb) + 凹んだドア板」の 4 要素から構成される建具として描画する
- 既存の procedural brick / wood-plank シェーダはそのまま流用する (シェーダ側の変更なし)
- **BREAKING (内部 API)**: `CellMeshBuilder.build_faces(cell, pos)` per-cell インターフェースを残しつつ、新たに `build_meshes(visible_cells, wiz_map)` per-batch インターフェースを追加。`DungeonScene._rebuild_mesh` は新インターフェースを呼ぶよう変更される

## Capabilities

### New Capabilities
(なし)

### Modified Capabilities
- `dungeon-3d-rendering`: 壁ジオメトリ要件を更新 (厚みあり box への変更)、ドア要件を建具構造へ更新、新規要件として「コーナー柱」「幅木 / 笠木」「エッジ単位の重複排除描画」を追加

## Impact

- **修正対象コード**:
  - `src/dungeon/cell_mesh_builder.gd` — 中核の変更、新メソッド追加と既存メソッドの内部実装変更
  - `src/dungeon_scene/dungeon_scene.gd` — `_rebuild_mesh` から新 API 呼び出しへ
  - `src/dungeon_scene/dungeon_wall.gdshader` — 変更なし (既存 procedural pattern を流用)
- **修正対象テスト**:
  - `tests/dungeon/test_cell_mesh_builder.gd` — 既存テストの一部 (壁が単一クワッドである前提のもの) を新ジオメトリに合わせて更新、新ジオメトリ用テストを追加
- **依存関係**: 追加なし
- **パフォーマンス**: 1 セルあたりの face 数は概算で 4-5 倍 (単純壁 4 → box 化 + 柱 + トリム ≒ 20)。`ImmediateMesh` の規模としては許容範囲内 (典型的な視野 13 セル × 20 face × 6 三角 ≒ 1500 三角)
- **ゲームプレイ影響**: 視覚的のみ。当たり判定や移動可能性は WizMap データ側で完全に管理されており、3D 描画のジオメトリ変更は移動・遭遇・探索済みマップ等のロジックに一切影響しない
