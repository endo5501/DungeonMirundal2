## ADDED Requirements

### Requirement: START tile triggers return dialog
DungeonScreen SHALL detect when the player moves onto the START tile and display a confirmation dialog asking "地上に戻りますか？" with options "はい" and "いいえ".

#### Scenario: Moving onto START tile shows dialog
- **WHEN** the player moves onto the START tile
- **THEN** a confirmation dialog SHALL be displayed with text "地上に戻りますか？"

#### Scenario: Dialog has yes and no options
- **WHEN** the return confirmation dialog is displayed
- **THEN** it SHALL show "はい" and "いいえ" as selectable options

### Requirement: Confirming return emits signal
DungeonScreen SHALL emit a `return_to_town` signal when the player selects "はい" on the return confirmation dialog.

#### Scenario: Select yes to return
- **WHEN** the player selects "はい" on the return dialog
- **THEN** the `return_to_town` signal SHALL be emitted

### Requirement: Canceling return continues exploration
DungeonScreen SHALL close the return dialog and resume normal exploration when the player selects "いいえ".

#### Scenario: Select no to continue
- **WHEN** the player selects "いいえ" on the return dialog
- **THEN** the dialog SHALL close and the player SHALL remain on the START tile with normal controls restored

### Requirement: Dialog pauses exploration input
While the return confirmation dialog is displayed, DungeonScreen SHALL NOT process movement or turn input.

#### Scenario: Movement blocked during dialog
- **WHEN** the return dialog is displayed and the player presses a movement key
- **THEN** the player SHALL NOT move

### Requirement: Dialog appears each time START tile is entered
The return dialog SHALL appear every time the player moves onto the START tile, not just the first time.

#### Scenario: Repeated visits show dialog
- **WHEN** the player moves onto the START tile, selects "いいえ", moves away, and returns to the START tile
- **THEN** the return dialog SHALL appear again
