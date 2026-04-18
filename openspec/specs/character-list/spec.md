## Purpose
ギルドに登録済みのキャラクター一覧画面の表示項目と操作を規定する。名前・職業・レベル・基本能力値の表示と、待機キャラクターの削除フローを対象とする。

## Requirements

### Requirement: Character list displays all registered characters
The character list screen SHALL display all characters registered with the Guild, showing name, level, race, job, and current assignment status (party or waiting).

#### Scenario: Display all characters
- **WHEN** the character list screen is shown with 5 registered characters (3 in party, 2 waiting)
- **THEN** all 5 characters SHALL be listed with name, level, race name, job name, and status

#### Scenario: Party characters show position
- **WHEN** a character is assigned to front row position 0
- **THEN** the character's status SHALL indicate "パーティ" (party membership)

#### Scenario: Waiting characters show status
- **WHEN** a character is not assigned to any party slot
- **THEN** the character's status SHALL indicate "待機中" (waiting)

#### Scenario: Empty list
- **WHEN** no characters are registered with the Guild
- **THEN** the list SHALL be empty (or display a message indicating no characters exist)

### Requirement: Character list shows detailed stats
When a character is selected and "詳細" is chosen, the screen SHALL display the character's full stats.

#### Scenario: Detail view shows all information
- **WHEN** the user selects a character and chooses "詳細"
- **THEN** the detail view SHALL show: name, race, job, level, HP (current/max), MP (current/max), STR, INT, PIE, VIT, AGI, LUC, and assignment status

#### Scenario: Return from detail view
- **WHEN** the user presses "戻る" on the detail view
- **THEN** the character list SHALL be displayed again

### Requirement: Character list allows deleting waiting characters
The character list SHALL allow deleting characters that are NOT currently in the party. A confirmation dialog SHALL be shown before deletion.

#### Scenario: Delete waiting character with confirmation
- **WHEN** the user selects a waiting character, chooses "削除", and confirms "はい"
- **THEN** Guild.remove() SHALL be called and the character SHALL no longer appear in the list

#### Scenario: Cancel delete
- **WHEN** the user selects a waiting character, chooses "削除", and selects "いいえ"
- **THEN** the character SHALL remain in the list unchanged

#### Scenario: Cannot delete party character
- **WHEN** the user selects a character currently in the party and chooses "削除"
- **THEN** the deletion SHALL be rejected (button disabled or error message shown)

### Requirement: Character list allows returning to menu
The character list screen SHALL provide a "戻る" option to return to the guild menu.

#### Scenario: Return to menu
- **WHEN** the user selects "戻る"
- **THEN** the back_requested signal SHALL be emitted and the guild menu SHALL be displayed
