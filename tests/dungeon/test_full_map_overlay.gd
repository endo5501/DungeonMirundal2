extends GutTest

var _overlay: FullMapOverlay
var _wiz_map: WizMap
var _explored_map: ExploredMap
var _player_state: PlayerState
var _dungeon_data: DungeonData
var _minimap_stub: Control


func _make_overlay(dungeon_name: String = "テストダンジョン",
		map_size: int = 8,
		player_pos: Vector2i = Vector2i(3, 3),
		explored_count: int = 2) -> FullMapOverlay:
	_dungeon_data = DungeonData.create(dungeon_name, 42, map_size)
	_wiz_map = _dungeon_data.wiz_map
	_explored_map = _dungeon_data.explored_map
	_explored_map.clear()
	# Mark a deterministic set of cells regardless of generation
	var marked := 0
	for cy in range(map_size):
		for cx in range(map_size):
			if marked >= explored_count:
				break
			_explored_map.mark_visited(Vector2i(cx, cy))
			marked += 1
		if marked >= explored_count:
			break
	_player_state = PlayerState.new(player_pos, Direction.NORTH)
	_dungeon_data.player_state = _player_state
	_minimap_stub = Control.new()
	_minimap_stub.visible = true
	add_child_autofree(_minimap_stub)
	_overlay = FullMapOverlay.new()
	add_child_autofree(_overlay)
	_overlay.setup(_wiz_map, _explored_map, _player_state, _dungeon_data, _minimap_stub)
	return _overlay


# --- Initial state ---

func test_initially_hidden():
	var overlay = _make_overlay()
	assert_false(overlay.visible)
	assert_false(overlay.is_open())


# --- Lifecycle ---

func test_open_makes_visible():
	var overlay = _make_overlay()
	overlay.open()
	assert_true(overlay.visible)
	assert_true(overlay.is_open())


func test_close_hides():
	var overlay = _make_overlay()
	overlay.open()
	overlay.close()
	assert_false(overlay.visible)
	assert_false(overlay.is_open())


func test_open_close_repeatable():
	var overlay = _make_overlay()
	overlay.open()
	overlay.close()
	overlay.open()
	assert_true(overlay.is_open())


# --- HUD: dungeon name ---

func test_hud_shows_dungeon_name():
	var overlay = _make_overlay("古びた地下牢")
	overlay.open()
	assert_eq(overlay.get_displayed_dungeon_name(), "古びた地下牢")


# --- HUD: coordinates ---

func test_hud_shows_player_coordinates():
	var overlay = _make_overlay("dungeon", 8, Vector2i(7, 3))
	overlay.open()
	var coord = overlay.get_displayed_coordinates()
	assert_string_contains(coord, "7")
	assert_string_contains(coord, "3")


func test_hud_coordinates_refresh_on_reopen():
	var overlay = _make_overlay("dungeon", 8, Vector2i(0, 0))
	overlay.open()
	overlay.close()
	_player_state.position = Vector2i(5, 6)
	overlay.open()
	var coord = overlay.get_displayed_coordinates()
	assert_string_contains(coord, "5")
	assert_string_contains(coord, "6")


# --- HUD: exploration rate ---

func test_hud_shows_exploration_rate_percent():
	# 8x8 = 64 cells, mark 16 -> 25%
	var overlay = _make_overlay("d", 8, Vector2i(0, 0), 16)
	overlay.open()
	var rate = overlay.get_displayed_exploration_rate()
	assert_string_contains(rate, "25")
	assert_string_contains(rate, "%")


func test_hud_exploration_rate_refreshes_on_reopen():
	var overlay = _make_overlay("d", 8, Vector2i(0, 0), 16)
	overlay.open()
	overlay.close()
	# Mark more cells: from 16 to 32 -> 50%
	var marked = 16
	for cy in range(_wiz_map.map_size):
		for cx in range(_wiz_map.map_size):
			if marked >= 32:
				break
			if not _explored_map.is_visited(Vector2i(cx, cy)):
				_explored_map.mark_visited(Vector2i(cx, cy))
				marked += 1
		if marked >= 32:
			break
	overlay.open()
	var rate = overlay.get_displayed_exploration_rate()
	assert_string_contains(rate, "50")


# --- ESC handling ---

func test_esc_closes_overlay():
	var overlay = _make_overlay()
	overlay.open()
	overlay._unhandled_input(TestHelpers.make_key_event(KEY_ESCAPE))
	assert_false(overlay.is_open())


func test_esc_when_hidden_does_nothing():
	var overlay = _make_overlay()
	# Overlay is hidden initially
	overlay._unhandled_input(TestHelpers.make_key_event(KEY_ESCAPE))
	assert_false(overlay.is_open())


func test_non_esc_key_when_visible_does_not_close():
	var overlay = _make_overlay()
	overlay.open()
	overlay._unhandled_input(TestHelpers.make_key_event(KEY_SPACE))
	assert_true(overlay.is_open())


# --- Minimap visibility coupling ---

func test_open_hides_minimap():
	var overlay = _make_overlay()
	_minimap_stub.visible = true
	overlay.open()
	assert_false(_minimap_stub.visible)


func test_close_restores_minimap():
	var overlay = _make_overlay()
	_minimap_stub.visible = true
	overlay.open()
	overlay.close()
	assert_true(_minimap_stub.visible)


func test_close_via_esc_restores_minimap():
	var overlay = _make_overlay()
	_minimap_stub.visible = true
	overlay.open()
	overlay._unhandled_input(TestHelpers.make_key_event(KEY_ESCAPE))
	assert_true(_minimap_stub.visible)
