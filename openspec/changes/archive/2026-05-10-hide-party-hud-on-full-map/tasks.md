## 1. テスト追加 (TDD red)

- [x] 1.1 `tests/dungeon/test_full_map_overlay.gd` の `_make_overlay()` ヘルパーに `_party_hud_stub: CanvasLayer` を追加し、`add_child_autofree` でツリーへ追加、`setup()` の末尾引数として渡す
- [x] 1.2 `test_open_hides_party_hud()` を追加 — `open()` 後に `_party_hud_stub.visible == false` を検証
- [x] 1.3 `test_close_restores_party_hud()` を追加 — `open()` → `close()` 後に `_party_hud_stub.visible == true` を検証
- [x] 1.4 `test_close_via_esc_restores_party_hud()` を追加 — `open()` → `_unhandled_input(ui_cancel)` 後に復帰を検証
- [x] 1.5 GUT を実行し、新規 3 テストが赤(失敗)、既存 minimap 関連 3 テストが緑であることを確認
- [x] 1.6 赤を確認した状態でコミット (English message)

## 2. 本体実装 (TDD green)

- [x] 2.1 `src/dungeon_scene/full_map_overlay.gd` にフィールド `var _party_hud_layer: CanvasLayer` を追加 (`_minimap_display` の隣)
- [x] 2.2 `setup()` シグネチャに `party_hud_layer: CanvasLayer = null` を末尾追加し、関数内で `_party_hud_layer = party_hud_layer` を代入
- [x] 2.3 `open()` の `_minimap_display.visible = false` の直後に `_party_hud_layer` の null チェック付き `visible = false` を追加
- [x] 2.4 `close()` の `_minimap_display.visible = true` の直後に `_party_hud_layer` の null チェック付き `visible = true` を追加

## 3. 配線

- [x] 3.1 `src/dungeon_scene/dungeon_screen.gd:82` の `_full_map_overlay.setup(...)` 呼び出しに `PartyHud` を末尾引数として追加
- [x] 3.2 `src/dungeon_scene/dungeon_screen.gd:262` の `_full_map_overlay.setup(...)` 呼び出しに `PartyHud` を末尾引数として追加

## 4. 検証

- [x] 4.1 GUT を実行: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/dungeon/test_full_map_overlay.gd -gexit` で全テスト緑を確認 (2257 tests passing)
- [x] 4.2 プロジェクト全体のテストスイートを実行し、リグレッション無しを確認 (-gtest が全スイートを走らせ全 pass)
- [x] 4.3 手動検証: ダンジョン進入 → M キーでフルマップを開く → パーティ HUD が消えること、フルマップが遮られず見えること
- [x] 4.4 手動検証: M キー / ESC キーでフルマップを閉じる → パーティ HUD が復帰すること
- [x] 4.5 手動検証: 既存 minimap 表示制御 (フルマップ開閉時に minimap が消える/戻る) のリグレッション無しを確認

## 5. コミット & 仕上げ

- [x] 5.1 修正内容を `git status` / `git diff` で確認
- [x] 5.2 全変更を English commit message でコミット (red: 240dfce, green: d6b10c5)
- [x] 5.3 OpenSpec change の archive (`/opsx:archive` または `openspec archive`) は `/opsx:verify` で整合性確認後に実施
