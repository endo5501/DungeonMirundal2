extends GutTest


const GUILD_IMAGE_PATH := "res://assets/images/facilities/guild.png"
const SHOP_IMAGE_PATH := "res://assets/images/facilities/shop.png"
const CHURCH_IMAGE_PATH := "res://assets/images/facilities/church.png"
const DUNGEON_IMAGE_PATH := "res://assets/images/facilities/dungeon.png"


func _make_screen() -> TownScreen:
	var s := TownScreen.new()
	add_child_autofree(s)
	return s


func _press(screen: TownScreen, action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	screen._unhandled_input(ev)


# --- baseline ---

func test_town_screen_loads_with_four_items():
	var s := _make_screen()
	var items := s.get_menu_items()
	assert_eq(items.size(), 4)
	assert_eq(items[0], "冒険者ギルド")
	assert_eq(items[1], "商店")
	assert_eq(items[2], "教会")
	assert_eq(items[3], "ダンジョン入口")


# --- illustration: image selection ---

func test_initial_cursor_shows_guild_image():
	var s := _make_screen()
	assert_eq(s.selected_index, 0)
	var tex: Texture2D = s.get_illustration_texture()
	assert_not_null(tex, "guild image should be loaded at initial cursor")
	if tex:
		assert_eq(tex.resource_path, GUILD_IMAGE_PATH)


func test_move_down_three_times_shows_dungeon_image():
	var s := _make_screen()
	_press(s, &"ui_down")
	_press(s, &"ui_down")
	_press(s, &"ui_down")
	assert_eq(s.selected_index, 3)
	var tex: Texture2D = s.get_illustration_texture()
	assert_not_null(tex, "dungeon image should be loaded after moving cursor to index 3")
	if tex:
		assert_eq(tex.resource_path, DUNGEON_IMAGE_PATH)


func test_move_down_once_shows_shop_image():
	var s := _make_screen()
	_press(s, &"ui_down")
	assert_eq(s.selected_index, 1)
	var tex: Texture2D = s.get_illustration_texture()
	assert_not_null(tex)
	if tex:
		assert_eq(tex.resource_path, SHOP_IMAGE_PATH)


# --- illustration: label tracks selection ---

func test_label_matches_selected_facility_name_initially():
	var s := _make_screen()
	assert_eq(s.get_illustration_label_text(), "冒険者ギルド")


func test_label_updates_when_cursor_moves():
	var s := _make_screen()
	_press(s, &"ui_down")
	assert_eq(s.get_illustration_label_text(), "商店")
	_press(s, &"ui_down")
	assert_eq(s.get_illustration_label_text(), "教会")
	_press(s, &"ui_down")
	assert_eq(s.get_illustration_label_text(), "ダンジョン入口")


# --- illustration: fallback when image cannot be loaded ---

func test_missing_image_shows_color_fallback():
	var s := _make_screen()
	s.facility_image_paths = [
		"res://assets/images/facilities/__missing_guild__.png",
		SHOP_IMAGE_PATH,
		CHURCH_IMAGE_PATH,
		DUNGEON_IMAGE_PATH,
	]
	s._update_illustration()
	assert_true(s.is_fallback_visible(),
		"fallback ColorRect must be visible when image is missing")
	assert_false(s.is_texture_visible(),
		"TextureRect must be hidden when image is missing")
	# Label should still show the facility name
	assert_eq(s.get_illustration_label_text(), "冒険者ギルド")


func test_existing_image_hides_fallback():
	var s := _make_screen()
	s.facility_image_paths = [
		GUILD_IMAGE_PATH,
		SHOP_IMAGE_PATH,
		CHURCH_IMAGE_PATH,
		DUNGEON_IMAGE_PATH,
	]
	s._update_illustration()
	assert_false(s.is_fallback_visible(),
		"fallback must be hidden when image loads successfully")
	assert_true(s.is_texture_visible(),
		"TextureRect must be visible when image loads successfully")
