## ADDED Requirements

### Requirement: CombatCommandMenu disables Attack when no reachable target exists

`CombatCommandMenu` SHALL, when building command rows for a `PartyCombatant`, evaluate whether at least one living monster is reachable for the actor's current weapon. The check SHALL use `TurnEngine.can_reach(actor, target)` against every living monster.

When no reachable target exists, the "攻撃" row SHALL render in a disabled state with a "(届かない)" suffix or equivalent visual indicator (gray text). Pressing Enter on the disabled "攻撃" row SHALL be a no-op (the menu does not advance to target selection or submit a command). Other rows (Defend / Cast / Item / Escape) SHALL remain enabled.

The disable check SHALL evaluate at command-menu build time only. Mid-turn changes (e.g., FRONT-row teammate dies during the same turn) do NOT mutate the menu, but in practice command menus are built before any turn resolution begins, so this gap is invisible to the player.

The Attack row SHALL NOT be omitted entirely (in contrast to magic-school omission). The row stays in its position and the menu's row count is preserved.

#### Scenario: Front-row Fighter with sword has Attack enabled
- **WHEN** the command menu is built for a FRONT-row Fighter equipped with a MELEE weapon, and at least one monster has `effective_row == FRONT`
- **THEN** the "攻撃" row SHALL be enabled

#### Scenario: Back-row Mage with no weapon has Attack disabled
- **WHEN** the command menu is built for a BACK-row Mage with no weapon equipped (fist = MELEE) while at least one FRONT-row teammate is alive
- **THEN** the "攻撃" row SHALL be disabled and SHALL render with a "(届かない)" suffix or equivalent gray treatment
- **AND** pressing Enter on the disabled row SHALL NOT advance the menu or submit a command

#### Scenario: Back-row archer (RANGED weapon) has Attack enabled
- **WHEN** the command menu is built for a BACK-row character equipped with a RANGED weapon and any monster is alive
- **THEN** the "攻撃" row SHALL be enabled

#### Scenario: Front-row Fighter with sword vs all-back monsters has Attack enabled (after promotion)
- **WHEN** the command menu is built and every monster's `original_row == BACK` (so every monster's `effective_row == FRONT` via promotion since the monster side has no FRONT)
- **THEN** the "攻撃" row SHALL be enabled

#### Scenario: Disabled Attack row preserves its slot position
- **WHEN** the "攻撃" row is disabled
- **THEN** the menu's other rows (Defend / Cast / Item / Escape) SHALL keep their pre-existing positions; the row SHALL NOT be removed from the list

### Requirement: CombatTargetSelector grays out unreachable targets

When `CombatTargetSelector` is shown for an `Attack` command, the selector SHALL evaluate `TurnEngine.can_reach(actor, target)` for each living monster candidate. Unreachable monsters SHALL render in a disabled / gray style and SHALL NOT be selectable: navigating onto them with the cursor MAY be allowed (so the player can see they exist), but pressing Enter on a disabled row SHALL be a no-op (the selector does not submit a target).

The reach check SHALL be re-evaluated when the selector is shown; mid-turn deaths from prior turn resolution are reflected via the standard `effective_row` computation.

When the entire enemy list is unreachable (defensive condition; UI should have prevented this via the CommandMenu disable above), the selector SHALL display an empty-state message and `ui_cancel` SHALL return to the command menu.

This requirement applies only to physical Attack target selection. Spell target selection (CombatSpellSelector / SPELL_TARGET phase) SHALL NOT apply reach restrictions — magic remains unbounded by row.

#### Scenario: MELEE attacker sees back-row monster as gray
- **WHEN** the target selector is opened for a FRONT-row MELEE attacker against a monster party that contains a FRONT slime and a BACK witch (both alive)
- **THEN** the slime row SHALL be selectable and the witch row SHALL be displayed in a disabled / gray style

#### Scenario: Disabled target row blocks Enter
- **WHEN** the cursor is on a disabled (unreachable) target row and Enter is pressed
- **THEN** no target SHALL be submitted; the selector SHALL stay open

#### Scenario: RANGED attacker sees all monsters selectable
- **WHEN** the target selector is opened for a RANGED attacker against a mixed-row monster party
- **THEN** every living monster SHALL be selectable

#### Scenario: Spell target selector ignores reach
- **WHEN** the spell target selector (not the attack target selector) is opened for any caster
- **THEN** every living monster SHALL be selectable regardless of caster row or weapon

### Requirement: CombatOverlay renders monsters with row-based depth

`CombatOverlay`'s enemy presentation area SHALL position monster visuals based on each `MonsterCombatant`'s `original_row`:

- FRONT-row monsters SHALL be rendered at the existing battle-area baseline with `scale = 1.0` and the higher (frontmost) `z_index` so that they are drawn over any back-row monsters that visually overlap them.
- BACK-row monsters SHALL be rendered with a vertical offset above the front-row baseline (drawn higher on screen, indicating depth), with `scale = 0.85` (smaller, indicating distance), and a lower `z_index` than the front row (so that overlap places them behind the front).
- Within each row, monster visuals SHALL be laid out horizontally with even spacing so that up to 5 FRONT and up to 5 BACK monsters fit in the enemy presentation area.

The exact pixel offset and exact spacing values SHALL be chosen at implementation time based on the available enemy area dimensions; the spec only mandates the relative placement (BACK higher / smaller / behind, FRONT at baseline / full size / front).

When the back row is empty (no BACK-row living monsters), the front row SHALL render in its existing position. When the front row is empty (all FRONT dead, BACK promoted), back-row monsters SHALL still be rendered at their back-row visual position — the visual position SHALL be driven by `original_row`, not by `effective_row`. Promotion is a combat-rule concept, not a visual one.

#### Scenario: FRONT monster renders at baseline with full scale
- **WHEN** a battle is rendered with a FRONT-row monster present
- **THEN** that monster's visual SHALL render at the existing baseline with `scale == 1.0`

#### Scenario: BACK monster renders above and smaller than FRONT
- **WHEN** a battle is rendered with both a FRONT-row and a BACK-row monster present
- **THEN** the BACK-row monster's visual SHALL be positioned higher on screen than the FRONT-row monster, SHALL be drawn at `scale == 0.85`, and SHALL have a lower `z_index` than the FRONT-row monster

#### Scenario: BACK monster stays at back position even after promotion
- **WHEN** all FRONT-row monsters are dead and only BACK-row monsters survive
- **THEN** the surviving BACK-row monsters SHALL still render at the back-row visual position (offset upward, scale 0.85)

#### Scenario: Up to 5 monsters per row fit horizontally
- **WHEN** a battle starts with 5 FRONT-row monsters
- **THEN** all 5 visuals SHALL be laid out horizontally within the enemy presentation area without clipping each other

### Requirement: CombatLog renders the wait action type

`CombatLog` SHALL render `TurnReport` entries of `type == "wait"` as a single line: `"<actor_name> は様子を見ている"`. The line SHALL be subject to the same retention / line-cap rules as other action types.

#### Scenario: Wait action produces a log line
- **WHEN** a `wait` action with `actor_name = "Bat"` is appended to the TurnReport
- **THEN** the CombatLog SHALL display "Bat は様子を見ている" as one line

### Requirement: CombatLog renders the attack_unreachable action type

`CombatLog` SHALL render `TurnReport` entries of `type == "attack_unreachable"` as a single line: `"<attacker_name> の攻撃は届かなかった"` (or equivalent). This entry only appears in defense-in-depth scenarios where the engine blocked an unreachable attack that bypassed the UI.

#### Scenario: attack_unreachable produces a log line
- **WHEN** an `attack_unreachable` action with `attacker_name = "Bob"` and `target_name = "Witch"` is appended to the TurnReport
- **THEN** the CombatLog SHALL display "Bob の攻撃は届かなかった" (or equivalent text including both names)

## MODIFIED Requirements

### Requirement: CombatOverlay renders a fixed Wizardry-style layout

The system SHALL display, while a battle is active, a fixed layout consisting of an enemy presentation area, a right-side battle UI column, and the persistent bottom party HUD. The enemy presentation area SHALL show monster species with per-species remaining counts in a framed `ENEMY` list window and monster visuals in a separate graphics area. Monster visuals SHALL be positioned per `MonsterCombatant.original_row`: FRONT-row monsters share a stable front-row baseline at full scale and the higher z_index, while BACK-row monsters are positioned higher on screen, smaller, and behind the front row (see "CombatOverlay renders monsters with row-based depth" requirement). When a living monster's MonsterData has battle art, the graphics area SHALL render that monster-specific image. When battle art is missing, the graphics area SHALL render the existing dummy monster image or procedural placeholder for that monster. The right-side battle UI column SHALL contain framed CombatLog and active command or selection windows. During battle, the normal dungeon minimap SHALL be hidden so the right-side battle UI can use the full column without overlapping itself or the party HUD. The CombatLog window SHALL be vertically compact enough to match its title plus eight retained visible log lines, leaving the active command or selection window to start higher in the same column. The CombatLog SHALL split multi-line action text into retained visible lines before enforcing its line cap. The CombatLog SHALL clip its contents to its own window so repeated battles cannot draw log text over command windows. The active command or selection window SHALL keep a clear vertical gap above the bottom party HUD. The bottom party HUD SHALL remain owned by PartyHud/PartyDisplay rather than by CombatOverlay.

The CommandMenu options for a living PartyCombatant SHALL preserve the existing localized command order and magic-school filtering: Attack, Defend, mage-school Cast only when the actor's job has `mage_school == true`, priest-school Cast only when the actor's job has `priest_school == true`, Item, and Escape. For a non-magic actor, magic entries SHALL be omitted entirely rather than greyed out. For a Bishop, both magic entries SHALL appear between Defend and Item. Item and Escape SHALL remain the last two entries regardless of magic visibility.

The MonsterPanel's per-species remaining counts SHALL be derived from a panel-internal `_displayed_alive` table that is initialized via `setup_for_battle(monsters)` at battle start (all monsters marked alive) and is mutated only by `apply_died(actor)` calls. The MonsterPanel SHALL NOT consult the live `MonsterCombatant.is_alive()` for count rendering during a battle, so that monster removal from the list is bound to log playback rather than to the engine's atomic resolution.

#### Scenario: MonsterPanel shows species and remaining count
- **WHEN** the monster party contains 2 live slimes and 1 live goblin
- **THEN** the MonsterPanel SHALL display text including both species names with their remaining counts

#### Scenario: MonsterPanel updates as monsters die
- **WHEN** one slime dies during resolution and the corresponding death log line is reached during playback
- **THEN** at or after the matching `flush_up_to_step` for that step, the MonsterPanel SHALL show the reduced count for slimes
- **AND** before that step the MonsterPanel SHALL still show the pre-death count

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

#### Scenario: Front-row monster visuals share a stable baseline
- **WHEN** the monster party contains multiple living FRONT-row monsters
- **THEN** all rendered FRONT-row monster visuals, whether texture-backed or dummy fallback, SHALL be positioned at the front-row baseline and SHALL share that stable baseline (back-row monster placement is governed by the row-based depth requirement)

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
- **THEN** log text SHALL NOT be drawn over the command windows below it

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
