## 1. ExploredMap

- [x] 1.1 ExploredMap クラスを実装する（mark_visited, mark_visible, is_visited, get_visited_cells, clear）
- [x] 1.2 ExploredMap のテストを作成・通過させる

## 2. MinimapRenderer

- [x] 2.1 MinimapRenderer クラスを実装する（render メソッドで Image を生成）
- [x] 2.2 エッジベースのピクセルマッピング（床・壁・ドア・角・背景）を実装する
- [x] 2.3 プレイヤー位置・方向の描画を実装する
- [x] 2.4 MinimapRenderer のテストを作成・通過させる

## 3. MinimapDisplay

- [x] 3.1 MinimapDisplay（Control）を実装する（TextureRect + Image 表示、右上配置、半透明背景）
- [x] 3.2 DungeonScreen にミニマップを組み込み、移動時に refresh する

## 4. PartyData

- [x] 4.1 PartyMemberData クラスを実装する（name, level, hp, mp）
- [x] 4.2 PartyData クラスを実装する（front_row, back_row, create_placeholder）
- [x] 4.3 PartyData のテストを作成・通過させる

## 5. PartyDisplay

- [x] 5.1 PartyMemberPanel（Control）を実装する（プレースホルダー画像、名前、LV、HP、MP 表示）
- [x] 5.2 PartyDisplay（Control）を実装する（前列3枠・後列3枠の配置、下部オーバーレイ、半透明背景）
- [x] 5.3 DungeonScreen にパーティ表示を組み込む

## 6. 統合

- [x] 6.1 DungeonScreen の更新フローを実装する（移動時に ExploredMap 更新 → ミニマップ再描画）
- [x] 6.2 初期表示時にスタート地点の可視セルを探索済みにする
- [x] 6.3 実際の画面で動作確認し、オーバーレイの視認性を調整する

## 7. 最終確認

- [x] 7.1 `/simplify`スキルを使用してコードレビューを実施
- [x] 7.2 `/codex:review --scope branch --background` スキルを使用して現在開発中のコードレビューを実施
- [x] 7.3 `/opsx:verify`でchangeを検証
