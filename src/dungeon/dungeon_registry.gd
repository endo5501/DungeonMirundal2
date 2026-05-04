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

const FLOOR_COUNT_RANGES := {
	SIZE_SMALL: [2, 4],
	SIZE_MEDIUM: [4, 7],
	SIZE_LARGE: [8, 12],
}

var _dungeons: Array[DungeonData] = []
var _rng: RandomNumberGenerator

func _init(rng_seed: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed

func create(dungeon_name: String, size_category: int) -> DungeonData:
	var size_range: Array = SIZE_RANGES[size_category]
	var floor_range: Array = FLOOR_COUNT_RANGES[size_category]
	var floor_count := _rng.randi_range(floor_range[0], floor_range[1])
	var floor_sizes: Array = []
	for _i in range(floor_count):
		floor_sizes.append(_rng.randi_range(size_range[0], size_range[1]))
	var base_seed := _rng.randi()
	var dd := DungeonData.create_with_floor_sizes(dungeon_name, base_seed, floor_sizes)
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
