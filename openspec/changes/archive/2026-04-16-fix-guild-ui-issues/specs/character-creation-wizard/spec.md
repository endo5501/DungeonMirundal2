## MODIFIED Requirements

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
- **WHEN** the user presses Enter with an empty name field
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
- **WHEN** the user selects "Elf" and presses Enter
- **THEN** Elf SHALL be stored as the chosen race and wizard SHALL advance to step 3

#### Scenario: Step 2 is not skipped
- **WHEN** the user completes step 1 by pressing Enter
- **THEN** step 2 SHALL be displayed with the race list visible
- **AND** no race SHALL be pre-selected or auto-confirmed
