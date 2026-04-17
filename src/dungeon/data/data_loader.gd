class_name DataLoader
extends RefCounted

const RACES_DIR := "res://data/races/"
const JOBS_DIR := "res://data/jobs/"
const MONSTERS_DIR := "res://data/monsters/"
const ENCOUNTER_TABLES_DIR := "res://data/encounter_tables/"

func load_all_races() -> Array[RaceData]:
	var results: Array[RaceData] = []
	for res in _load_resources(RACES_DIR):
		results.append(res as RaceData)
	return results

func load_all_jobs() -> Array[JobData]:
	var results: Array[JobData] = []
	for res in _load_resources(JOBS_DIR):
		results.append(res as JobData)
	return results

func load_all_monsters() -> Array[MonsterData]:
	var results: Array[MonsterData] = []
	for res in _load_resources(MONSTERS_DIR):
		results.append(res as MonsterData)
	return results

func load_all_encounter_tables() -> Array[EncounterTableData]:
	var results: Array[EncounterTableData] = []
	for res in _load_resources(ENCOUNTER_TABLES_DIR):
		results.append(res as EncounterTableData)
	return results

func _load_resources(dir_path: String) -> Array:
	var results: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource := ResourceLoader.load(dir_path + file_name)
			if resource != null:
				results.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results
