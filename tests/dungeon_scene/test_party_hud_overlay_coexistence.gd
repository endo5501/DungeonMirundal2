extends GutTest

# Verifies that opening the ESC menu or the full-map overlay on top of a
# screen where PartyHud is visible does NOT toggle PartyHud.visible to
# false. The HUD must remain visible (Z-order may cover it visually, but
# explicit hide must not happen).


func _hud() -> CanvasLayer:
	return TestHelpers.get_party_hud()


# --- ESC menu ---

func test_esc_menu_show_does_not_hide_party_hud():
	var esc := EscMenu.new()
	add_child_autofree(esc)
	_hud().show_hud()
	esc.show_menu()
	assert_true(_hud().visible,
		"opening the ESC menu should not hide PartyHud")


func test_esc_menu_hide_does_not_toggle_party_hud():
	var esc := EscMenu.new()
	add_child_autofree(esc)
	esc.show_menu()
	_hud().show_hud()
	esc.hide_menu()
	assert_true(_hud().visible,
		"closing the ESC menu should not toggle PartyHud off")


# --- Full-map overlay ---

func test_full_map_overlay_open_does_not_hide_party_hud():
	var overlay := FullMapOverlay.new()
	add_child_autofree(overlay)
	# FullMapOverlay.open() doesn't require setup() to be called for visibility
	# alone — it just toggles its own internal state. Skip data plumbing.
	_hud().show_hud()
	overlay.open()
	assert_true(_hud().visible,
		"opening the full-map overlay should not hide PartyHud")


func test_full_map_overlay_close_does_not_toggle_party_hud():
	var overlay := FullMapOverlay.new()
	add_child_autofree(overlay)
	overlay.open()
	_hud().show_hud()
	overlay.close()
	assert_true(_hud().visible,
		"closing the full-map overlay should not toggle PartyHud off")
