## 1. DungeonData.reset_to_start (入口リセット API)

- [x] 1.1 `tests/dungeon/test_dungeon_data.gd` に `reset_to_start()` のテストを追加する (失敗することを確認): START タイルに戻る / NORTH を向く / explored_map 不変 / dungeon_name・seed・map_size 不変 / 冪等
- [x] 1.2 `src/dungeon/dungeon_data.gd` に `reset_to_start()` を実装する (`_find_start(wiz_map)` を再利用、`player_state = PlayerState.new(start, Direction.NORTH)`)
- [x] 1.3 テストが通ることを確認する

## 2. main.gd 入場時リセット (B3)

- [x] 2.1 `tests/save_load/test_main_dungeon_entry.gd` を新規作成し「`_on_enter_dungeon` 経由で入場すると `DungeonData.player_state` が START にリセットされる」シナリオのテストを追加する (失敗することを確認)
- [x] 2.2 同ファイルにロード経路のテストを追加: `_load_game` 経由で dungeon screen を復元する時はリセットされない
- [x] 2.3 `src/main.gd:_on_enter_dungeon()` で `_current_dungeon_data.reset_to_start()` を `_show_dungeon_screen()` 呼び出しの直前に挿入する
- [x] 2.4 2.1/2.2 のテストが通ることを確認する
- [ ] 2.5 手動テスト: 全滅シナリオ → 町 → 再入場で入口スタートを確認
- [ ] 2.6 手動テスト: 脱出の巻物 → 町 → 再入場で入口スタートを確認
- [ ] 2.7 手動テスト: 緊急脱出の巻物 (戦闘中) → 町 → 再入場で入口スタートを確認
- [ ] 2.8 手動テスト: ダンジョン中でセーブ → ロードで保存位置から開始することを確認

## 3. Minimap START マーカー

- [x] 3.1 `tests/dungeon/test_minimap_renderer.gd` に以下を追加 (失敗することを確認):
  - 探索済み START タイルに専用マーカー色のピクセルが描かれる
  - マーカー色は `COLOR_FLOOR`・`COLOR_PLAYER` と異なる
  - マーカーは対象セルの 3x3 床領域内に収まり、壁ギャップピクセルに侵食しない
  - 未探索 START タイルにはマーカーが描かれない
  - プレイヤーが START タイル上にいる時は中央セルのプレイヤー表示が優先される
- [x] 3.2 `src/dungeon/minimap_renderer.gd` に `COLOR_START` 定数を追加し、`_draw_cell` 内で `tile == TileType.START` のセルに対してマーカー (中央列 3 ピクセル) を重ね描きする
- [x] 3.3 3.1 のテストが通ることを確認する
- [ ] 3.4 手動テスト: ダンジョン内で入口付近を歩き、ミニマップに入口マーカーが表示されることを確認

## 4. 3D 入口の階段メッシュ

- [x] 4.1 `tests/dungeon/test_cell_mesh_builder.gd` に以下を追加 (失敗することを確認):
  - START タイルのセルでは `stairs_up_*` を含む追加 face が生成される
  - FLOOR タイルのセルでは階段 face が生成されない
  - 階段の全頂点がセル内 (x/z 範囲内、`0 <= y < CELL_HEIGHT`) に収まる
  - START タイルでも通常の floor/ceiling は引き続き生成される
- [x] 4.2 `src/dungeon/cell_mesh_builder.gd` に階段色定数と階段メッシュ生成ロジック (`_add_stairs_up`) を追加し、`build_faces` 内で `cell.tile == TileType.START` の時に呼び出す (3 段、各 top/riser/east/west = 4 面 × 3 = 12 face)
- [x] 4.3 4.1 のテストが通ることを確認する
- [ ] 4.4 手動テスト: Godot エディタで実行し、入口セル上で 3D ビューに階段が立体的に描かれていることを確認

## 5. 最終検証

- [x] 5.1 すべてのテストスイートを実行して通過を確認する (1066 tests passing)
- [ ] 5.2 入口が見えない・位置が残る問題が再現しないことをゲーム内で一連の流れ (通常探索 → 全滅 / 脱出巻物 / 自発帰還 → 再入場) で確認する
- [x] 5.3 `openspec validate improve-dungeon-entrance-ux --strict` を実行して構文エラーがないことを確認する
- [x] 5.4 変更内容をまとめてコミットする (英語メッセージ) — commit 885a21b
