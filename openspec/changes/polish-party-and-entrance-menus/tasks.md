## 1. PartyFormation の待機リスト CursorMenuRow 化

- [x] 1.1 `tests/` の既存 `party_formation` 関連テストを確認し、待機リストの表示検証がどうなっているか把握する
- [x] 1.2 待機リストが `CursorMenuRow` ベースで描画されることを検証する GUT テストを追加する (失敗することを確認)
- [x] 1.3 `src/guild_scene/party_formation.gd` の `_rebuild_display()` 内の待機リスト生成を `CursorMenuRow.create(...)` に置き換える
- [x] 1.4 選択状態の更新を `CursorMenu.update_rows` または同等の `set_selected` 呼び出しに置き換える
- [x] 1.5 追加したテストがパスすることを確認する

## 2. PartyFormation の格子カーソル文字差し替え

- [x] 2.1 格子 (前列/後列) でカーソル位置のスロットが `"▶ "` プレフィックスで描画されることを検証する GUT テストを追加する (失敗することを確認)
- [x] 2.2 `src/guild_scene/party_formation.gd` の `CURSOR` 定数を `"> "` から `"▶ "` に変更する
- [x] 2.3 `_rebuild_display()` の格子行生成で `CURSOR.strip_edges() + " "` となっている箇所を `CURSOR` そのまま使用する形に整理する (または意図通り2文字幅を維持する)
- [x] 2.4 追加したテストがパスすることを確認する
- [x] 2.5 待機リスト側のラベルに `"▶"` 文字が埋め込まれていないことをテストで確認する

## 3. PartyFormation レガシー定数の除去確認

- [x] 3.1 `src/guild_scene/party_formation.gd` 内に `"> "` を値とする定数が存在しないことを確認する (差し替え完了)
- [x] 3.2 spec の `Party formation prohibits legacy cursor prefix string` 要件に対応するテストを確認・追加する

## 4. DungeonEntrance の状態機械再設計

- [x] 4.1 `tests/` の既存 `dungeon_entrance` 関連テストを確認し、どのシナリオが新フローと矛盾するか洗い出す
- [x] 4.2 起動時フォーカスがボタン列であることを検証するテストを追加する (失敗することを確認)
- [x] 4.3 `潜入する` 活性化後にリスト焦点へ遷移することを検証するテストを追加する
- [x] 4.4 `破棄` 活性化後にリスト焦点へ遷移することを検証するテストを追加する
- [x] 4.5 リスト焦点中のESCでボタン列に戻り、アクションが実行されないことを検証するテストを追加する
- [x] 4.6 `src/town_scene/dungeon_entrance.gd` の `Focus` enum 扱いを「起動時は常に BUTTONS」になるように `setup()` を修正する (レジストリが空でなくても BUTTONS から開始)
- [x] 4.7 `_unhandled_input` の動作を新状態機械に合わせて書き直す:
  - `BUTTON_FOCUS` (既定): 上下でボタン移動、Enterで `_activate_button`、ESCで `do_back`
  - `LIST_FOCUS_ENTER`: 上下でリストカーソル移動、Enterで `enter_dungeon.emit`、ESCで `BUTTON_FOCUS` に戻る
  - `LIST_FOCUS_DELETE`: 上下でリストカーソル移動、Enterで `_show_delete_confirm`、ESCで `BUTTON_FOCUS` に戻る
- [x] 4.8 `_activate_button` を修正: `潜入` → `LIST_FOCUS_ENTER` 遷移、`破棄` → `LIST_FOCUS_DELETE` 遷移
- [x] 4.9 追加したテストがすべてパスすることを確認する

## 5. DungeonEntrance の disabled 条件整理

- [x] 5.1 `is_enter_disabled()` / `is_delete_disabled()` を新条件 (レジストリ空 or パーティ空 ベース) に書き換えるテストを追加する (既存テストがカバー)
- [x] 5.2 `is_enter_disabled` を「レジストリ空 OR パーティ空」に変更する
- [x] 5.3 `is_delete_disabled` を「レジストリ空」に変更する
- [x] 5.4 `_update_button_disabled()` の disabled 配列計算を新条件に合わせる
- [x] 5.5 追加したテストがパスすることを確認する

## 6. DungeonEntrance の初期カーソル配置

- [x] 6.1 空レジストリで `新規生成` にカーソルが置かれることを検証するテストがすでにあるか確認・更新する
- [x] 6.2 非空レジストリで `潜入する` にカーソルが置かれることを検証するテストを追加する
- [x] 6.3 `setup()` で `_button_menu.selected_index` を登録ダンジョン有無に応じて設定するロジックを調整する
- [x] 6.4 追加したテストがパスすることを確認する

## 7. ヒントテキストの更新

- [x] 7.1 ダンジョン入口のヒントテキスト (画面下部のキー表) が新フローに沿った表記になっていることを確認する (必要なら `dungeon_entrance.gd` に追加)
- [x] 7.2 パーティ編成のヒントテキストはカーソル記号変更の影響なしであることを確認する

## 8. 手動検証

- [ ] 8.1 `godot --editor` でプロジェクトを開き、ギルド > パーティ編成で待機リストと格子のカーソルが `"▶"` に変わっていることを目視確認
- [ ] 8.2 街 > ダンジョン入口で起動時に `潜入する` にカーソルがあることを確認
- [ ] 8.3 `潜入する` → Enter でリストに焦点が移ることを確認
- [ ] 8.4 リスト焦点中にESCでボタン列に戻ることを確認
- [ ] 8.5 `破棄` → Enter → リスト選択 → Enter → 確認ダイアログ → `はい`/`いいえ` の動作を確認
- [ ] 8.6 空レジストリ状態で `新規生成` が初期フォーカスになることを確認
- [ ] 8.7 空レジストリ時に `潜入する` / `破棄` が disabled 色で表示されることを確認

## 9. 仕上げ

- [x] 9.1 `godot --headless -s addons/gut/gut_cmdln.gd` で全テストがパスすることを確認
- [ ] 9.2 変更内容をコミットする (spec 更新、実装、テストを論理単位でまとめる)
- [ ] 9.3 PR作成 or main へのマージを検討する (`/opsx:archive` で change をアーカイブする)
