## 1. TileType と FloorData の基盤整備

- [x] 1.1 `tests/dungeon/test_tile_type.gd` に `STAIRS_DOWN` / `STAIRS_UP` の enum 値が定義されているテストを追加（red）
- [x] 1.2 `src/dungeon/tile_type.gd` の enum を `{ FLOOR, START, GOAL, STAIRS_DOWN, STAIRS_UP }` に拡張（green）
- [x] 1.3 `tests/dungeon/test_floor_data.gd` を新規作成し、`FloorData.create(seed, size, role)` で WizMap が役割に応じたタイル配置で生成されることを検証するテストを書く（red）
- [x] 1.4 `src/dungeon/floor_data.gd` を新規作成（`seed_value` / `map_size` / `wiz_map` / `explored_map` を保持、`to_dict` / `from_dict` 含む）し 1.3 のテストを通す（green）
- [x] 1.5 `tests/dungeon/test_floor_data.gd` に to_dict/from_dict の round-trip テストを追加し通す
- [x] 1.6 `Grep` で旧 `TileType.FLOOR/START/GOAL` 直接参照箇所（`full_map_renderer` / `cell_mesh_builder` / `minimap_renderer` / `dungeon_view` / `dungeon_screen` 等）を洗い出し、新タイルが登場した場合の最低限の表示挙動（START と同等で可）を実装。それぞれ既存テストで非回帰を確認

## 2. WizMap 階段配置と generate API 拡張

- [x] 2.1 `tests/dungeon/test_wiz_map.gd` に「first / middle / last / single 各役割で正しい組合せのタイル（START/STAIRS_DOWN/STAIRS_UP/GOAL）が配置される」テストを追加（red）
- [x] 2.2 `src/dungeon/wiz_map.gd` に `place_for_role(rng, role)` 相当の API を追加（既存 `place_start_and_goal` を内部利用または役割分岐）し 2.1 を green にする
- [x] 2.3 `tests/dungeon/test_wiz_map.gd` に「階段マスは部屋中央付近 / BFS 最遠点に配置される」テストを追加して通す
- [x] 2.4 `tests/dungeon/test_wiz_map.gd` に「階段マスのエッジ通行性は STAIRS_DOWN/UP でも他タイルと同じ規則で判定される」テストを追加して通す
- [x] 2.5 `WizMap.generate(seed, ..., role)` のシグネチャに role 引数（または新メソッド `generate_for_role`）を追加し、既存呼び出し側（`DungeonData.create` 等）の互換性を担保

## 3. PlayerState の current_floor 拡張

- [x] 3.1 `tests/dungeon/test_player_state.gd`（無ければ新規作成）に「`current_floor` が初期値 0 で読み書きできる」テストを追加（red）
- [x] 3.2 `src/dungeon/player_state.gd` に `current_floor: int = 0` を追加して 3.1 を green
- [x] 3.3 `to_dict` / `from_dict` の round-trip テストを追加し（current_floor 含む / 欠落時は 0 にデフォルト）通す

## 4. DungeonData の多階層化

- [x] 4.1 `tests/dungeon/test_dungeon_data.gd` の既存テストを多階層 API に書き換え（red になる前提）
- [x] 4.2 `tests/dungeon/test_dungeon_data.gd` に「`DungeonData.create(name, base_seed, size_category, floor_count)` で `floors` が指定数生成され、各階の seed が決定論的派生になっている」テストを追加(red)
- [x] 4.3 `tests/dungeon/test_dungeon_data.gd` に「`current_wiz_map()` / `current_explored_map()` が `player_state.current_floor` に追従する」テストを追加（red）
- [x] 4.4 `tests/dungeon/test_dungeon_data.gd` に「`get_exploration_rate()` が全階合計セル数に対する全階合計訪問セル数になる」テストを追加（red）
- [x] 4.5 `tests/dungeon/test_dungeon_data.gd` に「`reset_to_start()` が floors[0] の START + current_floor=0 へ戻し、explored_map は不変」テストを追加（red）
- [x] 4.6 `src/dungeon/dungeon_data.gd` を多階層構造に再実装し 4.1-4.5 を green
- [x] 4.7 `tests/dungeon/test_dungeon_data.gd` に to_dict / from_dict の round-trip テスト（多階層、current_floor 込み）を追加して通す

## 5. DungeonRegistry の階数決定

- [x] 5.1 `DungeonRegistry` 用テスト（既存 or 新規）に「create(SMALL) で floors.size() が 2-4」「MEDIUM で 4-7」「LARGE で 8-12」のテストを追加（red）
- [x] 5.2 `src/dungeon/dungeon_registry.gd` に階数レンジ定数を追加し、`create()` が `_rng.randi_range` で階数決定するよう修正（green）
- [x] 5.3 同テストで「各階の map_size が size_category のレンジ内で独立にランダム決定される」検証を追加して通す
- [x] 5.4 同テストで「同一 RNG seed なら create() の結果が決定論的（floors 数・各階 seed が一致）」検証を追加して通す
- [x] 5.5 `to_dict` / `from_dict` round-trip テストを多階層対応に更新して通す

## 6. DungeonScreen の階対応とフロア遷移

- [x] 6.1 `tests/esc_menu/test_dungeon_screen_esc.gd` ほか DungeonScreen テストの setup を多階層 DungeonData に対応させる（既存テストを green に保つ）
- [x] 6.2 `tests/dungeon/test_dungeon_screen_floor_transition.gd` を新規作成し、「STAIRS_DOWN 進入で `_return_dialog.setup("下の階に降りますか?", ...)` が呼ばれる」テストを追加（red）
- [x] 6.3 同テストに「STAIRS_UP 進入で `_return_dialog.setup("上の階に戻りますか?", ...)` が呼ばれる」テスト追加（red）
- [x] 6.4 同テストに「descend 確定で current_floor が +1、position が次階の STAIRS_UP、facing 保持」テスト追加（red）
- [x] 6.5 同テストに「ascend 確定で current_floor が -1、position が前階の STAIRS_DOWN、facing 保持」テスト追加（red）
- [x] 6.6 同テストに「stair 進入時にエンカウンタが同時トリガすると、エンカウンタが先に表示され、解決後に階段ダイアログが出る」テスト追加（red）
- [x] 6.7 同テストに「フロア遷移では step_taken が emit されない」テスト追加（red）
- [x] 6.8 `src/dungeon_scene/dungeon_screen.gd` を実装更新し 6.2-6.7 を green
  - `_dungeon_data` から `current_wiz_map()` / `current_explored_map()` を都度取得する形に変更
  - `_check_stair_tile()` を追加し、`_on_position_changed` の中で START チェック前に評価
  - `_on_descend_confirmed()` / `_on_ascend_confirmed()` を追加し、階遷移とレンダリング差し替え（`_dungeon_scene.wiz_map` の差し替え、`_minimap_display.setup` 再呼び出し、`_full_map_overlay.setup` 再呼び出し、`_refresh_all`）を行う
  - 遷移ロジックでは `step_taken` を emit しない
- [x] 6.9 既存の `dungeon-return` 系テストが多階層構造でも非回帰であることを確認

## 7. EncounterCoordinator の階別テーブル切替

- [x] 7.1 `tests/dungeon/test_encounter_coordinator.gd` に「ダンジョン入場時 / 階遷移時に `set_table` が現在階対応のテーブルで呼ばれる」テストを追加（red）
- [x] 7.2 同テストに「該当階のテーブルがない場合、登録済み最大階のテーブルにフォールバックし push_warning が呼ばれる」テスト追加（red）
- [x] 7.3 同テストに「テーブル未登録時にはエンカウンタが発火しない」テスト追加（red）
- [x] 7.4 `src/dungeon/encounter_coordinator.gd` または `main.gd` の `_attach_encounter_coordinator_to_screen` 周辺に、現在階に応じた `set_table` 呼び出しとフォールバックロジックを実装（green）
- [x] 7.5 `main.gd:207-208` の TODO コメントを削除
- [x] 7.6 階遷移時にテーブル再セットがトリガされるよう、`DungeonScreen` から `floor_changed(new_floor)` シグナル等を発火、または `DungeonScreen` 自身が `EncounterCoordinator` への参照を持って set_table する（実装方針は green の中で確定）

## 8. 追加エンカウンターテーブル

- [x] 8.1 `data/encounter_tables/floor_2.tres` を新規作成（floor=2、`floor_1.tres` と同等のスキーマ、やや強めの構成）
- [x] 8.2 `tests/dungeon/test_data_loader.gd` で `load_all_encounter_tables` が floor_1 と floor_2 の両方を返すことを検証
- [ ] 8.3 （任意）floor_3.tres も追加して MEDIUM 以上のダンジョンで意味のある段階差をつける

## 9. 統合テストとレンダリング検証

- [x] 9.1 `tests/save_load/` に多階層 DungeonData を含むセーブの round-trip テストを追加し、ロード後の各階 wiz_map（タイル配置含む）と explored_map が完全一致することを検証
- [x] 9.2 GUT テスト一式を実行し全 green であることを確認
- [x] 9.3 PlayGodot 等で実機起動し、新規ダンジョン作成 → 1F STAIRS_DOWN → 2F STAIRS_UP → 1F の往復、町への帰還、セーブ/ロード後の階位置復元、エンカウンタ発火を手動で確認
- [x] 9.4 確認結果をコミットメッセージで言及（手動確認項目を列挙）

## 10. 仕上げ

- [x] 10.1 `openspec validate add-multi-floor-dungeons` が通ることを確認
- [x] 10.2 不要になったコメント・dead code を削除（旧 single-floor 経路、`_wiz_map`/`_explored_map` の保持様式変更に伴うクリーンアップ）
- [x] 10.3 変更内容を 1 つのコミットに集約してコミット（コミットメッセージは英語）
- [x] 10.4 `/simplify`スキルでコードレビューを実施
