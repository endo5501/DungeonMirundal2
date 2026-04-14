extends Control

var _current_screen: Control
var _current_dungeon_data: DungeonData

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
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
	var screen := TitleScreen.new()
	screen.start_new_game.connect(_on_start_new_game)
	screen.quit_game.connect(_on_quit_game)
	_switch_screen(screen)

func _on_start_new_game() -> void:
	GameState.new_game()
	_show_town_screen()

func _on_quit_game() -> void:
	get_tree().quit()

# --- Town Screen ---

func _show_town_screen() -> void:
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
	var has_party := _has_party_members()
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
	screen.setup(
		_current_dungeon_data.wiz_map,
		_current_dungeon_data.player_state,
		_current_dungeon_data.explored_map,
		GameState.guild.get_party_data()
	)

func _on_return_to_town() -> void:
	GameState.heal_party()
	_current_dungeon_data = null
	_show_town_screen()

# --- Helpers ---

func _has_party_members() -> bool:
	if GameState.guild == null:
		return false
	var pd := GameState.guild.get_party_data()
	for member in pd.get_front_row():
		if member != null:
			return true
	for member in pd.get_back_row():
		if member != null:
			return true
	return false
