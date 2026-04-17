## 1. データリソース基盤（MonsterData）

- [ ] 1.1 `tests/dungeon/data/test_monster_data.gd` を作成し、フィールド定義・HP 範囲バリデーションの失敗するテストを書く
- [ ] 1.2 `src/dungeon/data/monster_data.gd` (`extends Resource`) を作成し、テストを通す（`@export` フィールド、`is_valid()` 的なバリデータ）
- [ ] 1.3 `tests/dungeon/data/test_monster_data.gd` にサンプル `.tres` 読み込みテストを追加
- [ ] 1.4 `data/monsters/` ディレクトリ作成とサンプル 2〜3 体（例: slime, goblin, bat）を `.tres` で作成
- [ ] 1.5 テスト実行しすべて green になることを確認

## 2. Monster インスタンスと MonsterRepository

- [ ] 2.1 `tests/dungeon/test_monster.gd` を作成し、MonsterData + RNG から HP をロールするテストを書く（決定論性含む）
- [ ] 2.2 `src/dungeon/monster.gd` (`extends RefCounted`) を実装、テストを通す
- [ ] 2.3 `tests/dungeon/test_monster_repository.gd` を作成し、`get(monster_id)` のヒット/ミス、一括ロードをテスト
- [ ] 2.4 `src/dungeon/monster_repository.gd` を実装
- [ ] 2.5 `src/dungeon/data/data_loader.gd` に `load_all_monsters()` を追加し、既存 `test_data_loader.gd` を拡張
- [ ] 2.6 全テスト green を確認

## 3. EncounterTableData / EncounterPattern

- [ ] 3.1 `tests/dungeon/data/test_encounter_pattern.gd` でグループ展開・個体数範囲をテスト
- [ ] 3.2 `src/dungeon/data/monster_group_spec.gd` と `src/dungeon/data/encounter_pattern.gd` を実装
- [ ] 3.3 `tests/dungeon/data/test_encounter_table_data.gd` でフィールド・重みリスト検証
- [ ] 3.4 `src/dungeon/data/encounter_table_data.gd` と `src/dungeon/data/encounter_entry.gd` を実装
- [ ] 3.5 `data/encounter_tables/` に階層 1 用サンプル `.tres` を作成
- [ ] 3.6 `DataLoader.load_all_encounter_tables()` を追加
- [ ] 3.7 全テスト green を確認

## 4. EncounterManager（判定 + 生成）

- [ ] 4.1 `tests/dungeon/test_encounter_manager.gd` を作成し、以下のテストを書く:
  - 閾値直下/直上で `should_trigger` が期待通り
  - 同一シードでのシーケンス決定論性
  - 連続エンカウント抑止（cooldown）
- [ ] 4.2 `src/dungeon/encounter_manager.gd` (`extends RefCounted`) を実装し、should_trigger を通す
- [ ] 4.3 生成ロジックのテストを追加: 重み選択の決定論性、MonsterGroupSpec 個体数範囲、未知 monster_id のエラー
- [ ] 4.4 `generate(floor, rng) -> MonsterParty` を実装
- [ ] 4.5 `src/dungeon/monster_party.gd` (`extends RefCounted`) を最小実装（Monster 配列の保持と by_species 集計）
- [ ] 4.6 全テスト green を確認

## 5. EncounterOutcome + EncounterOverlay（スタブ）

- [ ] 5.1 `tests/dungeon/test_encounter_outcome.gd` で enum・デフォルト値・拡張フィールドの動作を確認
- [ ] 5.2 `src/dungeon/encounter_outcome.gd` (`extends RefCounted`) を実装
- [ ] 5.3 `tests/dungeon_scene/test_encounter_overlay.gd` を作成:
  - 初期は非表示
  - `start_encounter(party)` で可視化、名前表示
  - 確認入力で `encounter_resolved` 発火、CLEARED 返却
  - 二重発火しないこと
- [ ] 5.4 `src/dungeon_scene/encounter_overlay.gd` (`extends CanvasLayer`) を実装（`EscMenu` と同じ layer 方針）
- [ ] 5.5 モンスターグループ表示フォーマット（「スライム x2」）を実装
- [ ] 5.6 全テスト green を確認

## 6. DungeonScreen 統合

- [ ] 6.1 既存 `tests/dungeon_scene/test_dungeon_screen.gd`（または新規）を拡張し、以下のテストを追加:
  - 前進成功時にステップシグナル発火
  - 壁衝突時は発火しない
  - 旋回時は発火しない
  - エンカウント発生中は入力無視
  - スタート地点とエンカウントが同時トリガーされたらエンカウント優先
- [ ] 6.2 `DungeonScreen` にステップシグナル（例: `step_taken(new_position)`）を追加
- [ ] 6.3 `_unhandled_input` のロジックを調整: `moved` を「位置変化」「向き変化」に分離、位置変化のみステップ発火
- [ ] 6.4 エンカウント中のガードフラグ（`_encounter_active`）を導入し、入力を遮断
- [ ] 6.5 スタート地点リターン判定をエンカウント解決後に再チェックするフローを実装
- [ ] 6.6 全テスト green を確認

## 7. 統合配線（main.gd / 上位調整役）

- [ ] 7.1 `DungeonScreen` のオーナー（main.gd または該当の親シーン）で以下をテスト可能な形で配線:
  - `step_taken` → `EncounterManager.should_trigger` → 必要なら `generate` → `EncounterOverlay.start_encounter`
  - `encounter_resolved` 受信で `_encounter_active` 解除・必要ならリターン判定再実行
- [ ] 7.2 `main.gd` 側の ESC 入力が EncounterOverlay 表示中に無効化されるテストを追加
- [ ] 7.3 手動プレイで確認: ダンジョンを数歩歩き、エンカウント表示→解除→再びダンジョン操作に戻る、スタート地点上でのエンカウント順序

## 8. ドキュメントとクリーンアップ

- [ ] 8.1 `data/monsters/`・`data/encounter_tables/` のサンプル内容を README 相当の短いコメントで説明
- [ ] 8.2 `tests/` 配下で `_rng.seed = 12345` 系のマジックナンバーを定数化（レビュー負荷軽減）
- [ ] 8.3 実プレイで cooldown = 3 のテンポ感を確認し、違和感があれば design.md の該当記述を更新（他の決定事項は変更予定なし）
- [ ] 8.4 `openspec verify --change monster-and-encounter` を通す
- [ ] 8.5 全 GUT テストグリーンを最終確認
