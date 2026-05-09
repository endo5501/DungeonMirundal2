## 1. project.godot 設定追加

- [x] 1.1 `project.godot` に `[display]` セクションを追加し、`window/size/viewport_width=1600`, `window/size/viewport_height=900`, `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"` を設定する
- [x] 1.2 起動して 1600×900 のウィンドウで開くこと、リサイズで全 UI が均一スケールすることを目視確認する

## 2. DungeonScreen のリサイズ対応

- [x] 2.1 `DungeonScreen._notification(NOTIFICATION_RESIZED)` を実装し、`_wiz_map` と `_player_state` の null ガード後に `_refresh_all()` を呼ぶ
- [x] 2.2 GUT テストを追加: `DungeonScreen` に `NOTIFICATION_RESIZED` を送出し、`_sub_viewport.render_target_update_mode` が `UPDATE_ONCE` に設定されることを確認する
- [x] 2.3 GUT テストを追加: `_wiz_map = null` 状態で `NOTIFICATION_RESIZED` を送出してもクラッシュしないことを確認する
- [x] 2.4 起動 → ダンジョン入場 → ウィンドウリサイズで描画が消えないことを目視確認する

## 3. PartyMemberPanel / PartyDisplay の定数 bump

- [x] 3.1 `src/dungeon_scene/party_member_panel.gd` の `PANEL_WIDTH` を `180→240`, `PANEL_HEIGHT` を `168→224` に変更する
- [x] 3.2 `PORTRAIT_WIDTH` を `128→170`, `PORTRAIT_HEIGHT` を `104→138` に変更する
- [x] 3.3 `FONT_SIZE` を `14→21`, `BADGE_FONT_SIZE` を `12→18` に変更する
- [x] 3.4 `STATUS_ICON_SIZE` を `16→21`, `STATUS_ICON_GAP` を `2→3`, `STATUS_ICON_FONT_SIZE` を `12→18` に変更する
- [x] 3.5 `src/dungeon_scene/party_display.gd` の `MARGIN` を `8→11`, `LABEL_FONT_SIZE` を `20→30`, `LABEL_AREA_HEIGHT` を `26→35`, `LABEL_BOX_WIDTH` を `200→266`, `LABEL_OUTLINE_SIZE` を `3→4`, `WINDOW_PADDING` を `8→11` に変更する
- [x] 3.6 既存テスト (`tests/dungeon_scene/test_party_member_panel*.gd`, `test_party_display*.gd`) で具体値を期待しているものを新しい定数値に合わせて更新する
- [x] 3.7 GUT テストを追加 (もしくは既存に追記): 6 パネル並びが design canvas 1600 内で重ならず中央ギャップが正であることを確認する

## 4. 戦闘 UI の font_size bump

- [x] 4.1 `src/dungeon_scene/combat/combat_log.gd` の font_size `14→21`, `16→24` に変更する
- [x] 4.2 `src/dungeon_scene/combat/combat_command_menu.gd` の font_size `16→24` に変更する
- [x] 4.3 `src/dungeon_scene/combat/combat_target_selector.gd` の font_size `16→24` に変更する
- [x] 4.4 `src/dungeon_scene/combat/combat_spell_selector.gd` の font_size `16→24`, `14→21` に変更する
- [x] 4.5 `src/dungeon_scene/combat/combat_item_selector.gd` の font_size `16→24`, `12→18` に変更する
- [x] 4.6 `src/dungeon_scene/combat/combat_result_panel.gd` の font_size `22→33`, `16→24`, `14→21` に変更する
- [x] 4.7 `src/dungeon_scene/combat/combat_monster_panel.gd` の `TITLE_FONT_SIZE` `18→27`, `LIST_FONT_SIZE` `18→27` に変更する
- [x] 4.8 戦闘 UI 関連テストの期待値を更新する

## 5. モンスター戦闘画像の bump

- [x] 5.1 `src/dungeon_scene/combat/combat_monster_panel.gd` の `DESIRED_VISUAL_SIZE` を `Vector2(180, 144)→Vector2(270, 216)`, `VISUAL_GAP` を `28.0→42.0` に変更する
- [x] 5.2 関連テスト (もしあれば) の期待値を更新する

## 6. その他の status toast 等 font 調整

- [x] 6.1 `src/dungeon_scene/dungeon_screen.gd` の `show_status_tick` 内 `font_size = 16` を `24` に変更する

## 7. 統合動作確認

- [x] 7.1 起動 → デフォルトサイズ 1600×900 で UI が読みやすいサイズで表示されることを目視確認する
- [x] 7.2 ウィンドウを 1280×720 程度に縮小して UI が均一に縮むことを目視確認する
- [x] 7.3 ウィンドウを 1920×1080 / 2560×1440 に拡大して UI が均一に拡大することを目視確認する
- [x] 7.4 ウルトラワイド (例: ウィンドウ横幅 2400 × 縦 900) で歪まず、右カラムが端に貼り付くことを目視確認する
- [x] 7.5 ダンジョン探索中にウィンドウをリサイズしてダンジョン3D 描画が消失しないことを目視確認する
- [x] 7.6 戦闘中 (CombatOverlay 表示中) にリサイズして UI 各要素が崩れないことを目視確認する

## 8. 視覚確認後の追加調整

- [x] 8.1 PartyMemberPanel の portrait 領域を下方向に拡張: `PORTRAIT_HEIGHT` 138→174, `PANEL_HEIGHT` 224→240, `get_hp_bar_rect` Y=112→184, `get_mp_bar_rect` Y=134→200 (ハードコード値が portrait bump に追従していなかったための補正)
- [x] 8.2 戦闘メニューの行 (CursorMenuRow) font_size を bump: combat_command_menu 16→24, combat_target_selector 16→24, combat_spell_selector 14→21, combat_item_selector 14→21
- [x] 7.7 全 GUT テストを実行し、すべて pass することを確認する
