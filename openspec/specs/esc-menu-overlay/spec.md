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

### Requirement: アイテム一覧ビューは所持品を閲覧できる
The system SHALL provide an item-list view under ESC メニュー > パーティ > アイテム that displays the entries of `GameState.inventory` (items and gold). The MVP view SHALL be read-only: it SHALL NOT provide any use/consume action on items.

#### Scenario: 所持ゴールドを表示
- **WHEN** アイテム一覧ビューを開く
- **THEN** 画面上部に `GameState.inventory.gold` の値が表示される

#### Scenario: 所持アイテムを一覧表示
- **WHEN** アイテム一覧ビューを開き、インベントリに3個のアイテムが入っている
- **THEN** すべての3個のアイテムが名前と分類（武器/鎧/... など）と共に表示される

#### Scenario: 装備中のアイテムに印を付ける
- **WHEN** 所持アイテムのうち1つが何らかのキャラに装備されている
- **THEN** 該当アイテムの行に装備中であることを示す印（例: 「装」マーク、装備者名）が表示される

#### Scenario: 使用ボタンは存在しない
- **WHEN** アイテム一覧ビューを表示する
- **THEN** 「使用」「使う」「Use」といったアクションは画面上に提供されない（MVP）

#### Scenario: ESCで前画面に戻る
- **WHEN** アイテム一覧ビュー表示中にESCキーを押す
- **THEN** パーティサブメニューに戻る

### Requirement: 装備ビューで装備の変更ができる
The system SHALL provide an equipment view under ESC メニュー > パーティ > 装備 that SHALL allow the player to pick a character, see their six slots (武器 / 鎧 / 兜 / 盾 / 籠手 / 装身具), and equip or unequip items from `GameState.inventory`. The view SHALL enforce the equip rules (slot type match and `allowed_jobs` match) defined by the equipment capability.

#### Scenario: キャラクター選択
- **WHEN** 装備ビューを開く
- **THEN** パーティメンバーの一覧が表示され、いずれかを選択できる

#### Scenario: スロット一覧の表示
- **WHEN** キャラクターを選択する
- **THEN** 6スロット（武器 / 鎧 / 兜 / 盾 / 籠手 / 装身具）が表示され、各スロットに現在装備しているアイテム名または「なし」が表示される

#### Scenario: 装備候補の表示（職業制限を反映）
- **WHEN** スロットを選択する
- **THEN** インベントリから「対応する equip_slot を持ち、`allowed_jobs` に対象キャラの職業を含むアイテム」が候補として表示され、それ以外はグレーアウトまたは非表示となる

#### Scenario: 装備変更の反映
- **WHEN** 候補からアイテムを選んで確定する
- **THEN** `character.equipment.equip(slot, instance, character)` が呼ばれ、該当スロットのアイテムが更新される（既存アイテムはインベントリに残る）

#### Scenario: 装備解除
- **WHEN** スロット選択時に「はずす」を選択する
- **THEN** `character.equipment.unequip(slot)` が呼ばれ、スロットは空になる（アイテムはインベントリに残る）

#### Scenario: ESCで1階層戻る
- **WHEN** 装備ビューのいずれかの階層（キャラクター選択 / スロット選択 / 候補選択）でESCを押す
- **THEN** 1階層上に戻る（最上位ではパーティサブメニューに戻る）

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
