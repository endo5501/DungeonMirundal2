extends GutTest

const TEST_SEED: int = 12345


func _make_monster_data(id: StringName, name: String) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = name
	data.max_hp_min = 5
	data.max_hp_max = 5
	return data


func _make_group(id: StringName, min_count: int, max_count: int) -> MonsterGroupSpec:
	var spec := MonsterGroupSpec.new()
	spec.monster_id = id
	spec.count_min = min_count
	spec.count_max = max_count
	return spec


func _make_pattern(groups: Array[MonsterGroupSpec]) -> EncounterPattern:
	var pattern := EncounterPattern.new()
	pattern.groups = groups
	return pattern


func _make_entry(pattern: EncounterPattern, weight: int) -> EncounterEntry:
	var entry := EncounterEntry.new()
	entry.pattern = pattern
	entry.weight = weight
	return entry


func _make_always_trigger_table() -> EncounterTableData:
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 1.0  # always triggers
	table.entries = [_make_entry(_make_pattern([_make_group(&"slime", 2, 2)]), 1)]
	return table


func _make_never_trigger_table() -> EncounterTableData:
	var table := EncounterTableData.new()
	table.floor = 1
	table.probability_per_step = 0.0  # never triggers
	table.entries = [_make_entry(_make_pattern([_make_group(&"slime", 2, 2)]), 1)]
	return table


func _make_repository() -> MonsterRepository:
	var repo := MonsterRepository.new()
	repo.register(_make_monster_data(&"slime", "Slime"))
	repo.register(_make_monster_data(&"goblin", "Goblin"))
	return repo


func _make_map(start_pos: Vector2i) -> WizMap:
	var wiz_map := WizMap.new(8)
	wiz_map.generate(42)
	for y in range(wiz_map.map_size):
		for x in range(wiz_map.map_size):
			if wiz_map.cell(x, y).tile == TileType.START:
				wiz_map.cell(x, y).tile = TileType.FLOOR
	wiz_map.cell(start_pos.x, start_pos.y).tile = TileType.START
	return wiz_map


func _make_screen() -> DungeonScreen:
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var wiz_map := _make_map(Vector2i(7, 7))
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	return screen


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


# --- basic ---

func test_coordinator_is_node():
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng())
	add_child_autofree(coord)
	assert_is(coord, Node)


func test_coordinator_owns_overlay_after_ready():
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng())
	add_child_autofree(coord)
	assert_not_null(coord.get_overlay())


func test_coordinator_encounter_inactive_initially():
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng())
	add_child_autofree(coord)
	assert_false(coord.is_encounter_active())


# --- step_taken -> encounter flow ---

func test_step_taken_with_triggering_table_shows_overlay():
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng())
	add_child_autofree(coord)
	coord.set_table(_make_always_trigger_table())
	var screen := _make_screen()
	coord.attach_screen(screen)
	screen.step_taken.emit(Vector2i(4, 4))
	assert_true(coord.get_overlay().visible)
	assert_true(coord.is_encounter_active())


func test_step_taken_with_non_triggering_table_keeps_overlay_hidden():
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng())
	add_child_autofree(coord)
	coord.set_table(_make_never_trigger_table())
	var screen := _make_screen()
	coord.attach_screen(screen)
	screen.step_taken.emit(Vector2i(4, 4))
	assert_false(coord.get_overlay().visible)
	assert_false(coord.is_encounter_active())


func test_encounter_activates_screen_guard():
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng())
	add_child_autofree(coord)
	coord.set_table(_make_always_trigger_table())
	var screen := _make_screen()
	coord.attach_screen(screen)
	screen.step_taken.emit(Vector2i(4, 4))
	assert_true(screen.is_encounter_active())


# --- resolution ---

func test_overlay_resolve_clears_encounter_state():
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng())
	add_child_autofree(coord)
	coord.set_table(_make_always_trigger_table())
	var screen := _make_screen()
	coord.attach_screen(screen)
	screen.step_taken.emit(Vector2i(4, 4))
	coord.get_overlay().resolve()
	assert_false(coord.is_encounter_active())
	assert_false(screen.is_encounter_active())


func test_resolve_emits_encounter_finished_signal():
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng())
	add_child_autofree(coord)
	coord.set_table(_make_always_trigger_table())
	var screen := _make_screen()
	coord.attach_screen(screen)
	watch_signals(coord)
	screen.step_taken.emit(Vector2i(4, 4))
	coord.get_overlay().resolve()
	assert_signal_emitted(coord, "encounter_finished")


# --- attach/detach safety ---

func test_detach_screen_disconnects_step_taken():
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng())
	add_child_autofree(coord)
	coord.set_table(_make_always_trigger_table())
	var screen := _make_screen()
	coord.attach_screen(screen)
	coord.detach_screen()
	screen.step_taken.emit(Vector2i(4, 4))
	assert_false(coord.get_overlay().visible, "detached screen must not trigger overlay")


func _make_unmanaged_screen() -> DungeonScreen:
	# Screen that is NOT autofreed; caller is responsible for lifecycle.
	var screen := DungeonScreen.new()
	add_child(screen)
	var wiz_map := _make_map(Vector2i(7, 7))
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	return screen


func test_detach_after_screen_freed_does_not_error():
	# Simulates leaving the dungeon through paths that free the screen
	# without calling detach (ESC quit, save/load while in dungeon).
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng())
	add_child_autofree(coord)
	var screen := _make_unmanaged_screen()
	coord.attach_screen(screen)
	screen.free()  # screen reference now invalid
	coord.detach_screen()  # must not touch the freed object
	assert_false(coord.is_encounter_active())


func test_attach_after_previous_screen_freed_does_not_error():
	# New DungeonScreen enters while coordinator still holds a stale
	# reference to a freed previous screen. attach_screen must not error.
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng())
	add_child_autofree(coord)
	coord.set_table(_make_always_trigger_table())
	var old_screen := _make_unmanaged_screen()
	coord.attach_screen(old_screen)
	old_screen.free()
	var new_screen := _make_screen()
	coord.attach_screen(new_screen)
	new_screen.step_taken.emit(Vector2i(4, 4))
	assert_true(coord.is_encounter_active(),
		"new screen must be wired correctly after freed-predecessor recovery")


# --- cooldown propagation ---

func test_cooldown_suppresses_consecutive_encounters():
	var coord := EncounterCoordinator.new(_make_repository(), _make_rng(), 3)
	add_child_autofree(coord)
	coord.set_table(_make_always_trigger_table())
	var screen := _make_screen()
	coord.attach_screen(screen)
	screen.step_taken.emit(Vector2i(4, 4))
	coord.get_overlay().resolve()
	# next 3 steps should NOT trigger
	for i in range(3):
		screen.step_taken.emit(Vector2i(4, 4))
		assert_false(coord.is_encounter_active(),
			"step %d should be suppressed by cooldown" % i)
