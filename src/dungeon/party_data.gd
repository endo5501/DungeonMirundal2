class_name PartyData
extends RefCounted

var _front_row: Array  # Array of PartyMemberData or null, size 3
var _back_row: Array   # Array of PartyMemberData or null, size 3

func _init(front: Array = [], back: Array = []) -> void:
	_front_row = _pad_row(front)
	_back_row = _pad_row(back)

func _pad_row(row: Array) -> Array:
	var result: Array = []
	result.resize(3)
	for i in range(3):
		if i < row.size():
			result[i] = row[i]
		else:
			result[i] = null
	return result

func get_front_row() -> Array:
	return _front_row.duplicate()

func get_back_row() -> Array:
	return _back_row.duplicate()

static func create_placeholder() -> PartyData:
	var front := [
		PartyMemberData.new("Fighter", 5, 120, 150, 10, 10),
		PartyMemberData.new("Knight", 5, 140, 160, 8, 8),
		PartyMemberData.new("Thief", 4, 80, 100, 20, 25),
	]
	var back := [
		PartyMemberData.new("Mage", 5, 60, 70, 80, 100),
		PartyMemberData.new("Priest", 5, 90, 110, 60, 80),
		PartyMemberData.new("Bishop", 4, 70, 85, 50, 65),
	]
	return PartyData.new(front, back)
