## 1. テスト準備 (TDD: red)

- [ ] 1.1 既存の `tests/dungeon_scene/test_party_display_character_binding.gd` 他、レイアウトに依存するアサーションがあれば洗い出して記録
- [ ] 1.2 新規テスト `tests/dungeon_scene/test_party_display_layout.gd` を作成: PartyDisplay の anchors が full-bottom (`anchor_left=0, anchor_right=1, anchor_top=1, anchor_bottom=1`) になる
- [ ] 1.3 同テストファイル内: 前列3パネルが画面左端から左詰めで並ぶ(`position.x` が左→右に増加、最左パネルの x が `MARGIN` 以下)
- [ ] 1.4 同テストファイル内: 後列3パネルが画面右端から右詰めで並ぶ(最右パネルの右端が画面右端から `MARGIN` 以下)
- [ ] 1.5 同テストファイル内: 前列・後列の全パネルが同じ `position.y` を持つ
- [ ] 1.6 同テストファイル内: 前列右端パネルと後列左端パネルの間に水平方向の隙間がある(中央が空く)
- [ ] 1.7 同テストファイル内: PartyDisplay に `ColorRect` の background 子(`_bg_panel`)が存在しない
- [ ] 1.8 新規テスト `tests/dungeon_scene/test_party_display_labels.gd` を作成: PartyDisplay が "FRONT" / "BACK" を draw_string で出力する(描画フックで検証 or テスト用ヘルパで draw 呼び出しを記録)
- [ ] 1.9 新規テスト `tests/dungeon_scene/test_party_member_panel_size.gd` を作成: `PartyMemberPanel.PANEL_WIDTH == 180`、`PANEL_HEIGHT >= 100`、`FONT_SIZE >= 20`
- [ ] 1.10 新規テスト `tests/dungeon_scene/test_party_member_panel_empty.gd` を作成: `_data == null` かつ `_character == null` のとき `_draw()` が `draw_rect`/`draw_string` を呼び出さない(描画フックで検証)
- [ ] 1.11 同テスト内: `bind_party_characters([A, null, B], [...])` で 2 番目の前列パネルが空、3 番目はそのまま B として描画され、F3 が左に詰めて移動しないこと
- [ ] 1.12 GUT 実行 → red を確認(新規テストが失敗、既存テストはレイアウト依存箇所のみ失敗)
- [ ] 1.13 red 状態でコミット

## 2. PartyMemberPanel の更新 (TDD: green for panel-side)

- [ ] 2.1 `src/dungeon_scene/party_member_panel.gd` の `FONT_SIZE` を 20 に更新
- [ ] 2.2 `PANEL_HEIGHT` を 110 に更新(必要なら 100/105 と調整可)
- [ ] 2.3 `_draw()` の行間 `line_h` をフォントサイズに合わせて再計算(目安: `FONT_SIZE + 4`)
- [ ] 2.4 `_draw()` 冒頭で `_data == null` のとき early return(背景矩形 `draw_rect` も呼ばない)に変更
- [ ] 2.5 名前/LV/HP/MP の 4 行が PANEL_HEIGHT 内に収まる Y 座標を再調整(MP 行の bottom が `PANEL_HEIGHT - 4` 以下)
- [ ] 2.6 GUT 実行 → `test_party_member_panel_size.gd` / `test_party_member_panel_empty.gd` が green になることを確認

## 3. PartyDisplay の更新 (TDD: green for display-side)

- [ ] 3.1 `src/dungeon_scene/party_display.gd` の `_ready()` でアンカーを full-bottom に変更(`anchor_left=0, anchor_right=1, anchor_top=1, anchor_bottom=1`、対応 offset を 0 に)
- [ ] 3.2 `_bg_panel: ColorRect` の生成と `add_child` を削除、フィールド宣言も削除
- [ ] 3.3 `_create_row(row_index)` を廃止し、前列を画面左端から margin 詰めで配置するロジックを書く(3 パネル分の `position.x = MARGIN + i * (PANEL_WIDTH + MARGIN)`)
- [ ] 3.4 後列を画面右端から margin 詰めで配置するロジックを書く(右端 `width - MARGIN` から逆算: `position.x = width - MARGIN - (3 - i) * PANEL_WIDTH - (2 - i) * MARGIN` 等)
- [ ] 3.5 前列・後列の `position.y` を同一値に揃える(ラベル領域の下、HUD 全体高さ ~140px の下半分)
- [ ] 3.6 後列のレイアウトは `PartyDisplay.size.x` に依存するため、`_ready()` の実行タイミングと `resized` シグナルの両方で再計算する関数 `_layout_panels()` を用意
- [ ] 3.7 `PartyDisplay._draw()` をオーバーライドし、"FRONT" を前列パネル群の真上に左揃えで `draw_string`、"BACK" を後列パネル群の真上に右揃えで `draw_string` する
- [ ] 3.8 ラベルのフォントサイズは `PartyMemberPanel.FONT_SIZE` 以上(20pt 以上)とする
- [ ] 3.9 `bind_party_characters` 関数のシグネチャ・挙動はそのまま維持(空スロットで `bind_character(null)` を呼ぶ動作も維持)
- [ ] 3.10 `setup(party_data)` のスナップショット経路もそのまま維持
- [ ] 3.11 GUT 実行 → `test_party_display_layout.gd` / `test_party_display_labels.gd` が green になることを確認

## 4. 既存テストの修正

- [ ] 4.1 `tests/dungeon_scene/test_party_display_character_binding.gd` でレイアウト座標に依存する箇所があれば、座標値ではなく相対関係(前列が左、後列が右、同じ y)で検証するよう更新
- [ ] 4.2 `tests/dungeon_scene/test_esc_menu_heal_refreshes_status_bar.gd` 等の関連テストでレイアウト関連の期待があれば同様に更新
- [ ] 4.3 GUT 全テスト実行 → green を確認

## 5. 手動確認

- [ ] 5.1 ダンジョンに入って前列・後列が左下・右下に分かれて表示されることを確認(`tmp/dungeon2.png` 相当のシーンで中央が空くこと)
- [ ] 5.2 FRONT / BACK ラベルが読み取れる位置・色で出ることを確認
- [ ] 5.3 名前/LV/HP/MP がパネル内に収まり、フォント拡大後も切れないことを確認
- [ ] 5.4 パーティが 6 人未満の場合(例: 前列 2 人)、空スロットが完全に透明になり、視覚ノイズがないことを確認
- [ ] 5.5 ESC メニューでの回復・状態異常付与がリアルタイムにパネルに反映されること(既存挙動の回帰確認)
- [ ] 5.6 PANEL_HEIGHT, FRONT/BACK ラベルの色など、目視で気になる箇所があれば値を微調整

## 6. クリーンアップ・コミット

- [ ] 6.1 不要になったコメント・デッドコード(`MARGIN` 以外の不要定数、`_bg_panel` 関連の残骸)を削除
- [ ] 6.2 `openspec validate enlarge-party-display --strict` を実行して valid を確認
- [ ] 6.3 green 状態でコミット
