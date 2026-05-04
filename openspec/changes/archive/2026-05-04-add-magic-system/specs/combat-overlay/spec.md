## MODIFIED Requirements

### Requirement: CombatOverlay renders a fixed Wizardry-style layout

The system SHALL display, while a battle is active, a fixed layout consisting of four panels: a MonsterPanel showing monster species with per-species remaining counts, a PartyStatusPanel showing each Character's name/level/HP/MP, a CommandMenu, and a CombatLog showing recent actions.

The CommandMenu options for a living PartyCombatant SHALL be assembled in this order: 「こうげき」, 「ぼうぎょ」, 「魔術」 (only if the actor's job has `mage_school == true`), 「祈り」 (only if the actor's job has `priest_school == true`), 「アイテム」, 「にげる」. For a non-magic actor (e.g. Fighter), the magic entries SHALL be omitted entirely (not greyed-out) so the menu shows only 「こうげき」/「ぼうぎょ」/「アイテム」/「にげる」. For a Bishop both 「魔術」 and 「祈り」 SHALL appear in this order. The position of 「アイテム」 and 「にげる」 SHALL be the last two entries regardless of magic visibility.

#### Scenario: MonsterPanel shows species and remaining count
- **WHEN** the monster party contains 2 live slimes and 1 live goblin
- **THEN** the MonsterPanel SHALL display text including both `"スライム"` and `"ゴブリン"` with their remaining counts

#### Scenario: MonsterPanel updates as monsters die
- **WHEN** one slime dies during resolution
- **THEN** after the log advances, the MonsterPanel SHALL show the reduced count for slimes

#### Scenario: MonsterPanel does not show per-individual HP
- **WHEN** any monster is alive
- **THEN** the MonsterPanel SHALL NOT show numeric HP for individual monsters

#### Scenario: PartyStatusPanel shows HP and MP live from Character
- **WHEN** a PartyCombatant's underlying Character takes damage or spends MP
- **THEN** the PartyStatusPanel SHALL display the updated `current_hp` / `max_hp` and `current_mp` / `max_mp` on the next refresh

#### Scenario: CommandMenu for Fighter omits magic entries
- **WHEN** the CommandMenu is shown for a living Fighter
- **THEN** the selectable options SHALL be exactly 「こうげき」, 「ぼうぎょ」, 「アイテム」, 「にげる」 in that order, and SHALL NOT include 「魔術」 or 「祈り」

#### Scenario: CommandMenu for Mage shows 「魔術」
- **WHEN** the CommandMenu is shown for a living Mage
- **THEN** the selectable options SHALL include 「魔術」 between 「ぼうぎょ」 and 「アイテム」, and SHALL NOT include 「祈り」

#### Scenario: CommandMenu for Priest shows 「祈り」
- **WHEN** the CommandMenu is shown for a living Priest
- **THEN** the selectable options SHALL include 「祈り」 between 「ぼうぎょ」 and 「アイテム」, and SHALL NOT include 「魔術」

#### Scenario: CommandMenu for Bishop shows both magic entries
- **WHEN** the CommandMenu is shown for a living Bishop
- **THEN** the selectable options SHALL be 「こうげき」, 「ぼうぎょ」, 「魔術」, 「祈り」, 「アイテム」, 「にげる」 in that order

#### Scenario: Item command remains present even when inventory has no consumables
- **WHEN** the CommandMenu is shown and `GameState.inventory` contains zero consumable ItemInstances
- **THEN** 「アイテム」 SHALL still be listed as a selectable option (its position SHALL NOT shift)

## ADDED Requirements

### Requirement: CombatSpellSelector lists the actor's spells filtered by school

The system SHALL provide a `CombatSpellSelector` Control that, when opened from 「魔術」 or 「祈り」, lists every SpellData in the active actor's `Character.known_spells` whose `school` matches the chosen entry (`mage` or `priest`). Each row SHALL display the spell's `display_name`, `mp_cost`, and the actor's current MP. Rows whose `mp_cost > current_mp` SHALL be visually disabled and SHALL NOT be selectable. If the filtered list is empty, the selector SHALL show an empty-state message and SHALL allow the user to back out without consuming the action.

#### Scenario: Mage spell selector lists only mage spells
- **WHEN** a Mage with `known_spells = [&"fire", &"frost"]` opens the spell selector via 「魔術」
- **THEN** the list SHALL contain "ファイア" and "フロスト" only

#### Scenario: Bishop priest selector lists only priest spells
- **WHEN** a Bishop opens 「祈り」 with `known_spells = [&"fire", &"heal"]`
- **THEN** the list SHALL contain "ヒール" only

#### Scenario: MP-insufficient spell is disabled
- **WHEN** a Mage with `current_mp = 1` opens 「魔術」 and `fire.mp_cost = 2`
- **THEN** the "ファイア" row SHALL be visibly disabled and SHALL NOT trigger selection on Enter

#### Scenario: Empty spell list allows backing out
- **WHEN** a Lord at level 3 (no priest spells learned yet) opens 「祈り」
- **THEN** the selector SHALL display an empty-state message and the back input SHALL return to the CommandMenu without submitting any command

### Requirement: CombatTargetSelector resolves targets for casting based on target_type

The system SHALL provide a `CombatTargetSelector` Control that, after spell selection, prompts for the cast target according to `spell.target_type`:

- `ENEMY_ONE`: cursor over individual living MonsterCombatants.
- `ENEMY_GROUP`: cursor over living monster species (groups), where each group corresponds to one row of the MonsterPanel.
- `ALLY_ONE`: cursor over living PartyCombatants.
- `ALLY_ALL`: no prompt; immediately confirm.

Confirming a target SHALL submit a Cast command to the TurnEngine carrying the spell id and the target descriptor.

#### Scenario: ENEMY_ONE prompts for individual monster
- **WHEN** a Mage selects "ファイア" with 2 slimes and 1 goblin alive
- **THEN** the target selector SHALL allow choosing one of the three individual monsters

#### Scenario: ENEMY_GROUP prompts for species
- **WHEN** a Mage selects "フレイム" with 2 slimes and 1 goblin alive
- **THEN** the target selector SHALL show two options: スライム group and ゴブリン group (1 row per species)

#### Scenario: ALLY_ONE prompts for party member
- **WHEN** a Priest selects "ヒール" with a 4-member party where 3 are alive
- **THEN** the target selector SHALL allow choosing one of the 3 living members

#### Scenario: ALLY_ALL skips the prompt
- **WHEN** a Priest selects "オールヒール"
- **THEN** the target selector SHALL NOT display a prompt and SHALL immediately submit the Cast command

#### Scenario: Back input returns to spell selection
- **WHEN** the user presses the Back input while the target selector is open
- **THEN** the target selector SHALL hide and the spell selector SHALL be re-shown without submitting a command

### Requirement: CombatLog renders cast action entries

The system SHALL render TurnReport cast entries in the CombatLog so that each cast produces at least one log line containing the caster name, the spell's display name, and a per-target outcome line (or summary) describing the HP delta. Skipped casts SHALL produce a single log line stating the reason in Japanese.

#### Scenario: Cast hit produces caster + spell + target line
- **WHEN** a fire spell from "Alice" hits "スライム" for `7` damage
- **THEN** at least one CombatLog line SHALL contain "Alice", "ファイア", and "スライム", along with the damage value `7`

#### Scenario: Group cast lists multiple targets in summary
- **WHEN** a flame spell from "Alice" hits two slimes for `5` and `4`
- **THEN** the CombatLog SHALL contain entries enumerating both targets and their respective damage values

#### Scenario: Heal cast shows positive delta
- **WHEN** a heal spell from "Bob" heals "Alice" for `6` HP
- **THEN** the CombatLog SHALL contain a line referencing "Bob", "ヒール", "Alice", and a `+6` (or equivalent positive) indicator

#### Scenario: Skipped cast logs reason
- **WHEN** a Mage tries to cast a spell with insufficient MP and the engine emits `cast_skipped_no_mp`
- **THEN** a single CombatLog line SHALL state that the cast failed because of insufficient MP, naming the caster and the spell
