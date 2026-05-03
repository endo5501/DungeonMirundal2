## 1. TestHelpers 拡張

- [ ] 1.1 `tests/test_helpers.gd` に `make_corridor_fixture(start: Vector2i, dir: int, length: int = 3) -> WizMap` を追加(start から dir 方向へ length セル分 OPEN を確保した 8x8 フィクスチャ)
- [ ] 1.2 `make_blocked_fixture(start: Vector2i) -> WizMap` を追加(start を全方向 WALL に閉じ込めた 8x8 フィクスチャ)
- [ ] 1.3 `make_neighbor_to_start_fixture(start: Vector2i, dir: int) -> WizMap` を追加(start のある方向の隣接セルから dir 反対向きで forward すると start に着くフィクスチャ。F012 の test_start_tile_return_dialog_suppressed 用)
- [ ] 1.4 ヘルパー単体テスト `tests/test_test_helpers.gd` を追加し、各フィクスチャが要求 topology を満たすことを検証する

## 2. test_dungeon_screen_encounter.gd の決定化 (TDD)

- [ ] 2.1 `test_forward_move_emits_step_taken` を `make_corridor_fixture` ベースに書き換え、`pending` を削除
- [ ] 2.2 `test_blocked_move_does_not_emit_step_taken` を `make_blocked_fixture` ベースに書き換え、`pending` を削除
- [ ] 2.3 `test_movement_blocked_when_encounter_active` を `make_corridor_fixture` ベースに書き換え、`pending` を削除
- [ ] 2.4 `test_encounter_active_clears_back_to_normal_movement` を `make_corridor_fixture` ベースに書き換え、`pending` を削除
- [ ] 2.5 `test_start_tile_return_dialog_suppressed_when_encounter_activates_during_step` を `make_neighbor_to_start_fixture` ベースに書き換え、`pending` を削除
- [ ] 2.6 全テスト通過を確認しコミット

## 3. test_dungeon_screen_full_map.gd の決定化 (TDD)

- [ ] 3.1 `test_forward_move_blocked_while_overlay_visible` を `make_corridor_fixture` ベースに書き換え、`pending` を削除
- [ ] 3.2 `test_movement_resumes_after_overlay_closes` を `make_corridor_fixture` ベースに書き換え、`pending` を削除
- [ ] 3.3 全テスト通過を確認しコミット

## 4. テストディレクトリ整理

- [ ] 4.1 空ディレクトリ `tests/dungeon_scene/` を削除する(`.gitkeep` がある場合はそれも)

## 5. HasMpSlot テスト追加 (TDD)

- [ ] 5.1 `tests/items/test_has_mp_slot.gd` を新規作成
- [ ] 5.2 max_mp > 0 の対象に対して `is_satisfied` が true を返すテスト
- [ ] 5.3 max_mp == 0 の対象に対して `is_satisfied` が false を返すテスト
- [ ] 5.4 max_mp プロパティを持たない対象に対して `is_satisfied` が false を返すテスト
- [ ] 5.5 null 対象に対して `is_satisfied` が false を返すテスト
- [ ] 5.6 `reason()` が "MP を持たない職業" を返すテスト
- [ ] 5.7 全テスト通過を確認しコミット

## 6. project-setup spec の更新

- [ ] 6.1 spec delta が `openspec/changes/make-dungeon-tests-deterministic/specs/project-setup/spec.md` に追加されていることを確認
- [ ] 6.2 既存テストファイル全体を grep して `pending(` の用法をレビューし、入力データ不適合での skip が他に残っていないことを確認

## 7. 仕上げ

- [ ] 7.1 `openspec validate make-dungeon-tests-deterministic --strict`
- [ ] 7.2 `/simplify`スキルでコードレビューを実施
- [ ] 7.3 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイートが通ることを確認
- [ ] 7.4 `/opsx:verify make-dungeon-tests-deterministic`
- [ ] 7.5 `/opsx:archive make-dungeon-tests-deterministic`
