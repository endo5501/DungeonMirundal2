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

- [x] 3.1 `tests/dungeon/test_monster_repository.gd` に「`find_by_tier(2)` が goblin/skeleton を含む」「`find_by_tier(99)` が空配列を返す (not null)」「同じ呼び出しが同じ順序を返す (deterministic)」のテストを追加 (red)
- [x] 3.2 `src/dungeon/monster_repository.gd` に `find_by_tier(tier: int) -> Array[MonsterData]` を実装 (green)
- [x] 3.3 `tests/dungeon/test_monster_repository.gd` の全テストが通ることを確認
- [x] 3.4 上記をコミット (`feat: add MonsterRepository.find_by_tier`)

## 4. EncounterTableData を新スキーマへ刷新

- [x] 4.1 `tests/dungeon/test_encounter_table_data.gd` を新スキーマ用に書き換え
- [x] 4.2 `src/dungeon/data/encounter_table_data.gd` から `entries` フィールドと `total_weight` メソッドを削除
- [x] 4.3 `src/dungeon/data/encounter_table_data.gd` に `tier_weights` `species_count_min/max` `count_per_species_min/max` を追加し `is_valid()` を新条件で実装
- [x] 4.4 tier_weights のキー正規化 (文字列→int) ヘルパー `normalized_tier_weights()` を追加
- [x] 4.5 `tests/dungeon/test_encounter_table_data.gd` の全テストが通ることを確認
- [x] 4.6 上記をコミット (sections 4-9 を 1 commit にまとめる)

## 5. EncounterPattern / EncounterEntry / MonsterGroupSpec を削除

- [x] 5.1 `tests/dungeon/test_encounter_pattern.gd` 等の旧 Pattern 系テストファイルを削除
- [x] 5.2 `src/dungeon/data/encounter_pattern.gd` を削除 (`.gd.uid` も含む)
- [x] 5.3 `src/dungeon/data/encounter_entry.gd` を削除 (`.gd.uid` も含む)
- [x] 5.4 `src/dungeon/data/monster_group_spec.gd` を削除 (`.gd.uid` も含む)
- [x] 5.5 残った参照を grep で洗い出し → 不要な参照は SpellResolution.entries のみ (無関係)
- [x] 5.6 sections 4-9 の単一コミットにまとめる

## 6. EncounterManager.generate を tier 抽選アルゴリズムへ刷新

- [x] 6.1 `tests/dungeon/test_encounter_manager.gd` を tier 方式に書き換え
- [x] 6.2 `src/dungeon/encounter_manager.gd` の `generate` を tier 抽選アルゴリズムで書き直す
- [x] 6.3 `tests/dungeon/test_encounter_manager_row_truncation.gd` を新 API で書き換え
- [x] 6.4 全テストが通ることを確認
- [x] 6.5 sections 4-9 の単一コミットにまとめる

## 7. EncounterCoordinator のテストを新 API へ追随

- [x] 7.1 `tests/dungeon/test_encounter_coordinator.gd` のヘルパーを新スキーマで書き直す
- [x] 7.2 既存の floor-based table selection / fallback テストが通るように調整
- [x] 7.3 `tests/dungeon/test_encounter_coordinator.gd` 全テストが通ることを確認
- [x] 7.4 sections 4-9 の単一コミットにまとめる

## 8. data/encounter_tables/ のテーブル .tres を刷新・新規作成

- [x] 8.1 `tests/dungeon/test_data_loader.gd` の floor table テストを新スキーマで書き直し、floor 1〜12 全存在チェックを追加
- [x] 8.2 `data/encounter_tables/floor_1.tres` を新スキーマで上書き
- [x] 8.3 `data/encounter_tables/floor_2.tres` を新スキーマで上書き
- [x] 8.4 `data/encounter_tables/floor_3.tres` を新規作成
- [x] 8.5 `data/encounter_tables/floor_4.tres` を新規作成
- [x] 8.6 `data/encounter_tables/floor_5.tres` を新規作成
- [x] 8.7 `data/encounter_tables/floor_6.tres` を新規作成
- [x] 8.8 `data/encounter_tables/floor_7.tres` を新規作成
- [x] 8.9 `data/encounter_tables/floor_8.tres` を新規作成
- [x] 8.10 `data/encounter_tables/floor_9.tres` を新規作成
- [x] 8.11 `data/encounter_tables/floor_10.tres` を新規作成
- [x] 8.12 `data/encounter_tables/floor_11.tres` を新規作成
- [x] 8.13 `data/encounter_tables/floor_12.tres` を新規作成
- [x] 8.14 `tests/dungeon/test_data_loader.gd` 全テストが通ることを確認
- [x] 8.15 sections 4-9 の単一コミットにまとめる

## 9. main.gd 等の呼び出し側を最終確認

- [x] 9.1 `src/main.gd` は `is_valid()` を経由するだけで interface 互換、変更不要
- [x] 9.2 grep で旧クラス参照が残っていないことを確認 (SpellResolution.entries は無関係)
- [x] 9.3 全テスト 2444 件 green を確認
- [x] 9.4 sections 4-9 をまとめてコミット (`refactor: replace encounter patterns with tier-weighted generation`)

## 10. 手動動作確認

- [ ] 10.1 Godot エディタでプロジェクトを起動 → エラー無くロードできることを確認
- [ ] 10.2 SMALL ダンジョン (2〜4階) を新規作成 → 各階を歩き回り tier 1〜2 のモンスター (slime/bat/goblin/skeleton) が出現することを確認
- [ ] 10.3 LARGE ダンジョン (8〜12階) を新規作成 → 深部で tier 4〜5 のモンスター (witch/dark_priest/wraith/lich/dragon) が出現することを確認
- [ ] 10.4 push_warning が想定外で出ていないか、出力ログを確認 (空 tier hit や row truncation overflow が起きていないか)

## 11. OpenSpec ドキュメント検証

- [x] 11.1 `openspec validate add-monster-tier-encounters --strict` を実行して strict 検証パスを確認
- [ ] 11.2 全テスト・手動確認パス後、`/opsx:archive` でアーカイブする (実装完了後の作業)
