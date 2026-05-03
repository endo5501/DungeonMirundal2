## ADDED Requirements

### Requirement: ItemUseFlow は独立した Control として動作する
SHALL: `ItemUseFlow extends Control` クラスを `src/esc_menu/flows/item_use_flow.gd` に定義する。本 Control は `setup(context: ItemUseContext, inventory: Inventory, party: Array[Character])` メソッドで初期化され、内部に 4 つのサブビュー(`SELECT_ITEM`, `SELECT_TARGET`, `CONFIRM`, `RESULT`)を持つ。フロー完了時に `flow_completed(message: String)` シグナルを発行する。

#### Scenario: setup でフローが初期化される
- **WHEN** `ItemUseFlow.new()` をインスタンス化し `setup(context, inventory, party)` を呼ぶ
- **THEN** SELECT_ITEM サブビューが表示され、`inventory.list()` から使用可能アイテムが列挙される

#### Scenario: アイテム選択後に対象選択に進む
- **WHEN** SELECT_ITEM サブビューでユーザがアイテムを選択して ui_accept を押す
- **THEN** SELECT_TARGET サブビューに遷移し、`_selected_item` がそのアイテムにセットされる

#### Scenario: 対象選択後に確認に進む
- **WHEN** SELECT_TARGET サブビューでユーザが対象キャラクターを選択して ui_accept を押す
- **THEN** CONFIRM サブビューに遷移する

#### Scenario: 確認後にアイテムが使用される
- **WHEN** CONFIRM サブビューで「はい」を選択して ui_accept
- **THEN** `selected_item.item.effect.apply(target, context)` が呼ばれ、結果メッセージが RESULT サブビューに表示される

#### Scenario: 結果表示後にフロー完了
- **WHEN** RESULT サブビューで ui_accept または ui_cancel が押される
- **THEN** `flow_completed(message)` シグナルが発行される

#### Scenario: ui_cancel で前サブビューに戻る
- **WHEN** SELECT_TARGET または CONFIRM サブビューで ui_cancel が押される
- **THEN** 1 つ前のサブビューに戻る

#### Scenario: SELECT_ITEM での ui_cancel はフローキャンセル
- **WHEN** SELECT_ITEM サブビューで ui_cancel が押される
- **THEN** `flow_completed("")` シグナルが空メッセージで発行される(キャンセル扱い)

### Requirement: ItemUseFlow は ItemUseContext を尊重する
SHALL: `setup` で渡された `ItemUseContext` を全てのアイテム使用判定に渡す。`item.get_context_failure_reason(ctx)` が空文字列でないアイテムは選択リストに表示されないか、disabled で表示される。`item.get_target_failure_reason(target, ctx)` が空文字列でない対象は SELECT_TARGET で disabled となる。

#### Scenario: コンテキストに合わないアイテムは選択不可
- **WHEN** SELECT_ITEM が表示され、あるアイテムが `get_context_failure_reason(ctx)` で「町でのみ使用可」と返す
- **THEN** そのアイテムは disabled 状態で表示される

#### Scenario: ターゲット条件に合わないキャラは選択不可
- **WHEN** SELECT_TARGET が表示され、あるキャラクターが `get_target_failure_reason(target, ctx)` で「MP を持たない職業」と返す
- **THEN** そのキャラクターは disabled 状態で表示される

### Requirement: ItemUseFlow は EscMenu と CombatOverlay の双方から再利用可能
SHALL: ItemUseFlow は `ItemUseContext.in_combat` の値に依存せず、setup で渡された context をそのまま使う。EscMenu からの呼び出し(in_combat = false)と CombatOverlay からの呼び出し(in_combat = true)で同じ Flow が機能する。

#### Scenario: EscMenu から呼ばれる
- **WHEN** EscMenu がアイテム使用フローを開始し、ItemUseFlow.setup(context_with_in_combat_false, ...) を呼ぶ
- **THEN** 戦闘中フラグの影響を受けずにフローが進行する

#### Scenario: CombatOverlay から呼ばれる
- **WHEN** CombatOverlay がアイテム使用フローを開始し、ItemUseFlow.setup(context_with_in_combat_true, ...) を呼ぶ
- **THEN** 戦闘中専用のアイテムも候補に含まれ、戦闘中不可能なアイテムは除外される

### Requirement: ItemUseFlow は単体でテスト可能である
SHALL: ItemUseFlow は EscMenu や CombatOverlay 全体をセットアップせずに直接インスタンス化してテストできる。テストは setup → handle_input(synthetic events) → assert sub_view 遷移 / flow_completed 発行を検証する。

#### Scenario: 単体テストでフロー全体を駆動できる
- **WHEN** テスト内で `ItemUseFlow.new()` を作り setup と handle_input だけで操作する
- **THEN** EscMenu や CombatOverlay は不要で、フローの全 4 サブビューを通せる
