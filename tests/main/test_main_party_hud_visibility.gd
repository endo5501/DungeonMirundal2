extends GutTest

# Verifies that main.gd toggles PartyHud.visible based on the active screen.
# Visible: Town, Guild, Shop, Temple, DungeonEntrance, Dungeon.
# Hidden: Title, Load, Save.
#
# Each test explicitly sets the HUD's initial state to the opposite of the
# expected post-transition state, so the assertion verifies a real toggle
# performed by main.gd's screen-switch code.


var _saved_guild: Guild


func before_each() -> void:
	_saved_guild = GameState.guild
	GameState.guild = Guild.new()


func after_each() -> void:
	GameState.guild = _saved_guild


func _make_main() -> Node:
	var main_scene: PackedScene = load("res://src/main.tscn")
	var inst := main_scene.instantiate()
	add_child_autofree(inst)
	return inst


func _hud() -> Node:
	return TestHelpers.get_party_hud()


# --- Hidden screens (start visible, expect hidden after transition) ---

func test_title_screen_hides_hud():
	_hud().show_hud()
	var m := _make_main()
	# main._ready() shows TitleScreen; visibility should now be false.
	assert_false(_hud().visible, "TitleScreen should hide PartyHud")
	assert_true(m != null)


func test_load_screen_from_title_hides_hud():
	var m := _make_main()
	_hud().show_hud()
	m._on_load_from_title()
	assert_false(_hud().visible, "LoadScreen should hide PartyHud")


func test_save_screen_hides_hud():
	var m := _make_main()
	_hud().show_hud()
	m._on_save_requested()
	assert_false(_hud().visible, "SaveScreen should hide PartyHud")


# --- Visible screens (start hidden, expect visible after transition) ---

func test_town_screen_shows_hud():
	var m := _make_main()
	_hud().hide_hud()
	m._show_town_screen()
	assert_true(_hud().visible, "TownScreen should show PartyHud")


func test_guild_screen_shows_hud():
	var m := _make_main()
	_hud().hide_hud()
	m._on_open_guild()
	assert_true(_hud().visible, "GuildScreen should show PartyHud")


func test_shop_screen_shows_hud():
	var m := _make_main()
	_hud().hide_hud()
	m._on_open_shop()
	assert_true(_hud().visible, "ShopScreen should show PartyHud")


func test_temple_screen_shows_hud():
	var m := _make_main()
	_hud().hide_hud()
	m._on_open_temple()
	assert_true(_hud().visible, "TempleScreen should show PartyHud")


func test_dungeon_entrance_shows_hud():
	var m := _make_main()
	_hud().hide_hud()
	m._on_open_dungeon_entrance()
	assert_true(_hud().visible, "DungeonEntrance should show PartyHud")
