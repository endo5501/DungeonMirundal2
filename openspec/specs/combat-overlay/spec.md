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
The system SHALL display, while a battle is active, a fixed layout consisting of four panels: a MonsterPanel showing monster species with per-species remaining counts, a PartyStatusPanel showing each Character's name/level/HP, a CommandMenu with at least the entries 「こうげき」/「ぼうぎょ」/「にげる」, and a CombatLog showing recent actions.

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

#### Scenario: CommandMenu offers three commands
- **WHEN** the CommandMenu is shown for a living PartyCombatant
- **THEN** the selectable options SHALL include 「こうげき」, 「ぼうぎょ」, and 「にげる」

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
