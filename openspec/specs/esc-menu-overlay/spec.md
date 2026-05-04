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
パーティメニューは以下のサブ項目 SHALL を表示する:「ステータス」「アイテム」「装備」「じゅもん」。MVP では「ステータス」「アイテム」「装備」が常に選択可能で、「じゅもん」は魔法職（`mage_school == true` または `priest_school == true` の Character）が現在のパーティに 1 人以上居る場合に選択可能となる。誰も魔法職でない場合は「じゅもん」は disabled 状態で表示する。

#### Scenario: パーティメニュー項目一覧
- **WHEN** メインメニューから「パーティ」を選択する
- **THEN** 以下の項目が表示される: 「ステータス」「アイテム」「装備」「じゅもん」

#### Scenario: 魔法職がいる場合は「じゅもん」が選択可能
- **WHEN** パーティに 1 人でも魔法職（mage_school または priest_school が true）の Character がいる状態でパーティメニューを開く
- **THEN** 「じゅもん」は有効状態で表示され、選択できる

#### Scenario: 魔法職がいない場合は「じゅもん」が disabled
- **WHEN** パーティ全員が非魔法職（fighter / thief / ninja のみ）の状態でパーティメニューを開く
- **THEN** 「じゅもん」は disabled 状態で表示され、選択できない

#### Scenario: ステータスを選択
- **WHEN** 「ステータス」にカーソルを合わせてEnterキーを押す
- **THEN** パーティステータス表示画面が表示される

#### Scenario: アイテムを選択
- **WHEN** 「アイテム」にカーソルを合わせてEnterキーを押す
- **THEN** アイテム一覧表示画面（パーティ共有インベントリ）が表示される

#### Scenario: 装備を選択
- **WHEN** 「装備」にカーソルを合わせてEnterキーを押す
- **THEN** 装備変更画面が表示される（キャラクター選択から開始）

#### Scenario: じゅもんを選択
- **WHEN** 「じゅもん」にカーソルを合わせてEnterキーを押す
- **THEN** SpellUseFlow（呪文使用フロー）の画面が表示される（詠唱者選択から開始）

### Requirement: EscMenu はサブフローを子 Control として保持し委譲する
SHALL: `EscMenu` の View enum は最大でも 7 値(`MAIN_MENU`, `PARTY_MENU`, `STATUS`, `QUIT_DIALOG`, `ITEMS_FLOW`, `EQUIPMENT_FLOW`, `SPELL_FLOW`)に収まること。アイテム使用、装備変更、および呪文詠唱のサブフローは EscMenu のフィールドではなく `ItemUseFlow` / `EquipmentFlow` / `SpellUseFlow` という別 Control の子インスタンスとして保持され、EscMenu は visibility 切替とシグナル受信のみを行う。

#### Scenario: View enum は 7 値以下
- **WHEN** `esc_menu.gd` の View enum を確認する
- **THEN** その値は `MAIN_MENU`, `PARTY_MENU`, `STATUS`, `QUIT_DIALOG`, `ITEMS_FLOW`, `EQUIPMENT_FLOW`, `SPELL_FLOW` のサブセットである

#### Scenario: SpellUseFlow は子 Control として保持される
- **WHEN** `esc_menu.gd` のフィールドを検査する
- **THEN** `SpellUseFlow` 型の子 Control を保持しているフィールドが存在し、EscMenu からはシグナル接続と visibility 切替で連携する

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

### Requirement: ESCメニューの終了確認は ConfirmDialog で構築される
SHALL: ESCメニューで「終了」を選択した時の確認ダイアログは、`ConfirmDialog` の子インスタンスを利用して構築される。`EscMenu` 内でインライン実装する終了確認 UI コードは存在しない。

#### Scenario: 終了確認ダイアログ表示時に ConfirmDialog が使われる
- **WHEN** ユーザが ESC メニューで「終了」を選択
- **THEN** `_quit_dialog.setup("ゲームを終了しますか？", 1)` が呼ばれ、ConfirmDialog が visible になる

#### Scenario: 「はい」確定でタイトル画面に戻る
- **WHEN** ConfirmDialog が `confirmed` シグナルを発行
- **THEN** `quit_to_title` シグナルが発行される

#### Scenario: 「いいえ」または ESC で終了がキャンセルされる
- **WHEN** ConfirmDialog が `cancelled` シグナルを発行
- **THEN** ダイアログが閉じ、ESCメニューのメインに戻る

### Requirement: SpellUseFlow は戦闘外詠唱の専用フローを提供する

The system SHALL provide a `SpellUseFlow` Control that handles the full out-of-battle spell-casting flow: caster selection → school selection (Bishop only) → spell selection → target selection → effect application. The flow SHALL exclusively offer spells whose `scope == OUTSIDE_OK` and which appear in the chosen caster's `Character.known_spells`. The flow SHALL deduct MP via `Character.current_mp` (clamped at zero, never negative) and SHALL apply effects identically to in-battle casting through the same `SpellEffect.apply` path.

#### Scenario: 詠唱者選択のリストは魔法職に限定される
- **WHEN** SpellUseFlow を開く
- **THEN** 詠唱者選択のリストは、パーティ内の生存しており、かつ `mage_school` または `priest_school` が true の Character のみを表示する

#### Scenario: Bishop は系統選択を経由する
- **WHEN** Bishop を詠唱者として選択する
- **THEN** 「魔術」「祈り」を選ぶ系統選択画面が次に表示される

#### Scenario: Mage / Priest は系統選択をスキップする
- **WHEN** Mage または Priest を詠唱者として選択する
- **THEN** 系統選択画面はスキップされ、その職の唯一の系統で `scope == OUTSIDE_OK` の呪文一覧が直接表示される

#### Scenario: 戦闘専用呪文は呪文一覧に表示されない
- **WHEN** Mage を詠唱者として選択し、`known_spells` に "ファイア"（BATTLE_ONLY）と "ヒール"（OUTSIDE_OK）の両方が含まれる前提（仮定）で呪文一覧を開く
- **THEN** 表示されるのは `scope == OUTSIDE_OK` の呪文だけであり、ファイアは表示されない

#### Scenario: ALLY_ONE 呪文は対象選択画面で味方を選ばせる
- **WHEN** "ヒール" を選択する
- **THEN** 対象選択画面が表示され、生存している味方からひとりを選択できる

#### Scenario: ALLY_ALL 呪文は対象選択をスキップして即時適用する
- **WHEN** "オールヒール" を選択する
- **THEN** 対象選択画面はスキップされ、生存している全味方に効果が適用される

#### Scenario: MP 不足の呪文は disabled
- **WHEN** 詠唱者の `current_mp` が `spell.mp_cost` より少ない呪文がリストに含まれる
- **THEN** 該当呪文の行は disabled 状態で表示され、選択できない

#### Scenario: 詠唱後の HP/MP 変更は保存形式に反映される
- **WHEN** "ヒール" を成功させて対象キャラの `current_hp` が増え、詠唱者の `current_mp` が減る
- **THEN** 直後に `Character.to_dict()` を呼ぶと、変更後の `current_hp` / `current_mp` が辞書に反映される

#### Scenario: フロー完了後にパーティメニューへ戻る
- **WHEN** SpellUseFlow が呪文の効果適用を完了する、または途中で Back/Cancel が押される
- **THEN** SpellUseFlow は閉じ、ESC メニューのパーティサブメニューに戻る

