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
	if item_repository == null:
		var loader := DataLoader.new()
		item_repository = loader.load_all_items()
	if inventory == null:
		inventory = Inventory.new()


func new_game() -> void:
	guild = Guild.new()
	dungeon_registry = DungeonRegistry.new()
	inventory = Inventory.new()
	inventory.gold = INITIAL_GOLD
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
