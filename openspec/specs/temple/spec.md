## Purpose
教会サービス（蘇生・状態異常回復・寄進・祝福など）を規定する。サービス料金、成功／失敗確率、対象キャラクターの状態変化を対象とする。
## Requirements
### Requirement: TempleScreen is a town sub-screen for resurrection
The system SHALL provide a `TempleScreen` (Control) that the player enters from TownScreen by selecting 「教会」. TempleScreen SHALL list every party member and SHALL distinguish living (current_hp > 0) from dead (current_hp <= 0) members visually.

#### Scenario: Entering the temple from town
- **WHEN** the player selects 「教会」 on TownScreen
- **THEN** TempleScreen SHALL be displayed

#### Scenario: Exit returns to town
- **WHEN** the player presses ESC or selects 「出る」 on TempleScreen
- **THEN** TempleScreen SHALL close and TownScreen SHALL be displayed

#### Scenario: Living and dead members are distinguishable
- **WHEN** the party contains both living and dead members
- **THEN** TempleScreen SHALL visually differentiate dead members (e.g., greyed label, status text) from living ones

### Requirement: Resurrection cost is level-proportional
The system SHALL compute the resurrection cost for a dead character as `character.level * TempleScreen.REVIVE_COST_PER_LEVEL`, where `REVIVE_COST_PER_LEVEL` is a named constant (initial value `100`).

#### Scenario: Level 1 character costs 100G
- **WHEN** a character with `level == 1` is selected for resurrection
- **THEN** the displayed cost SHALL be `100` gold

#### Scenario: Level 5 character costs 500G
- **WHEN** a character with `level == 5` is selected for resurrection
- **THEN** the displayed cost SHALL be `500` gold

### Requirement: Resurrection always succeeds in MVP and restores the character to 1 HP
The system SHALL, on successful payment of the resurrection cost, set the target character's `current_hp = 1` (returning the character from dead to barely alive) with 100% success. The MVP SHALL NOT implement resurrection failure, ashes, lost, or any other failure state.

#### Scenario: Successful resurrection
- **WHEN** the party has sufficient gold and the player confirms resurrection of a character with `current_hp == 0`
- **THEN** `Inventory.spend_gold(cost)` SHALL succeed, and the character's `current_hp` SHALL be exactly `1`

#### Scenario: Resurrection does not restore MP
- **WHEN** a resurrection succeeds
- **THEN** the character's `current_mp` SHALL remain at its pre-resurrection value (not restored)

#### Scenario: Success rate is 100% in MVP
- **WHEN** any valid resurrection attempt with sufficient gold is executed
- **THEN** it SHALL always succeed; no random roll SHALL be performed

### Requirement: Resurrection is blocked without sufficient gold
The system SHALL NOT perform resurrection (and SHALL NOT spend any gold) when the party's current gold is less than the computed cost. TempleScreen SHALL display an informational message indicating insufficient funds.

#### Scenario: Insufficient gold blocks resurrection
- **WHEN** the party has 50G and the player attempts to resurrect a character whose cost is 100G
- **THEN** `GameState.inventory.gold` SHALL remain 50, the character's `current_hp` SHALL remain 0, and an "ゴールドが足りません" (or equivalent) message SHALL be displayed

### Requirement: Living characters are not valid resurrection targets
The system SHALL NOT allow the player to select a character with `current_hp > 0` as a resurrection target.

#### Scenario: Living character is skipped
- **WHEN** the player attempts to select a living character on TempleScreen
- **THEN** the selection SHALL be rejected with an "蘇生対象がいません" (or equivalent) message, or the selection cursor SHALL skip living entries

### Requirement: TempleScreen.revive は spend_gold の戻り値だけに依存する
SHALL: `TempleScreen.revive` は `spend_gold(cost)` の戻り値のみで成功/失敗を判定する。`gold < cost` を事前に check して early return する重複ガードは存在しない。

#### Scenario: spend_gold が false ならエラーメッセージを表示する
- **WHEN** ゴールドが不足している状態で revive を実行
- **THEN** `_inventory.spend_gold(cost)` が false を返し、エラーメッセージが表示される

#### Scenario: 旧 gold < cost 重複ガードは存在しない
- **WHEN** `temple_screen.gd:revive` を grep
- **THEN** `if gold < cost: ...` のような事前 check は存在しない(spend_gold の戻り値だけが分岐に使われる)

