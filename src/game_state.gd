extends Node

const LOCATION_TITLE := "title"
const LOCATION_TOWN := "town"
const LOCATION_DUNGEON := "dungeon"

var guild: Guild
var dungeon_registry: DungeonRegistry
var game_location: String = LOCATION_TITLE
var current_dungeon_index: int = -1
var save_manager: SaveManager = SaveManager.new()

func new_game() -> void:
	guild = Guild.new()
	dungeon_registry = DungeonRegistry.new()
	game_location = LOCATION_TOWN
	current_dungeon_index = -1

func heal_party() -> void:
	if guild == null:
		return
	for row in range(2):
		for pos in range(3):
			var ch: Character = guild.get_character_at(row, pos)
			if ch != null:
				ch.current_hp = ch.max_hp
				ch.current_mp = ch.max_mp
