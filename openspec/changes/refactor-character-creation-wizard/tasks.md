## 1. CharacterCreationStep 基底の追加 (TDD)

- [x] 1.1 `tests/guild_scene/steps/test_character_creation_step.gd` を作成し、`StepTransition` enum 値の存在テスト
- [x] 1.2 基底クラスの `build` / `handle_input` のデフォルト実装(no-op / STAY 返却)テスト
- [x] 1.3 テストを実行し失敗することを確認しコミット (Red)
- [x] 1.4 `src/guild_scene/character_creation_step.gd` を新規作成、`class_name CharacterCreationStep extends RefCounted`、StepTransition enum、`build` / `handle_input` のデフォルト実装
- [x] 1.5 テスト通過を確認しコミット (Green)

## 2. NameInputStep の抽出 (TDD)

- [x] 2.1 `tests/guild_scene/steps/test_name_input_step.gd` を作成、`build` で LineEdit が作られるテスト、`handle_input` で ui_accept (focus 制御) と ui_cancel が CANCEL を返すテスト
- [x] 2.2 既存 `_input_step1` ロジックの移植先テスト(focus 当たってない時の ui_accept で focus、focus 当たってる時の ui_accept で advance 想定)
- [x] 2.3 テスト Red 確認しコミット
- [x] 2.4 `src/guild_scene/steps/name_input_step.gd` を実装
- [x] 2.5 テスト Green 確認しコミット

## 3. RaceSelectionStep の抽出 (TDD)

- [x] 3.1 `tests/guild_scene/steps/test_race_selection_step.gd` を作成、種族リスト表示テスト、ui_up/ui_down で cursor 移動、ui_accept で ADVANCE、ui_back で BACK、ui_cancel で CANCEL
- [x] 3.2 テスト Red コミット
- [x] 3.3 `src/guild_scene/steps/race_selection_step.gd` を実装、MenuController を活用
- [x] 3.4 テスト Green コミット

## 4. BonusAllocationStep の抽出 (TDD)

- [x] 4.1 `tests/guild_scene/steps/test_bonus_allocation_step.gd` を作成、ui_up/ui_down で cursor 移動、ui_left/ui_right で stat 増減、KEY_R で reroll、ui_accept で残り 0 のとき ADVANCE / それ以外 STAY、ui_back で BACK、ui_cancel で CANCEL
- [x] 4.2 テスト Red コミット
- [x] 4.3 `src/guild_scene/steps/bonus_allocation_step.gd` を実装(MenuController に乗らないので独自 input)
- [x] 4.4 テスト Green コミット

## 5. JobSelectionStep の抽出 (TDD)

- [x] 5.1 `tests/guild_scene/steps/test_job_selection_step.gd` を作成、不適格 job の disabled 表示、ui_accept で適格 job のみ ADVANCE
- [x] 5.2 テスト Red コミット
- [x] 5.3 `src/guild_scene/steps/job_selection_step.gd` を実装
- [x] 5.4 テスト Green コミット

## 6. ConfirmationStep の抽出 (TDD)

- [x] 6.1 `tests/guild_scene/steps/test_confirmation_step.gd` を作成、`build` でサマリ表示、ui_accept で ADVANCE(=確定)、ui_back / ui_cancel で BACK / CANCEL
- [x] 6.2 テスト Red コミット
- [x] 6.3 `src/guild_scene/steps/confirmation_step.gd` を実装
- [x] 6.4 テスト Green コミット

## 7. character_creation.gd のディスパッチャ化 (TDD)

- [x] 7.1 既存 `tests/guild_scene/test_character_creation.gd` が無修正で通ることを目標にする
- [x] 7.2 `src/guild_scene/character_creation.gd` の `_steps: Array[CharacterCreationStep]` フィールドを追加、`_init` で 5 個の Step を生成
- [x] 7.3 `_build_step_ui` を `_steps[current_step - 1].build(_content, self)` に書き換え、`_step_label.text = step.get_title()` を設定
- [x] 7.4 `_unhandled_input` を `_steps[current_step - 1].handle_input(event, self)` に書き換え、戻り値で `advance()` / `go_back()` / `cancel()` をディスパッチ
- [x] 7.5 旧 `_build_step1` 〜 `_build_step5` を削除
- [x] 7.6 旧 `_input_step1` 〜 `_input_step5` を削除
- [x] 7.7 `_is_back_pressed` 等のヘルパーが Step 側に移ったら削除
- [x] 7.8 既存テスト全通過を確認しコミット

## 8. 動作確認

- [x] 8.1 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイート通過
- [x] 8.2 ゲーム起動 → ギルド → キャラクター作成 → 5 ステップを順に通って作成完了することを目視確認
- [x] 8.3 各ステップで ESC キャンセル、Backspace で前ステップ戻り、ボーナスポイント reroll、不適格職業 disabled 表示などを確認

## 9. 仕上げ

- [x] 9.1 `openspec validate refactor-character-creation-wizard --strict`
- [x] 9.2 `/simplify`スキルでコードレビューを実施
- [x] 9.3 `/opsx:verify refactor-character-creation-wizard`
- [ ] 9.4 `/opsx:archive refactor-character-creation-wizard`
