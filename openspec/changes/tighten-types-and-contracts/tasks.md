## 1. RaceData / JobData に id フィールド追加 (TDD)

- [x] 1.1 `tests/data/test_race_data.gd` (新規) に `RaceData` の `id: StringName` フィールド存在テストを追加
- [x] 1.2 `tests/data/test_job_data.gd` (新規) に同様のテスト追加
- [x] 1.3 `tests/data/test_data_files.gd` (新規 or 既存) で全 `data/races/*.tres` の `id` が ファイル名 basename と一致することを assert するテスト追加
- [x] 1.4 `data/jobs/*.tres` についても同様のテスト追加
- [x] 1.5 テスト Red コミット
- [x] 1.6 `src/data/race_data.gd` に `@export var id: StringName` を追加
- [x] 1.7 `src/data/job_data.gd` に同様
- [x] 1.8 各 `data/races/*.tres` ファイルを Godot エディタで開いて `id` 値を設定(human.tres → "human" など)
- [x] 1.9 各 `data/jobs/*.tres` についても同様
- [x] 1.10 テスト Green コミット

## 2. Character.to_dict の id 経由化 (TDD)

- [x] 2.1 `tests/dungeon/test_character.gd` に「id 設定済み RaceData を使った to_dict が race_id = id 値を返す」テスト追加
- [x] 2.2 「id 未設定の RaceData (id == &"") では resource_path から fallback する」テスト追加
- [x] 2.3 テスト Red コミット
- [x] 2.4 `src/dungeon/character.gd:to_dict` の `race.resource_path.get_file().get_basename()` を `race.id != &"" ? String(race.id) : <fallback>` に変更
- [x] 2.5 同様に job_id の取得も修正
- [x] 2.6 fallback 経路で `push_warning` を出す
- [x] 2.7 テスト Green コミット

## 3. Inventory.spend_gold(0) を no-op true に (TDD)

- [x] 3.1 `tests/items/test_inventory.gd` に「spend_gold(0) が true を返し、gold は変わらない」テスト追加
- [x] 3.2 テスト Red コミット
- [ ] 3.3 `src/items/inventory.gd:spend_gold` を amount==0 で true 返却に変更
- [ ] 3.4 テスト Green コミット

## 4. GameState の初期化対称化 (TDD)

- [ ] 4.1 `tests/game_state/test_game_state.gd` (新規 or 既存) に new_game 後の各フィールドの値テスト
- [ ] 4.2 「new_game を 2 度呼んでも item_repository が保持される」テスト追加
- [ ] 4.3 「_ready が idempotent(2 度呼んでも既存 guild が再構築されない)」テスト追加
- [ ] 4.4 テスト Red(item_repository 保持はおそらく既に通る、対称性テストが Red)
- [ ] 4.5 `src/game_state.gd` に `_initialize_state(reset_for_new_game: bool = false)` ヘルパーを追加
- [ ] 4.6 `_ready` を `_initialize_state(false)` 呼び出しに置換
- [ ] 4.7 `new_game` を `_initialize_state(true)` 呼び出しに置換
- [ ] 4.8 テスト Green コミット

## 5. 暗黙 Variant の型明示

- [ ] 5.1 `src/dungeon/wiz_map.gd:124` の `var tmp = ...` に型注釈
- [ ] 5.2 `src/items/equipment.gd:116` の `var raw = ...` に型注釈(または `as int` キャスト)
- [ ] 5.3 `src/dungeon_scene/combat_overlay.gd:234` の `var ch = ...` に Variant 注釈 + コメント
- [ ] 5.4 `src/items/item_instance.gd:23` の暗黙型を明示
- [ ] 5.5 `src/items/effects/heal_hp_effect.gd:10` の暗黙型を明示
- [ ] 5.6 `src/items/effects/heal_mp_effect.gd:10` の暗黙型を明示
- [ ] 5.7 `src/dungeon/full_map_renderer.gd:49` の暗黙型を明示
- [ ] 5.8 `src/guild_scene/party_formation.gd:126` の暗黙型を明示
- [ ] 5.9 `src/combat/turn_engine.gd:64,98` の `var cmd = _pending_commands.get(...)` を `var cmd: CombatCommand = ... as CombatCommand` に変更、null チェック追加
- [ ] 5.10 全テスト通過を確認しコミット

## 6. Typed array シグネチャの導入

- [ ] 6.1 `src/dungeon/explored_map.gd:12` の `mark_visible(cells: Array)` を `mark_visible(cells: Array[Vector2i])` に
- [ ] 6.2 `src/dungeon/guild.gd:get_party_characters` を `Array[Array]` で返却
- [ ] 6.3 各テストが通過することを確認しコミット

## 7. 冗長キャスト削除と target 型ドキュメント

- [ ] 7.1 `src/dungeon/wiz_map.gd:218,220` の冗長な `as int` キャストを削除
- [ ] 7.2 `src/items/item.gd:get_target_failure_reason(target, ctx)` の `target` を `Variant` 型注釈、コメントで「Character | CombatActor」を明示
- [ ] 7.3 全テスト通過を確認しコミット

## 8. 動作確認

- [ ] 8.1 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイート通過
- [ ] 8.2 ゲーム起動 → ロード→ 既存セーブが問題なく復元されることを確認
- [ ] 8.3 新規ゲーム → キャラクター作成 → セーブ → ロード のラウンドトリップ確認
- [ ] 8.4 `RaceData.id` が空のままの `.tres` がないことを目視確認(全 5 races + 全 jobs)
- [ ] 8.5 fallback が出ないこと(push_warning がログに出ていないこと)を確認

## 9. 仕上げ

- [ ] 9.1 `openspec validate tighten-types-and-contracts --strict`
- [ ] 9.2 `/simplify`スキルでコードレビューを実施
- [ ] 9.3 `/opsx:verify tighten-types-and-contracts`
- [ ] 9.4 `/opsx:archive tighten-types-and-contracts`
