## 1. EncounterOverlay の抽象化と SimpleEncounterOverlay 抽出 (TDD)

- [ ] 1.1 `tests/dungeon_scene/test_simple_encounter_overlay.gd` を新規作成、`start_encounter` で UI が visible になるテスト、ui_accept で encounter_resolved 発行テスト
- [ ] 1.2 既存 `tests/dungeon_scene/test_encounter_overlay.gd` (あれば)が `EncounterOverlay.new()` を直接 instantiate しているテストを `SimpleEncounterOverlay.new()` に変更
- [ ] 1.3 テスト Red コミット
- [ ] 1.4 `src/dungeon_scene/simple_encounter_overlay.gd` を新規実装、現在の `encounter_overlay.gd` の `_build_ui` ロジックをコピー
- [ ] 1.5 `src/dungeon_scene/encounter_overlay.gd` を抽象基底に変更:
  - `_ready` を削除(または空に)
  - `_build_ui` を削除
  - `start_encounter` を `push_error` で override 強制
  - `encounter_resolved` シグナルだけ残す
- [ ] 1.6 `src/dungeon_scene/encounter_coordinator.gd:_ready` で `SimpleEncounterOverlay.new()` を instantiate するように変更
- [ ] 1.7 テスト Green コミット

## 2. main.gd の ESC ゲート集約 (TDD)

- [ ] 2.1 `tests/test_main.gd` (or 既存)に `_should_open_esc_menu` の各ケーステストを追加
- [ ] 2.2 テスト Red コミット
- [ ] 2.3 `src/main.gd` に `_should_open_esc_menu() -> bool` メソッドを追加、3 ゲートを内部評価
- [ ] 2.4 `_unhandled_input` を `_should_open_esc_menu` 経由に書き換え
- [ ] 2.5 テスト Green コミット

## 3. _refresh_combat_overlay_dependencies の削除 (TDD)

- [ ] 3.1 既存テストで `_refresh_combat_overlay_dependencies` を呼んでいる箇所がないことを grep 確認
- [ ] 3.2 `_combat_overlay.setup_dependencies(...)` の呼び出しを `_on_start_new_game` および `_load_game` 完了タイミングに移動
- [ ] 3.3 `_setup_encounter_coordinator` で `setup_dependencies` を呼んでいたら、guild が null である可能性があるので削除し、後で呼ぶ形に
- [ ] 3.4 `_attach_encounter_coordinator_to_screen` から `_refresh_combat_overlay_dependencies` 呼び出しを削除
- [ ] 3.5 `_refresh_combat_overlay_dependencies` メソッド本体を削除
- [ ] 3.6 全テスト通過を確認しコミット

## 4. DungeonEntrance.setup のシグネチャ変更 (TDD)

- [ ] 4.1 `tests/town/test_dungeon_entrance.gd` の `setup(registry, true)` 形式の呼び出しを `setup(registry, guild)` に書き換え
- [ ] 4.2 「パーティが空 Guild の場合に enter が disabled」テスト
- [ ] 4.3 「パーティが 1 人いる Guild の場合に enter が enabled」テスト
- [ ] 4.4 テスト Red コミット
- [ ] 4.5 `src/town_scene/dungeon_entrance.gd:setup` を `setup(registry: DungeonRegistry, guild: Guild)` 形式に変更
- [ ] 4.6 内部で `_has_party = _guild.has_party_members()` のような snapshot を保持しないようにし、UI 構築時およびイベント発生時に `_guild.has_party_members()` を直接 query する
- [ ] 4.7 `src/main.gd:_on_open_dungeon_entrance` から `var has_party := GameState.guild.has_party_members()` を削除し、`screen.setup(GameState.dungeon_registry, GameState.guild)` を呼ぶ
- [ ] 4.8 テスト Green コミット

## 5. 動作確認

- [ ] 5.1 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイート通過
- [ ] 5.2 ゲーム起動 → タイトル → 新規 → 町 → ダンジョン入口 → ダンジョン → エンカウンタ → 戦闘終了 → 町、の全フロー目視確認
- [ ] 5.3 ESC キーが各画面で適切に動くか確認(タイトル無視、町・ダンジョン・ギルドで開く、エンカウンタ中無視)
- [ ] 5.4 SimpleEncounterOverlay は production では使われないが、テストが通ること

## 6. 仕上げ

- [ ] 6.1 `openspec validate cleanup-main-and-encounter-wiring --strict`
- [ ] 6.2 `/simplify`スキルでコードレビューを実施
- [ ] 6.3 `/opsx:verify cleanup-main-and-encounter-wiring`
- [ ] 6.4 `/opsx:archive cleanup-main-and-encounter-wiring`
