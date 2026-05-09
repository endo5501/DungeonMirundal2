class_name SaveSession
extends RefCounted

# Logic layer for the Dev Console save editor. Owns the in-memory state
# (Inventory + Array[Character]) plus the surrounding save-file dictionary
# so we can round-trip JSON without losing fields the editor doesn't know.
# All mutations are routed through this class so they can be unit-tested
# without instantiating any UI.

const STAT_KEYS: Array[StringName] = [&"STR", &"INT", &"PIE", &"VIT", &"AGI", &"LUC"]
const CURRENT_VERSION := 1

enum LoadResult {
	OK,
	FILE_NOT_FOUND,
	PARSE_ERROR,
}

var _save_dir: String
var _data: Dictionary = {}
var _inventory: Inventory = null
var _characters: Array[Character] = []
var _item_repo: ItemRepository = null
var _spell_repo: SpellRepository = null


func _init(save_dir: String = "user://saves/") -> void:
	_save_dir = save_dir
	var loader := DataLoader.new()
	_item_repo = loader.load_all_items()
	_spell_repo = loader.load_spell_repository()


func get_save_dir() -> String:
	return _save_dir


func get_item_repository() -> ItemRepository:
	return _item_repo


func get_spell_repository() -> SpellRepository:
	return _spell_repo


func _slot_path(slot_number: int) -> String:
	return _save_dir + "save_%03d.json" % slot_number


# Returns a list of slot numbers currently present on disk, sorted ascending.
func list_slots() -> Array[int]:
	var out: Array[int] = []
	if not DirAccess.dir_exists_absolute(_save_dir):
		return out
	var dir := DirAccess.open(_save_dir)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("save_") and name.ends_with(".json"):
			var stem := name.get_basename().trim_prefix("save_")
			out.append(int(stem))
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func load_slot(slot_number: int) -> int:
	var path := _slot_path(slot_number)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return LoadResult.FILE_NOT_FOUND
	var raw := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		return LoadResult.PARSE_ERROR
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return LoadResult.PARSE_ERROR
	_data = parsed
	var inv_data: Dictionary = _data.get("inventory", {"gold": 0, "items": []})
	_inventory = Inventory.from_dict(inv_data, _item_repo)
	_characters = []
	var guild_data: Dictionary = _data.get("guild", {})
	var chars_arr: Array = guild_data.get("characters", [])
	for ch_data in chars_arr:
		var ch := Character.from_dict(ch_data, _inventory, _spell_repo)
		if ch != null:
			_characters.append(ch)
	return LoadResult.OK


func save_to_slot(slot_number: int) -> bool:
	if not DirAccess.dir_exists_absolute(_save_dir):
		DirAccess.make_dir_recursive_absolute(_save_dir)
	# Re-stamp the bits we own into _data so unrelated fields (game_location,
	# dungeons, current_dungeon_index, guild.front_row/back_row/party_name)
	# are preserved verbatim across the round-trip.
	if _inventory != null:
		_data["inventory"] = _inventory.to_dict()
	var guild_data: Dictionary = _data.get("guild", {})
	var chars_arr: Array = []
	for ch in _characters:
		chars_arr.append(ch.to_dict(_inventory))
	guild_data["characters"] = chars_arr
	_data["guild"] = guild_data
	_data["last_saved"] = Time.get_datetime_string_from_system()
	if not _data.has("version"):
		_data["version"] = CURRENT_VERSION
	var path := _slot_path(slot_number)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(_data))
	f.close()
	return true


# --- Character listing / access ------------------------------------------

func list_characters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ch in _characters:
		out.append({
			"name": ch.character_name,
			"race_id": _resource_id(ch.race),
			"job_id": _resource_id(ch.job),
			"level": ch.level,
		})
	return out


func get_character(char_idx: int) -> Character:
	if char_idx < 0 or char_idx >= _characters.size():
		return null
	return _characters[char_idx]


func _check_idx(char_idx: int) -> bool:
	return char_idx >= 0 and char_idx < _characters.size()


# --- Character mutators --------------------------------------------------

func set_character_name(char_idx: int, new_name: String) -> bool:
	if not _check_idx(char_idx):
		return false
	_characters[char_idx].character_name = new_name
	return true


func set_race(char_idx: int, race_id: StringName) -> bool:
	if not _check_idx(char_idx):
		return false
	var path := "res://data/races/" + String(race_id) + ".tres"
	if not ResourceLoader.exists(path):
		return false
	var race: RaceData = load(path) as RaceData
	if race == null:
		return false
	_characters[char_idx].race = race
	return true


func set_job(char_idx: int, job_id: StringName) -> bool:
	if not _check_idx(char_idx):
		return false
	var path := "res://data/jobs/" + String(job_id) + ".tres"
	if not ResourceLoader.exists(path):
		return false
	var job: JobData = load(path) as JobData
	if job == null:
		return false
	_characters[char_idx].job = job
	return true


# Write only the level integer. Does NOT rebuild HP/MP/spells — that's what
# set_level() does. Exists so the UI's level spinbox can route through
# SaveSession instead of mutating Character directly (preserves R4: every
# mutation goes through this class).
func set_level_value(char_idx: int, level: int) -> bool:
	if not _check_idx(char_idx):
		return false
	_characters[char_idx].level = level
	return true


func set_level(char_idx: int, target_level: int) -> bool:
	if not _check_idx(char_idx):
		return false
	if target_level < 1:
		return false
	var ch := _characters[char_idx]
	if ch.job == null:
		return false
	var max_level: int = ch.job.exp_table.size() + 1
	var clamped: int = mini(target_level, max_level)
	# Reset to a known Lv1 baseline using the same formulas Character.create()
	# uses for HP/MP and spells, then climb back via level_up() so HP/MP/spells
	# match what a normally-played character at this level would have.
	var vit: int = int(ch.base_stats.get(&"VIT", 0))
	ch.level = 1
	ch.accumulated_exp = 0
	ch.max_hp = ch.job.base_hp + vit / 3
	if ch.job.is_magic_capable():
		ch.max_mp = ch.job.base_mp
	else:
		ch.max_mp = 0
	ch.known_spells = []
	ch._rebuild_known_spells_through_level(1)
	while ch.level < clamped:
		ch.level_up()
	ch.accumulated_exp = ch.job.exp_to_reach_level(clamped)
	ch.current_hp = ch.max_hp
	ch.current_mp = ch.max_mp
	return true


func set_accumulated_exp(char_idx: int, exp: int) -> bool:
	if not _check_idx(char_idx):
		return false
	_characters[char_idx].accumulated_exp = exp
	return true


func set_current_hp(char_idx: int, hp: int) -> bool:
	if not _check_idx(char_idx):
		return false
	_characters[char_idx].current_hp = hp
	return true


func set_max_hp(char_idx: int, hp: int) -> bool:
	if not _check_idx(char_idx):
		return false
	_characters[char_idx].max_hp = hp
	return true


func set_current_mp(char_idx: int, mp: int) -> bool:
	if not _check_idx(char_idx):
		return false
	_characters[char_idx].current_mp = mp
	return true


func set_max_mp(char_idx: int, mp: int) -> bool:
	if not _check_idx(char_idx):
		return false
	_characters[char_idx].max_mp = mp
	return true


func set_base_stat(char_idx: int, stat_key: StringName, value: int) -> bool:
	if not _check_idx(char_idx):
		return false
	if not (stat_key in STAT_KEYS):
		return false
	_characters[char_idx].base_stats[stat_key] = value
	return true


func toggle_known_spell(char_idx: int, spell_id: StringName, learned: bool) -> bool:
	if not _check_idx(char_idx):
		return false
	var ch := _characters[char_idx]
	if learned:
		if not ch.known_spells.has(spell_id):
			ch.known_spells.append(spell_id)
	else:
		ch.known_spells.erase(spell_id)
	return true


# Rebuild HP/MP from the current level using Character.level_up() math, but
# preserve known_spells (we save and restore around the climb so that
# level_up's spell-grant calls don't mutate the player's manual edits).
func recompute_hp_mp_from_level(char_idx: int) -> bool:
	if not _check_idx(char_idx):
		return false
	var ch := _characters[char_idx]
	if ch.job == null:
		return false
	var target: int = ch.level
	var saved_spells: Array[StringName] = ch.known_spells.duplicate()
	var vit: int = int(ch.base_stats.get(&"VIT", 0))
	ch.level = 1
	ch.max_hp = ch.job.base_hp + vit / 3
	if ch.job.is_magic_capable():
		ch.max_mp = ch.job.base_mp
	else:
		ch.max_mp = 0
	while ch.level < target:
		ch.level_up()
	ch.known_spells = saved_spells
	ch.current_hp = ch.max_hp
	ch.current_mp = ch.max_mp
	return true


func recompute_spells_from_level(char_idx: int) -> bool:
	if not _check_idx(char_idx):
		return false
	_characters[char_idx]._rebuild_known_spells_through_level(_characters[char_idx].level)
	return true


# --- Inventory mutators --------------------------------------------------

func list_inventory() -> Array[ItemInstance]:
	if _inventory == null:
		return []
	return _inventory.list()


func get_gold() -> int:
	if _inventory == null:
		return 0
	return _inventory.gold


func set_gold(amount: int) -> bool:
	if _inventory == null:
		return false
	_inventory.gold = amount
	return true


func add_item(item_id: StringName, identified: bool = true) -> bool:
	if _inventory == null:
		return false
	var item: Item = _item_repo.find(item_id)
	if item == null:
		return false
	_inventory.add(ItemInstance.new(item, identified))
	return true


# Removes the item at inv_idx and clears it from any character's equipment
# slot. The auto-clear is required because Equipment serializes via inventory
# index — leaving a stale reference would either crash or silently re-equip
# a different item after the indexes shift.
func remove_item(inv_idx: int) -> bool:
	if _inventory == null:
		return false
	var items := _inventory.list()
	if inv_idx < 0 or inv_idx >= items.size():
		return false
	var target: ItemInstance = items[inv_idx]
	for ch in _characters:
		if ch.equipment == null:
			continue
		for slot in Equipment.ALL_SLOTS:
			if ch.equipment.get_equipped(slot) == target:
				ch.equipment.unequip(slot)
	_inventory.remove(target)
	return true


# --- Equipment mutators (validation bypass) ------------------------------

func equip(char_idx: int, slot: int, inv_idx: int) -> bool:
	if not _check_idx(char_idx):
		return false
	if _inventory == null:
		return false
	var items := _inventory.list()
	if inv_idx < 0 or inv_idx >= items.size():
		return false
	var ch := _characters[char_idx]
	if ch.equipment == null:
		ch.equipment = Equipment.new()
	var instance: ItemInstance = items[inv_idx]
	# An ItemInstance can only be equipped on one (character, slot) at a time
	# — mirrors equipment_flow._unequip_from_other_holders. Without this,
	# putting Robe on character B while character A also wears it produces
	# a state the live game never creates and can't safely round-trip.
	# This is data integrity, not validation: we still bypass slot-type and
	# job-allow checks (those are the user-facing validation we deliberately
	# suppress).
	_clear_instance_from_all_slots(instance)
	# Bypass Equipment.equip() which would refuse on slot mismatch or job
	# disallow. The whole point of the dev console is to permit those states.
	ch.equipment._slots[slot] = instance
	return true


func _clear_instance_from_all_slots(instance: ItemInstance) -> void:
	for other in _characters:
		if other == null or other.equipment == null:
			continue
		for s in Equipment.ALL_SLOTS:
			if other.equipment.get_equipped(s) == instance:
				other.equipment.unequip(s)


func unequip(char_idx: int, slot: int) -> bool:
	if not _check_idx(char_idx):
		return false
	var ch := _characters[char_idx]
	if ch.equipment == null:
		return false
	ch.equipment.unequip(slot)
	return true


# --- Helpers -------------------------------------------------------------

func _resource_id(res: Resource) -> String:
	if res == null:
		return ""
	if "id" in res and res.id != &"":
		return String(res.id)
	return ""
