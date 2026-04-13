extends GutTest

var _screen: GuildScreen

func before_each():
	_screen = GuildScreen.new()
	add_child_autofree(_screen)

# --- _switch_view ---

func test_switch_view_adds_child():
	var view := Control.new()
	_screen._switch_view(view)
	assert_eq(_screen._current_view, view)
	assert_true(view.is_inside_tree())

func test_switch_view_frees_previous():
	var old_view := Control.new()
	_screen._switch_view(old_view)
	var new_view := Control.new()
	_screen._switch_view(new_view)
	assert_eq(_screen._current_view, new_view)
	assert_true(new_view.is_inside_tree())
	assert_true(old_view.is_queued_for_deletion())

func test_switch_view_with_null_current():
	# First call when _current_view is null should work fine
	var view := Control.new()
	_screen._switch_view(view)
	assert_eq(_screen._current_view, view)

# --- Guild and DataLoader ---

func test_has_guild():
	assert_not_null(_screen.guild)
	assert_is(_screen.guild, Guild)

func test_has_data_loader():
	assert_not_null(_screen.data_loader)
	assert_is(_screen.data_loader, DataLoader)

# --- Initial view ---

func test_ready_shows_guild_menu():
	await get_tree().process_frame
	assert_not_null(_screen._current_view)
	assert_is(_screen._current_view, GuildMenu)
