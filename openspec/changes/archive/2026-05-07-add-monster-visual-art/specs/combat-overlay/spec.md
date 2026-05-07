## MODIFIED Requirements

### Requirement: CombatOverlay renders a fixed Wizardry-style layout

The system SHALL display, while a battle is active, a fixed layout consisting of an enemy presentation area, a right-side battle UI column, and the persistent bottom party HUD. The enemy presentation area SHALL show monster species with per-species remaining counts in a framed `ENEMY` list window and monster visuals in a separate graphics area. When a living monster's MonsterData has battle art, the graphics area SHALL render that monster-specific image. When battle art is missing, the graphics area SHALL render the existing dummy monster image or procedural placeholder for that monster. The right-side battle UI column SHALL contain framed CombatLog and active command or selection windows. During battle, the normal dungeon minimap SHALL be hidden so the right-side battle UI can use the full column without overlapping itself or the party HUD. The CombatLog window SHALL be vertically compact enough to match its title plus eight retained visible log lines, leaving the active command or selection window to start higher in the same column. The CombatLog SHALL split multi-line action text into retained visible lines before enforcing its line cap. The CombatLog SHALL clip its contents to its own window so repeated battles cannot draw log text over command windows. The active command or selection window SHALL keep a clear vertical gap above the bottom party HUD. The bottom party HUD SHALL remain owned by PartyHud/PartyDisplay rather than by CombatOverlay.

The CommandMenu options for a living PartyCombatant SHALL preserve the existing localized command order and magic-school filtering: Attack, Defend, mage-school Cast only when the actor's job has `mage_school == true`, priest-school Cast only when the actor's job has `priest_school == true`, Item, and Escape. For a non-magic actor, magic entries SHALL be omitted entirely rather than greyed out. For a Bishop, both magic entries SHALL appear between Defend and Item. Item and Escape SHALL remain the last two entries regardless of magic visibility.

#### Scenario: MonsterPanel shows species and remaining count
- **WHEN** the monster party contains 2 live slimes and 1 live goblin
- **THEN** the MonsterPanel SHALL display text including both species names with their remaining counts

#### Scenario: MonsterPanel updates as monsters die
- **WHEN** one slime dies during resolution
- **THEN** after the log advances, the MonsterPanel SHALL show the reduced count for slimes

#### Scenario: MonsterPanel does not show per-individual HP
- **WHEN** any monster is alive
- **THEN** the MonsterPanel SHALL NOT show numeric HP for individual monsters

#### Scenario: MonsterPanel shows monster-specific enemy visuals
- **WHEN** the monster party contains one or more living monsters whose MonsterData has `battle_texture` and the battle UI is refreshed
- **THEN** the enemy presentation area SHALL render at least one monster-specific texture representing the living enemies

#### Scenario: MonsterPanel falls back to dummy enemy visuals
- **WHEN** the monster party contains a living monster whose MonsterData has no `battle_texture` and the battle UI is refreshed
- **THEN** the enemy presentation area SHALL render a dummy monster image or procedural placeholder for that living enemy

#### Scenario: MonsterPanel uses an ENEMY list window
- **WHEN** the monster party contains one or more living monsters and the battle UI is refreshed
- **THEN** the enemy count list SHALL be shown in a framed window titled `"ENEMY"` and the window SHALL NOT span the enemy graphics area

#### Scenario: Monster visuals sit lower with stable baseline
- **WHEN** the monster party contains multiple living monsters
- **THEN** all rendered monster visuals, whether texture-backed or dummy fallback, SHALL be positioned lower in the battle area and SHALL share a stable baseline

#### Scenario: CombatLog is placed in the right-side battle column
- **WHEN** CombatOverlay builds its combat UI
- **THEN** the CombatLog SHALL be anchored in the right-side battle UI column and SHALL NOT occupy the center-left enemy presentation area

#### Scenario: Dungeon minimap is hidden during combat
- **WHEN** a battle becomes active
- **THEN** the normal dungeon minimap SHALL be hidden
- **AND** when the battle is no longer active, the minimap visibility SHALL be restored to its previous state

#### Scenario: CombatLog starts at the top of the right-side battle column
- **WHEN** CombatOverlay builds its combat UI for battle
- **THEN** the CombatLog SHALL NOT reserve vertical space for the minimap

#### Scenario: CombatLog uses the available window height
- **WHEN** more than four combat log lines are appended
- **THEN** the CombatLog SHALL retain exactly eight recent lines to fit the compact battle log window without overlapping command windows

#### Scenario: Multi-line actions count as visible log lines
- **WHEN** a spell or other action appends text containing multiple newline-separated display rows
- **THEN** the CombatLog SHALL split that text into separate retained visible lines
- **AND** the eight-line cap SHALL be applied to visible lines rather than to action entries

#### Scenario: CombatLog is compact and command windows start higher
- **WHEN** CombatOverlay shows the right-side CombatLog and active command window
- **THEN** the CombatLog SHALL occupy only the upper compact portion of the right-side column
- **AND** the active command window SHALL begin close below the CombatLog instead of leaving a large unused vertical gap
- **AND** the active command window SHALL end high enough to avoid overlapping the bottom party HUD

#### Scenario: CombatLog content stays inside its window
- **WHEN** repeated battles append enough log lines to fill the CombatLog
- **THEN** the CombatLog SHALL clip rendered line content to its own framed window

#### Scenario: Command and selection panels are placed in the right-side battle column
- **WHEN** CombatOverlay shows the CommandMenu, CombatTargetSelector, CombatSpellSelector, or combat ItemUseFlow panel
- **THEN** the active command or selection panel SHALL be anchored in the right-side battle UI column

#### Scenario: CombatLog and command windows do not overlap
- **WHEN** CombatOverlay shows the CombatLog and the active command or selection window
- **THEN** their vertical layout ranges SHALL be separated and the command window SHALL stay above the bottom party HUD area

#### Scenario: Right-side battle UI panels are framed
- **WHEN** CombatOverlay shows the CombatLog, CommandMenu, CombatTargetSelector, CombatSpellSelector, or combat ItemUseFlow panel
- **THEN** the visible panel SHALL render as a framed window

#### Scenario: Party HUD remains external to CombatOverlay
- **WHEN** a battle is active
- **THEN** CombatOverlay SHALL NOT create a separate PartyStatusPanel, and live party status SHALL continue to be displayed by PartyHud/PartyDisplay

#### Scenario: CommandMenu for Fighter omits magic entries
- **WHEN** the CommandMenu is shown for a living Fighter
- **THEN** the selectable options SHALL be Attack, Defend, Item, and Escape in that order, and SHALL NOT include either magic entry

#### Scenario: CommandMenu for Mage shows mage magic
- **WHEN** the CommandMenu is shown for a living Mage
- **THEN** the selectable options SHALL include the mage magic entry between Defend and Item and SHALL NOT include the priest magic entry

#### Scenario: CommandMenu for Priest shows priest magic
- **WHEN** the CommandMenu is shown for a living Priest
- **THEN** the selectable options SHALL include the priest magic entry between Defend and Item and SHALL NOT include the mage magic entry

#### Scenario: CommandMenu for Bishop shows both magic entries
- **WHEN** the CommandMenu is shown for a living Bishop
- **THEN** the selectable options SHALL be Attack, Defend, mage magic, priest magic, Item, and Escape in that order

#### Scenario: Item command remains present even when inventory has no consumables
- **WHEN** the CommandMenu is shown and `GameState.inventory` contains zero consumable ItemInstances
- **THEN** the Item command SHALL still be listed as a selectable option and its position SHALL NOT shift
