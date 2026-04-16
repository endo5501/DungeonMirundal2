extends Control

var _current_screen: Control
var _current_dungeon_data: DungeonData
var _esc_menu: EscMenu
var _is_title_screen: bool = true

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_esc_menu = EscMenu.new()
	_esc_menu.quit_to_title.connect(_on_quit_to_title)
	add_child(_esc_menu)
	_show_title_screen()

# --- Screen switching ---

func _switch_screen(new_screen: Control) -> void:
	if _current_screen:
		_current_screen.queue_free()
	_current_screen = new_screen
	new_screen.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(new_screen)

# --- Title Screen ---

func _show_title_screen() -> void:
	_is_title_screen = true
	var screen := TitleScreen.new()
	screen.start_new_game.connect(_on_start_new_game)
	screen.quit_game.connect(_on_quit_game)
	_switch_screen(screen)

func _on_start_new_game() -> void:
	GameState.new_game()
	_show_town_screen()

func _on_quit_game() -> void:
	get_tree().quit()

# --- ESC Menu ---

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and not _is_title_screen and not _esc_menu.is_menu_visible():
		_on_esc_key_pressed()
		get_viewport().set_input_as_handled()

func _on_esc_key_pressed() -> void:
	if _is_title_screen:
		return
	_esc_menu.show_menu()

func _on_quit_to_title() -> void:
	_esc_menu.hide_menu()
	_current_dungeon_data = null
	_show_title_screen()

# --- Town Screen ---

func _show_town_screen() -> void:
	_is_title_screen = false
	var screen := TownScreen.new()
	screen.open_guild.connect(_on_open_guild)
	screen.open_dungeon_entrance.connect(_on_open_dungeon_entrance)
	_switch_screen(screen)

# --- Guild Screen ---

func _on_open_guild() -> void:
	var screen := GuildScreen.new()
	screen.setup(GameState.guild)
	screen.back_requested.connect(_on_guild_back)
	_switch_screen(screen)

func _on_guild_back() -> void:
	_show_town_screen()

# --- Dungeon Entrance ---

func _on_open_dungeon_entrance() -> void:
	var has_party := GameState.guild.has_party_members()
	var screen := DungeonEntrance.new()
	screen.setup(GameState.dungeon_registry, has_party)
	screen.enter_dungeon.connect(_on_enter_dungeon)
	screen.back_requested.connect(_on_dungeon_entrance_back)
	_switch_screen(screen)

func _on_dungeon_entrance_back() -> void:
	_show_town_screen()

# --- Dungeon Screen ---

func _on_enter_dungeon(index: int) -> void:
	_current_dungeon_data = GameState.dungeon_registry.get_dungeon(index)
	var screen := DungeonScreen.new()
	screen.return_to_town.connect(_on_return_to_town)
	_switch_screen(screen)
	screen.setup_from_data(_current_dungeon_data, GameState.guild.get_party_data())

func _on_return_to_town() -> void:
	GameState.heal_party()
	_current_dungeon_data = null
	_show_town_screen()

