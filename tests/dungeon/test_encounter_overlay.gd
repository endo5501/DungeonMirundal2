extends GutTest

# EncounterOverlay is the abstract base for SimpleEncounterOverlay and CombatOverlay.
# Concrete UI behavior is tested via test_simple_encounter_overlay.gd.

func test_overlay_is_canvas_layer():
	var overlay := EncounterOverlay.new()
	assert_is(overlay, CanvasLayer)
	overlay.free()


func test_overlay_layer_matches_esc_menu():
	var overlay := EncounterOverlay.new()
	assert_eq(overlay.layer, 10)
	overlay.free()


func test_encounter_resolved_signal_defined_on_base():
	var overlay := EncounterOverlay.new()
	var signals := overlay.get_signal_list()
	var found := false
	for sig in signals:
		if sig["name"] == "encounter_resolved":
			found = true
			break
	assert_true(found, "encounter_resolved signal should be declared on EncounterOverlay base")
	overlay.free()


func test_is_active_starts_false():
	var overlay := EncounterOverlay.new()
	assert_false(overlay.is_active())
	overlay.free()


func test_simple_encounter_overlay_subclass_extends_base():
	var subclass := SimpleEncounterOverlay.new()
	assert_is(subclass, EncounterOverlay)
	subclass.free()


func test_combat_overlay_subclass_extends_base():
	var subclass := CombatOverlay.new()
	assert_is(subclass, EncounterOverlay)
	subclass.free()
