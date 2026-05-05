extends GutTest

# Verifies that DungeonScreen no longer instantiates or owns its own
# PartyDisplay child — the autoload PartyHud is now the sole owner.


func _make_screen() -> DungeonScreen:
	var screen := DungeonScreen.new()
	add_child_autofree(screen)
	var wiz_map := WizMap.new(8)
	wiz_map.generate(42)
	var ps := PlayerState.new(Vector2i(3, 3), Direction.NORTH)
	screen.setup(wiz_map, ps)
	return screen


func test_dungeon_screen_has_no_party_display_child():
	var screen := _make_screen()
	for child in screen.get_children():
		assert_false(child is PartyDisplay,
			"DungeonScreen should not own a PartyDisplay child (HUD lives on the PartyHud autoload now)")
