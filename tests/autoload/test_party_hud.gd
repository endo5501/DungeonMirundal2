extends GutTest

# Verifies that PartyHud is registered as a Godot autoload, extends
# CanvasLayer, owns exactly one PartyDisplay child, and exposes show_hud /
# hide_hud that toggle visibility idempotently.


func _hud() -> Node:
	return get_node("/root/PartyHud")


func test_party_hud_autoload_exists():
	assert_not_null(_hud(), "PartyHud autoload should be reachable at /root/PartyHud")


func test_party_hud_extends_canvas_layer():
	var hud := _hud()
	assert_true(hud is CanvasLayer, "PartyHud should extend CanvasLayer")


func test_party_hud_has_single_party_display_child():
	var hud := _hud()
	var found: int = 0
	for child in hud.get_children():
		if child is PartyDisplay:
			found += 1
	assert_eq(found, 1, "PartyHud should own exactly one PartyDisplay child")


func test_show_hud_makes_visible():
	var hud := _hud()
	hud.hide_hud()
	hud.show_hud()
	assert_true(hud.visible, "show_hud() must set visible = true")


func test_hide_hud_makes_invisible():
	var hud := _hud()
	hud.show_hud()
	hud.hide_hud()
	assert_false(hud.visible, "hide_hud() must set visible = false")


func test_show_hud_is_idempotent():
	var hud := _hud()
	hud.show_hud()
	hud.show_hud()
	assert_true(hud.visible, "show_hud() called twice should leave visible = true")


func test_hide_hud_is_idempotent():
	var hud := _hud()
	hud.hide_hud()
	hud.hide_hud()
	assert_false(hud.visible, "hide_hud() called twice should leave visible = false")
