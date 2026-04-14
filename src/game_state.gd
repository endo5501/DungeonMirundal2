extends Node

var guild: Guild
var dungeon_registry: DungeonRegistry

func new_game() -> void:
	guild = Guild.new()
	dungeon_registry = DungeonRegistry.new()

func heal_party() -> void:
	if guild == null:
		return
	for row in range(2):
		for pos in range(3):
			var ch: Character = guild.get_character_at(row, pos)
			if ch != null:
				ch.current_hp = ch.max_hp
				ch.current_mp = ch.max_mp
