## 1. Autoload 基盤の準備 (TDD: red)

- [x] 1.1 新規テスト `tests/autoload/test_party_hud.gd` を作成: `PartyHud` autoload の存在(`get_node("/root/PartyHud")` 経由)と `CanvasLayer` 継承
- [x] 1.2 同テスト: `PartyHud` が `PartyDisplay` を子として 1 つだけ持つ
- [x] 1.3 同テスト: `show_hud()` で `visible = true`、`hide_hud()` で `visible = false`、各冪等性
- [x] 1.4 GUT 実行 → red 確認(autoload 未登録なのでテスト失敗)
- [x] 1.5 red 状態でコミット

## 2. PartyHud autoload 実装 (TDD: green for autoload-side)

- [ ] 2.1 `src/autoload/party_hud.gd` 作成。`extends CanvasLayer`、`_ready()` で `PartyDisplay.new()` を子に追加
- [ ] 2.2 `show_hud()` / `hide_hud()` を実装(`visible` を直接設定、冪等)
- [ ] 2.3 `project.godot` の `[autoload]` セクションに `PartyHud="*res://src/autoload/party_hud.gd"` を追加
- [ ] 2.4 GUT 実行 → 1.1〜1.3 が green になることを確認
- [ ] 2.5 ここでコミット

## 3. bind_active_party の実装 (TDD: red→green)

- [ ] 3.1 新規テスト `tests/autoload/test_party_hud_bind.gd`: `GameState.guild` のアクティブパーティ(Character の前列3 + 後列3)があるとき、`PartyHud.bind_active_party()` を呼ぶと PartyDisplay が bind される
- [ ] 3.2 同テスト: 部分パーティ(前列2 + 後列1)の場合、空スロットは null として bind される
- [ ] 3.3 GUT 実行 → red 確認
- [ ] 3.4 `PartyHud.bind_active_party()` を実装。GameState からアクティブパーティを取得し、`PartyDisplay.bind_party_characters(front, back)` を呼ぶ
- [ ] 3.5 GUT 実行 → green 確認
- [ ] 3.6 コミット

## 4. パーティ変更通知の整備 (TDD: red→green)

- [ ] 4.1 既存コードを調査: `Guild` または `GameState` に "active party changed" 相当のシグナルがあるか確認
- [ ] 4.2 無ければ `Guild`(または `GameState`)に `active_party_changed(front_row: Array, back_row: Array)` シグナルを追加(spec として `party-hud-autoload` の Requirement と一致するよう)
- [ ] 4.3 既存の編成変更コード(パーティ追加/削除/並び替え)から、編成完了時に新シグナルを emit するよう変更
- [ ] 4.4 新規テスト: 編成変更で `PartyHud` が再 bind されること(モックで検証 or signal 経由)
- [ ] 4.5 `PartyHud._ready()` 内で当該シグナルに `bind_active_party()` を接続
- [ ] 4.6 GUT 実行 → green 確認
- [ ] 4.7 コミット

## 5. main.gd / 各 screen の表示制御 (TDD: red→green)

- [ ] 5.1 新規テスト `tests/main/test_main_party_hud_visibility.gd` を作成: 各 screen 切替時の `PartyHud.visible` 値
  - TitleScreen → false
  - TownScreen → true
  - GuildScreen → true
  - DungeonEntrance → true
  - DungeonScreen → true
  - LoadScreen → false
  - SaveScreen → false
- [ ] 5.2 GUT 実行 → red 確認
- [ ] 5.3 `src/main.gd` の screen 切替関数に `PartyHud.show_hud()` / `hide_hud()` を仕込む
- [ ] 5.4 GUT 実行 → green 確認
- [ ] 5.5 コミット

## 6. GuildScreen 編成画面の特例 (TDD: red→green)

- [ ] 6.1 新規テスト `tests/guild_scene/test_guild_party_formation_hud.gd`: 編成画面に入ると `PartyHud.visible = false`、戻ると `true`
- [ ] 6.2 GUT 実行 → red 確認
- [ ] 6.3 `src/guild_scene/guild_menu.gd`(または該当する formation 開閉箇所)で `PartyHud.hide_hud()` / `show_hud()` を呼ぶ
- [ ] 6.4 GUT 実行 → green 確認
- [ ] 6.5 コミット

## 7. DungeonScreen から PartyDisplay 所有を外す

- [ ] 7.1 新規テスト `tests/dungeon_scene/test_dungeon_screen_no_party_display.gd`: DungeonScreen が `PartyDisplay` を子として持たない
- [ ] 7.2 GUT 実行 → red 確認
- [ ] 7.3 `src/dungeon_scene/dungeon_screen.gd` から `PartyDisplay` 生成・追加・bind 処理を削除
- [ ] 7.4 既存テスト `tests/dungeon_scene/test_party_display_character_binding.gd` などが、PartyHud 経由の検証になるように更新(または該当範囲を `tests/autoload/` 側へ移譲)
- [ ] 7.5 既存テスト `tests/dungeon_scene/test_esc_menu_heal_refreshes_status_bar.gd` を PartyHud 経由の検証に変更
- [ ] 7.6 GUT 実行 → 全 green 確認
- [ ] 7.7 コミット

## 8. 状態異常アイコン描画 (TDD: red→green)

- [ ] 8.1 新規テスト `tests/dungeon_scene/test_party_member_panel_status_icons.gd` を作成
  - 単一ステータス([&"poison"])で 1 個のアイコンが描画される
  - 複数ステータス([&"poison", &"blind", &"sleep"])で 3 個のアイコンが描画される
  - 空 [] でアイコンが描画されない
  - statuses_changed シグナルでアイコンが追加・削除される
  - PartyMemberData snapshot 経路ではアイコンが描画されない
- [ ] 8.2 GUT 実行 → red 確認
- [ ] 8.3 `src/dungeon_scene/party_member_panel.gd` に状態色テーブル(StringName → Color)と状態ラベルテーブル(StringName → String)の定数を追加
- [ ] 8.4 `_draw()` の最後に、`_character != null` のとき `_character.persistent_statuses` を走査してアイコン(色矩形 + 1〜2 文字)を描画する処理を追加
- [ ] 8.5 アイコンエリアの位置を決定(MP 行の下 or 右側)。スペース不足なら `PANEL_HEIGHT` を 130〜140 に拡張
- [ ] 8.6 GUT 実行 → green 確認
- [ ] 8.7 コミット

## 9. 行動不能の暗転オーバーレイ (TDD: red→green)

- [ ] 9.1 新規テスト `tests/dungeon_scene/test_party_member_panel_dim.gd` を作成
  - HP=0 で暗転矩形が描画される
  - sleep 付与で暗転される
  - paralysis 付与で暗転される
  - petrify 付与で暗転される
  - poison のみでは暗転されない
  - confusion のみでは暗転されない
  - HP 回復で暗転が消える
- [ ] 9.2 GUT 実行 → red 確認
- [ ] 9.3 `PartyMemberPanel` に `_is_incapacitated()` private ヘルパを追加
- [ ] 9.4 `_draw()` の最後(状態アイコン描画の後)に、`_is_incapacitated()` が真ならパネル全領域に半透明黒(`Color(0, 0, 0, 0.55)`)を `draw_rect` で上塗り
- [ ] 9.5 `hp_changed` / `statuses_changed` のいずれでも `queue_redraw` がかかることを再確認(既存挙動)
- [ ] 9.6 GUT 実行 → green 確認
- [ ] 9.7 コミット

## 10. レイアウト最終調整・手動確認

- [ ] 10.1 街(TownScreen)で HUD が表示されることを目視確認
- [ ] 10.2 ギルドメインメニューで HUD が表示され、編成画面で消え、戻ると再表示されることを確認
- [ ] 10.3 商店・教会・ダンジョン入口で表示されることを確認
- [ ] 10.4 タイトル・ロード・セーブで非表示であることを確認
- [ ] 10.5 ダンジョンに入る → 出る で HUD が継続して同じインスタンスを表示することを確認
- [ ] 10.6 メンバーに毒/盲目/睡眠等を付与してアイコンが出ること、行動不能で暗転することを確認
- [ ] 10.7 ESC メニュー / 全画面マップを開いた時に HUD が visible のままであることを確認
- [ ] 10.8 PANEL_HEIGHT・アイコン位置・色など、視認性で気になる点を微調整

## 11. クリーンアップ・最終コミット

- [ ] 11.1 不要になったコード(DungeonScreen 内の旧 bind 処理の残骸、デッドコード、未使用 import)を削除
- [ ] 11.2 `openspec validate persistent-party-display --strict` で valid を確認
- [ ] 11.3 全 GUT テスト green を確認
- [ ] 11.4 最終コミット
