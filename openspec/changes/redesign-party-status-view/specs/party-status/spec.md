## MODIFIED Requirements

### Requirement: パーティメンバー一覧の表示
SHALL: パーティステータス画面は左ペインに「パーティ編成済みメンバー」のみをカーソル付きリストとして表示する。順序は前列スロット (row=0, pos=0..2) → 後列スロット (row=1, pos=0..2) とし、各行のラベルは `"%d. %s" % [position+1, character_name]` の形式で、編成位置 1〜6 とキャラクター名を示す。空スロットは行として描画せず、編成済みメンバーだけを並べる（カーソルは空欄に止まらない）。リストには `CursorMenu` ベースのカーソル UI を用いる。

#### Scenario: 前列・後列の順でリスト化される
- **WHEN** パーティ編成が「前列: A, B, 空, 後列: C, 空, D」のときにステータス画面を開く
- **THEN** 左ペインのリストは上から順に `1. A`, `2. B`, `4. C`, `6. D` の 4 行を表示する

#### Scenario: パーティが空の場合
- **WHEN** パーティが空（編成済みメンバーがいない）の状態でステータス画面を開く
- **THEN** 左ペインにはメンバー行が表示されず、画面に「パーティが編成されていません」のメッセージが表示される

#### Scenario: 初期カーソル位置はリスト先頭
- **WHEN** ステータス画面を開く
- **THEN** カーソルは左ペインリストの先頭メンバーに置かれ、右ペインにはそのキャラクターの詳細が表示される

### Requirement: キャラクター詳細情報の表示
SHALL: 右ペインはカーソルが当たっているキャラクターの詳細を以下の項目すべて含めて表示する: ジョブポートレイト画像、キャラクター名、種族名（race.race_name）、職業名（job.job_name）、レベル、状態行、HP（現在値/最大値）、MP（現在値/最大値）、経験値、基礎ステータス（STR, INT, PIE, VIT, AGI, LUC）、装備 6 スロット、習得呪文一覧。右ペインは `ScrollContainer` でクリップし、表示要素が画面に収まらない場合はスクロール可能とする。

#### Scenario: ポートレイトの表示
- **WHEN** カーソルが Fighter 職のキャラクターに当たっている
- **THEN** 右ペインに `assets/images/portraits/jobs/fighter.png` のテクスチャが表示される

#### Scenario: ポートレイトのフォールバック
- **WHEN** カーソルが当たっているキャラクターの job_id に対応するポートレイト画像が存在しない、または job が `null` である
- **THEN** ポートレイト領域は空のプレースホルダ（暗い矩形）を表示し、エラーで処理が止まらない

#### Scenario: HP/MP のフォーマット
- **WHEN** 右ペインが描画される
- **THEN** 「HP: 現在値/最大値」「MP: 現在値/最大値」の形式で表示される

#### Scenario: 経験値のフォーマット (通常)
- **WHEN** カーソルが Lv.1 で `accumulated_exp = 100`、`job.exp_to_reach_level(2) = 1000` のキャラクターに当たっている
- **THEN** 右ペインに「EXP: 100 / 1000」が表示される

#### Scenario: 経験値のフォーマット (最大レベル)
- **WHEN** カーソルが当たっているキャラクターの level が `job.exp_table.size() + 1` 以上である
- **THEN** 右ペインに「EXP: <現在値> (MAX)」の形式で表示される（`/ 次レベル必要値` は表示しない）

#### Scenario: 基礎ステータスの表示
- **WHEN** 右ペインが描画される
- **THEN** STR, INT, PIE, VIT, AGI, LUC の 6 項目の値が表示される（並びはこの順序）

#### Scenario: 装備 6 スロットの表示
- **WHEN** 右ペインが描画される
- **THEN** `Equipment.ALL_SLOTS` の順序で 6 行表示され、各行のラベルは「武器」「鎧」「兜」「盾」「籠手」「装身具」のいずれかである。装備済みアイテムは表示名（鑑定済みなら `Item.item_name`、未鑑定なら `Item.unidentified_name`）が、未装備なら「(なし)」が表示される

#### Scenario: 習得呪文の表示 (日本語名)
- **WHEN** カーソルが当たっているキャラクターの `known_spells` に `"heal"` (display_name = "ヒール") が含まれる
- **THEN** 習得呪文セクションに「ヒール」が表示される

#### Scenario: 習得呪文の表示 (空)
- **WHEN** カーソルが当たっているキャラクターの `known_spells` が空配列である
- **THEN** 習得呪文セクションには「(未習得)」が表示される

### Requirement: カーソル操作で詳細パネルが切り替わる
SHALL: 左ペインのカーソルを ↑/↓ で移動すると、移動完了と同フレーム内で右ペインの詳細表示が新たな選択キャラクターのものに更新される。ラップは `CursorMenu` の既定挙動に従う。

#### Scenario: ↓ キーで次のメンバーへ
- **WHEN** カーソルがリスト先頭メンバー A にあるとき ↓ を押す
- **THEN** カーソルが次のメンバー B に移動し、右ペインの表示が B のものに切り替わる

#### Scenario: ↑ キーで前のメンバーへ
- **WHEN** カーソルがメンバー B にあるとき ↑ を押す
- **THEN** カーソルが前のメンバー A に戻り、右ペインの表示が A のものに切り替わる

### Requirement: ステータス画面からの戻る操作
SHALL: パーティステータス画面で `ui_cancel` action（ESC キーなど）を行うとパーティメニューに戻る。`ui_accept` action は本画面では何も行わない（閲覧専用）。

#### Scenario: ESC キーで戻る
- **WHEN** パーティステータス画面で `ui_cancel` action を発火する
- **THEN** パーティメニューに戻る

#### Scenario: Enter キーは無反応
- **WHEN** パーティステータス画面で `ui_accept` action を発火する
- **THEN** 画面遷移は発生せず、カーソル位置と表示内容も変わらない

### Requirement: EscMenuStatus shows a status line per character

`EscMenuStatus` (the character detail panel under the ESC menu's status sub-flow) SHALL render a one-line summary of the currently selected character's `persistent_statuses` in the right pane. The format SHALL be:

- When `persistent_statuses` is empty: `"状態: 通常"`
- Otherwise: `"状態: " + names.join(", ")` where each `name` is the StatusData's `display_name` (or `String(status_id)` when the lookup fails).

The line SHALL be rendered in the standard status-detail font/style and SHALL be visible without additional navigation.

#### Scenario: Clean character shows 通常
- **WHEN** the ESC menu status panel cursor is on a character with empty `persistent_statuses`
- **THEN** a label SHALL render reading "状態: 通常"

#### Scenario: Single-status character shows its display name
- **WHEN** the cursor is on a character whose `persistent_statuses == [&"poison"]`
- **THEN** a label SHALL render reading "状態: 毒"

#### Scenario: Multi-status character shows comma-separated names
- **WHEN** the cursor is on a character whose `persistent_statuses == [&"poison", &"petrify"]`
- **THEN** a label SHALL render reading "状態: 毒, 石化"
