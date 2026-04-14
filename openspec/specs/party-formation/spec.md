## ADDED Requirements

### Requirement: Party formation displays party grid and waiting list
The party formation screen SHALL display the current party composition (front row 3 slots, back row 3 slots) and a list of unassigned (waiting) characters.

#### Scenario: Display party grid with members
- **WHEN** the party formation screen is shown with 2 characters assigned (front row positions 0 and 1)
- **THEN** front row slots 0 and 1 SHALL show character names, and all other slots SHALL show as empty

#### Scenario: Display waiting characters
- **WHEN** the party formation screen is shown with 3 unassigned characters
- **THEN** the waiting list SHALL display all 3 characters with name, level, race, and job

#### Scenario: Empty state
- **WHEN** the party formation screen is shown with no characters registered
- **THEN** all party slots SHALL be empty and the waiting list SHALL be empty

### Requirement: Party formation allows adding characters to slots
When an empty party slot is selected, the user SHALL be able to choose a character from the waiting list to assign to that slot.

#### Scenario: Add character to empty slot
- **WHEN** the user selects an empty slot and chooses a waiting character
- **THEN** Guild.assign_to_party() SHALL be called and the slot SHALL display the character

#### Scenario: No action on empty slot when no waiting characters
- **WHEN** the user selects an empty slot but no characters are waiting
- **THEN** no assignment action SHALL be available

### Requirement: Party formation allows removing characters from slots
When an occupied party slot is selected, the user SHALL be able to remove the character, returning them to the waiting list.

#### Scenario: Remove character from slot
- **WHEN** the user selects an occupied slot and confirms removal
- **THEN** Guild.remove_from_party() SHALL be called and the character SHALL appear in the waiting list

#### Scenario: Slot becomes empty after removal
- **WHEN** a character is removed from front row position 1
- **THEN** front row position 1 SHALL display as empty

### Requirement: Party formation supports party name editing
The party name SHALL be displayed at the top of the screen. Selecting it SHALL allow the user to edit the name inline.

#### Scenario: Display party name
- **WHEN** the party formation screen is shown
- **THEN** the current party name SHALL be displayed at the top

#### Scenario: Edit party name
- **WHEN** the user selects the party name and enters "勇者たち"
- **THEN** the party name SHALL be updated to "勇者たち"

### Requirement: Party formation allows returning to menu
The party formation screen SHALL provide a "戻る" option to return to the guild menu.

#### Scenario: Return to menu
- **WHEN** the user selects "戻る"
- **THEN** the back_requested signal SHALL be emitted and the guild menu SHALL be displayed
