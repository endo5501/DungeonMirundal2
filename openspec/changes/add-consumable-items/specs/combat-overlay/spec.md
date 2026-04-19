## MODIFIED Requirements

### Requirement: CombatOverlay renders a fixed Wizardry-style layout
The system SHALL display, while a battle is active, a fixed layout consisting of four panels: a MonsterPanel showing monster species with per-species remaining counts, a PartyStatusPanel showing each Character's name/level/HP, a CommandMenu with the entries 「こうげき」/「ぼうぎょ」/「アイテム」/「にげる」, and a CombatLog showing recent actions.

#### Scenario: MonsterPanel shows species and remaining count
- **WHEN** the monster party contains 2 live slimes and 1 live goblin
- **THEN** the MonsterPanel SHALL display text including both `"スライム"` and `"ゴブリン"` with their remaining counts

#### Scenario: MonsterPanel updates as monsters die
- **WHEN** one slime dies during resolution
- **THEN** after the log advances, the MonsterPanel SHALL show the reduced count for slimes

#### Scenario: MonsterPanel does not show per-individual HP
- **WHEN** any monster is alive
- **THEN** the MonsterPanel SHALL NOT show numeric HP for individual monsters

#### Scenario: PartyStatusPanel shows HP live from Character
- **WHEN** a PartyCombatant's underlying Character takes damage
- **THEN** the PartyStatusPanel SHALL display the updated `current_hp` / `max_hp` on the next refresh

#### Scenario: CommandMenu offers four commands
- **WHEN** the CommandMenu is shown for a living PartyCombatant
- **THEN** the selectable options SHALL include 「こうげき」, 「ぼうぎょ」, 「アイテム」, and 「にげる」, in that order

#### Scenario: Item command remains present even when inventory has no consumables
- **WHEN** the CommandMenu is shown and `GameState.inventory` contains zero consumable ItemInstances
- **THEN** 「アイテム」 SHALL still be listed as a selectable option (its position SHALL NOT shift)

## ADDED Requirements

### Requirement: Item command opens a consumable selection sub-menu

The system SHALL, when a living PartyCombatant selects 「アイテム」 from the CommandMenu, open an item-selection sub-menu listing every `ItemInstance` in `GameState.inventory` whose `item.category == CONSUMABLE`.

For each listed item, the sub-menu SHALL evaluate the item's `context_conditions` against an `ItemUseContext` with `is_in_combat == true` and `is_in_dungeon == true`. Items with unsatisfied context conditions SHALL be displayed in a grayed / disabled style with the failing reason surfaced on attempt.

#### Scenario: Selecting 「アイテム」 opens consumables list
- **WHEN** the acting PartyCombatant confirms 「アイテム」 on the CommandMenu, and inventory contains `potion` and `long_sword`
- **THEN** the opened list SHALL include `potion` and SHALL NOT include `long_sword`

#### Scenario: Empty consumable inventory shows informational message
- **WHEN** the acting PartyCombatant confirms 「アイテム」 and inventory contains zero CONSUMABLE items
- **THEN** a "アイテムがありません" (or equivalent) message SHALL be displayed, and focus SHALL return to the CommandMenu without committing any command for this actor

#### Scenario: Escape-scroll is grayed in combat
- **WHEN** the consumable list includes `escape_scroll` (context `[InDungeonOnly, NotInCombatOnly]`)
- **THEN** that row SHALL be grayed / disabled; attempting to select it SHALL surface the `NotInCombatOnly` reason and SHALL NOT proceed

#### Scenario: Emergency-escape-scroll is enabled in combat
- **WHEN** the consumable list includes `emergency_escape_scroll` (context `[InDungeonOnly]`)
- **THEN** that row SHALL be enabled and selectable while combat is active in the dungeon

### Requirement: Item command collects target and commits an ItemCommand

The system SHALL, after a consumable is selected, gate the flow by the item's `target_conditions`:

- If `target_conditions` is empty (no-target consumables such as escape scrolls), the flow SHALL commit an `ItemCommand { actor, item_instance, target = null }` immediately.
- If `target_conditions` is non-empty, the flow SHALL open a target selection listing living PartyCombatants (for support-style effects). Members failing any `target_conditions.is_satisfied(member, ctx)` SHALL be grayed / non-selectable, with the reason surfaced on attempt. On confirmation, the flow SHALL commit an `ItemCommand { actor, item_instance, target }`.

Committed ItemCommands SHALL be queued into the same per-actor command slot as attack/defend/escape, so that command collection advances normally to the next living PartyCombatant.

#### Scenario: No-target item commits without target selection
- **WHEN** the actor selects `emergency_escape_scroll` (empty target_conditions)
- **THEN** target selection SHALL NOT be shown, and an `ItemCommand { target = null }` SHALL be committed for that actor

#### Scenario: Potion requires a valid target
- **WHEN** the actor selects `potion` (target_conditions include `AliveOnly` and `NotFullHp`) and the party has one wounded alive member, one full-HP alive member, and one dead member
- **THEN** only the wounded alive member SHALL be selectable; the other two SHALL be grayed

#### Scenario: Selecting invalid target surfaces reason
- **WHEN** the actor attempts to target a full-HP member with `potion`
- **THEN** the `NotFullHp` reason SHALL be surfaced and the command SHALL NOT be committed

### Requirement: ItemCommand is resolved in normal agility order

The system SHALL resolve `ItemCommand` actions mixed with attack/defend/escape commands in standard agility order (no special priority). Resolution SHALL follow this rule:

1. At the moment of resolving an actor's `ItemCommand`, the system SHALL check `actor.is_alive()` (or equivalent: can still act).
2. If the actor can no longer act (killed, petrified, or otherwise disabled before their turn arrives), the command SHALL be **cancelled**: the `ItemInstance` SHALL NOT be consumed, and no `effect.apply` SHALL be invoked. A cancellation line SHALL be added to the CombatLog (e.g., "<actor> は 行動不能で アイテムを使えなかった").
3. Otherwise, the system SHALL invoke `item.effect.apply(actor, targets, context_with_is_in_combat_true)`.
4. On `result.success == true`, the instance SHALL be removed from `GameState.inventory`, and the effect-specific outcome SHALL be logged (e.g., "<actor> は ポーションを使った！ <target> の HP が <n> 回復した").
5. On `result.success == false`, the instance SHALL remain in the inventory, the failure `message` SHALL be logged, and the actor's turn SHALL end.

#### Scenario: Item used in agility order, not boosted
- **WHEN** three actors have agility 15 / 12 / 10 and the AGI 12 actor commits an ItemCommand while AGI 15 commits こうげき and AGI 10 commits ぼうぎょ
- **THEN** the resolution order SHALL be AGI 15 → AGI 12 (item) → AGI 10, with no special timing adjustment for the item use

#### Scenario: Dead actor before turn cancels ItemCommand
- **WHEN** an actor who queued an ItemCommand is reduced to `current_hp <= 0` by a faster enemy before their turn resolves
- **THEN** the ItemCommand SHALL be cancelled, the `ItemInstance` SHALL remain in inventory, and a cancellation line SHALL be added to the log

#### Scenario: Successful potion restores HP and consumes instance
- **WHEN** an ItemCommand using `potion { power = 20 }` targeting a wounded member is resolved successfully
- **THEN** the target's `current_hp` SHALL increase by 20 (clamped to `max_hp`), the `ItemInstance` SHALL be removed from inventory, and a log line describing the heal SHALL appear

### Requirement: Emergency escape scroll terminates combat as ESCAPED

The system SHALL, when an `ItemCommand` whose effect is `EscapeToTownEffect` resolves during combat, terminate the battle immediately with `EncounterOutcome.result == ESCAPED` (no gained EXP, no gained gold). Any remaining queued commands for slower actors in the same turn SHALL be discarded. After the CombatLog/ResultPanel sequence completes, the player SHALL be transitioned to the town menu entry, identical to the START-tile return destination.

#### Scenario: Emergency escape ends battle immediately
- **WHEN** an ItemCommand using `emergency_escape_scroll` resolves during combat resolution
- **THEN** the battle SHALL terminate with `EncounterOutcome.result == ESCAPED`, `gained_experience == 0`, and `gained_gold == 0`

#### Scenario: Remaining slower commands are discarded on escape
- **WHEN** `emergency_escape_scroll` resolves at AGI 12, and AGI 10 had a queued こうげき
- **THEN** the AGI 10 command SHALL NOT be resolved, and its log line SHALL NOT appear

#### Scenario: Escape via scroll transitions to town menu entry
- **WHEN** the ResultPanel for the scroll-induced ESCAPED outcome is confirmed
- **THEN** the player SHALL end up at the town menu entry (same destination as the START-tile return dialog)

#### Scenario: Emergency scroll is consumed on successful escape
- **WHEN** `emergency_escape_scroll` resolves successfully and the battle ends in ESCAPED
- **THEN** the `ItemInstance` for that scroll SHALL be removed from `GameState.inventory`
