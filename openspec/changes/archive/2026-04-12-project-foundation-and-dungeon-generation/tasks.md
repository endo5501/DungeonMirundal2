## 1. プロジェクト初期セットアップ

- [x] 1.1 Godot 4.x プロジェクトを作成（project.godot, src/, tests/ ディレクトリ）
- [x] 1.2 GUT プラグインを addons/gut/ に導入し、テスト実行を確認
- [x] 1.3 サンプルテスト（hello world レベル）を作成してGUT動作を検証

## 2. 基本データ型の実装

- [x] 2.1 Direction（方向enum + dx/dy/opposite ヘルパー）のテストを作成
- [x] 2.2 Direction を実装（src/dungeon/direction.gd）
- [x] 2.3 EdgeType（WALL/OPEN/DOOR）と TileType（FLOOR/START/GOAL）のテストを作成
- [x] 2.4 EdgeType, TileType を実装（src/dungeon/edge_type.gd, tile_type.gd）
- [x] 2.5 Cell クラスのテストを作成（初期状態、エッジ保持）
- [x] 2.6 Cell クラスを実装（src/dungeon/cell.gd）
- [x] 2.7 Rect クラスのテストを作成（intersects, contains, center）
- [x] 2.8 Rect クラスを実装（src/dungeon/rect.gd）

## 3. WizMap 基本機能

- [x] 3.1 WizMap の初期化テストを作成（サイズ制約、全セルWALL初期化）
- [x] 3.2 WizMap の基本構造を実装（コンストラクタ、in_bounds, cell, set_edge, get_edge）
- [x] 3.3 エッジ双方向同期のテストを作成
- [x] 3.4 open_between, set_edge の双方向同期を実装
- [x] 3.5 移動判定（can_move）のテストを作成
- [x] 3.6 can_move を実装

## 4. 完全迷路生成

- [x] 4.1 carve_perfect_maze のテストを作成（全セル連結、スパニングツリーのエッジ数）
- [x] 4.2 carve_perfect_maze を実装（DFSによる完全迷路）

## 5. 部屋生成

- [x] 5.1 generate_rooms のテストを作成（部屋サイズ制約、重なりなし、マップ端マージン）
- [x] 5.2 generate_rooms を実装
- [x] 5.3 carve_room / carve_rooms のテストを作成（部屋内部OPEN化）
- [x] 5.4 carve_room / carve_rooms を実装

## 6. ループとドア

- [x] 6.1 add_extra_links のテストを作成（壁のOPEN化、連結維持）
- [x] 6.2 add_extra_links を実装
- [x] 6.3 add_doors_between_room_and_nonroom のテストを作成（部屋境界のDOOR配置条件）
- [x] 6.4 add_doors_between_room_and_nonroom を実装

## 7. 解析と配置

- [x] 7.1 BFS のテストを作成（距離計算の正確性）
- [x] 7.2 BFS を実装
- [x] 7.3 is_fully_connected のテストを作成
- [x] 7.4 is_fully_connected を実装
- [x] 7.5 place_start_and_goal のテストを作成（START位置、GOAL最遠）
- [x] 7.6 place_start_and_goal を実装

## 8. 生成パイプライン統合

- [x] 8.1 generate メソッドの統合テストを作成（デフォルト/カスタムパラメータ、シード再現性）
- [x] 8.2 generate メソッドを実装
- [x] 8.3 シード再現性テスト（同一シード→同一結果、異なるシード→異なる結果）を確認
