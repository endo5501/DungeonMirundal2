## 1. MonsterData に tier フィールドを追加

- [x] 1.1 `tests/dungeon/test_monster_data.gd` に「tier デフォルトは 1」「tier=3 は有効」「tier=0 は invalid」「tier=6 は invalid」のテストを追加 (red)
- [x] 1.2 `src/dungeon/data/monster_data.gd` に `@export var tier: int = 1` を追加し `is_valid()` で `1 <= tier <= 5` をチェックする実装を追加 (green)
- [x] 1.3 `tests/dungeon/test_monster_data.gd` の全テストが通ることを確認
- [x] 1.4 上記をコミット (`feat: add tier field to MonsterData`)

## 2. 既存 12 MonsterData .tres に tier 値を明示記入

- [x] 2.1 `tests/dungeon/test_data_loader.gd` に「全 shipped monster が `1 <= tier <= 5`」「slime/bat=1」「goblin/skeleton=2」「ghost/imp/goblin_shaman=3」「witch/dark_priest/wraith=4」「lich/dragon=5」「各 tier に最低1種存在」のテストを追加 (red)
- [x] 2.2 `data/monsters/slime.tres` `bat.tres` に `tier = 1` を追記
- [x] 2.3 `data/monsters/goblin.tres` `skeleton.tres` に `tier = 2` を追記
- [x] 2.4 `data/monsters/ghost.tres` `imp.tres` `goblin_shaman.tres` に `tier = 3` を追記
- [x] 2.5 `data/monsters/witch.tres` `dark_priest.tres` `wraith.tres` に `tier = 4` を追記
- [x] 2.6 `data/monsters/lich.tres` `dragon.tres` に `tier = 5` を追記
- [x] 2.7 `tests/dungeon/test_data_loader.gd` の全テストが通ることを確認
- [x] 2.8 上記をコミット (`feat: assign tier to all shipped monster data`)

## 3. MonsterRepository に find_by_tier を追加

- [ ] 3.1 `tests/dungeon/test_monster_repository.gd` に「`find_by_tier(2)` が goblin/skeleton を含む」「`find_by_tier(99)` が空配列を返す (not null)」「同じ呼び出しが同じ順序を返す (deterministic)」のテストを追加 (red)
- [ ] 3.2 `src/dungeon/monster_repository.gd` に `find_by_tier(tier: int) -> Array[MonsterData]` を実装 (green)
- [ ] 3.3 `tests/dungeon/test_monster_repository.gd` の全テストが通ることを確認
- [ ] 3.4 上記をコミット (`feat: add MonsterRepository.find_by_tier`)

## 4. EncounterTableData を新スキーマへ刷新

- [ ] 4.1 `tests/dungeon/test_encounter_table_data.gd` を新スキーマ用に書き換え:
  - 「`tier_weights` / `species_count_min/max` / `count_per_species_min/max` が読み書きできる」
  - 「空 `tier_weights` は invalid」「全ゼロ `tier_weights` は invalid」
  - 「tier キー 6 は invalid」「tier キー 0 は invalid」
  - 「`species_count_min > species_count_max` は invalid」
  - 「`count_per_species_min > count_per_species_max` は invalid」
  - 「`probability_per_step = 1.5` は invalid」「`probability_per_step = -0.1` は invalid」
  - 「文字列 tier キー `"3"` も int に正規化される」のテストを追加 (red)
- [ ] 4.2 `src/dungeon/data/encounter_table_data.gd` から `entries` フィールドと `total_weight` メソッドを削除
- [ ] 4.3 `src/dungeon/data/encounter_table_data.gd` に `tier_weights` `species_count_min/max` `count_per_species_min/max` を追加し `is_valid()` を新条件で実装 (green)
- [ ] 4.4 tier_weights のキー正規化 (文字列→int) ヘルパーを追加
- [ ] 4.5 `tests/dungeon/test_encounter_table_data.gd` の全テストが通ることを確認
- [ ] 4.6 上記をコミット (`refactor: redesign EncounterTableData around tier weights`)

## 5. EncounterPattern / EncounterEntry / MonsterGroupSpec を削除

- [ ] 5.1 `tests/dungeon/test_encounter_pattern.gd` 等の旧 Pattern 系テストファイルを削除
- [ ] 5.2 `src/dungeon/data/encounter_pattern.gd` を削除 (`.gd.uid` も含む)
- [ ] 5.3 `src/dungeon/data/encounter_entry.gd` を削除 (`.gd.uid` も含む)
- [ ] 5.4 `src/dungeon/data/monster_group_spec.gd` を削除 (`.gd.uid` も含む)
- [ ] 5.5 残った参照 (encounter_manager.gd / encounter_coordinator.gd / tests / main.gd) を grep で洗い出す
- [ ] 5.6 上記をコミット (`refactor: remove EncounterPattern/Entry/MonsterGroupSpec`)

## 6. EncounterManager.generate を tier 抽選アルゴリズムへ刷新

- [ ] 6.1 `tests/dungeon/test_encounter_manager.gd` を tier 方式に書き換え:
  - 「`species_count_min=1, max=1, tier_weights={1:1}` + slime のみ存在 → 結果に slime のみ」
  - 「`count_per_species_min=2, max=4` → 2〜4 体生成」
  - 「重み `{1:1, 2:2, 3:1}` で seed 固定 → tier 2 が選ばれる決定論性」
  - 「同じ seed で 2 度実行 → 同一 party」
  - 「空 tier に当たったら push_warning + そのスロットはスキップ、残りスロットは継続」
  - 「null table → 空 party」
  - 既存の cooldown 系テスト (should_trigger) は維持 (red)
- [ ] 6.2 `src/dungeon/encounter_manager.gd` の `generate` を新アルゴリズムで書き直す:
  - `_pick_weighted_entry` は廃止し `_pick_tier_weighted(tier_weights, rng)` を新設
  - `_populate_party` は廃止し inline の species ループに置き換え
  - `find_by_tier` の結果が空ならスキップ + warning
  - row bucket truncation (ROW_CAP=5, push_warning) は維持
  - `MonsterRepository` への依存は維持 (green)
- [ ] 6.3 `tests/dungeon/test_encounter_manager_row_truncation.gd` を新 API (`tier_weights` + species/count ranges) で書き換え
- [ ] 6.4 `tests/dungeon/test_encounter_manager.gd` `test_encounter_manager_row_truncation.gd` 全テストが通ることを確認
- [ ] 6.5 上記をコミット (`refactor: rewrite EncounterManager.generate around tier weights`)

## 7. EncounterCoordinator のテストを新 API へ追随

- [ ] 7.1 `tests/dungeon/test_encounter_coordinator.gd` のヘルパー (`_make_always_trigger_table` `_make_never_trigger_table` `_make_table_for_floor` 等) を新スキーマで書き直す
- [ ] 7.2 既存の floor-based table selection / fallback テストが通るように調整
- [ ] 7.3 `tests/dungeon/test_encounter_coordinator.gd` 全テストが通ることを確認
- [ ] 7.4 上記をコミット (`test: adapt encounter coordinator tests to tier schema`)

## 8. data/encounter_tables/ のテーブル .tres を刷新・新規作成

- [ ] 8.1 `tests/dungeon/test_data_loader.gd` の `test_loaded_floor_1_table_is_valid` `test_loaded_floor_2_table_is_valid` `test_load_all_encounter_tables_returns_floor_1_and_2` を新スキーマで書き直し、さらに「floor_3〜12 が全て存在 + is_valid」のテストを追加 (red)
- [ ] 8.2 `data/encounter_tables/floor_1.tres` を `tier_weights={1:6, 2:1}, species 1-1, count 2-4, prob 0.10` で上書き
- [ ] 8.3 `data/encounter_tables/floor_2.tres` を `tier_weights={1:4, 2:3}, species 1-2, count 2-4, prob 0.11` で上書き
- [ ] 8.4 `data/encounter_tables/floor_3.tres` を `tier_weights={1:2, 2:5, 3:1}, species 1-2, count 2-4, prob 0.12` で新規作成
- [ ] 8.5 `data/encounter_tables/floor_4.tres` を `tier_weights={1:1, 2:4, 3:3}, species 1-2, count 2-4, prob 0.13` で新規作成
- [ ] 8.6 `data/encounter_tables/floor_5.tres` を `tier_weights={2:2, 3:5, 4:1}, species 1-2, count 2-4, prob 0.13` で新規作成
- [ ] 8.7 `data/encounter_tables/floor_6.tres` を `tier_weights={2:1, 3:4, 4:3}, species 1-2, count 2-4, prob 0.14` で新規作成
- [ ] 8.8 `data/encounter_tables/floor_7.tres` を `tier_weights={3:3, 4:4, 5:1}, species 1-2, count 2-3, prob 0.14` で新規作成
- [ ] 8.9 `data/encounter_tables/floor_8.tres` を `tier_weights={3:2, 4:4, 5:2}, species 1-2, count 2-3, prob 0.15` で新規作成
- [ ] 8.10 `data/encounter_tables/floor_9.tres` を `tier_weights={3:1, 4:4, 5:3}, species 1-2, count 1-3, prob 0.15` で新規作成
- [ ] 8.11 `data/encounter_tables/floor_10.tres` を `tier_weights={4:3, 5:4}, species 1-2, count 1-3, prob 0.16` で新規作成
- [ ] 8.12 `data/encounter_tables/floor_11.tres` を `tier_weights={4:2, 5:5}, species 1-2, count 1-2, prob 0.16` で新規作成
- [ ] 8.13 `data/encounter_tables/floor_12.tres` を `tier_weights={4:1, 5:6}, species 1-1, count 1-2, prob 0.17` で新規作成
- [ ] 8.14 `tests/dungeon/test_data_loader.gd` 全テストが通ることを確認
- [ ] 8.15 上記をコミット (`feat: ship encounter tables for floors 1-12 with tier curve`)

## 9. main.gd 等の呼び出し側を最終確認

- [ ] 9.1 `src/main.gd` の `_load_encounter_tables_by_floor` 周辺が新スキーマで動作することを確認 (基本的には interface 互換で済むはず)
- [ ] 9.2 grep で `EncounterPattern` `EncounterEntry` `MonsterGroupSpec` が残っていないことを確認
- [ ] 9.3 全テスト (`gut`) を実行し green を確認
- [ ] 9.4 上記をコミット (`chore: clean up encounter table call sites`)

## 10. 手動動作確認

- [ ] 10.1 Godot エディタでプロジェクトを起動 → エラー無くロードできることを確認
- [ ] 10.2 SMALL ダンジョン (2〜4階) を新規作成 → 各階を歩き回り tier 1〜2 のモンスター (slime/bat/goblin/skeleton) が出現することを確認
- [ ] 10.3 LARGE ダンジョン (8〜12階) を新規作成 → 深部で tier 4〜5 のモンスター (witch/dark_priest/wraith/lich/dragon) が出現することを確認
- [ ] 10.4 push_warning が想定外で出ていないか、出力ログを確認 (空 tier hit や row truncation overflow が起きていないか)

## 11. OpenSpec ドキュメント検証

- [ ] 11.1 `openspec validate add-monster-tier-encounters --strict` を実行して strict 検証パスを確認
- [ ] 11.2 全テスト・手動確認パス後、`/opsx:archive` でアーカイブする (実装完了後の作業)
