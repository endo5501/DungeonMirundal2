# Tech Debt Audit — DungeonMirundal2

Generated: 2026-05-03
Scope: `src/` (104 GDScript files, ~8,846 LOC) plus `tests/` (~12,917 LOC), `data/`, `openspec/`.
Stack: Godot 4.6, GDScript, GUT for tests, `.tres` resources for game data.

---

## Executive summary

Ranked by impact. Top items first.

1. **Three god UI files concentrate ~17 % of source LOC.** `src/esc_menu/esc_menu.gd` (772 LOC, 11-state View enum), `src/dungeon_scene/combat_overlay.gd` (552, 7-phase state machine), `src/guild_scene/character_creation.gd` (440, 5-step wizard) each fold UI building, view switching, input dispatch, and game-state mutation into one class. They are also among the top-churned files in the last 6 months.
2. **`SaveManager.save()` silently swallows disk errors.** `src/save_manager.gd:35-43` returns on `FileAccess.open() == null` with no signal/log. A full disk or permission failure looks identical to a successful save in the UI flow (see `src/save_screen.gd:134-135`).
3. **Three parallel slot/category enums, kept in sync by hand.** `Item.ItemCategory` (`src/items/item.gd:4`), `Item.EquipSlot` (`item.gd:5`), and `Equipment.EquipSlot` (`src/items/equipment.gd:4`) overlap. `Equipment.slot_from_item_slot` (`equipment.gd:26-34`) and `Item.is_slot_consistent` (`item.gd:22-40`) exist solely to bridge them. Adding a new equipment category currently requires editing five places.
4. **Two parallel input conventions.** Action-based (`event.is_action_pressed("ui_up")`, ~17 files) and keycode-based (`KEY_UP, KEY_W` match, ~8 files) coexist. Neither is consistently used per scene. Title screen, town screen, character_creation use actions; dungeon_screen, esc_menu, combat_overlay, save/load screens use keycodes. There is no shared input router — each Control reimplements its own boilerplate.
5. **`Character.from_dict` silently returns broken characters.** `src/dungeon/character.gd:120,122` does `load("res://data/races/" + race_id + ".tres") as RaceData` with no null check. A renamed/missing race or job leaves `ch.race`/`ch.job == null` and the next call to `ch.race.race_name` (`src/esc_menu/esc_menu.gd:406`) crashes far from the load site.
6. **18 files reimplement `_unhandled_input` from scratch.** Same up/down/accept/cancel boilerplate, slightly different per file (action vs keycode, with/without `set_input_as_handled`). No shared `MenuController` mixin or helper.
7. **Two test files fall back to `pending()` when the random seed produces unsuitable terrain.** `tests/dungeon/test_dungeon_screen_encounter.gd:30,45,84,113,152` and `tests/dungeon/test_dungeon_screen_full_map.gd:71,100`. Tests skip rather than control the seed — they're non-deterministic on what they actually verify.
8. **`character_creation.gd` per-step input handlers are 80 % copy-paste.** Five `_input_stepN` methods (`src/guild_scene/character_creation.gd:188-301`) each repeat ui_up / ui_down / ui_accept / back / cancel with a different loop count. A step descriptor + dispatcher would cut this by ~60 %.
9. **`shop_screen.gd:_input_buy` and `_input_sell` are near-duplicates.** `src/town_scene/shop_screen.gd:277-302` vs `304-330` differ only in the underlying list and the "remove from list after action" tail.
10. **`pending` test markers and the `# TODO` in `main.gd:201` (multi-floor dungeons, hard-coded `floor=1` lookup at `:202`) are the only formal known-debt markers in source.** Most debt below is undocumented.

---

## Architectural mental model

DungeonMirundal2 is a Wizardry-style first-person dungeon RPG built on Godot 4.6 with GDScript. The runtime topology is a single `Control` (`src/main.gd`) that swaps full-screen scenes in and out via `_switch_screen`: title → town (hub of guild/shop/temple/dungeon-entrance) → dungeon (3D first-person view with overlays). A persistent `CanvasLayer` ESC menu (`src/esc_menu/esc_menu.gd`) sits on top of every non-title scene. Game data — characters, party, inventory, dungeons — lives on a single autoload (`src/game_state.gd`). Static reference data (races, jobs, monsters, items, encounter tables) is `.tres` files in `data/`, loaded once via `DataLoader` and looked up by id. Save/load serializes the autoload state to JSON in `user://saves/`.

Combat is a phase-based turn system (`TurnEngine` in `src/combat/`) wrapped by an overlay (`CombatOverlay`) that handles UI and per-phase input. Encounters are stepwise random rolls coordinated by `EncounterCoordinator`/`EncounterManager` and surfaced via `DungeonScreen.step_taken`. Dungeons are procedurally generated mazes (`WizMap`) with rooms-and-corridors plus extra links and doors. The "view" of a dungeon is a 4-deep cone-cast (`DungeonView.get_render_cells`) fed to an `ImmediateMesh` rebuilt every refresh (`DungeonScene._rebuild_mesh`). A separate `FullMapRenderer` produces a top-down image for the M-key overlay.

The architecture is reasonable for a small RPG and matches the readme. Where it strains is **at the seams between UI and game-state mutation**: many "screens" reach into `GameState` directly rather than receiving dependencies, and several UI classes have grown to encode their own multi-mode state machines instead of delegating. Tests are extensive (104 test files vs 104 src files; ~1.46:1 LOC ratio), which is why this audit doesn't recommend rewrites — the safety net is there to refactor incrementally.

The OpenSpec workflow under `openspec/` is the project's chosen way of capturing intent before implementation, and the archived changes under `openspec/changes/archive/` are the de facto changelog.

---

## Findings

| ID | Category | File:Line | Severity | Effort | Description | Recommendation |
|----|----------|-----------|----------|--------|-------------|----------------|
| F001 | Architectural decay | src/esc_menu/esc_menu.gd:1-773 | High | L | 772-LOC god class. 11-value `View` enum (`:9`); UI build, view switching, input, item-use sub-flow, equipment sub-flow, status display, and game-state mutation all coexist. Top-churned file (14 commits in 6 months). | Extract `ItemUseFlow` (`:540-650`) and `EquipmentFlow` (`:660-773`) into separate `Control` children that the menu just shows/hides. Keep `EscMenu` as a router. |
| F002 | Architectural decay | src/dungeon_scene/combat_overlay.gd:1-553 | High | L | 552-LOC overlay holds a 7-phase state machine (`:4-12`), four UI subpanels, dependency wiring, battle setup, per-phase input, and `_finalize_battle`'s level-up/gold logic (`:293-310`). | Move `_finalize_battle` reward computation (`:293-320`) into a `BattleResolver` RefCounted that returns a `BattleSummary`. Pull per-phase input handlers into one `CombatInputRouter` keyed by `Phase`. |
| F003 | Architectural decay | src/guild_scene/character_creation.gd:62-301 | High | M | 5-step wizard with 5 nearly identical `_build_stepN` + `_input_stepN` pairs. Boilerplate ratio ≈ 60 %. | Define a `Step` struct (`title`, `build()`, `handle_input(event)`, `can_advance()`) and drive both build and input from a single dispatcher. Removes `_input_step1..5` and the duplicated cancel/back paths. |
| F004 | Consistency rot | src/items/item.gd:4-5, src/items/equipment.gd:4 | High | M | Three overlapping enums: `Item.ItemCategory` (8), `Item.EquipSlot` (7 incl NONE), `Equipment.EquipSlot` (6). `Equipment.slot_from_item_slot` (`equipment.gd:26-34`) is a manual translation. `Item.is_slot_consistent` (`item.gd:22-40`) is a runtime cross-check that would be unnecessary if there were one source of truth. | Drop `Equipment.EquipSlot` entirely; index `Equipment._slots` directly by `Item.EquipSlot`. Keep `ItemCategory` as a higher-level grouping (so consumables are still distinguishable). Delete `slot_from_item_slot` and `is_slot_consistent`. |
| F005 | Consistency rot | 18 files (see grep below) | High | M | `_unhandled_input` boilerplate reimplemented per scene: ~17 files use `is_action_pressed`, ~8 use `KEY_*` match. Different "consume input" behaviour (some always call `set_input_as_handled`, some only on match). `src/dungeon_scene/dungeon_screen.gd:85-122`, `src/esc_menu/esc_menu.gd:224-284`, `src/save_screen.gd:105-127`, etc. | Add `MenuController` (RefCounted) with `route(event, handlers: Dictionary)`. Pick one convention (action-based is more remap-friendly) and migrate per-scene over time. Keep keycode-based for combat/dungeon real-time inputs only if movement bindings demand it. |
| F006 | Error handling | src/save_manager.gd:34-43 | High | S | `save()` returns void, swallows `FileAccess.open == null`. Same bug at `:127` and `:139` for last-slot pointer. UI shows "保存しました" regardless. | Change signature to `func save(slot_number: int) -> bool` and propagate to `SaveScreen._on_slot_selected` (`:134-140`). Render error label on failure. |
| F007 | Error handling | src/dungeon/character.gd:119-122 | High | S | `load("res://data/races/" + race_id + ".tres") as RaceData` with no null check. A bad save leaves `ch.race`/`ch.job` null; downstream `ch.race.race_name` (`src/esc_menu/esc_menu.gd:406`) and `ch.job` checks crash. | Validate after load; if either is null, return null from `from_dict` and have `Guild.from_dict` (`src/dungeon/guild.gd:99-100`) skip the entry with `push_warning`. |
| F008 | Error handling | src/dungeon/data/data_loader.gd:43-54 | Medium | S | `DirAccess.open == null` returns silently. If the directory is missing (e.g. typo, asset pack not exported), the game starts with empty races/jobs/monsters and silently breaks downstream (Character.create returns null, no items load). | `push_error` when dir is missing. Consider an `assert` in debug builds since this is a packaging error, not a runtime condition. |
| F009 | Error handling | src/main.gd:259-263 | Medium | S | `_load_game` ignores `save_manager.load()` failure beyond `return`. UI is in the load screen at this point; user gets no feedback. | Surface failure to `LoadScreen` so it can show "ロードに失敗しました". |
| F010 | Architectural decay | src/dungeon_scene/dungeon_scene.gd:11-19, 55-63 | Low | S | `DungeonScene` instantiates its own `DungeonView` (`:19`) used only as a fallback when `refresh()` is called with empty `visible_cells`. In practice `DungeonScreen` always supplies the cells (`src/dungeon_scene/dungeon_screen.gd:75-82`). | Remove the fallback; require callers to pass `visible_cells`, drop `_dungeon_view` field. |
| F011 | Architectural decay | src/dungeon_scene/encounter_overlay.gd, src/dungeon_scene/combat_overlay.gd:44 | Medium | S | `EncounterOverlay` is *both* a concrete class (used in tests and as the default wired in `EncounterCoordinator._ready`) and a base class for `CombatOverlay`. `CombatOverlay._ready` does not call `super._ready()`, so the parent's `_build_ui` is dead in the combat path but live elsewhere. The contract is implicit. | Make `EncounterOverlay` an interface-shaped abstract (no `_ready`/`_build_ui` of its own), promote the simple-encounter UI to a `SimpleEncounterOverlay` subclass. Tests that need the simple flow use the named subclass. |
| F012 | Test debt | tests/dungeon/test_dungeon_screen_encounter.gd:30,45,84,113,152; tests/dungeon/test_dungeon_screen_full_map.gd:71,100 | High | M | Tests `pending(...)` when a randomly generated dungeon doesn't have the topology they need. The "test" then asserts nothing about the encounter flow at all. | Generate a fixture map with `DungeonData.create("...", deterministic_seed, size)` and assert against known coordinates. If a generic map is needed, keep retrying seeds until one matches the requirement, then run the test once. Never `pending` for terrain shape. |
| F013 | Test debt | tests/dungeon_scene/ | Low | XS | Empty directory. `.gutconfig.json` doesn't include it; nothing references it. | Delete the directory. |
| F014 | Architectural decay | src/town_scene/shop_screen.gd:277-330 | Medium | S | `_input_buy` and `_input_sell` differ only in the data source (`get_buy_catalog` vs `get_sell_candidates`) and the post-action position fix-up. ~80 % overlap. | Extract `_handle_list_input(event, count, on_accept: Callable)`. |
| F015 | Architectural decay | src/town_scene/temple_screen.gd:62-67 | Low | XS | `revive` checks `gold < cost` (`:62`) then calls `spend_gold` (`:65`) which checks the same thing. Two error paths set the same message. | Drop the manual `gold < cost` check; rely on `spend_gold` returning false. |
| F016 | Performance | src/dungeon/full_map_renderer.gd:40-42, 100-105, 113-115 | Low | M | Full-map render uses `img.set_pixel` in nested loops. For a max-size 30×30 map at, say, 20px cells, ≈360k `set_pixel` calls per redraw. Fine for a once-per-keypress overlay, but it scales worst-case >5× the current default. | If perf becomes an issue, replace floor/player block fills with a single `img.fill_rect()` per cell. Defer until a profiler shows it. |
| F017 | Performance | src/dungeon_scene/dungeon_scene.gd:73-89 | Low | M | `_rebuild_mesh` reconstructs the `ImmediateMesh` every refresh including on simple turns (no cell-set change). Acceptable today (≤25 cells), but `_cached_visible_cells` is recomputed per call. | Cache by `(position, facing)` and skip rebuild on identical input. Defer until profiler shows it. |
| F018 | Type & contract debt | src/dungeon/wiz_map.gd:124, src/items/equipment.gd:116, src/dungeon_scene/combat_overlay.gd:234, src/items/item_instance.gd:23, src/items/effects/heal_hp_effect.gd:10, src/items/effects/heal_mp_effect.gd:10, src/dungeon/full_map_renderer.gd:49, src/guild_scene/party_formation.gd:126, src/combat/turn_engine.gd:64,98 | Medium | S | 11 declarations in the form `var x = something_with_unknown_type`. GDScript silently treats them as Variant. Most are Dictionary `.get()` results that should be cast. | Add explicit types. Especially `var cmd = _pending_commands.get(...)` (`turn_engine.gd:64,98`) — this is on a hot turn-resolution path. |
| F019 | Type & contract debt | src/dungeon/explored_map.gd:12 | Low | XS | `mark_visible(cells: Array)` should be `Array[Vector2i]`. The only caller (`src/dungeon_scene/dungeon_screen.gd:80`) already uses `Array[Vector2i]`. | Tighten the parameter type. |
| F020 | Type & contract debt | src/dungeon/guild.gd:45-47 | Low | S | `get_party_characters` returns `Array` (containing 2 `Array`s of `Character|null`). Callers (`src/dungeon_scene/combat_overlay.gd:469`) iterate with `for row in rows: for ch in row` and rely on convention. | Either return `Array[Array]` with documented invariant, or refactor to `Array[Character]` (flat) plus a `row_of(ch)` helper. |
| F021 | Type & contract debt | src/dungeon/wiz_map.gd:218, 220 | Low | XS | `maxi(5, mini(8, map_size / 3 + 1) as int)` and `maxi(2, (map_size / 4) as int)` — the `as int` is redundant since `mini`/integer division already return int. Likely leftover from a refactor. | Drop the `as int` casts. |
| F022 | Consistency rot | src/dungeon_scene/dungeon_screen.gd:110-122 vs src/esc_menu/esc_menu.gd:226-242 | Low | S | Two different conventions for movement keys: `KEY_W`/`KEY_S`/`KEY_A`/`KEY_D` (dungeon) vs `KEY_UP`/`KEY_DOWN`/`KEY_W`/`KEY_S` (menus). Both work; future contributors won't know which to follow. | Document in CLAUDE.md or a `docs/conventions.md`: action-based for menus, keycode-based for movement, both KEY_arrow + WASD wherever applicable. |
| F023 | Architectural decay | src/main.gd:103-115 | Medium | S | Top-level ESC handling reaches into `_encounter_coordinator.is_encounter_active()`, `_esc_menu.is_menu_visible()`, and the `_current_screen is TitleScreen` discriminator. Three independent gates of "something else owns input now". | Replace with a `_input_blocked_by: Array[Node]` set or a `consumes_global_esc()` virtual on screens. |
| F024 | Architectural decay | src/main.gd:7,202-205 | Medium | S | `_encounter_tables_by_floor` keyed by floor int, but only floor 1 exists; `_attach_encounter_coordinator_to_screen` hard-codes `.get(1, null)`. The `# TODO` (`:201`) acknowledges this. Currently load-bearing for first dungeon only. | When multi-floor lands: read `dungeon_data.current_floor` (does not exist yet). Until then, replace the dictionary with a single `_floor_1_table` field; the dictionary lookup is misleading. |
| F025 | Documentation drift | docs/reference/first_plan.md vs implementation | Low | S | First plan describes "地上へ戻ったらHPを全回復, 死亡以外の状態異常も解除". The first half is implemented (`src/game_state.gd:34-42`), the second half — status effects — has no implementation surface (no `status_effect.gd`, no condition-removal calls). | Either implement minimal status-effect framework (currently absent) or update the plan to scope it out. |
| F026 | Documentation drift | docs/reference/first_plan.md, src/data | Low | XS | `first_plan.md` is a snapshot from project inception. Several decisions captured there have evolved (e.g. equipment slots count). Reads as authoritative but isn't. | Add a top banner: "Snapshot from project start. Authoritative spec lives in `openspec/specs/`." |
| F027 | Architectural decay | src/items/equipment.gd:37-42, 68-78 | Low | S | `can_equip` and `equip` re-implement the same validation (slot match + job allowed). Subtly different shapes — `can_equip` returns bool, `equip` returns `EquipResult` with a reason — but the gating logic duplicates. | `equip` should call `can_equip` once and use a single `EquipFailure` reason mapping. |
| F028 | Test debt | src/inventory.gd implicit | Low | S | `Inventory.spend_gold(0)` returns `false` (`src/items/inventory.gd:41-42`). Most callers expect true on a no-op spend. Currently never triggered because no caller passes 0, but it is a footgun. | Treat amount==0 as a successful no-op (return true) or document the contract. |
| F029 | Performance | src/items/inventory.gd:26-27 | Low | XS | `list()` returns `_items.duplicate()` on every call. Some hot paths call it inside loops (e.g. `src/esc_menu/esc_menu.gd:444,465,471,489,494`). | Either accept (small N) or cache an "active" snapshot when the inventory mutates. Defer until profiler shows it. |
| F030 | Type & contract debt | src/game_state.gd:25-31 | Medium | S | `new_game()` rebuilds `guild`, `dungeon_registry`, `inventory`, `gold`, `game_location`, `current_dungeon_index` but not `item_repository`. The `_ready` (`:17-22`) is the only initializer and runs once on autoload. If `new_game` is called twice (which it can be, via title→play→quit-to-title→new), state is fine — but the asymmetry between `_ready` and `new_game` is a hazard for adding new GameState fields. | Have `new_game` go through a single `_initialize_state()` helper that also runs from `_ready`. |
| F031 | Architectural decay | src/dungeon_scene/dungeon_screen.gd:165-220 | Low | S | The "return to town?" dialog is built ad-hoc inside `_show_return_dialog`. The same shape exists in `src/town_scene/dungeon_entrance.gd:179-234` (delete confirm) and `src/save_screen.gd:78-103` (overwrite confirm) and `src/esc_menu/esc_menu.gd:124-126` (quit confirm). | Extract a `ConfirmDialog` Control. Three or four similar inline implementations is the threshold. |
| F032 | Consistency rot | data/items/potion.tres, data/items/magic_potion.tres | Low | XS | Sibling items use prefixed (`magic_potion`) and unprefixed (`potion`) names. Other items (`leather_armor`, `wooden_shield`) follow `material_kind` consistently. | Rename `potion.tres` to `healing_potion.tres` (and update its `item_id`) for consistency. |
| F033 | Architectural decay | src/dungeon_scene/combat_overlay.gd:201-249 | Low | S | The item-use sub-flow inside CombatOverlay (`_open_item_selector` → `_on_item_selector_item_selected` → `_valid_item_targets` → `_commit_item_command`) duplicates the flow already implemented in `src/esc_menu/esc_menu.gd:540-650`. Different `ItemUseContext` (in_combat true vs false) but same shape. | Extract `ItemUseFlow` controller used by both. Will also make F001 lighter. |
| F034 | Type & contract debt | src/items/item.gd:58 | Low | XS | `get_target_failure_reason(target, ctx)` — `target` is untyped. Callers pass either `Character` or `CombatActor`. | Define a `Targetable` interface or accept both with explicit overloads. At minimum, type-hint as `Variant` and document. |
| F035 | Architectural decay | src/main.gd:32, 209-212 | Medium | S | `_equipment_provider = InventoryEquipmentProvider.new()` is created once in `main.gd:_setup_encounter_coordinator` and never reconfigured. `_refresh_combat_overlay_dependencies` rewires it on every dungeon attach. The provider's lifecycle matches the run; the per-attach refresh is dead defensive code. | Wire dependencies once at `_setup_encounter_coordinator`; drop `_refresh_combat_overlay_dependencies` unless multi-guild support arrives. |
| F036 | Architectural decay | src/dungeon/full_map_renderer.gd:108-116 | Low | S | `_draw_player` overpaints the player cell with `COLOR_PLAYER`, erasing the START/GOAL marker if the player is standing on one. May or may not be intentional. | Either preserve the marker (composite a smaller player dot) or document that player position takes precedence. |
| F037 | Architectural decay | src/combat/turn_engine.gd:178-189 | Medium | S | `_resolve_attack` silently retargets to a random alive enemy when the original target died earlier in the turn (`:181`). User picked the slime, slime dies turn-start, attack now lands on whichever alive monster `_pick_living_same_side_as` returns. Could surprise players. | At minimum, surface the retarget in `TurnReport` so the combat log can say "X attacked Y instead". Currently the log shows the substitute as if the player chose it. |
| F038 | Architectural decay | src/dungeon_scene/combat_overlay.gd:277-283 | Low | S | `await get_tree().create_timer(log_line_delay).timeout` inside a for-loop blocks the function but can race with input if the user closes the overlay mid-sequence (encounter_resolved or visible=false during await). Probably fine because input is gated by `_is_active`, but the await chain is fragile. | Use a `Tween` or a `Timer` node so the playback is cancellable. |
| F039 | Test debt | tests/save_load/test_main_dungeon_entry.gd, tests/save_load/test_main_save_load.gd | Low | M | High-level main.gd flows are covered, but `_load_game` failure paths (corrupt JSON, version mismatch) appear untested in `tests/save_load/test_save_manager.gd`. Search for "version" in tests returns no `> CURRENT_VERSION` cases. | Add one test for `version > CURRENT_VERSION` (returns false, GameState unchanged) and one for malformed JSON. |
| F040 | Architectural decay | src/dungeon/explored_map.gd:30, src/dungeon/dungeon_data.gd:48 | Low | XS | `to_dict` stores positions as `[x, y]` pairs (`explored_map.gd:30-31`). Saves bloat: a 30×30 map fully explored → 900 two-element arrays = ~9 KB just for the explored map. Default JSON pretty-print (`save_manager.gd:33` uses `\t`) doubles that. | Either store as a packed string (`"x,y;x,y;..."`) or stop using `\t` indent (replace with `""`) for save files. The pretty form was likely a debugging aid. |
| F041 | Consistency rot | src/title_scene/title_screen.gd:64-75 | Low | XS | `_unhandled_input` does not handle ESC. Every other menu screen has an ESC path (some to back, some to no-op). On title there is nothing to ESC to, but consistency would say "ignore explicitly". | Add an explicit no-op match arm for KEY_ESCAPE so future readers don't think it was forgotten. |
| F042 | Documentation drift | README.md:7,107-111 | Low | XS | Readme says "Godot Engine 4.6+". `project.godot:20` declares `config/features=PackedStringArray("4.6")` exactly. The "4.6+" claim is unverified — opening in 4.7 would auto-migrate the project file. | Either pin to "4.6.x" in the readme or test on 4.7. |
| F043 | Architectural decay | src/items/conditions/, src/items/effects/ | Low | XS | Effects subdirectory has 4 effects (`heal_hp_effect`, `heal_mp_effect`, `escape_to_town_effect`, plus the abstract `item_effect.gd`). Conditions has 7. Each is a tiny RefCounted file. The split-by-subtype is fine, but `item_use_context.gd` lives under `conditions/` while it's used by both effects and conditions. | Move `item_use_context.gd` and `item_effect_result.gd` up to `src/items/`. |
| F044 | Test debt | tests/items/, src/items/conditions/has_mp_slot.gd | Low | XS | `HasMpSlot` (14 LOC) has no targeted test. It's exercised indirectly via `test_item_conditions.gd`. | If kept, add one direct test; if redundant with broader test, leave a comment. |
| F045 | Architectural decay | src/town_scene/town_screen.gd:200-204 | Low | XS | `select_item` uses `match index: 0:..1:..2:..3:..` for the 4 facilities. Brittle if the menu order changes. | Keep `MENU_ITEMS` as `Array[Dictionary]` `{ label, signal_name }` or use named constants like `MAIN_IDX_*` already used in `esc_menu.gd:13-16`. |
| F046 | Architectural decay | src/main.gd:170-179 | Low | XS | `_on_open_dungeon_entrance` reaches into `GameState.guild.has_party_members()` to gate the entrance UI's enter button. The `DungeonEntrance` itself stores `_has_party` and never re-asks. If the user creates a party while the entrance is open (impossible in current UX) the button stays disabled. | Pass the `Guild` reference; let `DungeonEntrance` query freshly. Trivial change, future-proofs. |
| F047 | Type & contract debt | src/dungeon/character.gd:97 | Low | XS | `race.resource_path.get_file().get_basename()` infers the id from the file name. Brittle if a `.tres` is renamed without rebuilding the data folder. | `RaceData` and `JobData` should expose an explicit `id: StringName` field. Save uses that field instead of the path. |
| F048 | Documentation drift | openspec/specs/ vs implementation | Low | M | 47 specs in `openspec/specs/`. Most are accurate (recent changes flow through OpenSpec), but `character-creation`, `equipment` etc. encode the current god-class shape. Refactoring per F003/F004 will require sympathetic spec updates. | Out of scope for this audit, but plan: any refactor that touches a god class should produce an OpenSpec change first to preserve the spec's authority. |

**Total findings: 48** (3 High-likelihood-of-breaking, ~20 Medium structure/consistency, rest Low/XS cleanup).

---

## Top 5 — if you fix nothing else, fix these

### 1. F006 — Make `SaveManager.save` return success/failure (Effort: S)

Today, a full disk or revoked write permission still ends up showing "保存しました". Save UX is the place where silent failures are most damaging.

```gdscript
# src/save_manager.gd
func save(slot_number: int) -> bool:
	_ensure_dir()
	var inv: Inventory = GameState.inventory
	var data := { ... }
	var f := FileAccess.open(_slot_path(slot_number), FileAccess.WRITE)
	if f == null:
		push_error("save: cannot open %s (err=%d)" % [_slot_path(slot_number), FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var lf := FileAccess.open(_last_slot_path(), FileAccess.WRITE)
	if lf == null:
		push_error("save: cannot write last_slot pointer")
		return false  # data is saved but pointer isn't — still surface to user
	lf.store_string(str(slot_number))
	lf.close()
	return true
```

Then propagate to `SaveScreen._on_slot_selected` and `_handle_overwrite_input` (`src/save_screen.gd:129-161`) so failure renders an error label instead of `save_completed.emit()`.

### 2. F007 — Validate race/job after `load()` in `Character.from_dict` (Effort: S)

```gdscript
# src/dungeon/character.gd  from_dict
var race_id: String = data.get("race_id", "human")
ch.race = load("res://data/races/" + race_id + ".tres") as RaceData
if ch.race == null:
	push_warning("Character.from_dict: missing race '%s', skipping character" % race_id)
	return null
var job_id: String = data.get("job_id", "fighter")
ch.job = load("res://data/jobs/" + job_id + ".tres") as JobData
if ch.job == null:
	push_warning("Character.from_dict: missing job '%s', skipping character" % job_id)
	return null
```

Then in `Guild.from_dict` (`src/dungeon/guild.gd:99-100`), skip null returns instead of registering them. Combine with F047 to remove the path-based id fragility entirely.

### 3. F004 — Collapse the three slot/category enums (Effort: M)

Steps:

- Delete `Equipment.EquipSlot` (`src/items/equipment.gd:4`).
- Replace `_slots: Dictionary` keyed by `Equipment.EquipSlot` with `_slots: Dictionary` keyed by `Item.EquipSlot` (skipping `NONE`).
- Update `EQUIPMENT_SLOT_VALUES` in `src/esc_menu/esc_menu.gd:25-32` to use `Item.EquipSlot`.
- Delete `Equipment.slot_from_item_slot` and `Item.is_slot_consistent`. Replace `is_slot_consistent` callers (search: `is_slot_consistent`) with a single load-time check in tests.
- Tests under `tests/items/test_equipment.gd` and `test_item.gd` will need parameter updates.

### 4. F012 — Make `tests/dungeon/test_dungeon_screen_*` deterministic (Effort: M)

Replace the seed-and-pray pattern with explicit fixtures. Either:

- Use a hand-built `WizMap.new(8)` plus targeted `set_edge` calls to construct exactly the configuration the test needs (open forward, blocked forward, near start tile). This is the cleanest.
- Or, retry seeds in a `for seed in range(0, 1000)` until the topology check passes; fail the test if no seed matches.

`pending()` is a no-op in `should_exit=true` GUT runs and falsely reports green CI.

### 5. F005 + F003 — Extract a shared `MenuController` and refactor `character_creation` to step descriptors (Effort: M each, do together)

```gdscript
# src/ui/menu_controller.gd
class_name MenuController
extends RefCounted

static func handle(event: InputEvent, menu: CursorMenu, rebuild: Callable, on_accept: Callable, on_back: Callable) -> bool:
	if event.is_action_pressed("ui_down"):
		menu.move_cursor(1); rebuild.call(); return true
	elif event.is_action_pressed("ui_up"):
		menu.move_cursor(-1); rebuild.call(); return true
	elif event.is_action_pressed("ui_accept"):
		on_accept.call(); return true
	elif event.is_action_pressed("ui_cancel"):
		on_back.call(); return true
	return false
```

Then `title_screen.gd`, `town_screen.gd`, `temple_screen.gd`, the top-level menu of `shop_screen.gd`, and most of `dungeon_entrance.gd` collapse to ~5 lines of `_unhandled_input`. Migrate per-file as opportunities arise.

For F003, define a `Step` descriptor:

```gdscript
class Step:
	var title: String
	var build: Callable  # () -> void, builds rows into _content
	var input: Callable  # (InputEvent) -> bool
	var can_advance: Callable  # () -> bool
```

Then `_build_step_ui` becomes one line and `_unhandled_input` dispatches to `_steps[current_step - 1].input`.

---

## Quick wins

- [ ] F010 — Drop the unused `DungeonView` fallback in `DungeonScene.refresh`
- [ ] F013 — Delete empty `tests/dungeon_scene/` directory
- [ ] F015 — Drop redundant `gold < cost` guard in `TempleScreen.revive`
- [ ] F019 — Type `ExploredMap.mark_visible(cells: Array[Vector2i])`
- [ ] F021 — Drop redundant `as int` casts in `wiz_map.gd:218,220`
- [ ] F032 — Rename `data/items/potion.tres` → `healing_potion.tres`
- [ ] F035 — Drop dead `_refresh_combat_overlay_dependencies`
- [ ] F040 — Drop `\t` pretty-print from `JSON.stringify` in save files
- [ ] F041 — Add explicit ESC no-op in `title_screen.gd`
- [ ] F042 — Pin or verify Godot version in README
- [ ] F043 — Move `item_use_context.gd` out of `conditions/`

---

## Things that look bad but are actually fine

- **`WizMap.add_extra_links` partial Fisher-Yates** (`src/dungeon/wiz_map.gd:111-129`) — the inline comment explains it: `Array.shuffle()` uses its own RNG, which would break seed reproducibility. Manual shuffle is the right call here, not a code smell.

- **`assert(size >= 8, ...)` in `WizMap._init`** (`src/dungeon/wiz_map.gd:9`) — looks fragile because asserts are stripped from release builds. But the readme (`README.md:93`) and the calling code (`DungeonRegistry.SIZE_RANGES` at `src/dungeon/dungeon_registry.gd:8-12`) all guarantee size ≥ 8 via the size-category enum. The assert is a debug-only sanity rail, not validation.

- **`_pick_living_same_side_as` retarget in `TurnEngine`** (`src/combat/turn_engine.gd:202-210`) — retargeting a dead target's hit to another living enemy is a real combat decision (not a bug). Many JRPGs do this. F037 is about *visibility* (the log doesn't say it happened), not about removing the behavior.

- **`_encounter_rng.randomize()` in production** (`src/main.gd:30-31`) — randomized per-run is the right call for a roguelike-ish game. The places that need determinism use their own `RandomNumberGenerator` with explicit seeds (`DungeonData.create`).

- **`CursorMenu.move_cursor` skipping disabled entries by full wrap-around** (`src/dungeon/cursor_menu.gd:22-30`) — the `for _i in range(count)` loop with reset to `start` if all are disabled looks paranoid, but it's the correct way to avoid an infinite loop when every item is disabled. Don't simplify.

- **`EncounterOverlay` having both standalone-functional and base-class roles** (F011) — looks like a smell but is *deliberately* a substitution surface for tests. The pattern works; the cleanup in F011 is purely cosmetic.

- **All `_items.duplicate()` returns from `Inventory`/`Guild`/`DungeonRegistry`** (F029) — defensive copies on container accessors prevent callers from mutating internal state. The cost is real but the bug-prevention benefit is also real. Don't optimize this away without a profiler.

- **JSON-with-tabs save format** (`src/save_manager.gd:33`) — looks like wasted bytes (F040 calls it out as Low) but makes saves diff-friendly during development. Whether to keep it for shipped builds is a real call; it is *not* incompetence.

- **`tmp/` directory committed-in-feel** — checked: `tmp/` is in `.gitignore` (`.gitignore:8-9`) and `git ls-files tmp/` returns nothing. The PNGs are local screenshots, properly ignored.

- **`.gutconfig.json` listing `tests/town/` even though I initially saw it as missing** — `tests/town/` does exist with `test_shop_screen.gd`, `test_temple_screen.gd`, `test_town_screen.gd`. False alarm during exploration.

---

## Open questions for the maintainer

1. **Multi-floor dungeons** (F024) — is this a planned feature with an OpenSpec change drafted, or aspirational? `main.gd:201` TODO + single `floor_1.tres` table suggests planned but not started.

2. **`first_plan.md` status** (F025, F026) — is this an authoritative snapshot of intent, or superseded by the OpenSpec workflow? Status effects (described in `first_plan.md:7`) have no implementation surface — was that descoped intentionally?

3. **`FullMapRenderer._draw_player` overdrawing START/GOAL** (F036) — intentional? If the start tile is also the player tile (just entered the dungeon), the marker is invisible until the player moves.

4. **Dual input conventions** (F004 / F022) — was the action-based vs keycode-based split deliberate (e.g. movement wants both arrows AND WASD without action remapping in project.godot), or did files drift?

5. **`tests/dungeon/test_dungeon_screen_*.gd` `pending()` calls** (F012) — are these intentional acknowledgements of "this test is environment-dependent" or just stalled work? If the latter, they currently report green CI for tests that did nothing.

6. **The `is_slot_consistent` mechanism** (`src/items/item.gd:22-40`, F004) — is there a place this is actually called at runtime (asset-load validation, item-editor)? If only tests call it, F004 becomes safer.

7. **`_overwrite_slot` in `SaveScreen`** (`src/save_screen.gd:18`) — there's no rate limit or confirm-twice. If a hand slips and confirms overwrite of the wrong slot, the previous save is gone. Acceptable for a personal RPG, but worth confirming.

8. **`tmp/after*.png`** — manual-test artifacts from a recent OpenSpec change verification. Should the workflow document where these go, or are they purely ad-hoc?
