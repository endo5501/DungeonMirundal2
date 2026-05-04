## MODIFIED Requirements

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

## ADDED Requirements

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
