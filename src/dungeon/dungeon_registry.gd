class_name DungeonRegistry
extends RefCounted

const SIZE_SMALL := 0
const SIZE_MEDIUM := 1
const SIZE_LARGE := 2

const SIZE_RANGES := {
	SIZE_SMALL: [8, 12],
	SIZE_MEDIUM: [13, 20],
	SIZE_LARGE: [21, 30],
}

var _dungeons: Array[DungeonData] = []
var _rng: RandomNumberGenerator

func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

func create(dungeon_name: String, size_category: int) -> DungeonData:
	var range_arr: Array = SIZE_RANGES[size_category]
	var map_size := _rng.randi_range(range_arr[0], range_arr[1])
	var seed_val := _rng.randi()
	var dd := DungeonData.create(dungeon_name, seed_val, map_size)
	_dungeons.append(dd)
	return dd

func remove(index: int) -> void:
	_dungeons.remove_at(index)

func get_dungeon(index: int) -> DungeonData:
	return _dungeons[index]

func get_all() -> Array[DungeonData]:
	return _dungeons.duplicate()

func size() -> int:
	return _dungeons.size()

func to_dict() -> Dictionary:
	var arr: Array = []
	for dd in _dungeons:
		arr.append(dd.to_dict())
	return {"dungeons": arr}

static func from_dict(data: Dictionary) -> DungeonRegistry:
	var reg := DungeonRegistry.new()
	var arr: Array = data.get("dungeons", [])
	for dd_data in arr:
		reg._dungeons.append(DungeonData.from_dict(dd_data))
	return reg
