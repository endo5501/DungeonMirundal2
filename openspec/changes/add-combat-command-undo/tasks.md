## 1. TurnEngine.withdraw_command (TDD)

- [x] 1.1 Write GUT test: `submit_command(0, AttackCommand)` followed by `withdraw_command(0)` removes the entry from `_pending_commands` and `are_party_commands_complete()` returns `false`
- [x] 1.2 Write GUT test: `withdraw_command` while `state == RESOLVING` or `FINISHED` is a no-op (no mutation)
- [x] 1.3 Write GUT test: `withdraw_command` on an index with no pending command is a safe no-op
- [x] 1.4 Write GUT test: `submit_command(CastCommand{mp_cost=4})` then `withdraw_command` leaves `caster.current_mp` unchanged and emits no signals (no `actor_action_started` / `actor_spent_mp`)
- [x] 1.5 Run tests, confirm they fail (red)
- [x] 1.6 Implement `TurnEngine.withdraw_command(party_index: int) -> void` in `src/combat/turn_engine.gd`
- [x] 1.7 Run tests, confirm they pass (green)
- [x] 1.8 Commit: `Add TurnEngine.withdraw_command for COMMAND_INPUT undo`

## 2. CombatInputRouter routing for cancel (TDD)

- [x] 2.1 Write GUT test: `route(ui_cancel, Phase.COMMAND_MENU, panels)` calls `panels.overlay.request_undo_actor()` exactly once and returns `true`
- [x] 2.2 Write GUT test: `route(ui_cancel, Phase.COMMAND_MENU, panels)` with `panels.overlay == null` returns `false` and does not raise
- [x] 2.3 Write GUT test: `route(ui_down, Phase.COMMAND_MENU, panels)` still calls `command_menu.move_down()` and does not call `overlay.request_undo_actor`
- [x] 2.4 Write GUT test: `route(ui_cancel, Phase.TARGET_SELECT, panels)` calls `panels.target_selector.request_cancel()` exactly once and returns `true`
- [x] 2.5 Write GUT test: `route(ui_up, Phase.TARGET_SELECT, panels)` still calls `target_selector.move_up()` (regression guard)
- [x] 2.6 Write GUT test: `route(ui_cancel, Phase.SPELL_TARGET, panels)` still calls `target_selector.request_cancel()` (regression guard)
- [x] 2.7 Run tests, confirm they fail (red)
- [x] 2.8 Update `src/combat/combat_input_router.gd`: add `panels.overlay` handling for COMMAND_MENU + ui_cancel, switch TARGET_SELECT to `_route_to_panel_cancellable`
- [x] 2.9 Run tests, confirm they pass (green)
- [x] 2.10 Commit: `Route ui_cancel to overlay undo and target cancel in CombatInputRouter`

## 3. CombatOverlay.request_undo_actor (step-back) (TDD)

- [x] 3.1 Write GUT test (overlay-level): with party `[A,B,C]` all alive, simulate `submit_command(A,...)` then advance to B's COMMAND_MENU, call `request_undo_actor()` → `_current_actor_index == A_idx`, A's pending command removed, `_command_menu.show_for(A)` invoked, phase still `COMMAND_MENU`
- [x] 3.2 Write GUT test: triple `request_undo_actor()` from D walks back D→C→B→A withdrawing each
- [x] 3.3 Write GUT test: dead-skip backward — party `[A,B(dead),C,D]`, two `request_undo_actor()` calls from D land on A (skipping B), with C and A pending commands withdrawn at each step
- [x] 3.4 Write GUT test: `request_undo_actor()` while on the first living member is a no-op (`_pending_commands` unchanged, `_current_actor_index` unchanged, phase unchanged)
- [x] 3.5 Write GUT test: when called outside `Phase.COMMAND_MENU`, `request_undo_actor()` is a safe no-op
- [x] 3.6 Write GUT test: step-back hides any visible sub-panel (`target_selector`, `spell_selector`, `item_use_flow`) before re-showing the prior actor's command menu
- [x] 3.7 Run tests, confirm they fail (red)
- [x] 3.8 Implement `request_undo_actor()` and a private `_step_back_to_previous_living_actor()` helper in `src/dungeon_scene/combat_overlay.gd`. Build the `panels` Dictionary passed to `CombatInputRouter.route` to include the `overlay` key (`self`). Mirror the forward dead-skip loop in reverse.
- [x] 3.9 Run tests, confirm they pass (green)
- [x] 3.10 Commit: `Add CombatOverlay.request_undo_actor for inter-actor command undo`

## 4. CombatOverlay TARGET_SELECT cancel handling (TDD)

- [x] 4.1 Write GUT test: in `Phase.TARGET_SELECT`, dispatch the existing `target_selector.cancelled` signal (or simulate `request_cancel` followed by `cancelled`) → `_current_phase == Phase.COMMAND_MENU`, `_command_menu.show_for(current_actor)` invoked, `target_selector` hidden, no `submit_command` for the current actor
- [x] 4.2 Write GUT test: in `Phase.SPELL_TARGET`, the same signal still routes to `Phase.SPELL_SELECT` (regression guard for existing Cast cancel)
- [x] 4.3 Run tests, confirm they fail (red)
- [x] 4.4 Extend `_on_target_selector_cancelled` in `src/dungeon_scene/combat_overlay.gd` to handle `Phase.TARGET_SELECT`: hide selector, set phase to `COMMAND_MENU`, re-show `_command_menu` for current actor; keep existing SPELL_TARGET branch intact
- [x] 4.5 Run tests, confirm they pass (green)
- [x] 4.6 Commit: `Allow ui_cancel during attack target selection to return to command menu`

## 5. End-to-end regression checks

- [x] 5.1 Run the full GUT suite to ensure no existing combat / overlay test regressed (2177/2177 passing)
- [ ] 5.2 Manual playtest: Attack → ui_cancel returns to command menu (no submit)
- [ ] 5.3 Manual playtest: Cast (mage / priest) → spell select cancel → command menu (regression)
- [ ] 5.4 Manual playtest: Cast → target select cancel → spell select (regression, NOT command menu)
- [ ] 5.5 Manual playtest: A confirms attack, B menu open, ui_cancel → A's menu, A's command cleared
- [ ] 5.6 Manual playtest: 4-member party (one mid-party member dead), confirm dead-skip on backward navigation
- [ ] 5.7 Manual playtest: ui_cancel on first living member is silently ignored
- [ ] 5.8 Manual playtest: Item flow cancel still returns to command menu
- [x] 5.9 Update `MEMORY.md` if any non-obvious gotchas surfaced (only if applicable) — none surfaced

## 6. Validation

- [x] 6.1 `openspec validate add-combat-command-undo --strict`
- [ ] 6.2 `openspec verify add-combat-command-undo` (or `/opsx:verify`) once implementation is complete
- [ ] 6.3 Final commit (if any cleanup): `Finalize add-combat-command-undo`
