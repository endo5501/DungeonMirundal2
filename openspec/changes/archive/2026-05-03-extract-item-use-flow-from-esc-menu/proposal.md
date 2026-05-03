## Why

`src/esc_menu/esc_menu.gd` は 772 LOC、11 値の View enum を内部で持つ god class で、過去 6 ヶ月で 14 commits と top-churned ファイル。UI 構築、ビュー切替、入力ディスパッチ、アイテム使用サブフロー、装備サブフロー、ステータス表示、GameState 変更がすべて 1 クラスに同居している。

このうち **アイテム使用サブフロー(ITEMS / ITEM_USE_TARGET / ITEM_USE_CONFIRM)** と **装備サブフロー(EQUIPMENT / EQUIPMENT_CHARACTER / EQUIPMENT_SLOT / EQUIPMENT_CANDIDATE)** は、それぞれ独立した「内部状態+UI+入力」を持つフローで、`EscMenu` の View 切替に乗っているだけで、本質的には独立 Control に切り出せる。切り出すことで `EscMenu` は「メイン+パーティ+ステータス+終了」の 6 ビュー程度のルータに縮小し、後続のフロー追加(設定画面など)が容易になる。

加えて、戦闘オーバーレイ(`combat_overlay.gd:201-249`)が EscMenu と同形のアイテム使用フローを再実装している(F033)。本 change で抽出する `ItemUseFlow` を C7 で再利用することで、その重複も解消できる。

## What Changes

- `src/esc_menu/flows/item_use_flow.gd` を新規追加(`ItemUseFlow extends Control`)
  - 内部で 3 ビュー(SELECT_ITEM / SELECT_TARGET / CONFIRM)を持つ
  - `setup(context: ItemUseContext)` で発動条件を渡す
  - `result_completed(success: bool, message: String)` シグナル発行
- `src/esc_menu/flows/equipment_flow.gd` を新規追加(`EquipmentFlow extends Control`)
  - 内部で 3 ビュー(CHARACTER / SLOT / CANDIDATE)を持つ
  - `setup(party: Array[Character], inventory: Inventory)` で開始
  - `flow_completed` シグナル発行
- `src/esc_menu/esc_menu.gd` を:
  - View enum を 11 値から 6 値(MAIN_MENU, PARTY_MENU, STATUS, QUIT_DIALOG, ITEMS_FLOW, EQUIPMENT_FLOW)に縮小
  - ITEMS_FLOW / EQUIPMENT_FLOW では子 Control(`ItemUseFlow` / `EquipmentFlow`)を `add_child` し、シグナルで戻りを受ける
  - 700+ LOC の `_build_items_*` / `_input_items_*` / `_build_equipment_*` / `_input_equipment_*` メソッドを撤去
- 入力ルーティングは MenuController + 各 Flow の独自ロジックを使う
- 既存テスト(`tests/esc_menu/test_esc_menu.gd`)の外部観測可能なシナリオは無修正で通る。内部 View 値や `_items_index` 等の private state を assert するテストは更新が必要。
- 抽出した Flow に対する単体テスト(`tests/esc_menu/flows/test_item_use_flow.gd`, `test_equipment_flow.gd`)を追加

## Capabilities

### Modified Capabilities

- `esc-menu-overlay`: View enum 縮小、サブフローを子 Control に委譲する旨を明記。

### New Capabilities

- `item-use-flow`: アイテム使用フロー(対象選択 → 実行 → 結果表示)を独立 Control として規定。EscMenu と CombatOverlay の双方から再利用される。
- `equipment-flow`: 装備変更フロー(キャラクター選択 → スロット選択 → 候補選択)を独立 Control として規定。

## Impact

- **新規コード**:
  - `src/esc_menu/flows/item_use_flow.gd`
  - `src/esc_menu/flows/equipment_flow.gd`
  - `tests/esc_menu/flows/test_item_use_flow.gd`
  - `tests/esc_menu/flows/test_equipment_flow.gd`
- **変更コード**:
  - `src/esc_menu/esc_menu.gd` — 約 300〜400 LOC 削減見込み(11 ビューから 6 ビューに、サブフローのメソッドを撤去)
- **互換性**:
  - 外部から見える挙動(ESCメニューの操作フロー、各画面遷移)は不変
  - `EscMenu` の public API(`show_menu`, `hide_menu`, シグナル)は不変
  - 既存テストの「外部観測可能シナリオ」は通る、private state 検証テストは更新
- **依存関係**:
  - C4a (MenuController) を利用
  - C4b (action ベース統一) 完了が前提
  - C7 (combat_overlay リファクタ) で本 change の `ItemUseFlow` を再利用
  - C3 (equipment slot enum 統合) 完了後に着手すると `EquipmentFlow` の slot 参照がシンプルになる
