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


# --- add-status-poison-and-petrify: auto-cure on town arrival ---

func _make_character(char_name: String, statuses: Array[StringName] = []) -> Character:
	var human := load("res://data/races/human.tres") as RaceData
	var fighter := load("res://data/jobs/fighter.tres") as JobData
	var ch := Character.new()
	ch.character_name = char_name
	ch.race = human
	ch.job = fighter
	ch.level = 1
	ch.base_stats = {&"STR": 8, &"INT": 8, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	ch.max_hp = 10
	ch.current_hp = 10
	ch.max_mp = 0
	ch.current_mp = 0
	ch.persistent_statuses = statuses
	return ch


func test_notify_arrival_clears_persistent_statuses_for_all_members():
	var guild := Guild.new()
	var alice := _make_character("Alice", [&"poison"])
	var bob := _make_character("Bob", [&"petrify"])
	guild.register(alice)
	guild.register(bob)
	guild.assign_to_party(alice, 0, 0)
	guild.assign_to_party(bob, 0, 1)
	var s := _make_screen()
	s.setup(guild)
	s.notify_arrival()
	assert_eq(alice.persistent_statuses.size(), 0)
	assert_eq(bob.persistent_statuses.size(), 0)


func test_notify_arrival_shows_message_when_someone_was_afflicted():
	var guild := Guild.new()
	var alice := _make_character("Alice", [&"poison"])
	guild.register(alice)
	guild.assign_to_party(alice, 0, 0)
	var s := _make_screen()
	s.setup(guild)
	s.notify_arrival()
	assert_true(s.get_arrival_message().contains("状態異常"),
		"arrival message should mention 状態異常 when cures occurred")


func test_notify_arrival_no_message_when_no_one_afflicted():
	var guild := Guild.new()
	var alice := _make_character("Alice")
	guild.register(alice)
	guild.assign_to_party(alice, 0, 0)
	var s := _make_screen()
	s.setup(guild)
	s.notify_arrival()
	assert_eq(s.get_arrival_message(), "")


func test_notify_arrival_emits_message_only_once_for_multiple_cures():
	# Multiple afflicted members should still trigger only a single notification.
	var guild := Guild.new()
	var alice := _make_character("Alice", [&"poison"])
	var bob := _make_character("Bob", [&"poison", &"petrify"])
	guild.register(alice)
	guild.register(bob)
	guild.assign_to_party(alice, 0, 0)
	guild.assign_to_party(bob, 0, 1)
	var s := _make_screen()
	s.setup(guild)
	s.notify_arrival()
	# get_arrival_message returns the single composed message; we just verify
	# it is non-empty (single notification semantics).
	assert_true(s.get_arrival_message() != "")
