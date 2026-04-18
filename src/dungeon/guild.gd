class_name Guild
extends RefCounted

var _characters: Array[Character] = []
var _front_row: Array = [null, null, null]
var _back_row: Array = [null, null, null]
var party_name: String = ""

func register(character: Character) -> void:
	_characters.append(character)

func remove(character: Character) -> bool:
	if _is_in_party(character):
		return false
	_characters.erase(character)
	return true

func get_all_characters() -> Array[Character]:
	return _characters.duplicate()

func get_unassigned() -> Array[Character]:
	var result: Array[Character] = []
	for ch in _characters:
		if not _is_in_party(ch):
			result.append(ch)
	return result

func assign_to_party(character: Character, row: int, position: int) -> bool:
	if _is_in_party(character):
		return false
	var target_row := _get_row(row)
	if target_row[position] != null:
		return false
	target_row[position] = character
	return true

func remove_from_party(row: int, position: int) -> void:
	var target_row := _get_row(row)
	target_row[position] = null

func get_party_data() -> PartyData:
	return PartyData.new(_row_to_party_member_data(_front_row), _row_to_party_member_data(_back_row))


func get_party_characters() -> Array:
	# Returns [front_row, back_row] where each row is an Array of 3 (Character or null).
	return [_front_row.duplicate(), _back_row.duplicate()]

func get_character_at(row: int, position: int) -> Character:
	var target_row := _get_row(row)
	return target_row[position]

func has_party_members() -> bool:
	for i in range(3):
		if _front_row[i] != null or _back_row[i] != null:
			return true
	return false

func is_in_party(character: Character) -> bool:
	return _is_in_party(character)

func to_dict(inventory: Inventory = null) -> Dictionary:
	var chars_arr: Array = []
	for ch in _characters:
		chars_arr.append(ch.to_dict(inventory))
	var front: Array = []
	for i in range(3):
		if _front_row[i] != null:
			front.append(_characters.find(_front_row[i]))
		else:
			front.append(null)
	var back: Array = []
	for i in range(3):
		if _back_row[i] != null:
			back.append(_characters.find(_back_row[i]))
		else:
			back.append(null)
	return {
		"characters": chars_arr,
		"front_row": front,
		"back_row": back,
		"party_name": party_name,
	}

static func from_dict(data: Dictionary, inventory: Inventory = null) -> Guild:
	var guild := Guild.new()
	guild.party_name = data.get("party_name", "")
	var chars_arr: Array = data.get("characters", [])
	for ch_data in chars_arr:
		guild.register(Character.from_dict(ch_data, inventory))
	var all_chars := guild.get_all_characters()
	var front: Array = data.get("front_row", [null, null, null])
	for i in range(3):
		if front[i] != null:
			guild.assign_to_party(all_chars[int(front[i])], 0, i)
	var back: Array = data.get("back_row", [null, null, null])
	for i in range(3):
		if back[i] != null:
			guild.assign_to_party(all_chars[int(back[i])], 1, i)
	return guild

func _is_in_party(character: Character) -> bool:
	for i in range(3):
		if _front_row[i] == character or _back_row[i] == character:
			return true
	return false

func _get_row(row: int) -> Array:
	return _front_row if row == 0 else _back_row

func _row_to_party_member_data(row: Array) -> Array:
	var result: Array = []
	for i in range(3):
		if row[i] != null:
			result.append((row[i] as Character).to_party_member_data())
		else:
			result.append(null)
	return result
