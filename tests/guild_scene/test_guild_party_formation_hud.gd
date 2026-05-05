extends GutTest

# Verifies GuildScreen hides PartyHud while the party formation editor is
# open and re-shows it when returning to the guild's main menu.


var _saved_guild: Guild


func before_each() -> void:
	_saved_guild = GameState.guild
	GameState.guild = Guild.new()


func after_each() -> void:
	GameState.guild = _saved_guild


func _hud() -> CanvasLayer:
	return TestHelpers.get_party_hud()


func _make_guild_screen() -> GuildScreen:
	var screen := GuildScreen.new()
	add_child_autofree(screen)
	screen.setup(GameState.guild)
	return screen


func test_party_formation_hides_hud():
	var screen := _make_guild_screen()
	_hud().show_hud()
	screen._on_party_formation()
	assert_false(_hud().visible,
		"opening party formation should hide PartyHud")


func test_returning_from_formation_shows_hud():
	var screen := _make_guild_screen()
	screen._on_party_formation()
	# back from formation goes back to main guild menu via _show_menu().
	_hud().hide_hud()
	screen._show_menu()
	assert_true(_hud().visible,
		"returning to guild main menu should show PartyHud")
