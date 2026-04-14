class_name PartyFormation
extends Control

signal back_requested

var _guild: Guild
var _party_slots: Array = []  # Array of 6: Character or null
var _waiting: Array[Character] = []

func setup(guild: Guild) -> void:
	_guild = guild
	refresh()

func refresh() -> void:
	_waiting = _guild.get_unassigned()
	_party_slots.resize(6)
	for i in range(3):
		_party_slots[i] = _guild.get_character_at(0, i)
		_party_slots[i + 3] = _guild.get_character_at(1, i)

func get_party_slots() -> Array:
	return _party_slots.duplicate()

func get_waiting_characters() -> Array[Character]:
	return _waiting

func add_to_slot(row: int, position: int, waiting_index: int) -> void:
	if waiting_index < 0 or waiting_index >= _waiting.size():
		return
	var ch := _waiting[waiting_index]
	_guild.assign_to_party(ch, row, position)

func remove_from_slot(row: int, position: int) -> void:
	_guild.remove_from_party(row, position)

func get_party_name() -> String:
	return _guild.party_name

func set_party_name(value: String) -> void:
	_guild.party_name = value

func go_back() -> void:
	back_requested.emit()

