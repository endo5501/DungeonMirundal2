extends Control

var _current_screen: Control
var _current_dungeon_data: DungeonData
var _esc_menu: EscMenu
var _encounter_coordinator: EncounterCoordinator
var _encounter_tables_by_floor: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_setup_encounter_coordinator()
	_esc_menu = EscMenu.new()
	_esc_menu.quit_to_title.connect(_on_quit_to_title)
	_esc_menu.save_requested.connect(_on_save_requested)
	_esc_menu.load_requested.connect(_on_load_requested)
	add_child(_esc_menu)
	_show_title_screen()

func _setup_encounter_coordinator() -> void:
	var loader := DataLoader.new()
	var repository := MonsterRepository.new()
	repository.register_all(loader.load_all_monsters())
	for table in loader.load_all_encounter_tables():
		if table != null and table.is_valid():
			_encounter_tables_by_floor[table.floor] = table
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_encounter_coordinator = EncounterCoordinator.new(repository, rng)
	add_child(_encounter_coordinator)

# --- Screen switching ---

func _switch_screen(new_screen: Control) -> void:
	if _current_screen:
		if _current_screen is DungeonScreen and _encounter_coordinator != null:
			_encounter_coordinator.detach_screen()
		_current_screen.queue_free()
	_current_screen = new_screen
	new_screen.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(new_screen)
	move_child(_esc_menu, -1)

# --- Title Screen ---

func _show_title_screen() -> void:
	var screen := TitleScreen.new()
	screen.setup_save_state(GameState.save_manager)
	screen.start_new_game.connect(_on_start_new_game)
	screen.continue_game.connect(_on_continue_game)
	screen.load_game.connect(_on_load_from_title)
	screen.quit_game.connect(_on_quit_game)
	_switch_screen(screen)

func _on_start_new_game() -> void:
	GameState.new_game()
	_show_town_screen()

func _on_continue_game() -> void:
	var slot := GameState.save_manager.get_last_slot()
	if slot >= 0:
		_load_game(slot)

func _on_load_from_title() -> void:
	var screen := LoadScreen.new()
	screen.setup(GameState.save_manager)
	screen.load_requested.connect(_on_load_slot_selected)
	screen.back_requested.connect(_on_load_title_back)
	_switch_screen(screen)

func _on_load_title_back() -> void:
	_show_title_screen()

func _on_quit_game() -> void:
	get_tree().quit()

# --- ESC Menu ---

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and not _current_screen is TitleScreen and not _esc_menu.is_menu_visible():
		if _encounter_coordinator != null and _encounter_coordinator.is_encounter_active():
			return
		_on_esc_key_pressed()
		get_viewport().set_input_as_handled()

func _on_esc_key_pressed() -> void:
	_esc_menu.show_menu()

func _on_quit_to_title() -> void:
	_esc_menu.hide_menu()
	_current_dungeon_data = null
	_show_title_screen()

# --- Town Screen ---

func _show_town_screen() -> void:
	GameState.game_location = GameState.LOCATION_TOWN
	GameState.current_dungeon_index = -1
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
	GameState.game_location = GameState.LOCATION_DUNGEON
	GameState.current_dungeon_index = index
	_current_dungeon_data = GameState.dungeon_registry.get_dungeon(index)
	_show_dungeon_screen(_current_dungeon_data)

func _show_dungeon_screen(dungeon_data: DungeonData) -> void:
	var screen := DungeonScreen.new()
	screen.return_to_town.connect(_on_return_to_town)
	_switch_screen(screen)
	screen.setup_from_data(dungeon_data, GameState.guild.get_party_data())
	_attach_encounter_coordinator_to_screen(screen)

func _attach_encounter_coordinator_to_screen(screen: DungeonScreen) -> void:
	if _encounter_coordinator == null:
		return
	# TODO: use the dungeon's current floor once multi-floor dungeons land.
	var table: EncounterTableData = _encounter_tables_by_floor.get(1, null)
	if table == null:
		return
	_encounter_coordinator.set_table(table)
	_encounter_coordinator.attach_screen(screen)

func _on_return_to_town() -> void:
	GameState.heal_party()
	_current_dungeon_data = null
	_show_town_screen()

# --- Save/Load from ESC Menu ---

func _on_save_requested() -> void:
	var screen := SaveScreen.new()
	screen.setup(GameState.save_manager)
	screen.save_completed.connect(_on_save_completed)
	screen.back_requested.connect(_on_save_back)
	_switch_screen(screen)

func _on_save_completed() -> void:
	_esc_menu.on_save_completed()
	_restore_current_screen()

func _on_save_back() -> void:
	_restore_current_screen()

func _on_load_requested() -> void:
	var screen := LoadScreen.new()
	screen.setup(GameState.save_manager)
	screen.load_requested.connect(_on_load_slot_selected)
	screen.back_requested.connect(_on_load_back)
	_switch_screen(screen)

func _on_load_slot_selected(slot_number: int) -> void:
	_esc_menu.hide_menu()
	_load_game(slot_number)

func _on_load_back() -> void:
	_restore_current_screen()

func _restore_current_screen() -> void:
	match GameState.game_location:
		GameState.LOCATION_TOWN:
			_show_town_screen()
		GameState.LOCATION_DUNGEON:
			if _current_dungeon_data:
				_show_dungeon_screen(_current_dungeon_data)

# --- Load Game ---

func _load_game(slot_number: int) -> void:
	var ok := GameState.save_manager.load(slot_number)
	if not ok:
		return
	match GameState.game_location:
		GameState.LOCATION_TOWN:
			_show_town_screen()
		GameState.LOCATION_DUNGEON:
			_current_dungeon_data = GameState.dungeon_registry.get_dungeon(GameState.current_dungeon_index)
			_show_dungeon_screen(_current_dungeon_data)
