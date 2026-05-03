## ADDED Requirements

### Requirement: EscMenu はサブフローを子 Control として保持し委譲する
SHALL: `EscMenu` の View enum は最大でも 6 値(`MAIN_MENU`, `PARTY_MENU`, `STATUS`, `QUIT_DIALOG`, `ITEMS_FLOW`, `EQUIPMENT_FLOW`)に収まること。アイテム使用および装備変更のサブフローは EscMenu のフィールドではなく `ItemUseFlow` / `EquipmentFlow` という別 Control の子インスタンスとして保持され、EscMenu は visibility 切替とシグナル受信のみを行う。

#### Scenario: View enum は 6 値以下
- **WHEN** `esc_menu.gd` の View enum を確認する
- **THEN** その値は `MAIN_MENU`, `PARTY_MENU`, `STATUS`, `QUIT_DIALOG`, `ITEMS_FLOW`, `EQUIPMENT_FLOW` のサブセットである(11 値の旧 enum は撤廃されている)

#### Scenario: アイテム使用は Flow に委譲される
- **WHEN** ユーザがパーティメニューで「アイテム」を選択する
- **THEN** EscMenu は子の `ItemUseFlow` を visible にし、自身のメインメニュー UI は visibility = false にする

#### Scenario: 装備変更は Flow に委譲される
- **WHEN** ユーザがパーティメニューで「装備」を選択する
- **THEN** EscMenu は子の `EquipmentFlow` を visible にし、自身のメインメニュー UI は visibility = false にする

#### Scenario: Flow 完了でメインメニューに戻る
- **WHEN** `ItemUseFlow.flow_completed` または `EquipmentFlow.flow_completed` シグナルが発行される
- **THEN** EscMenu は当該 Flow を visibility = false にし、PARTY_MENU を再表示する

### Requirement: EscMenu はサブフロー表示中は自身の入力を無視する
SHALL: `EscMenu._unhandled_input` は `_current_view == ITEMS_FLOW` または `EQUIPMENT_FLOW` のとき early return する。Flow 自身が `_unhandled_input` を持ち、必要に応じて `set_input_as_handled()` を呼ぶ。

#### Scenario: Flow 表示中の input は EscMenu に届かない
- **WHEN** ItemUseFlow が visible で何らかの key event が発行される
- **THEN** EscMenu の `_unhandled_input` は early return し、Flow 側で処理が完結する

## REMOVED Requirements

### Requirement: EscMenu manages item-use sub-views inline
**Reason**: EscMenu の View enum を 11 値から 6 値に縮小するため、`ITEMS`, `ITEM_USE_TARGET`, `ITEM_USE_CONFIRM` ビューは `ItemUseFlow` という独立 Control に抽出される。EscMenu 内の `_items_index`, `_item_use_instance`, `_item_use_target_index`, `_item_use_confirm_index`, `_item_use_last_message` 等のフィールドおよび関連メソッドは削除される。

**Migration**: ItemUseFlow を子 Control として追加し、setup() でコンテキストを渡す。flow_completed シグナルで結果を受け取る。

### Requirement: EscMenu manages equipment sub-views inline
**Reason**: EscMenu の View enum 縮小に伴い、`EQUIPMENT`, `EQUIPMENT_CHARACTER`, `EQUIPMENT_SLOT`, `EQUIPMENT_CANDIDATE` ビューは `EquipmentFlow` という独立 Control に抽出される。EscMenu 内の `_equipment_character_index`, `_equipment_slot_index`, `_equipment_candidate_index` 等のフィールドおよび関連メソッドは削除される。

**Migration**: EquipmentFlow を子 Control として追加し、setup() でパーティと inventory を渡す。flow_completed シグナルで完了を受け取る。
