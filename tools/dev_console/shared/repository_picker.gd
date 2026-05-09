class_name RepositoryPicker
extends RefCounted

# Helpers for filling an OptionButton with the entries of a repository or
# a directory of .tres resources. Each call clears any prior items so the
# button can be re-populated freely (e.g. when inventory contents change).
#
# Conventions:
# - The OptionButton's metadata `id` is the entry index (0..n-1) — callers
#   should use OptionButton.get_selected() to retrieve it.
# - The display string is the human-readable name (item_name, job_name, etc.)
#   plus the kebab-case id in parentheses for disambiguation.


# Empty-marker prepended to slot pickers so a slot can be cleared.
const EMPTY_LABEL := "-- empty --"
const EMPTY_INDEX := -1


static func fill_with_items(option: OptionButton, repo: ItemRepository) -> void:
	option.clear()
	if repo == null:
		return
	var items := repo.all()
	# Sort for stable display order.
	items.sort_custom(func(a: Item, b: Item) -> bool:
		return String(a.item_id) < String(b.item_id))
	for i in range(items.size()):
		var it := items[i]
		option.add_item("%s (%s)" % [it.item_name, String(it.item_id)], i)


static func fill_with_spells(option: OptionButton, repo: SpellRepository) -> void:
	option.clear()
	if repo == null:
		return
	var ids: Array = repo.ids()
	ids.sort()
	for i in range(ids.size()):
		option.add_item(String(ids[i]), i)


# Generic .tres directory loader; returns the resource list so callers can
# resolve a selection back to the underlying Resource.
static func fill_from_dir(option: OptionButton, dir_path: String) -> Array:
	option.clear()
	var results: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			var res: Resource = ResourceLoader.load(dir_path + name)
			if res != null:
				results.append(res)
		name = dir.get_next()
	dir.list_dir_end()
	results.sort_custom(func(a: Resource, b: Resource) -> bool:
		return String(_id_of(a)) < String(_id_of(b)))
	for i in range(results.size()):
		var label := _label_for(results[i])
		option.add_item(label, i)
	return results


# Inventory listing for slot equip pickers. Prepends the EMPTY entry at id -1
# so unequip-by-selection works as one operation.
static func fill_with_inventory_for_slot(option: OptionButton, instances: Array[ItemInstance]) -> void:
	option.clear()
	option.add_item(EMPTY_LABEL, EMPTY_INDEX)
	for i in range(instances.size()):
		var inst: ItemInstance = instances[i]
		var label: String = "(unknown)"
		if inst != null and inst.item != null:
			label = "#%d  %s" % [i, inst.item.item_name]
		option.add_item(label, i)


static func _id_of(res: Resource) -> StringName:
	if res == null:
		return &""
	if "id" in res:
		return res.id
	return &""


static func _label_for(res: Resource) -> String:
	if res == null:
		return "(null)"
	var id_str: String = String(_id_of(res))
	# Prefer .job_name / .item_name / etc. when present for richer labels.
	for prop in ["item_name", "job_name", "race_name"]:
		if prop in res and String(res.get(prop)) != "":
			return "%s (%s)" % [String(res.get(prop)), id_str]
	return id_str
