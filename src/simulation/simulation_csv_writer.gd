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
	var file := _open_for_write(path)
	if file == null:
		return false
	file.store_line(",".join(COLUMNS))
	for row in rows:
		file.store_line(_format_row(row))
	file.close()
	return true


## Generic table writer for the balance dashboard: `rows` is an Array of
## Dictionaries mapping each column name to an ALREADY-FORMATTED String cell
## (see DashboardRunner.format_cells). Cells are escaped with the same minimal
## RFC 4180 quoting as write(), so identical rows yield byte-identical files.
static func write_table(path: String, columns: PackedStringArray, rows: Array) -> bool:
	var file := _open_for_write(path)
	if file == null:
		return false
	file.store_line(",".join(columns))
	for row in rows:
		var cells := PackedStringArray()
		for column in columns:
			cells.append(_escape_cell(String((row as Dictionary)[column])))
		file.store_line(",".join(cells))
	file.close()
	return true


## Resolves `path`, creates missing parent directories and opens the file for
## writing. Returns null (with a pushed error) on failure.
static func _open_for_write(path: String) -> FileAccess:
	var absolute := _resolve_path(path)
	var parent := absolute.get_base_dir()
	var err := DirAccess.make_dir_recursive_absolute(parent)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("SimulationCsvWriter: failed to create directory '%s' (error %d)" % [parent, err])
		return null
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		push_error("SimulationCsvWriter: failed to open '%s' for writing (error %d)" % [
			absolute, FileAccess.get_open_error(),
		])
	return file


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
			cells.append(_escape_cell(String(value)))
		else:
			cells.append(str(int(value)))
	return ",".join(cells)


## Minimal RFC 4180 quoting: only cells containing a comma, double quote, or
## CR/LF are wrapped in double quotes (embedded quotes doubled). Plain cells
## are written as-is so existing outputs stay byte-identical.
static func _escape_cell(cell: String) -> String:
	if cell.contains(",") or cell.contains("\"") or cell.contains("\r") or cell.contains("\n"):
		return "\"%s\"" % cell.replace("\"", "\"\"")
	return cell
