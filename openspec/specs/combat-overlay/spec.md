## Purpose
戦闘中に重ねて表示される UI オーバーレイの構造を規定する。コマンドメニュー・敵情報パネル・ターゲット選択・戦闘結果パネルの表示切替とキーバインドを対象とする。

## Requirements

### Requirement: CombatOverlay extends EncounterOverlay and preserves the signal contract
The system SHALL provide a `CombatOverlay` (extends `EncounterOverlay`) that replaces the stub dismissal flow with a full Wizardry-style battle UI while preserving the existing signal/function contract: `start_encounter(monster_party)` and `encounter_resolved(outcome: EncounterOutcome)`.

#### Scenario: CombatOverlay is a CanvasLayer at layer 10
- **WHEN** a CombatOverlay is instantiated
- **THEN** it SHALL be a CanvasLayer with `layer == 10`, matching the existing EncounterOverlay convention

#### Scenario: start_encounter initializes a TurnEngine from the given monster_party
- **WHEN** `start_encounter(monster_party)` is called on CombatOverlay with a populated MonsterParty
- **THEN** CombatOverlay SHALL construct a TurnEngine seeded with wrapped PartyCombatants (from the active Guild party) and MonsterCombatants (from the monster_party), and SHALL transition the engine to `COMMAND_INPUT`

#### Scenario: encounter_resolved fires exactly once with a populated outcome
- **WHEN** the battle reaches a terminal state and the result screen is confirmed
- **THEN** `encounter_resolved` SHALL be emitted exactly once with an `EncounterOutcome` whose `result`, `gained_experience`, and `drops` fields reflect the actual battle outcome

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

### Requirement: CombatOverlay collects commands one member at a time
The system SHALL, in each turn's command-input phase, prompt each living PartyCombatant in Guild order for a command before advancing to resolution.

#### Scenario: Next-member prompt after command confirmed
- **WHEN** the first living PartyCombatant confirms a command
- **THEN** the CommandMenu SHALL advance to the next living PartyCombatant

#### Scenario: Dead members are skipped
- **WHEN** a PartyCombatant has `is_alive() == false` at the moment their turn to input arrives
- **THEN** the CommandMenu SHALL skip them and advance immediately

#### Scenario: All living commands collected triggers resolution
- **WHEN** every living PartyCombatant has a command submitted
- **THEN** CombatOverlay SHALL invoke `TurnEngine.resolve_turn(rng)` and display the resulting TurnReport in the CombatLog

### Requirement: CombatLog shows recent actions with fixed-height rolling
The system SHALL display combat log entries in a fixed-height panel that retains the most recent N lines (N >= 4), discarding oldest lines as new ones arrive.

#### Scenario: Log retains at least four recent lines
- **WHEN** 10 action entries have been produced across multiple turns
- **THEN** the CombatLog SHALL display at least the 4 most recent entries

#### Scenario: Log formats per-action outcomes
- **WHEN** a party attack deals 8 damage to a slime
- **THEN** the corresponding log line SHALL mention the attacker name, the target species, and the damage value

### Requirement: ResultPanel shows outcome and level-ups before resolving
The system SHALL, upon battle termination, display a ResultPanel before emitting `encounter_resolved`; the panel's content depends on the outcome.

#### Scenario: CLEARED shows gained experience, gold, and level-up notifications
- **WHEN** the battle ends with `CLEARED` and any Character leveled up
- **THEN** the ResultPanel SHALL display the per-member gained experience, the party-total gained gold, and a line for each Character whose level increased, including the new level

#### Scenario: CLEARED with no level-ups still shows experience and gold
- **WHEN** the battle ends with `CLEARED` and no Character leveled up
- **THEN** the ResultPanel SHALL still display the per-member gained experience and the party-total gained gold

#### Scenario: WIPED shows a defeat message
- **WHEN** the battle ends with `WIPED`
- **THEN** the ResultPanel SHALL display a defeat message and SHALL NOT display gained experience or gold

#### Scenario: ESCAPED shows an escape message
- **WHEN** the battle ends with `ESCAPED`
- **THEN** the ResultPanel SHALL display an escape confirmation message and SHALL NOT display gained experience or gold

#### Scenario: Confirm input resolves the encounter
- **WHEN** the user presses Enter/Space on the ResultPanel
- **THEN** CombatOverlay SHALL hide itself and SHALL emit `encounter_resolved` with the populated EncounterOutcome

### Requirement: CombatOverlay computes gained_gold from dead monsters on CLEARED
The system SHALL, on a CLEARED outcome, compute `gained_gold` as the sum over every dead MonsterCombatant of `rng.randi_range(monster.data.gold_min, monster.data.gold_max)`, using the same injected RandomNumberGenerator as the turn engine for determinism under a fixed seed.

#### Scenario: Gold drop sums per-monster rolls
- **WHEN** a CLEARED battle ends with one slime dead (`gold_min=1, gold_max=3`) and one goblin dead (`gold_min=5, gold_max=15`), under a fixed RNG seed producing rolls of `2` and `10` respectively
- **THEN** the EncounterOutcome's `gained_gold` SHALL equal `12`

#### Scenario: Gold drop is zero for WIPED
- **WHEN** a battle ends with `WIPED`
- **THEN** the EncounterOutcome's `gained_gold` SHALL equal `0`

#### Scenario: Gold drop is zero for ESCAPED
- **WHEN** a battle ends with `ESCAPED`
- **THEN** the EncounterOutcome's `gained_gold` SHALL equal `0`

#### Scenario: Gold is credited to party inventory on encounter_resolved
- **WHEN** `encounter_resolved(outcome)` is emitted with `outcome.result == CLEARED` and `outcome.gained_gold == 30`
- **THEN** the caller (main.gd or equivalent wiring) SHALL invoke `GameState.inventory.add_gold(30)` and subsequent `GameState.inventory.gold` SHALL reflect the addition

### Requirement: CombatOverlay respects existing input-exclusion contracts
The system SHALL continue to block DungeonScreen input and ESC-menu invocation while a battle is active, reusing the `_encounter_active` flag that is already set/cleared by EncounterCoordinator.

#### Scenario: Dungeon movement keys are ignored during combat
- **WHEN** CombatOverlay is visible and the user presses arrow/WASD keys
- **THEN** the DungeonScreen position SHALL NOT change

#### Scenario: ESC does not open the ESC menu during combat
- **WHEN** CombatOverlay is visible and the user presses ESC
- **THEN** the ESC menu SHALL NOT appear

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
