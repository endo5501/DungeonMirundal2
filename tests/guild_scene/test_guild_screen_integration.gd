extends GutTest

var _screen: GuildScreen

func before_each():
	_screen = GuildScreen.new()
	add_child_autofree(_screen)
	await get_tree().process_frame

# --- Navigation ---

func test_initial_view_is_guild_menu():
	assert_is(_screen._current_view, GuildMenu)

func test_navigate_to_character_creation():
	var menu = _screen._current_view as GuildMenu
	menu.select_item(0)
	await get_tree().process_frame
	assert_is(_screen._current_view, CharacterCreation)

func test_navigate_to_party_formation():
	var menu = _screen._current_view as GuildMenu
	menu.select_item(1)
	await get_tree().process_frame
	assert_is(_screen._current_view, PartyFormation)

func test_navigate_to_character_list():
	var menu = _screen._current_view as GuildMenu
	menu.select_item(2)
	await get_tree().process_frame
	assert_is(_screen._current_view, CharacterList)

func test_back_from_creation_returns_to_menu():
	var menu = _screen._current_view as GuildMenu
	menu.select_item(0)
	await get_tree().process_frame
	var creation = _screen._current_view
	creation.cancel()
	await get_tree().process_frame
	assert_is(_screen._current_view, GuildMenu)

func test_back_from_formation_returns_to_menu():
	var menu = _screen._current_view as GuildMenu
	menu.select_item(1)
	await get_tree().process_frame
	var formation = _screen._current_view
	formation.go_back()
	await get_tree().process_frame
	assert_is(_screen._current_view, GuildMenu)

func test_back_from_list_returns_to_menu():
	var menu = _screen._current_view as GuildMenu
	menu.select_item(2)
	await get_tree().process_frame
	var char_list = _screen._current_view
	char_list.go_back()
	await get_tree().process_frame
	assert_is(_screen._current_view, GuildMenu)
