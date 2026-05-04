class_name DataLoader
extends RefCounted

const RACES_DIR := "res://data/races/"
const JOBS_DIR := "res://data/jobs/"
const MONSTERS_DIR := "res://data/monsters/"
const ENCOUNTER_TABLES_DIR := "res://data/encounter_tables/"
const ITEMS_DIR := "res://data/items/"
const SPELLS_DIR := "res://data/spells/"
const STATUSES_DIR := "res://data/statuses/"

# Static so the cache survives across `DataLoader.new()` call sites — each
# `has_*_flag` query, every dungeon step, and every spell-effect resolution
# would otherwise re-scan disk because a fresh DataLoader carries its own
# empty per-instance cache.
static var _status_repo_cache: StatusRepository = null

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


func load_all_items() -> ItemRepository:
	var repo := ItemRepository.new()
	for res in _load_resources(ITEMS_DIR):
		repo.register(res as Item)
	return repo


func load_all_spells() -> Array[SpellData]:
	var results: Array[SpellData] = []
	for res in _load_resources(SPELLS_DIR):
		results.append(res as SpellData)
	return results


func load_spell_repository() -> SpellRepository:
	var repo := SpellRepository.new()
	for spell in load_all_spells():
		repo.register(spell)
	return repo


# Lazily build a StatusRepository from data/statuses/*.tres. Subsequent calls
# on the same DataLoader instance return the cached repo (mirrors the contract
# tested in test_data_loader.test_load_status_repository_caches_instance_across_calls).
func load_status_repository() -> StatusRepository:
	if _status_repo_cache != null:
		return _status_repo_cache
	var repo := StatusRepository.new()
	# Missing directory is not an error — this change ships no .tres files yet.
	if DirAccess.dir_exists_absolute(STATUSES_DIR):
		for res in _load_resources(STATUSES_DIR):
			repo.register(res as StatusData)
	_status_repo_cache = repo
	return repo

func _load_resources(dir_path: String) -> Array:
	var results: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("DataLoader: cannot open %s (DirAccess.get_open_error=%d)" % [dir_path, DirAccess.get_open_error()])
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
