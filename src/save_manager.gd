class_name SaveManager
extends RefCounted

const CURRENT_VERSION := 1

var _save_dir: String

func _init(save_dir: String = "user://saves/") -> void:
	_save_dir = save_dir

func _slot_path(slot_number: int) -> String:
	return _save_dir + "save_%03d.json" % slot_number

func _last_slot_path() -> String:
	return _save_dir + "last_slot.txt"

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(_save_dir):
		DirAccess.make_dir_recursive_absolute(_save_dir)

func save(slot_number: int) -> void:
	_ensure_dir()
	var inv: Inventory = GameState.inventory
	var data := {
		"version": CURRENT_VERSION,
		"last_saved": Time.get_datetime_string_from_system(),
		"game_location": GameState.game_location,
		"current_dungeon_index": GameState.current_dungeon_index,
		"inventory": inv.to_dict() if inv != null else {"gold": 0, "items": []},
		"guild": GameState.guild.to_dict(inv),
		"dungeons": GameState.dungeon_registry.to_dict()["dungeons"],
	}
	var json_str := JSON.stringify(data, "\t")
	var f := FileAccess.open(_slot_path(slot_number), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(json_str)
	f.close()
	var lf := FileAccess.open(_last_slot_path(), FileAccess.WRITE)
	if lf == null:
		return
	lf.store_string(str(slot_number))
	lf.close()

func load(slot_number: int) -> bool:
	var f := FileAccess.open(_slot_path(slot_number), FileAccess.READ)
	if f == null:
		return false
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return false
	var data: Dictionary = json.data
	if int(data.get("version", 0)) > CURRENT_VERSION:
		return false
	# Restore inventory first so equipment indices can resolve to ItemInstances.
	var inv_data: Dictionary = data.get("inventory", {})
	GameState.inventory = Inventory.from_dict(inv_data, GameState.item_repository)
	GameState.guild = Guild.from_dict(data.get("guild", {}), GameState.inventory)
	GameState.dungeon_registry = DungeonRegistry.from_dict({"dungeons": data.get("dungeons", [])})
	GameState.game_location = data.get("game_location", GameState.LOCATION_TOWN)
	GameState.current_dungeon_index = int(data.get("current_dungeon_index", -1))
	return true

func list_saves() -> Array[Dictionary]:
	if not DirAccess.dir_exists_absolute(_save_dir):
		return []
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(_save_dir)
	if dir == null:
		return []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("save_") and file_name.ends_with(".json"):
			var meta := _read_save_meta(_save_dir + file_name)
			if meta.size() > 0:
				result.append(meta)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_time: String = a.get("last_saved", "")
		var b_time: String = b.get("last_saved", "")
		if a_time != b_time:
			return a_time > b_time
		return a.get("slot_number", 0) > b.get("slot_number", 0)
	)
	return result

func _read_save_meta(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return {}
	var data: Dictionary = json.data
	var slot_str := path.get_file().get_basename().trim_prefix("save_")
	var guild_data: Dictionary = data.get("guild", {})
	var party_name: String = guild_data.get("party_name", "")
	var max_level := 0
	var chars: Array = guild_data.get("characters", [])
	for ch in chars:
		var lv: int = ch.get("level", 1)
		if lv > max_level:
			max_level = lv
	var dungeon_name := ""
	var game_loc: String = data.get("game_location", "")
	if game_loc == GameState.LOCATION_DUNGEON:
		var idx: int = data.get("current_dungeon_index", -1)
		var dungeons: Array = data.get("dungeons", [])
		if idx >= 0 and idx < dungeons.size():
			dungeon_name = dungeons[idx].get("dungeon_name", "")
	return {
		"slot_number": int(slot_str),
		"last_saved": data.get("last_saved", ""),
		"game_location": game_loc,
		"party_name": party_name,
		"max_level": max_level,
		"dungeon_name": dungeon_name,
	}

func get_last_slot() -> int:
	var f := FileAccess.open(_last_slot_path(), FileAccess.READ)
	if f == null:
		return -1
	var slot := int(f.get_as_text().strip_edges())
	f.close()
	var sf := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if sf == null:
		return -1
	sf.close()
	return slot

func get_next_slot_number() -> int:
	if not DirAccess.dir_exists_absolute(_save_dir):
		return 1
	var max_slot := 0
	var dir := DirAccess.open(_save_dir)
	if dir == null:
		return 1
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("save_") and file_name.ends_with(".json"):
			var slot_str := file_name.get_basename().trim_prefix("save_")
			var slot := int(slot_str)
			if slot > max_slot:
				max_slot = slot
		file_name = dir.get_next()
	dir.list_dir_end()
	return max_slot + 1

func has_saves() -> bool:
	if not DirAccess.dir_exists_absolute(_save_dir):
		return false
	var dir := DirAccess.open(_save_dir)
	if dir == null:
		return false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("save_") and file_name.ends_with(".json"):
			dir.list_dir_end()
			return true
		file_name = dir.get_next()
	dir.list_dir_end()
	return false

func delete_save(slot_number: int) -> void:
	DirAccess.remove_absolute(_slot_path(slot_number))
