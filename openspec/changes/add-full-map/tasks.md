## 1. FullMapRenderer (TDD)

- [x] 1.1 `tests/dungeon/test_full_map_renderer.gd` を作成し、Image サイズ計算 (target_size と map_size から cell_px を導く) のテストを書く
- [x] 1.2 探索済み/未探索セルの描画 (床色塗り、未探索は背景色のまま) のテストを追加する
- [x] 1.3 WALL / DOOR / OPEN エッジの描画ルールのテストを追加する (ミニマップと同じく OPEN は両側探索済みなら床色で繋がる、片側未探索なら背景)
- [x] 1.4 START / GOAL マーカー描画のテストを追加する (色が互いに異なること、未探索なら描画されないこと、床域内に収まること)
- [x] 1.5 プレイヤー描画のテスト (位置・向きインジケータ、START 上で player 優先) を追加する
- [x] 1.6 テストを実行して全て失敗することを確認しコミットする (Red)
- [x] 1.7 `src/dungeon/full_map_renderer.gd` を実装する。RefCounted、`render(wiz_map, explored_map, player_state, target_size: Vector2i) -> Image` を提供する
- [x] 1.8 テストを実行して全て通過することを確認しコミットする (Green)

## 2. FullMapOverlay (TDD)

- [x] 2.1 `tests/dungeon/test_full_map_overlay.gd` を作成し、初期状態が `visible == false` であるテストを書く
- [x] 2.2 `open()` / `close()` / `is_open()` のライフサイクルのテストを追加する
- [x] 2.3 HUD 表示テスト (ダンジョン名・座標・探索率% が Label に反映されること、再開時に値が更新されること) を追加する
- [x] 2.4 ESC 入力で閉じるテストと、`get_viewport().set_input_as_handled()` が呼ばれていることを検証するテストを追加する (シグナル経由でも代替可)
- [x] 2.5 ミニマップ可視性連動のテスト (open で minimap_display.visible = false、close で true) を追加する
- [x] 2.6 テストを実行して全て失敗することを確認しコミットする (Red)
- [x] 2.7 `src/dungeon_scene/full_map_overlay.gd` を実装する。Control、PRESET_FULL_RECT、半透明背景パネル、TextureRect、3 つの Label (上部: ダンジョン名 / 下部: 座標・探索率)
- [x] 2.8 setup メソッドで `wiz_map`、`explored_map`、`player_state`、`dungeon_data` (名前と探索率取得用)、`minimap_display` 参照を受け取る
- [x] 2.9 `_unhandled_input` で ESC を処理し、`close()` を呼んで input を消費する
- [x] 2.10 テストを実行して全て通過することを確認しコミットする (Green)

## 3. DungeonScreen 統合 (TDD)

- [x] 3.1 `tests/dungeon/test_dungeon_screen.gd` (既存があれば追記、無ければ新規) に M キーで overlay が toggle されるテストを追加する
- [x] 3.2 エンカウンター中・帰還ダイアログ中は M キーが無視されるテストを追加する
- [x] 3.3 オーバーレイ表示中は移動キー (UP/DOWN/LEFT/RIGHT) が無効化されるテストを追加する
- [x] 3.4 オーバーレイ閉じた後に移動が再開できるテストを追加する
- [x] 3.5 テストを実行して全て失敗することを確認しコミットする (Red)
- [x] 3.6 `src/dungeon_scene/dungeon_screen.gd` の `setup()` で `FullMapOverlay` を生成して add_child し、`setup()` 内で必要な依存 (DungeonData の参照を含む) を渡す
- [x] 3.7 `setup_from_data()` から DungeonData を保持するフィールドを追加し、オーバーレイへ渡せるようにする
- [x] 3.8 `_unhandled_input` の冒頭で「オーバーレイ表示中なら早期リターン (M キーと ESC は overlay 側で処理されるので DungeonScreen は何もしない)」を追加する
- [x] 3.9 `_unhandled_input` の `_encounter_active` / `_showing_return_dialog` チェック後に M キー処理を追加 (toggle 呼び出し)
- [x] 3.10 テストを実行して全て通過することを確認しコミットする (Green)

## 4. 動作確認

- [x] 4.1 `godot --headless --import` を実行して新規 class_name を認識させる
- [x] 4.2 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイートが通ることを確認する
- [ ] 4.3 Godot エディタからゲームを起動し、ダンジョン画面で M キーを押して全体マップが表示されることを目視確認する
- [ ] 4.4 探索済みセルのみが描画されること、START / GOAL マーカーとプレイヤー位置・向きが表示されることを確認する
- [ ] 4.5 オーバーレイ表示中に移動キーを押しても動かないこと、ミニマップが消えていることを確認する
- [ ] 4.6 ESC で閉じた時に ESCメニューが開かないこと、もう一度 M で再開閉できることを確認する
- [ ] 4.7 エンカウンター発生中に M キーを押してもオーバーレイが開かないことを確認する
- [ ] 4.8 START タイル上で帰還ダイアログ表示中に M キーを押してもオーバーレイが開かないことを確認する

## 5. 仕上げ

- [x] 5.1 `openspec validate add-full-map --strict` で仕様の妥当性を検証する
- [ ] 5.2 すべてのテストが通り目視確認も完了したらコミットする
- [ ] 5.3 `/opsx:verify add-full-map` で実装と仕様の整合を最終確認する
- [ ] 5.4 `/opsx:archive add-full-map` で変更をアーカイブする
