## ADDED Requirements

### Requirement: 各ステップは独立した CharacterCreationStep として実装される
SHALL: キャラクター作成ウィザードの 5 ステップは、それぞれ `CharacterCreationStep` (RefCounted) を継承した独立クラスとして実装される。各ステップクラスは少なくとも `build(content: VBoxContainer, context)` と `handle_input(event: InputEvent, context) -> int` の 2 メソッドを提供する。返却値の int は `CharacterCreationStep.StepTransition` enum (`STAY`, `ADVANCE`, `BACK`, `CANCEL`) のいずれかであること。

#### Scenario: 各ステップは単体でテスト可能
- **WHEN** `NameInputStep.new()` をテスト内でインスタンス化し、`build` と `handle_input` を直接呼び出す
- **THEN** 各ステップは `CharacterCreation` クラス全体をセットアップせずに振る舞いを検証できる

#### Scenario: handle_input は StepTransition を返す
- **WHEN** ステップの `handle_input(event, context)` を呼び出す
- **THEN** 戻り値は `STAY`, `ADVANCE`, `BACK`, `CANCEL` のいずれかである

#### Scenario: build は VBoxContainer に UI を構築する
- **WHEN** ステップの `build(content, context)` を呼び出す
- **THEN** `content` の child として行ラベル等の UI が構築される

### Requirement: CharacterCreation はステップディスパッチャとして動作する
SHALL: `CharacterCreation._build_step_ui` は内部に保持する `_steps: Array[CharacterCreationStep]` から `current_step - 1` のインデックスでステップを取り出し、`step.build(_content, self)` を呼ぶ。`_input_step1`, `_input_step2`, ..., `_input_step5` のような per-step メソッドは存在しない。`_unhandled_input` は `_steps[current_step - 1].handle_input(event, self)` を呼び、戻り値の StepTransition に応じて `advance()` / `go_back()` / `cancel()` をディスパッチする。

#### Scenario: per-step メソッドは存在しない
- **WHEN** `character_creation.gd` を grep で検索
- **THEN** `_input_step1` ... `_input_step5` および `_build_step1` ... `_build_step5` のいずれの関数も存在しない

#### Scenario: ディスパッチャがステップに input を委譲する
- **WHEN** `_unhandled_input` が呼ばれる
- **THEN** `_steps[current_step - 1].handle_input(event, self)` が呼ばれ、その戻り値で次の遷移が決まる

#### Scenario: STAY 戻り値は何もしない
- **WHEN** ステップが `STAY` を返す
- **THEN** ディスパッチャは何もせず、step UI も再構築しない

#### Scenario: ADVANCE で次のステップに進む
- **WHEN** ステップが `ADVANCE` を返す
- **THEN** ディスパッチャは `advance()` を呼び、次のステップが build される

#### Scenario: BACK で前のステップに戻る
- **WHEN** ステップが `BACK` を返す
- **THEN** ディスパッチャは `go_back()` を呼び、前のステップが build される

#### Scenario: CANCEL でウィザードが終了する
- **WHEN** ステップが `CANCEL` を返す
- **THEN** ディスパッチャは `cancel()` を呼び、`back_requested` シグナルが発行される

### Requirement: ステップ切り替え直後の同フレーム入力は無視される
SHALL: ステップが切り替わった直後の同一フレームで届く `_unhandled_input` は無視される(既存挙動の維持)。これは前ステップの ui_accept がイベントとして次ステップに到達してしまうのを防ぐためのガードである。

#### Scenario: ステップ切替直後の input は無視される
- **WHEN** Step 2 で ui_accept を押して Step 3 に遷移し、同フレーム内で別の input が届く
- **THEN** Step 3 の `handle_input` は呼ばれない(次フレーム以降から有効)
