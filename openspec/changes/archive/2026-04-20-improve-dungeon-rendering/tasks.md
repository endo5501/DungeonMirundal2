## 1. Palette rebalance

- [x] 1.1 `src/dungeon/cell_mesh_builder.gd` のパレット定数(WALL/FLOOR/CEILING/DOOR/STAIRS)を design.md の新値に更新する
- [x] 1.2 既存の `tests/dungeon/test_cell_mesh_builder.gd`(またはそれに準ずるユニットテスト)で色定数をアサートしている箇所があれば期待値を更新する
- [x] 1.3 GUT テストを実行し、パレット関連のテストが通ることを確認する

## 2. Shader material replacement (unlit-compatible first)

- [x] 2.1 `src/dungeon_scene/dungeon_wall.gdshader` を新規作成する(spatial シェーダ、初期は UNSHADED 相当の単純な albedo パススルー)
- [x] 2.2 `DungeonScene._ready()` で `ShaderMaterial` を生成し、`_mesh_instance` の surface override を `StandardMaterial3D` から `ShaderMaterial` に差し替える
- [x] 2.3 `COLOR` をそのまま `ALBEDO` に渡すだけのシェーダで起動し、既存の見た目が再現されることを手動で確認する(`tmp/dungeon.png` を撮り比較)

## 3. Torch light

- [x] 3.1 `DungeonScene._ready()` で `Camera3D` の子として `OmniLight3D` を 1 基追加する(暖色、`omni_range=6.0`、`light_energy=1.5` を初期値)
- [x] 3.2 シェーダの `render_mode` から UNSHADED 相当の指定を外し、lit パスに切り替える
- [x] 3.3 ゲームを起動してトーチ光が壁・床・天井に乗り、距離で減衰することを手動確認する

## 4. Environment (ambient + fog)

- [x] 4.1 `DungeonScene._ready()` で `WorldEnvironment` を追加し、`Environment` を生成する
- [x] 4.2 `background_mode = BG_COLOR`、`ambient_light_color` を near-black(輝度 < 0.1)、`ambient_light_energy = 1.0` に設定する
- [x] 4.3 `fog_enabled = true`、`fog_light_color` を暗色、`fog_density` を 0.08 前後に設定する
- [x] 4.4 `WorldEnvironment` はシーン初期化時に 1 度だけ生成され、プレイヤー移動時に再生成されないことをコード上で保証する
- [x] 4.5 起動して奥が暗く沈むこと、周囲が過度に明るくないことを手動確認する

## 5. Procedural stone shader

- [x] 5.1 シェーダに world-space 擬似ノイズ関数を実装し、albedo に斑模様として乗算する(triplanar 的に normal の主軸で 2D 座標を選ぶ)
- [x] 5.2 壁面(normal の y 成分が小さい)に対し、world-space の y 座標と水平座標を量子化して煉瓦段ラインを描画する
- [x] 5.3 距離 AO を実装する(`length(CAMERA_POSITION_WORLD - VERTEX)` を使った 1 - smoothstep による albedo 減衰)
- [x] 5.4 タイル種別(`COLOR`)のヒュー差分が残るよう、ベースティントとノイズ/ブリックの強度を調整する
- [x] 5.5 起動して石壁らしい斑+煉瓦段+距離減衰が同時に効いていることを手動確認する

## 6. Visual tuning

- [x] 6.1 松明の `light_energy` と fog_density、距離 AO の `near/far`、ベース色を調整し、`tmp/dungeon.png` を改善前と撮り比べる
- [x] 6.2 扉 (DOOR) が壁 (WALL) から視覚的に区別可能であることを確認する
- [x] 6.3 階段 (STAIRS) が FLOOR と区別可能であることを確認する
- [x] 6.4 ミニマップ・HUD の視認性に悪影響が出ていないことを確認する

## 8. Door distinction and lateral visibility

- [x] 8.1 シェーダで扉タイル(頂点色の r - b > 0.25)を検出し、煉瓦ではなく縦木板+横帯(cross-band)パターンで描画する
- [x] 8.2 扉の表面からは stone speckle ノイズを外し、横方向木目のノイズに差し替える
- [x] 8.3 `DungeonView` の `left_visible`/`right_visible` ゲートを撤去し、各深さでラテラル判定を独立に行う
- [x] 8.4 視界テスト(`test_dungeon_view.gd` の near-wall occludes 系)を新挙動に合わせて更新し、分岐開口部が見える新シナリオを追加
- [x] 8.5 spec.md の `DungeonView calculates visible cells` に「奥の開口部は手前の壁で遮蔽されない」シナリオを追記
- [x] 8.6 spec.md の procedural shader 要件に「扉は木板パターン」シナリオを追記
- [x] 8.7 `DungeonView.get_visible_cells` に `fill_openings` パラメータを追加し、OPEN エッジ経由で 1 ホップ分の隣接セルを追加する flood を実装する(描画用)
- [x] 8.8 `DungeonScreen._refresh_all` の render_cells 計算で `fill_openings = true` を指定する(探索マーキングは従来どおり strict)
- [x] 8.9 spec.md に `fill_openings` の挙動を追記

## 7. Regression

- [x] 7.1 既存の GUT スイート全体を実行し、描画系以外のテストが通ることを確認する
- [x] 7.2 DungeonView の可視セル計算・CellMeshBuilder のジオメトリ生成に関する仕様は変えていないことを確認する(テストが依然緑)
- [x] 7.3 スクリーンショット比較(Before/After)を PR 説明用に `tmp/` に保存する
