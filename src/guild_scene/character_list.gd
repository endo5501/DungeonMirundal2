class_name CharacterList
extends Control

signal back_requested

var _guild: Guild
var _characters: Array[Character] = []

func setup(guild: Guild) -> void:
	_guild = guild
	refresh()

func refresh() -> void:
	_characters = _guild.get_all_characters()

func get_character_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for ch in _characters:
		entries.append({
			"character_name": ch.character_name,
			"level": ch.level,
			"race_name": ch.race.race_name,
			"job_name": ch.job.job_name,
			"status": _get_status(ch),
		})
	return entries

func get_character_detail(index: int) -> Dictionary:
	var ch := _characters[index]
	return {
		"character_name": ch.character_name,
		"race_name": ch.race.race_name,
		"job_name": ch.job.job_name,
		"level": ch.level,
		"current_hp": ch.current_hp,
		"max_hp": ch.max_hp,
		"current_mp": ch.current_mp,
		"max_mp": ch.max_mp,
		"stats": ch.base_stats.duplicate(),
		"status": _get_status(ch),
	}

func can_delete(index: int) -> bool:
	var ch := _characters[index]
	return _is_unassigned(ch)

func delete_character(index: int) -> void:
	var ch := _characters[index]
	_guild.remove(ch)

func go_back() -> void:
	back_requested.emit()

func _is_unassigned(ch: Character) -> bool:
	for unassigned in _guild.get_unassigned():
		if unassigned == ch:
			return true
	return false

func _get_status(ch: Character) -> String:
	if _is_unassigned(ch):
		return "待機中"
	return "パーティ"
