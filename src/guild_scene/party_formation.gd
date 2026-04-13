class_name PartyFormation
extends Control

signal back_requested

var _guild: Guild
var _party_name: String = ""
var _party_slots: Array = []  # Array of 6: Character or null
var _waiting: Array[Character] = []

func setup(guild: Guild) -> void:
	_guild = guild
	refresh()

func refresh() -> void:
	_waiting = _guild.get_unassigned()
	_party_slots.clear()
	var party_data := _guild.get_party_data()
	var front := party_data.get_front_row()
	var back := party_data.get_back_row()
	# Store Character references, not PartyMemberData
	var all_chars := _guild.get_all_characters()
	_party_slots.resize(6)
	for i in range(3):
		_party_slots[i] = _find_character_at(0, i, all_chars)
		_party_slots[i + 3] = _find_character_at(1, i, all_chars)

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
	return _party_name

func set_party_name(value: String) -> void:
	_party_name = value

func go_back() -> void:
	back_requested.emit()

func _find_character_at(row: int, position: int, all_chars: Array[Character]) -> Character:
	# Check which character is at this party position by testing assignment
	# We need to look at the guild's internal state
	# Use get_party_data to get PartyMemberData and match by name
	var party_data := _guild.get_party_data()
	var row_data: Array
	if row == 0:
		row_data = party_data.get_front_row()
	else:
		row_data = party_data.get_back_row()
	var member_data = row_data[position]
	if member_data == null:
		return null
	for ch in all_chars:
		if ch.character_name == member_data.member_name:
			return ch
	return null
