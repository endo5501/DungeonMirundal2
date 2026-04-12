## 1. PlayerState（プレイヤー状態管理）

- [x] 1.1 PlayerState クラスのテスト作成（test_player_state.gd）: 初期化、位置・方向の取得、turn_left/turn_right の回転テスト
- [x] 1.2 PlayerState クラスの実装（player_state.gd）: RefCounted、位置(Vector2i)・方向(int)の保持、turn_left/turn_right
- [x] 1.3 move_forward / move_backward のテスト作成: OPEN/DOOR で移動成功、WALL で移動失敗、マップ境界での移動拒否
- [x] 1.4 move_forward / move_backward の実装: WizMap.can_move() を利用した壁判定付き移動

## 2. DungeonView（視野計算）

- [x] 2.1 DungeonView クラスのテスト作成（test_dungeon_view.gd）: 前方4セル+左右1セルの可視セル計算、壁による遮蔽、マップ境界制限
- [x] 2.2 DungeonView クラスの実装（dungeon_view.gd）: RefCounted、プレイヤー位置・方向と WizMap から可視セルリストを返す

## 3. CellMeshBuilder（メッシュデータ生成）

- [x] 3.1 CellMeshBuilder のテスト作成（test_cell_mesh_builder.gd）: WALL エッジでの壁面頂点データ生成、OPEN エッジでは壁面なし、DOOR エッジでドア用マテリアル指定、床・天井の頂点データ生成
- [x] 3.2 CellMeshBuilder の実装（cell_mesh_builder.gd）: RefCounted、セル座標とエッジ情報から頂点データ（位置・法線・色）を生成

## 4. DungeonScene（3D シーン描画）

- [x] 4.1 DungeonScene の実装（dungeon_scene.gd）: Node3D、Camera3D の配置、ImmediateMesh による壁・床・天井描画
- [x] 4.2 DungeonScene の更新ロジック: PlayerState 変更時に視野再計算・メッシュ再構築・カメラ位置更新

## 5. DungeonScreen（画面構成とキー入力）

- [x] 5.1 DungeonScreen の実装（dungeon_screen.gd）: Control、SubViewportContainer + SubViewport + DungeonScene の組み立て
- [x] 5.2 キーボード入力処理の実装: 矢印キー / WASD → PlayerState の move_forward / move_backward / turn_left / turn_right 呼び出し
- [x] 5.3 統合テスト: WizMap 生成 → DungeonScreen 表示 → キー入力で移動・回転が正しく動作することをブラウザ/Godot エディタで確認
