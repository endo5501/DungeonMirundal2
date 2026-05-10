## 1. Test updates (TDD red phase)

- [x] 1.1 `tests/dungeon_scene/test_party_member_panel_size.gd::test_panel_width_is_240` を **新値 174** を期待するよう書き換え (関数名・メッセージも更新)
- [x] 1.2 同ファイル `test_body_font_size_is_enlarged_for_readability` のコメント/メッセージを「`FONT_SIZE` は名前バッジ用」と明示するよう更新 (既存の `[21, 30]` 範囲チェックは維持)
- [x] 1.3 同ファイルに新規テスト `test_panel_width_matches_portrait_with_margin`: `PANEL_WIDTH == 174` かつ `PANEL_WIDTH >= PORTRAIT_WIDTH` を検証
- [x] 1.4 同ファイルに新規テスト `test_bar_font_size_is_at_least_14`: `BAR_FONT_SIZE >= 14` を検証
- [x] 1.5 同ファイルに新規テスト `test_badge_font_size_fits_lv_99`: `BADGE_FONT_SIZE <= 16` かつ `get_level_badge_rect().size.x >= 48` を検証
- [x] 1.6 同ファイルに新規テスト `test_level_badge_fits_lv_99_string`: `BADGE_FONT_SIZE` で計算した "LV.99" の文字列幅が badge 矩形内に収まる (`ThemeDB.fallback_font.get_string_size` を使用)
- [x] 1.7 同ファイルに新規テスト `test_hp_and_mp_value_text_do_not_overlap_vertically`: `get_hp_bar_rect().position.y + BAR_FONT_SIZE` (HP 値テキストの下端) が `get_mp_bar_rect().position.y` (MP バー上端) を超えない
- [x] 1.8 同ファイルに新規テスト `test_hp_value_text_fits_within_panel_horizontally`: 最大値 "999/999" を `BAR_FONT_SIZE` で測った幅が `PANEL_WIDTH - bar_rect.position.x - bar_rect.size.x - 余白` 以内に収まる
- [x] 1.9 `tests/dungeon_scene/test_party_display_layout.gd::test_six_panels_fit_within_1600_design_canvas_with_positive_center_gap` の center gap が 300px 以上であることを追加で検証 (新 spec 要件)
- [x] 1.10 GUT 実行 (`scripts/run-gut.ps1` 等プロジェクト規約) → 1.1〜1.9 に対応する失敗を red で確認、関係ない既存テストは依然 green であることを確認 (5 failing: panel_width_is_174 / matches_portrait / badge_font_size_fits_lv_99 / level_badge_fits_lv_99_string / center_gap_300)

## 2. Implementation (TDD green phase)

- [x] 2.1 `src/dungeon_scene/party_member_panel.gd`: `PANEL_WIDTH` を 240 → 174 に変更
- [x] 2.2 同ファイル: 新定数 `const BAR_FONT_SIZE := 14` を追加 (HP/MP 行用、`FONT_SIZE` は名前バッジ専用として残す)
- [x] 2.3 同ファイル: `BADGE_FONT_SIZE` を 18 → 14 に変更
- [x] 2.4 同ファイル: `BAR_LEFT` を 32 → 26、`BAR_WIDTH` を 88 → 80 に変更 (worst-case "999 / 999" が右側に収まるよう実測で確定)
- [x] 2.5 同ファイル: `get_level_badge_rect()` の幅計算 `34.0` / `32.0` を `50.0` / `48.0` に更新 (badge 幅 48 を返す)
- [x] 2.6 同ファイル: `_draw_stat_bar()` の `FONT_SIZE` 参照を `BAR_FONT_SIZE` に置換 (HP/MP ラベル描画と value text 描画の 2 箇所)
- [x] 2.7 同ファイル: `_draw_stat_bar()` の value text 描画位置 `Vector2(124, ...)` と box 幅 `PANEL_WIDTH - 130` を新 `PANEL_WIDTH=174` に整合する値に更新 (例: `Vector2(BAR_LEFT + BAR_WIDTH + 2, ...)` と `PANEL_WIDTH - (BAR_LEFT + BAR_WIDTH + 6)` のように定数化)
- [x] 2.8 同ファイル: HP/MP ラベル描画の `Vector2(7, ...)` x 座標と box 幅 `24.0` も `BAR_LEFT - 余白` に整合 (例: x=4, width=BAR_LEFT-6=20)
- [x] 2.9 GUT 実行 → 1 章で red だったテストが green、既存テストも全て green であることを確認 (2254/2254 passed, exit 0)

## 3. Visual verification (ユーザ操作が必要 — Claude からは実行不能)

- [ ] 3.1 Godot エディタでプロジェクトを起動し、ダンジョン画面 (encounter なし) を表示
- [ ] 3.2 スクリーンショットを取得し `tmp/dungeon14_after.png` 等として保存、`tmp/dungeon14.png` (修正前) と比較
- [ ] 3.3 4 つの破綻 (LV 見切れ / HP MP ラベル見切れ / HP MP 数値の上下被り / バー右の死んだ余白) が全て解消していることを目視確認
- [ ] 3.4 戦闘画面に遷移して party HUD が崩れていないこと、status / stat-modifier アイコンが正常配置であること、shake/flash/lift/die アニメーションが従来通り動くことを確認

## 4. Spec sync & cleanup

- [x] 4.1 `openspec validate tweak-party-hud-layout` を実行し、proposal/design/specs/tasks 全てのバリデーション通過を確認 (valid)
- [ ] 4.2 (任意) スクリーンショット差分を含むコミットメッセージで TDD 完了を記録
- [ ] 4.3 `/opsx:archive tweak-party-hud-layout` を実行する準備が整ったことを確認 (実際の archive はユーザ判断)
