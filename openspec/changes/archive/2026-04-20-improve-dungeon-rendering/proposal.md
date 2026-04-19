## Why

現状のダンジョン 1 人称 3D 描画は `SHADING_MODE_UNSHADED` + ライト/環境光/フォグ無しのフラット塗りで、壁 0.70 と床/天井 0.10〜0.15 の輝度比が 4〜7 倍あり、明暗が二値的で地下迷宮らしい雰囲気に欠ける。既存の頂点法線は用意されているのに活かされておらず、追加アセット無しでも大きく見栄えを改善できる余地がある。

## What Changes

- `DungeonScene` にダイナミックな照明環境を導入する
  - `Camera3D` の子として松明相当の `OmniLight3D` を追加(暖色・距離減衰)
  - `WorldEnvironment` を追加し、ambient をほぼ黒、`depth_fog` を有効化
- 壁面マテリアルをライティングに反応する形へ変更する
  - `StandardMaterial3D` の `SHADING_MODE_UNSHADED` を解除し、既存 normal を利用
  - もしくは `ShaderMaterial` に置換(下記 C を参照)
- 手続き型シェーダで石壁風の質感を描く
  - world-space 座標ベースの擬似ノイズで斑模様
  - 壁の Y 座標を利用した煉瓦段ラインを描画
  - カメラからの距離に応じた擬似 AO(奥を暗く)
  - UV は当面追加せず triplanar 的な手法で回避
  - 扉タイルは頂点色の色調から検出し、煉瓦ではなく木板+横帯の専用パターンに切り替え
- タイル種別ごとの基本色(壁/床/天井/扉/階段)を暗めにリバランス
- CellMeshBuilder のパレット定数変更に伴う既存ユニットテストの更新
- `DungeonView` の視界判定を緩和し、手前の側壁が奥の開口部を遮蔽しないよう各深さ独立でラテラル判定する(深度バッファが幾何学的遮蔽を担保)

## Capabilities

### New Capabilities
<!-- なし -->

### Modified Capabilities
- `dungeon-3d-rendering`: 描画仕様に「動的ライト(松明)」「環境光/フォグ」「手続き型シェーダによる石壁風の質感」「タイル種別ごとの最新パレット」を追加し、「WALL はグレー/DOOR は茶色のベタ塗り」という現行要件をライティング前提の表現へ更新する

## Impact

- コード: `src/dungeon_scene/dungeon_scene.gd`(ライト/環境/マテリアル構築)、`src/dungeon/cell_mesh_builder.gd`(パレット定数のみ)
- 新規アセット(シェーダ): `src/dungeon_scene/dungeon_wall.gdshader`(仮名)
- 外部 PNG テクスチャの追加は本変更では行わない(将来 change で検討)
- UV の生成は本変更では行わない(world-space 手続き描画で回避)
- テスト: `tests/dungeon/test_cell_mesh_builder.gd` などで色定数をアサートしている箇所があれば追従。描画結果のビジュアル確認は手動 (`tmp/dungeon.png` の比較)
- 非目標: Wizardry クラシック風の黒背景+線画への路線変更、外部テクスチャ採用
