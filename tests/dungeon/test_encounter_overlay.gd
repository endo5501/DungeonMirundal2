extends GutTest

const TEST_SEED: int = 12345


func _make_monster_data(id: StringName, name: String) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = name
	data.max_hp_min = 5
	data.max_hp_max = 5
	return data


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _make_party(species_counts: Dictionary) -> MonsterParty:
	var party := MonsterParty.new()
	for id in species_counts.keys():
		var display_name := String(id).capitalize()
		var data := _make_monster_data(id, display_name)
		for i in range(species_counts[id]):
			party.add(Monster.new(data, _make_rng()))
	return party


# --- structural ---

func test_overlay_is_canvas_layer():
	var overlay := EncounterOverlay.new()
	assert_is(overlay, CanvasLayer)
	overlay.free()


func test_overlay_initially_hidden():
	var overlay := EncounterOverlay.new()
	add_child_autofree(overlay)
	assert_false(overlay.visible)


func test_overlay_layer_matches_esc_menu():
	var overlay := EncounterOverlay.new()
	assert_eq(overlay.layer, 10)
	overlay.free()


# --- start_encounter ---

func test_start_encounter_makes_overlay_visible():
	var overlay := EncounterOverlay.new()
	add_child_autofree(overlay)
	overlay.start_encounter(_make_party({&"slime": 2}))
	assert_true(overlay.visible)


func test_start_encounter_renders_monster_names():
	var overlay := EncounterOverlay.new()
	add_child_autofree(overlay)
	overlay.start_encounter(_make_party({&"slime": 2, &"goblin": 1}))
	var text := overlay.get_display_text()
	assert_string_contains(text, "Slime")
	assert_string_contains(text, "Goblin")


func test_start_encounter_formats_counts():
	var overlay := EncounterOverlay.new()
	add_child_autofree(overlay)
	overlay.start_encounter(_make_party({&"slime": 3}))
	var text := overlay.get_display_text()
	assert_string_contains(text, "x3")


func test_single_monster_omits_count_suffix_or_shows_x1():
	var overlay := EncounterOverlay.new()
	add_child_autofree(overlay)
	overlay.start_encounter(_make_party({&"goblin": 1}))
	var text := overlay.get_display_text()
	assert_string_contains(text, "Goblin")


# --- resolve signal ---

func test_resolve_emits_signal_with_cleared_outcome():
	var overlay := EncounterOverlay.new()
	add_child_autofree(overlay)
	watch_signals(overlay)
	overlay.start_encounter(_make_party({&"slime": 2}))
	overlay.resolve()
	assert_signal_emitted(overlay, "encounter_resolved")
	var params = get_signal_parameters(overlay, "encounter_resolved")
	assert_not_null(params)
	var outcome: EncounterOutcome = params[0]
	assert_eq(outcome.result, EncounterOutcome.Result.CLEARED)


func test_resolve_hides_overlay():
	var overlay := EncounterOverlay.new()
	add_child_autofree(overlay)
	overlay.start_encounter(_make_party({&"slime": 1}))
	overlay.resolve()
	assert_false(overlay.visible)


func test_resolve_does_not_double_emit():
	var overlay := EncounterOverlay.new()
	add_child_autofree(overlay)
	watch_signals(overlay)
	overlay.start_encounter(_make_party({&"slime": 1}))
	overlay.resolve()
	overlay.resolve()  # second call should be a no-op
	assert_signal_emit_count(overlay, "encounter_resolved", 1)


# --- input consumption ---

func test_confirm_key_dismisses_overlay():
	var overlay := EncounterOverlay.new()
	add_child_autofree(overlay)
	watch_signals(overlay)
	overlay.start_encounter(_make_party({&"slime": 1}))
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	overlay._unhandled_input(event)
	assert_signal_emitted(overlay, "encounter_resolved")
	assert_false(overlay.visible)


func test_other_keys_do_not_dismiss():
	var overlay := EncounterOverlay.new()
	add_child_autofree(overlay)
	watch_signals(overlay)
	overlay.start_encounter(_make_party({&"slime": 1}))
	var event := InputEventKey.new()
	event.keycode = KEY_A
	event.pressed = true
	overlay._unhandled_input(event)
	assert_signal_not_emitted(overlay, "encounter_resolved")
	assert_true(overlay.visible)
