class_name FloorData
extends RefCounted

var seed_value: int
var map_size: int
var wiz_map: WizMap
var explored_map: ExploredMap

static func create(p_seed: int, p_size: int, role: int) -> FloorData:
	var fd := FloorData.new()
	fd.seed_value = p_seed
	fd.map_size = p_size
	fd.wiz_map = WizMap.new(p_size)
	fd.wiz_map.generate(p_seed, -1, 4, -1, -1, 0.25, role)
	fd.explored_map = ExploredMap.new()
	return fd

func to_dict() -> Dictionary:
	return {
		"seed_value": seed_value,
		"map_size": map_size,
		"explored_map": explored_map.to_dict(),
	}

static func from_dict(data: Dictionary, role: int) -> FloorData:
	var fd := FloorData.new()
	fd.seed_value = int(data.get("seed_value", 0))
	fd.map_size = int(data.get("map_size", 8))
	fd.wiz_map = WizMap.new(fd.map_size)
	fd.wiz_map.generate(fd.seed_value, -1, 4, -1, -1, 0.25, role)
	fd.explored_map = ExploredMap.from_dict(data.get("explored_map", {"visited": []}))
	return fd
