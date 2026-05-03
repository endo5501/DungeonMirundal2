## Purpose
ギルドメニューから起動されるキャラクター作成ウィザードの画面構成と遷移を規定する。名前入力・種族選択・職業選択・能力値確認の各ステップの UI と入力要件を対象とする。
## Requirements
### Requirement: Character creation wizard has 5 sequential steps
The character creation wizard SHALL guide the user through 5 steps in order: name input, race selection, bonus point allocation, job selection, confirmation. Each step transition SHALL complete fully before the next step accepts input.

#### Scenario: Steps progress in order
- **WHEN** the user completes step 1 (name input) and presses Enter
- **THEN** step 2 (race selection) SHALL be displayed and SHALL accept user input

#### Scenario: Steps are sequential
- **WHEN** the user is on step 3
- **THEN** step 4 content SHALL NOT be accessible until step 3 is completed

#### Scenario: Step transition does not auto-advance
- **WHEN** the user presses Enter to advance from step 1 to step 2
- **THEN** step 2 SHALL be displayed and SHALL NOT be automatically advanced by the same key event
- **AND** the user SHALL be able to browse and select a race

### Requirement: Step 1 accepts character name input
Step 1 SHALL display a text input field for the character name. The name MUST NOT be empty to proceed. The step content SHALL be centered on the screen.

#### Scenario: Valid name input
- **WHEN** the user enters "Hero" and presses Enter
- **THEN** the wizard SHALL advance to step 2 (race selection)
- **AND** step 2 SHALL wait for user input before proceeding

#### Scenario: Empty name rejected
- **WHEN** the user presses next with an empty name field
- **THEN** the wizard SHALL NOT advance and SHALL indicate the name is required

### Requirement: Step 2 displays race selection with stats
Step 2 SHALL display all available races as a selectable list. Each race SHALL show its total stat values (STR, INT, PIE, VIT, AGI, LUC). The step content SHALL be centered on the screen.

#### Scenario: All races displayed
- **WHEN** step 2 is shown
- **THEN** all races from DataLoader SHALL be listed with their stat values

#### Scenario: Race selection shows stats
- **WHEN** step 2 is shown with Human race (STR:8, INT:8, PIE:8, VIT:8, AGI:8, LUC:8)
- **THEN** Human entry SHALL display all 6 stat values

#### Scenario: Select a race
- **WHEN** the user selects "Elf" and presses next
- **THEN** Elf SHALL be stored as the chosen race and wizard SHALL advance to step 3

#### Scenario: Step 2 is not skipped
- **WHEN** the user completes step 1 by pressing Enter
- **THEN** step 2 SHALL be displayed with the race list visible
- **AND** no race SHALL be pre-selected or auto-confirmed

### Requirement: Step 3 allocates bonus points with +/- controls
Step 3 SHALL generate bonus points via BonusPointGenerator, display remaining points, and provide +/- buttons for each stat. The displayed value SHALL be the total (race base + allocated bonus).

#### Scenario: Initial state shows bonus points and base stats
- **WHEN** step 3 is entered with Human race and 7 bonus points generated
- **THEN** remaining points SHALL show 7 and each stat SHALL display the race base value (8 for Human)

#### Scenario: Increment a stat
- **WHEN** the user presses + on STR with 7 remaining points
- **THEN** STR display SHALL increase by 1 and remaining points SHALL decrease to 6

#### Scenario: Decrement a stat
- **WHEN** the user presses - on STR with 1 point allocated to STR
- **THEN** STR display SHALL decrease by 1 and remaining points SHALL increase by 1

#### Scenario: Cannot decrement below zero allocation
- **WHEN** the user presses - on STR with 0 points allocated to STR
- **THEN** STR SHALL remain unchanged and remaining points SHALL remain unchanged

#### Scenario: Cannot increment with zero remaining
- **WHEN** the user presses + on any stat with 0 remaining points
- **THEN** the stat SHALL remain unchanged

#### Scenario: Must allocate all points to proceed
- **WHEN** the user presses next with remaining points > 0
- **THEN** the wizard SHALL NOT advance

#### Scenario: Advance when all points allocated
- **WHEN** the user presses next with remaining points = 0
- **THEN** the wizard SHALL advance to step 4

### Requirement: Step 3 provides bonus point reroll
Step 3 SHALL provide a "振り直し" (reroll) button that generates a new bonus point total and resets all allocations.

#### Scenario: Reroll resets allocation
- **WHEN** the user has allocated 3 points to STR and presses reroll
- **THEN** all allocations SHALL reset to 0 and a new bonus point total SHALL be generated

### Requirement: Returning to step 2 from step 3 resets allocation
When the user navigates back from step 3 to step 2, all bonus point allocations SHALL be discarded.

#### Scenario: Back from step 3 resets
- **WHEN** the user is on step 3 with allocations made and presses back
- **THEN** step 2 SHALL be displayed and all allocations SHALL be discarded

#### Scenario: Re-entering step 3 generates new bonus
- **WHEN** the user returns to step 2 and then advances to step 3 again
- **THEN** a new bonus point total SHALL be generated

### Requirement: Step 4 displays jobs with qualification status
Step 4 SHALL display all jobs. Jobs that the character qualifies for (based on current stats) SHALL be selectable. Jobs that the character does not qualify for SHALL be displayed as disabled/greyed out.

#### Scenario: Qualified jobs are selectable
- **WHEN** step 4 is shown and the character's stats meet Fighter requirements
- **THEN** Fighter SHALL be displayed as selectable

#### Scenario: Unqualified jobs are greyed out
- **WHEN** step 4 is shown and the character's stats do NOT meet Ninja requirements
- **THEN** Ninja SHALL be displayed as disabled and SHALL NOT be selectable

#### Scenario: Job selection advances to confirmation
- **WHEN** the user selects a qualified job and presses confirm
- **THEN** the wizard SHALL advance to step 5

### Requirement: Step 5 shows confirmation and creates character
Step 5 SHALL display a summary of the character (name, race, job, level, HP, MP, all stats) and allow the user to confirm creation.

#### Scenario: Confirmation displays all info
- **WHEN** step 5 is shown for "Hero", Human, Fighter with STR:11 INT:10 PIE:10 VIT:8 AGI:8 LUC:8
- **THEN** all values SHALL be displayed including calculated HP and MP

#### Scenario: Confirm creates character and registers with guild
- **WHEN** the user presses "作成" on the confirmation screen
- **THEN** Character.create() SHALL be called with the chosen parameters and the resulting character SHALL be registered with Guild

#### Scenario: After creation returns to guild menu
- **WHEN** character creation completes successfully
- **THEN** the wizard SHALL emit back_requested and the guild menu SHALL be displayed

### Requirement: Cancel exits wizard at any step
The wizard SHALL provide a "やめる" (cancel) option at every step that returns to the guild menu without creating a character.

#### Scenario: Cancel from any step
- **WHEN** the user presses "やめる" on any step
- **THEN** no character SHALL be created and the guild menu SHALL be displayed

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

