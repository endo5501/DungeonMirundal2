## Context

`character_creation.gd:62-301` の構造:
- `_build_step_ui()` が `match current_step:` で `_build_step1` 〜 `_build_step5` を呼ぶ
- `_unhandled_input()` が `match current_step:` で `_input_step1` 〜 `_input_step5` を呼ぶ
- 各 `_input_stepN` は ui_up/ui_down/ui_accept/ui_cancel/ui_back のボイラープレートを微妙に違う形で書いている
- 各 `_build_stepN` は `_step_label.text = "Step %d/%d - ..."` を冒頭で設定し、その後コンテンツを構築

ボイラープレートの違い:
- step1: 名前入力 (LineEdit、ui_accept で focus、ui_cancel でキャンセル)
- step2: 種族選択 (リストカーソル、ui_accept で確定+advance、ui_back で戻り、ui_cancel でキャンセル)
- step3: ボーナス配分 (リストカーソル + ui_left/ui_right で増減 + KEY_R で振り直し)
- step4: 職業選択 (リストカーソル + 不適格職業の disabled 判定)
- step5: 確認 (ui_accept で confirm_creation、ui_back で戻り、ui_cancel でキャンセル)

step3 のみ ui_left/ui_right と KEY_R が独自で、MenuController.route の 4 アクションでは収まらない。
他は MenuController + α で書ける。

## Goals / Non-Goals

**Goals:**
- 5 ステップを宣言的に記述する `CharacterCreationStep` 抽象を導入
- `character_creation.gd` の `_input_step1〜5` / `_build_step1〜5` を撤廃
- 各ステップを独立してテスト可能にする
- 外部挙動(API シグネチャ・シグナル発行・既存テスト)を完全に維持
- step3 の独自入力(ui_left/ui_right + R キー)も、Step 抽象の中で素直に書ける形にする

**Non-Goals:**
- ステップの追加・削除・並び替え(本 change はリファクタのみ)
- 名前入力 LineEdit を別実装にする
- ボーナスポイント生成器(`BonusPointGenerator`)の変更
- ステップ間の状態管理を別オブジェクトに完全分離(`CharacterCreationContext` を導入するが、状態は引き続き CharacterCreation が保持する形でも可)

## Decisions

### Decision 1: Step 抽象は RefCounted、build / handle_input の 2 メソッド

**選択**:
```gdscript
# character_creation_step.gd
class_name CharacterCreationStep
extends RefCounted

enum StepTransition { STAY, ADVANCE, BACK, CANCEL }

func get_title() -> String:
    return ""

# build the step UI inside `content` (VBoxContainer).
# `context` provides accessors to character creation state.
func build(content: VBoxContainer, context: CharacterCreationContext) -> void:
    pass

# returns StepTransition or-ed with consume flag (true if event was handled)
# implementations call MenuController.route or write custom routing
# Returns the transition decision; caller is responsible for set_input_as_handled.
func handle_input(event: InputEvent, context: CharacterCreationContext) -> int:
    return StepTransition.STAY
```

**理由**:
- 2 つのメソッドだけで step を表現できる(build と input)
- `get_title()` で step ラベルを返す形にすれば、ディスパッチャ側で `_step_label.text` を設定できる
- StepTransition enum で次のアクションを Caller に伝える(STAY = 何もしない、ADVANCE = 次へ、BACK = 前へ、CANCEL = ウィザード終了)

### Decision 2: CharacterCreationContext で状態を共有

**選択**:
```gdscript
# 直接 character_creation.gd を context として渡しても良い(self を context と見做す)
# が、専用の RefCounted を作って必要なフィールドだけ公開する方がテスタブル。
class_name CharacterCreationContext
extends RefCounted

var name_input: String
var selected_race_index: int
var selected_job_index: int
var bonus_total: int
var allocation: Dictionary
var races: Array[RaceData]
var jobs: Array[JobData]
var bonus_generator: BonusPointGenerator
var current_step: int

# Mutators called by steps
func set_name(s: String): name_input = s
func set_selected_race(i: int): selected_race_index = i
# ... (etc.)
```

**実装方針**: シンプルさ優先で **`character_creation.gd` 自身を `CharacterCreationContext` として step に渡す**(GDScript の duck typing で十分)。専用クラスは作らない。

**理由**:
- 状態を 2 重管理しないため、Context 専用クラスを作らずに `CharacterCreation` 自身を渡す
- 既存のメソッド(`select_race`, `select_job`, `increment_stat`, etc.)はそのまま使える
- テストでは `CharacterCreation.new()` をモックや subclass として使える

### Decision 3: step3 のカスタム入力は handle_input で直接書く

**選択**: `BonusAllocationStep.handle_input` は MenuController を使わず、ui_up/ui_down/ui_left/ui_right/ui_accept/ui_back/ui_cancel/KEY_R を直接処理する。

**理由**:
- step3 は他の step と入力パターンが違うので、共通化は不可能(してもボイラープレートは増えない)
- step3 だけ独自 input を持つことを明示することで、可読性が上がる

### Decision 4: ステップは「インスタンス化して保持」

**選択**: `character_creation.gd` の `_steps: Array[CharacterCreationStep]` フィールドに 5 個のインスタンスを `_init` で生成して保持する。`_build_step_ui` は `_steps[current_step - 1].build(_content, self)` を呼ぶだけ。

**理由**:
- 5 個のインスタンスを使い回すことで、step の状態を再構築せずに済む(step2 で選択中の cursor_index を step2 が保持できる)
- ただし、現在の実装では `_cursor_index` が CharacterCreation のフィールドだったので、その互換性を維持するため、step は cursor_index も `context` 経由でアクセス・更新する形にする(step が独自にカウンタを持たない)

### Decision 5: テストは「ステップ単体」と「ディスパッチャ統合」の 2 層

**選択**:
- 各 step の単体テスト: `tests/guild_scene/steps/test_<step>_step.gd` で build と handle_input を直接呼んで検証
- ディスパッチャ統合テスト: 既存の `tests/guild_scene/test_character_creation.gd` を流用(外部挙動が変わらないので無修正で通るはず)

**理由**:
- ステップ単体は MenuController + step ロジックの組み合わせ単位でテストできる
- 統合は既存テストでカバー済み(リファクタの安全網)

### Decision 6: Step ファイルの配置

**選択**: `src/guild_scene/steps/<step>_step.gd` というディレクトリを切る。`character_creation.gd` と同じディレクトリには `character_creation_step.gd`(基底クラス)を置く。

**理由**:
- 5 個のステップファイルでディレクトリが膨らむので、サブディレクトリに分ける
- 基底クラスは「親ファイルの隣」に置くことで関係性が明示される
- Godot の class_name は flat namespace なので、ディレクトリ構造はディスクの整理だけ

## Risks / Trade-offs

- **[step1 の LineEdit focus 競合]** 名前入力は LineEdit に focus が当たっている時、ui_accept がそれぞれ異なる挙動(focus 移動 vs フォーム submit)を取る → 既存実装の `_input_step1` の `not _name_edit.has_focus()` ガードを `NameInputStep.handle_input` 内に移植する。
- **[既存テストの assertions に依存]** `test_character_creation.gd` がプライベートフィールド(`_cursor_index` 等)を直接読んでいないことを確認 → 読んでいたら、後方互換のためフィールドを残すか、テスト側を更新する。
- **[step 切替時の `_cursor_index` 同期]** 現状は step 切替で `_cursor_index = 0` にリセット → step.build() の冒頭で context.set_cursor_index(0) を呼ぶ形に統一する。
- **[`_step_changed_frame` のフレームスキップ]** 現状 step 切替直後の同フレームの input を弾いている → ディスパッチャ側で同じガードを維持する。
- **[StepTransition enum の値]** STAY = 0 にすると false-y になり、bool に誤変換するリスク → enum で受けて明示的に比較する。
- **[InitialEquipment.grant の呼び出し]** confirm_creation が `InitialEquipment.grant` を呼ぶ → ConfirmationStep の handle_input で ADVANCE を返した時に CharacterCreation 側で confirm_creation を呼ぶ形に変える(step は character を作るが register と grant は CharacterCreation 側で)。
