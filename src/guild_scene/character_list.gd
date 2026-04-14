class_name CharacterList
extends Control

signal back_requested

var _guild: Guild
var _characters: Array[Character] = []
var _pending_delete_index: int = -1

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
	return not _guild.is_in_party(ch)

func delete_character(index: int) -> void:
	var ch := _characters[index]
	_guild.remove(ch)

func request_delete(index: int) -> void:
	if can_delete(index):
		_pending_delete_index = index

func confirm_delete() -> void:
	if _pending_delete_index < 0:
		return
	delete_character(_pending_delete_index)
	_pending_delete_index = -1

func cancel_delete() -> void:
	_pending_delete_index = -1

func get_pending_delete_index() -> int:
	return _pending_delete_index

func go_back() -> void:
	back_requested.emit()

func _get_status(ch: Character) -> String:
	if _guild.is_in_party(ch):
		return "パーティ"
	return "待機中"
