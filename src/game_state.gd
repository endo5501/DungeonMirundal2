extends Node

const LOCATION_TITLE := "title"
const LOCATION_TOWN := "town"
const LOCATION_DUNGEON := "dungeon"
const INITIAL_GOLD := 500

var guild: Guild
var dungeon_registry: DungeonRegistry
var game_location: String = LOCATION_TITLE
var current_dungeon_index: int = -1
var save_manager: SaveManager = SaveManager.new()
var inventory: Inventory
var item_repository: ItemRepository


func _ready() -> void:
	_initialize_state(false)


func new_game() -> void:
	_initialize_state(true)


func _initialize_state(reset_for_new_game: bool) -> void:
	if item_repository == null:
		var loader := DataLoader.new()
		item_repository = loader.load_all_items()
	if reset_for_new_game or guild == null:
		guild = Guild.new()
	if reset_for_new_game or dungeon_registry == null:
		dungeon_registry = DungeonRegistry.new()
	if reset_for_new_game or inventory == null:
		inventory = Inventory.new()
		if reset_for_new_game:
			inventory.gold = INITIAL_GOLD
	if reset_for_new_game:
		game_location = LOCATION_TOWN
		current_dungeon_index = -1


func heal_party() -> void:
	if guild == null:
		return
	for row in range(2):
		for pos in range(3):
			var ch: Character = guild.get_character_at(row, pos)
			if ch != null and not ch.is_dead():
				ch.current_hp = ch.max_hp
				ch.current_mp = ch.max_mp
