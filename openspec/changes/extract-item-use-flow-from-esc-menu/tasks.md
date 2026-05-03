## 1. ItemUseFlow の抽出 (TDD)

- [x] 1.1 `tests/esc_menu/flows/test_item_use_flow.gd` を作成、`ItemUseFlow.new()` が SELECT_ITEM サブビューで初期化されるテスト
- [x] 1.2 アイテム選択 → SELECT_TARGET 遷移テスト
- [x] 1.3 対象選択 → CONFIRM 遷移テスト
- [x] 1.4 「はい」確認 → effect 適用 → RESULT 遷移テスト
- [x] 1.5 RESULT で ui_accept → flow_completed(message) シグナルテスト
- [x] 1.6 各サブビューでの ui_cancel による前ビュー戻り / フローキャンセルテスト
- [x] 1.7 ItemUseContext.in_combat フィルタテスト(戦闘専用アイテムが in_combat=false で表示されないなど)
- [x] 1.8 テストを Red 確認しコミット
- [x] 1.9 `src/esc_menu/flows/item_use_flow.gd` を実装(`ItemUseFlow extends Control`、SubView enum、setup、handle_input、各サブビュー UI 構築)
- [x] 1.10 EscMenu の旧 `_build_items_*` / `_input_items_*` / `_handle_item_use_*` メソッドのロジックを ItemUseFlow に移植
- [x] 1.11 テスト Green 確認しコミット

## 2. EquipmentFlow の抽出 (TDD)

- [x] 2.1 `tests/esc_menu/flows/test_equipment_flow.gd` を作成、CHARACTER → SLOT → CANDIDATE の遷移テスト
- [x] 2.2 装備変更が `Equipment.equip` / `unequip` を呼ぶことの検証
- [x] 2.3 他キャラ装備のスワップテスト
- [x] 2.4 各サブビューでの ui_cancel テスト
- [x] 2.5 CHARACTER での ui_cancel が flow_completed を発行することの検証
- [x] 2.6 テスト Red 確認しコミット
- [x] 2.7 `src/esc_menu/flows/equipment_flow.gd` を実装
- [x] 2.8 EscMenu の旧 `_build_equipment_*` / `_input_equipment_*` メソッドのロジックを EquipmentFlow に移植
- [x] 2.9 テスト Green 確認しコミット

## 3. EscMenu のスリム化 (TDD)

- [x] 3.1 既存 `tests/esc_menu/test_esc_menu.gd` のうち、private state(`_items_index`, `_item_use_instance`, `_equipment_*_index`)を直接 assert しているテストを「外部観測可能シナリオ」に書き換え
- [x] 3.2 「ESC → パーティ → アイテム を選択すると ItemUseFlow が visible になる」テストを追加
- [x] 3.3 「ItemUseFlow.flow_completed 発行で PARTY_MENU に戻る」テストを追加
- [x] 3.4 同様に EquipmentFlow についてのテストを追加
- [x] 3.5 テスト Red 確認(現実装は旧構造のまま)
- [ ] 3.6 `src/esc_menu/esc_menu.gd` の View enum を 6 値に縮小(`ITEMS_FLOW`, `EQUIPMENT_FLOW` を追加、旧 7 値を削除)
- [ ] 3.7 EscMenu に `_item_use_flow: ItemUseFlow` と `_equipment_flow: EquipmentFlow` フィールドを追加、`_build_ui` で生成して add_child
- [ ] 3.8 メニュー選択時に Flow.setup を呼んで visible 切替する関数を追加
- [ ] 3.9 旧 `_build_items_*`, `_input_items_*`, `_build_equipment_*`, `_input_equipment_*` メソッドを削除
- [ ] 3.10 旧 `_items_index`, `_item_use_instance`, `_item_use_target_index`, `_item_use_confirm_index`, `_item_use_last_message`, `_equipment_character_index`, `_equipment_slot_index`, `_equipment_candidate_index` フィールドを削除
- [ ] 3.11 `_unhandled_input` の `_current_view == ITEMS_FLOW or EQUIPMENT_FLOW` early return を追加
- [ ] 3.12 テスト Green 確認しコミット

## 4. 動作確認

- [ ] 4.1 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイート通過
- [ ] 4.2 ゲーム起動 → ESC → パーティ → アイテム → アイテム選択 → 対象選択 → 確認 → 使用 → 結果 → 戻る、の全フロー目視確認
- [ ] 4.3 ESC → パーティ → 装備 → キャラ選択 → スロット選択 → 候補選択 → 装備変更、の全フロー目視確認
- [ ] 4.4 装備のスワップ(他キャラから取り上げる挙動)を目視確認
- [ ] 4.5 各サブビューで ESC で前に戻る挙動を確認

## 5. 仕上げ

- [ ] 5.1 `openspec validate extract-item-use-flow-from-esc-menu --strict`
- [ ] 5.2 `/simplify`スキルでコードレビューを実施
- [ ] 5.3 `/opsx:verify extract-item-use-flow-from-esc-menu`
- [ ] 5.4 `/opsx:archive extract-item-use-flow-from-esc-menu`
