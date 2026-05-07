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

The system SHALL display, while a battle is active, a fixed layout consisting of an enemy presentation area, a right-side battle UI column, and the persistent bottom party HUD. The enemy presentation area SHALL show monster species with per-species remaining counts in a framed `ENEMY` list window and monster visuals in a separate graphics area. When a living monster's MonsterData has battle art, the graphics area SHALL render that monster-specific image. When battle art is missing, the graphics area SHALL render the existing dummy monster image or procedural placeholder for that monster. The right-side battle UI column SHALL contain framed CombatLog and active command or selection windows. During battle, the normal dungeon minimap SHALL be hidden so the right-side battle UI can use the full column without overlapping itself or the party HUD. The CombatLog window SHALL be vertically compact enough to match its title plus eight retained visible log lines, leaving the active command or selection window to start higher in the same column. The CombatLog SHALL split multi-line action text into retained visible lines before enforcing its line cap. The CombatLog SHALL clip its contents to its own window so repeated battles cannot draw log text over command windows. The active command or selection window SHALL keep a clear vertical gap above the bottom party HUD. The bottom party HUD SHALL remain owned by PartyHud/PartyDisplay rather than by CombatOverlay.

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

### Requirement: CombatOverlay synchronizes panel refresh with log playback

CombatOverlay SHALL NOT call `_refresh_panels()` immediately after `TurnEngine.resolve_turn(rng)` returns inside `_resolve_turn_now()`. Instead, the per-step visual updates SHALL flow through `PartyHud.flush_up_to_step` driven by `_show_next_log_line`, and a single final `_refresh_panels()` SHALL be issued from `_on_log_playback_finished` to guarantee that the displayed state ultimately matches the engine's canonical state once playback completes.

If log playback is cancelled (e.g. via `cancel_log_playback`), the cleanup of buffered HUD events (existing behavior) SHALL drain remaining deltas and the next `_refresh_panels()` SHALL still produce a state consistent with the engine.

#### Scenario: resolve_turn return does not refresh panels
- **WHEN** `_resolve_turn_now()` calls `_turn_engine.resolve_turn(rng)` and the call returns
- **THEN** `_refresh_panels()` SHALL NOT be called within `_resolve_turn_now()` after that return

#### Scenario: log playback completion refreshes panels
- **WHEN** `_on_log_playback_finished()` is invoked after the last log line is shown
- **THEN** `_refresh_panels()` SHALL be called once before any battle finalization

#### Scenario: monsters remain visible until their death log line
- **WHEN** an attack kills a monster during `resolve_turn` at action index N, but the log has only displayed up through index N-1
- **THEN** the MonsterPanel SHALL still show the monster as alive
- **AND** when log playback advances to index N, the MonsterPanel SHALL show the monster as removed

### Requirement: CombatOverlay registers the monster panel with PartyHud at battle start

In `start_encounter(monster_party)`, after `PartyHud.attach_to_turn_engine(_turn_engine)`, CombatOverlay SHALL:
1. Call `_monster_panel.setup_for_battle(_turn_engine.monsters)` to initialize the panel's `_displayed_alive` table to all-true.
2. Call `PartyHud.attach_monster_panel(_monster_panel)` so that subsequent `actor_died` events for `MonsterCombatant` actors are bridged to the panel through the buffering pipeline.

When the battle ends and `PartyHud.detach_from_turn_engine()` is called, the matching `detach_monster_panel()` step SHALL also occur (handled by PartyHud) so the monster panel reference is released.

#### Scenario: setup_for_battle initializes displayed_alive
- **WHEN** `start_encounter` is invoked with a monster party containing 3 monsters
- **THEN** after the call, the MonsterPanel's internal `_displayed_alive` table SHALL contain exactly those 3 monsters mapped to `true`

#### Scenario: attach_monster_panel is called after attach_to_turn_engine
- **WHEN** `start_encounter` runs
- **THEN** `PartyHud.attach_monster_panel(_monster_panel)` SHALL be called after `PartyHud.attach_to_turn_engine(_turn_engine)`

#### Scenario: Battle end releases monster panel reference
- **WHEN** the battle is resolved and `PartyHud.detach_from_turn_engine()` is invoked
- **THEN** PartyHud's stored monster panel reference SHALL be cleared

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

### Requirement: CombatOverlay はaction ベースで入力を受ける
SHALL: `CombatOverlay._unhandled_input` は ui_* action(`ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_accept`, `ui_cancel`)を介してメニュー操作・コマンド選択を処理する。`event.keycode == KEY_*` の直接マッチを使ってはならない。各 phase ごとの入力ルーティング詳細は C7 (refactor-combat-overlay) のスコープであり、本要件では入力規約のみを規定する。

#### Scenario: コマンド選択 phase で ui_down がカーソルを動かす
- **WHEN** combat overlay がコマンド選択 phase で `is_action_pressed("ui_down")` がディスパッチされる
- **THEN** コマンドメニューのカーソルが次の項目に移動する

#### Scenario: ui_accept でコマンドが確定する
- **WHEN** combat overlay の任意の選択 phase で `is_action_pressed("ui_accept")` がディスパッチされる
- **THEN** 現在のカーソル選択が確定し、次の phase に進む

#### Scenario: ui_cancel で前 phase に戻る
- **WHEN** combat overlay のターゲット選択 phase などサブ選択 phase で `is_action_pressed("ui_cancel")` がディスパッチされる
- **THEN** 1 つ前の phase(コマンド選択)に戻る

### Requirement: CombatOverlay は BattleResolver で報酬を計算する
SHALL: `CombatOverlay._finalize_battle` は経験値・ゴールド・レベルアップの計算を直接行わず、`BattleResolver.resolve_rewards(_turn_engine, _rng)` を呼び出して `BattleSummary` を取得する。`show_result(outcome, summary)` は summary をそのまま `_result_panel.show_result` に渡す。`_compute_gold_drop`, `_collect_participant_characters`, `_collect_dead_monsters` メソッドは CombatOverlay から削除され、BattleResolver の private 関数として実装される。

#### Scenario: CombatOverlay が BattleResolver を呼ぶ
- **WHEN** 戦闘終了(CLEARED)時に `_finalize_battle` が呼ばれる
- **THEN** `BattleResolver.resolve_rewards(_turn_engine, _rng)` が 1 回呼ばれ、その返却値で `show_result` が呼ばれる

#### Scenario: 旧報酬計算メソッドは存在しない
- **WHEN** `combat_overlay.gd` を grep する
- **THEN** `_compute_gold_drop`, `_collect_participant_characters`, `_collect_dead_monsters` メソッドは存在しない

### Requirement: CombatOverlay は CombatInputRouter で phase 入力をルーティングする
SHALL: `CombatOverlay._unhandled_input` は phase ごとの入力処理を `CombatInputRouter.route(event, _current_phase, _panels)` 1 呼び出しに集約する。旧 `_handle_command_menu_key`, `_handle_target_select_key`, `_handle_item_select_key`, `_handle_result_key` の 4 メソッドは削除される。

#### Scenario: 旧 per-phase ハンドラは存在しない
- **WHEN** `combat_overlay.gd` を grep する
- **THEN** `_handle_command_menu_key`, `_handle_target_select_key`, `_handle_item_select_key`, `_handle_result_key` は存在しない

#### Scenario: phase に応じて適切な panel に input が届く
- **WHEN** COMMAND_MENU phase で ui_down がディスパッチされる
- **THEN** CombatInputRouter 経由で command_menu の cursor が下に移動する

### Requirement: CombatOverlay はアイテム使用に ItemUseFlow を使う
SHALL: アイテム使用は `ItemUseFlow` (C6 で抽出) を `_item_use_flow` フィールドとして保持し、コマンドメニューで「アイテム」が選ばれたら `_show_item_use_flow()` で起動する。`flow_completed` シグナルで戻りを受け、空メッセージならコマンドメニューに戻り、メッセージありなら `_advance_to_next_actor` を呼ぶ。旧 `_open_item_selector`, `_on_item_selector_item_selected`, `_valid_item_targets`, `_commit_item_command`, `_pending_item_instance` は削除される。

#### Scenario: アイテムコマンドで ItemUseFlow が表示される
- **WHEN** COMMAND_MENU phase でアイテムコマンドが選ばれる
- **THEN** `_item_use_flow.setup(ctx_in_combat_true, inventory, party_chars)` が呼ばれ、`_item_use_flow.visible = true` になる

#### Scenario: ItemUseFlow キャンセルでコマンドメニューに戻る
- **WHEN** ItemUseFlow が `flow_completed("")` を発行
- **THEN** ItemUseFlow が hidden になり、`_current_phase = Phase.COMMAND_MENU` で command_menu が再表示される

#### Scenario: ItemUseFlow 完了で次アクターに進む
- **WHEN** ItemUseFlow が `flow_completed("回復した！")` のような結果メッセージを発行
- **THEN** ItemUseFlow が hidden になり、`_advance_to_next_actor` が呼ばれる

### Requirement: CombatOverlay の戦闘ログ再生はキャンセル可能である
SHALL: `_play_log_sequentially` は `await get_tree().create_timer(...)` を使わず、`Timer` ノードベースの実装で 1 行ずつログを再生する。`encounter_resolved` 発行時や `_is_active = false` のとき、ペンディングのログ再生を `cancel_log_playback()` で安全に停止できること。

#### Scenario: ログ再生中にオーバーレイが非アクティブになると停止する
- **WHEN** `_play_log_sequentially` 実行中に `_is_active = false` がセットされ `cancel_log_playback()` が呼ばれる
- **THEN** Timer が停止し、ペンディングのログ行は再生されない

#### Scenario: ログ再生は Timer ノードで実装される
- **WHEN** `combat_overlay.gd` を grep する
- **THEN** `await get_tree().create_timer` は `_play_log_sequentially` 内に存在しない

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

### Requirement: CombatLog renders status-related action entries

`CombatLog` SHALL render the following TurnReport action types as one line each, in the order they appear in the report. The text SHALL pull `status_display` from `StatusRepository.find(status_id).display_name` (falling back to `String(status_id)` when the lookup fails).

| Entry type | Rendered text template |
|---|---|
| `tick_damage` | `"{actor_name} は {status_display} で {amount} ダメージを受けた"` |
| `wake` | `"{actor_name} は目を覚ました"` (status-specific text allowed for future statuses) |
| `inflict` | `"{target_name} は {status_display} になった"` |
| `cure` | `"{actor_name} の {status_display} が治った"` |
| `resist` | `"{target_name} は {status_display} に抵抗した"` |
| `action_locked` | `"{actor_name} は行動できない"` (status_display optional in this change) |
| `cast_silenced` | `"{caster_name} は呪文を唱えようとしたが声が出ない"` |
| `stat_mod` | `"{target_name} の {stat_display} が {sign}{abs(delta)} 変化した"` |
| `miss` | `"{attacker_name} の攻撃は外れた"` (already specified in `add-stat-modifier-and-hit-evasion`) |

#### Scenario: tick_damage entry is rendered with status display name
- **WHEN** a TurnReport contains a `tick_damage` entry with `actor_name = "Alice"`, `status_id = &"poison"`, `amount = 2`
- **THEN** the CombatLog SHALL show one line containing "Alice", "毒" (or fallback), and "2 ダメージ"

#### Scenario: cast_silenced entry shows the caster name
- **WHEN** a TurnReport contains a `cast_silenced` entry with `caster_name = "Alice"`
- **THEN** the CombatLog SHALL show "Alice は呪文を唱えようとしたが声が出ない"

#### Scenario: action_locked entry is rendered without crashing if status is unknown
- **WHEN** a TurnReport contains an `action_locked` entry but no matching status data is available
- **THEN** the CombatLog SHALL still produce a non-empty line (showing at least the actor name and a generic "行動できない" phrase)

### Requirement: CombatCommandMenu disables Cast row when caster has silence

`CombatCommandMenu` SHALL, when building command rows for a `PartyCombatant` whose `has_silence_flag()` returns `true`, render the "呪文" row in a disabled state (visually distinct, e.g. greyed text). Pressing Enter on a disabled Cast row SHALL be a no-op (the menu does not advance to spell selection). Other rows (Attack / Defend / Item / Escape) SHALL remain enabled.

The actual silence-induced no-op at action resolution remains the engine's responsibility; the menu disable is a UI affordance.

#### Scenario: Silence disables Cast row
- **WHEN** the command menu is built for a Mage whose `has_silence_flag() == true`
- **THEN** the Cast row SHALL be flagged disabled and SHALL render with a "(沈黙中)" suffix or equivalent visual indicator

#### Scenario: Disabled Cast row does not advance the menu
- **WHEN** the user moves the cursor onto the disabled Cast row and presses Enter
- **THEN** the menu SHALL remain on the command selection step and the action SHALL NOT be queued

#### Scenario: Other commands remain available when silenced
- **WHEN** the silenced Mage's command menu is open
- **THEN** Attack / Defend / Item / Escape rows SHALL be selectable and behave as usual

### Requirement: CombatLog renders confusion_swap annotations on attack and miss actions

When a TurnReport entry of type `attack` or `miss` carries a truthy `confusion_swap` flag (added by the engine when a confused actor's command was retargeted), the `CombatLog` SHALL prepend or append a clarifying phrase such as "(混乱中)" so the player understands why the actor attacked an unexpected target.

#### Scenario: Confused attack on an ally is rendered with annotation
- **WHEN** a TurnReport contains an `attack` entry with `attacker_name = "Alice"`, `target_name = "Bob"`, `damage = 4`, and `confusion_swap == true`
- **THEN** the CombatLog SHALL show a single line that includes "Alice", "Bob", "4", and the substring "混乱" (e.g. "Alice (混乱中) は Bob に 4 ダメージを与えた")

#### Scenario: Confused miss is rendered with annotation
- **WHEN** a TurnReport contains a `miss` entry with `confusion_swap == true`
- **THEN** the CombatLog SHALL show a line that includes the attacker name, target name, "外れた", and the substring "混乱"

#### Scenario: Non-confused attack/miss entries render unchanged
- **WHEN** a TurnReport contains an `attack` or `miss` entry without `confusion_swap` (or with it set to `false`)
- **THEN** the line SHALL render in the standard pre-existing format with no confusion annotation

