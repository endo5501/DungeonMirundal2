## Why

`main.gd` のトップレベル ESC 処理(`:103-115`)は、`_encounter_coordinator.is_encounter_active()`、`_esc_menu.is_menu_visible()`、`_current_screen is TitleScreen` の 3 つの独立ゲートをチェックしている(F023)。新しい画面やオーバーレイが追加されるたびにこのチェック群を更新する必要があり、forget しやすい。

加えて:
- `EncounterOverlay` が **具象クラス**(独立で使われ、ユニットテストの fallback でもある)と **基底クラス**(CombatOverlay の親)の二重役割になっており、暗黙の契約が散在する(F011)
- `_refresh_combat_overlay_dependencies` (`main.gd:209-212`) は `_attach_encounter_coordinator_to_screen` から呼ばれるが、`_setup_encounter_coordinator` ですでに同じセットアップを行っており、完全に dead defensive code(F035)
- `_on_open_dungeon_entrance` (`main.gd:170-179`) は `GameState.guild.has_party_members()` を引数としてパラメータに渡しており、`DungeonEntrance` 側は静的に保持する(F046)。これにより将来「画面を開いたまま party を変える」ことができても entrance がそれを認知できない

これらをまとめて整理し、main.gd の責務を「画面遷移と top-level input gate」に絞る。

## What Changes

- `EncounterOverlay` を抽象基底クラスに変える(自身は `_ready` / `_build_ui` を持たず、サブクラスが提供)
- 旧 `EncounterOverlay` の単純UI実装を `SimpleEncounterOverlay` (`src/dungeon_scene/simple_encounter_overlay.gd`) に切り出す
- `EncounterCoordinator._ready` で `EncounterOverlay()` を直接 instantiate している箇所を `SimpleEncounterOverlay` に変更
- `main.gd._unhandled_input` の 3 ゲートを `_input_blocked_by_screen()` ヘルパーに集約、または「screen が `consumes_global_esc()` を返すか」の virtual 経由にする
- `main.gd._refresh_combat_overlay_dependencies` を削除、`_setup_encounter_coordinator` で 1 度だけ依存配線する
- `DungeonEntrance.setup(registry, guild)` 形式に変更し、`has_party()` を `guild.has_party_members()` 内部呼び出しに置換
- 各テストを更新

## Capabilities

### Modified Capabilities

- `encounter-overlay`: 抽象基底化、`SimpleEncounterOverlay` という新しい具象クラスを追加
- `encounter-detection`: `EncounterCoordinator._ready` の overlay instantiation を `SimpleEncounterOverlay` に変更
- `screen-navigation`: `main.gd._unhandled_input` の input ゲートを統合
- `dungeon-entrance`: `setup` シグネチャに `Guild` を渡す形に変更

### New Capabilities

- `simple-encounter-overlay`: 単純な遭遇 UI(モンスター名表示・ui_accept で確定)を提供する具象 EncounterOverlay サブクラス

## Impact

- **新規コード**:
  - `src/dungeon_scene/simple_encounter_overlay.gd`
  - `tests/dungeon_scene/test_simple_encounter_overlay.gd`
- **変更コード**:
  - `src/dungeon_scene/encounter_overlay.gd` — 抽象基底化、`_ready` / `_build_ui` を空に
  - `src/dungeon_scene/encounter_coordinator.gd` — `_ready` で `SimpleEncounterOverlay.new()`
  - `src/main.gd` — `_unhandled_input` 統合、`_refresh_combat_overlay_dependencies` 削除
  - `src/town_scene/dungeon_entrance.gd` — `setup(registry, guild)` 形式に
- **削除**:
  - `main.gd` の `_refresh_combat_overlay_dependencies`
- **互換性**:
  - 既存外部挙動(各画面の遷移、エンカウンタ動作、ESCメニュー開閉)は不変
  - F024(マルチフロア対応)は計画外。`encounter_tables_by_floor` の配線は維持(将来のマルチフロア feature change で改訂)
- **依存関係**:
  - C7(combat_overlay リファクタ)完了後に着手すると、依存配線の整理が綺麗
  - C9(ConfirmDialog)と並行可能
