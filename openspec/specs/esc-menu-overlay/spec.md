## Purpose
ESC キーで開く共通サブメニューの階層と項目を規定する。パーティ（ステータス・アイテム・装備）、設定、ゲーム終了などのトップレベルと、その下の遷移を対象とする。
## Requirements
### Requirement: ESCキーでメニューを開く
SHALL: main.gdの`_unhandled_input()`でESCキーを検出し、ESCメニューをオーバーレイ表示する。子画面がESCイベントを消費した場合はメニューを開かない。

#### Scenario: 町画面でESCキーを押す
- **WHEN** 町画面が表示されている状態でESCキーを押す
- **THEN** ESCメニューがオーバーレイ表示される

#### Scenario: ダンジョン画面でESCキーを押す
- **WHEN** ダンジョン画面が表示されている状態でESCキーを押す（帰還ダイアログ非表示時）
- **THEN** ESCメニューがオーバーレイ表示される

#### Scenario: ギルド画面でESCキーを押す
- **WHEN** ギルド画面が表示されている状態でESCキーを押す
- **THEN** ESCメニューがオーバーレイ表示される

#### Scenario: ダンジョン帰還ダイアログ表示中にESCキーを押す
- **WHEN** ダンジョン画面の帰還確認ダイアログが表示されている状態でESCキーを押す
- **THEN** DungeonScreenがESCイベントを消費し、ESCメニューは開かない

#### Scenario: タイトル画面ではESCメニューを開かない
- **WHEN** タイトル画面が表示されている状態でESCキーを押す
- **THEN** ESCメニューは開かない

### Requirement: ESCキーまたは戻る操作でメニューを閉じる
SHALL: ESCメニュー表示中にESCキーを押すとメニューを閉じ、ゲーム画面に復帰する。サブメニュー表示中はメインメニューに戻る。

#### Scenario: メインメニュー表示中にESCキーを押す
- **WHEN** ESCメニューのメインメニューが表示されている状態でESCキーを押す
- **THEN** ESCメニューが閉じ、ゲーム画面に復帰する

#### Scenario: サブメニュー表示中にESCキーを押す
- **WHEN** ESCメニューのサブメニュー（パーティメニュー等）が表示されている状態でESCキーを押す
- **THEN** サブメニューが閉じ、メインメニューに戻る

### Requirement: メニュー表示中はゲーム入力を遮断する
SHALL: ESCメニュー表示中はフルスクリーンのオーバーレイが背面画面への入力を遮断する。

#### Scenario: メニュー表示中に移動キーを押す
- **WHEN** ダンジョン画面でESCメニューが表示されている状態で移動キーを押す
- **THEN** キャラクターは移動しない

#### Scenario: メニューを閉じた後は操作可能
- **WHEN** ESCメニューを閉じてゲーム画面に復帰する
- **THEN** 通常の入力操作が復帰する

### Requirement: メインメニュー項目の表示
SHALL: ESCメニューのメインメニューは以下の項目を表示する。CursorMenuによるカーソル操作で選択する。

#### Scenario: メインメニュー項目一覧
- **WHEN** ESCメニューを開く
- **THEN** 以下の項目が表示される: 「パーティ」「ゲームを保存」「ゲームをロード」「設定」「終了」

#### Scenario: disabled項目の表示
- **WHEN** ESCメニューを開く
- **THEN** 「ゲームを保存」「ゲームをロード」「設定」はdisabled状態で表示され、選択できない

#### Scenario: カーソル移動
- **WHEN** ESCメニュー表示中に上下キーを押す
- **THEN** カーソルが有効な項目間を移動する（disabled項目はスキップする）

#### Scenario: パーティを選択
- **WHEN** 「パーティ」にカーソルを合わせてEnterキーを押す
- **THEN** パーティメニューサブ画面が表示される

#### Scenario: 終了を選択
- **WHEN** 「終了」にカーソルを合わせてEnterキーを押す
- **THEN** 終了確認ダイアログが表示される

### Requirement: パーティサブメニュー項目の表示
パーティメニューは以下のサブ項目 SHALL を表示する:「ステータス」「アイテム」「装備」。MVP ではすべての項目が選択可能である（旧仕様で無効化されていた「アイテム」「装備」を有効化する）。

#### Scenario: パーティメニュー項目一覧
- **WHEN** メインメニューから「パーティ」を選択する
- **THEN** 以下の項目が表示される: 「ステータス」「アイテム」「装備」

#### Scenario: すべての項目が選択可能
- **WHEN** パーティメニューを開く
- **THEN** 「ステータス」「アイテム」「装備」すべてが有効状態で表示され、選択できる

#### Scenario: ステータスを選択
- **WHEN** 「ステータス」にカーソルを合わせてEnterキーを押す
- **THEN** パーティステータス表示画面が表示される

#### Scenario: アイテムを選択
- **WHEN** 「アイテム」にカーソルを合わせてEnterキーを押す
- **THEN** アイテム一覧表示画面（パーティ共有インベントリ）が表示される

#### Scenario: 装備を選択
- **WHEN** 「装備」にカーソルを合わせてEnterキーを押す
- **THEN** 装備変更画面が表示される（キャラクター選択から開始）

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

### Requirement: 終了確認ダイアログ
SHALL: 「終了」選択時に確認ダイアログを表示し、承認でタイトル画面に遷移する。

#### Scenario: 終了確認ダイアログの表示
- **WHEN** メインメニューの「終了」を選択する
- **THEN** 「タイトルに戻りますか？」と「はい」「いいえ」が表示される

#### Scenario: 終了を承認
- **WHEN** 終了確認ダイアログで「はい」を選択する
- **THEN** ESCメニューのquit_to_titleシグナルが発行され、タイトル画面に遷移する

#### Scenario: 終了をキャンセル
- **WHEN** 終了確認ダイアログで「いいえ」を選択する
- **THEN** 確認ダイアログが閉じ、メインメニューに戻る

### Requirement: ESCメニューはCanvasLayerで表示する
SHALL: ESCメニューはCanvasLayer（layer=10）上に配置し、現在の画面の上にオーバーレイ表示する。半透明の背景で背面を暗くする。

#### Scenario: オーバーレイ表示
- **WHEN** ESCメニューを開く
- **THEN** 半透明の暗い背景の上にメニューパネルが表示される

### Requirement: 装備サブメニューは Equipment.ALL_SLOTS をスロット一覧の単一ソースとする
SHALL: ESC メニューの装備サブメニューでスロット一覧を構築する際、`Equipment.ALL_SLOTS` (= `Item.EquipSlot.WEAPON` ... `Item.EquipSlot.ACCESSORY` の配列) を直接参照すること。`esc_menu.gd` 内で独自に WEAPON / ARMOR / ... の重複定数(以前の `EQUIPMENT_SLOT_VALUES`)を保持してはならない。

#### Scenario: 装備サブメニューが ALL_SLOTS から構築される
- **WHEN** ユーザが ESC → パーティ → 装備 を選択する
- **THEN** 表示される 6 個のスロット行は `Equipment.ALL_SLOTS` の順序と内容に一致する

#### Scenario: 新しい装備スロットが追加された場合
- **WHEN** 将来 `Item.EquipSlot` に新しい値が追加され、`Equipment.ALL_SLOTS` がそれを含むよう更新される
- **THEN** ESC メニューの装備サブメニューは追加修正なしで新しいスロットを 7 行目として表示する

### Requirement: ESCメニューはaction ベースで入力を受ける
SHALL: `EscMenu._unhandled_input` は ui_* action(`ui_up`, `ui_down`, `ui_accept`, `ui_cancel`)を介してメニュー操作を受け取る。`event.keycode == KEY_*` の直接マッチを使ってはならない。本要件は MenuController 採用そのもの(C6 で実施)とは独立で、入力規約のみを規定する。

#### Scenario: ui_down action でカーソルが下に移動する
- **WHEN** ESCメニューが開いている状態で `is_action_pressed("ui_down")` がディスパッチされる
- **THEN** メニュー上のカーソルが次の有効項目へ進む

#### Scenario: ui_cancel action でメニューが閉じる(またはサブメニューから戻る)
- **WHEN** ESCメニューが開いている状態で `is_action_pressed("ui_cancel")` がディスパッチされる
- **THEN** メニューが閉じる(メインメニューの場合)、またはサブメニューからメインに戻る

#### Scenario: ui_accept action で選択項目が確定する
- **WHEN** ESCメニューが開いている状態で `is_action_pressed("ui_accept")` がディスパッチされる
- **THEN** 選択中の項目が確定し、対応する遷移が起きる

