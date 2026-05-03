## Why

`character_creation.gd` (440 LOC) は 5 ステップウィザードで、各ステップに対応する `_build_stepN` と `_input_stepN` のペアが 5 つあり、ボイラープレートの占める割合が約 60%。同じ ui_up/ui_down/ui_accept/ui_cancel/ui_back パターンが少しずつ違う形で 5 回繰り返されている。今後ステップを追加・削除・並び替えるたびに、5 〜 10 箇所を同期して触る必要がある。

C4b で全画面が action ベースに移行し、`MenuController` が利用可能になっているので、本 change で **Step 記述子(`title`, `build()`, `handle_input(event)`, `can_advance()`, `on_back()`)** を導入し、`_build_step_ui` と `_unhandled_input` を 1 つのディスパッチャに収束させる。

外部から見える挙動は変わらない(既存テストが通り続ける)。

## What Changes

- `src/guild_scene/character_creation_step.gd` を新規追加(`CharacterCreationStep` RefCounted、抽象基底)
- `src/guild_scene/steps/` ディレクトリを作成し、各ステップを独立 RefCounted として実装:
  - `name_input_step.gd` — Step 1
  - `race_selection_step.gd` — Step 2
  - `bonus_allocation_step.gd` — Step 3(MenuController と整合しない左右増減があるため独自 input)
  - `job_selection_step.gd` — Step 4
  - `confirmation_step.gd` — Step 5
- 各ステップは `build(content: VBoxContainer, context: CharacterCreationContext)` と `handle_input(event, context) -> StepTransition` を提供
- `StepTransition` enum: `STAY`, `ADVANCE`, `BACK`, `CANCEL`
- `character_creation.gd` を 440 LOC から 200 LOC 程度に縮め、`_build_step_ui` と `_unhandled_input` をシンプルなディスパッチャに置換
- `_input_stepN` 5 メソッドを削除
- `_build_stepN` 5 メソッドをステップクラスに移行
- 既存テスト `tests/guild_scene/test_character_creation.gd` の外部挙動を変えない(=テスト無修正で通る)
- 各ステップごとに単体テストを追加(`tests/guild_scene/steps/test_*.gd`)

## Capabilities

### Modified Capabilities

- `character-creation-wizard`: 内部実装の構造を「ステップ記述子 + ディスパッチャ」に変更。既存の振る舞い要件は不変。新たに「ステップは独立してテスト可能」要件を追加。

## Impact

- **新規コード**:
  - `src/guild_scene/character_creation_step.gd` (基底)
  - `src/guild_scene/steps/name_input_step.gd`
  - `src/guild_scene/steps/race_selection_step.gd`
  - `src/guild_scene/steps/bonus_allocation_step.gd`
  - `src/guild_scene/steps/job_selection_step.gd`
  - `src/guild_scene/steps/confirmation_step.gd`
  - `tests/guild_scene/steps/test_name_input_step.gd`
  - `tests/guild_scene/steps/test_race_selection_step.gd`
  - `tests/guild_scene/steps/test_bonus_allocation_step.gd`
  - `tests/guild_scene/steps/test_job_selection_step.gd`
  - `tests/guild_scene/steps/test_confirmation_step.gd`
- **変更コード**:
  - `src/guild_scene/character_creation.gd` — ディスパッチャ化、ステップ記述子配列、`_input_stepN` / `_build_stepN` 削除
- **互換性**:
  - 外部 API(`back_requested`, `character_created`, `setup`, `select_race`, `confirm_creation` 等)は不変
  - 既存テスト `test_character_creation.gd` は無修正で通る
- **依存関係**:
  - C4a (MenuController) を利用
  - C4b (action ベース統一) 完了後に着手
  - C5 完了後、character creation の追加・変更が容易になる
