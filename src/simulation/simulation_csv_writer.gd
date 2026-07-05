class_name SimulationCsvWriter
extends RefCounted
## Writes per-battle expedition records to a CSV file (long format).
##
## Path resolution rule: "res://" and "user://" paths are globalized;
## OS-absolute paths are used as-is; any other (relative) path is resolved
## against the project root, i.e. ProjectSettings.globalize_path("res://")
## joined with the relative path. Missing parent directories are created.

const COLUMNS: PackedStringArray = [
	"run", "battle", "encounter", "turns",
	"hp_pct_before_heal", "party_hp_pct", "party_mp_pct",
	"deaths_cum", "outcome",
]
const PCT_COLUMNS: PackedStringArray = ["hp_pct_before_heal", "party_hp_pct", "party_mp_pct"]
const STRING_COLUMNS: PackedStringArray = ["encounter", "outcome"]


static func write(path: String, rows: Array) -> bool:
	var absolute := _resolve_path(path)
	var parent := absolute.get_base_dir()
	var err := DirAccess.make_dir_recursive_absolute(parent)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("SimulationCsvWriter: failed to create directory '%s' (error %d)" % [parent, err])
		return false
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		push_error("SimulationCsvWriter: failed to open '%s' for writing (error %d)" % [
			absolute, FileAccess.get_open_error(),
		])
		return false
	file.store_line(",".join(COLUMNS))
	for row in rows:
		file.store_line(_format_row(row))
	file.close()
	return true


static func _resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://").path_join(path)


static func _format_row(row: Dictionary) -> String:
	var cells := PackedStringArray()
	for column in COLUMNS:
		var value: Variant = row[column]
		if column in PCT_COLUMNS:
			cells.append("%.3f" % float(value))
		elif column in STRING_COLUMNS:
			cells.append(String(value))
		else:
			cells.append(str(int(value)))
	return ",".join(cells)
