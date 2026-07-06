class_name TresStatRewriter
extends RefCounted

# Text-level rewriter for the five combat stat value lines of a monster .tres
# file (design D5). ResourceSaver.save would reformat ext_resource ordering
# and whitespace, so the generator instead treats the file as a plain string
# and substitutes only the matched value segments; every other byte —
# including line endings — is preserved verbatim.
#
# All functions are pure: they take strings/dictionaries and return results;
# file I/O stays in the caller (balance_generator_cli.gd).

const FIELD_NAMES: Array[String] = ["max_hp_min", "max_hp_max", "attack", "defense", "agility"]


# Replaces the value of each `<field> = <int>` line with the value from
# `stats` (keys = FIELD_NAMES). Returns {"ok": bool, "content": String,
# "errors": Array[String]}. On any error (missing or ambiguous line, missing
# replacement value) `content` is the input unchanged — no partial rewrites.
static func rewrite(content: String, stats: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var updated := content
	for field in FIELD_NAMES:
		if not stats.has(field):
			errors.append("%s: no replacement value provided" % field)
			continue
		var regex := _value_line_regex(field)
		var found := regex.search(updated)
		if found == null:
			errors.append("%s: value line not found" % field)
			continue
		if regex.search(updated, found.get_end()) != null:
			errors.append("%s: value line appears more than once" % field)
			continue
		updated = regex.sub(updated, "%s = %d" % [field, int(stats[field])])
	if errors.is_empty():
		return {"ok": true, "content": updated, "errors": errors}
	return {"ok": false, "content": content, "errors": errors}


# Reads the current values of the five combat stat lines. Returns
# {"ok": bool, "stats": Dictionary, "errors": Array[String]}; `stats` holds
# every field that was found even when others are missing.
static func extract_stats(content: String) -> Dictionary:
	var errors: Array[String] = []
	var stats := {}
	for field in FIELD_NAMES:
		var found := _value_line_regex(field).search(content)
		if found == null:
			errors.append("%s: value line not found" % field)
			continue
		stats[field] = found.get_string(1).to_int()
	return {"ok": errors.is_empty(), "stats": stats, "errors": errors}


# Reads the `tier = N` line. Returns -1 when the line is missing.
static func extract_tier(content: String) -> int:
	var found := RegEx.create_from_string("(?m)^tier = (\\d+)").search(content)
	if found == null:
		return -1
	return found.get_string(1).to_int()


# Compares two field->int dictionaries and lists the fields whose values
# differ, in FIELD_NAMES order: [{"field": String, "current": int,
# "new": int}, ...]. Fields absent from either dictionary are ignored.
static func diff_stats(current: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var diffs: Array[Dictionary] = []
	for field in FIELD_NAMES:
		if not current.has(field) or not target.has(field):
			continue
		var current_value := int(current[field])
		var new_value := int(target[field])
		if current_value != new_value:
			diffs.append({"field": field, "current": current_value, "new": new_value})
	return diffs


# Matches `<field> = <int>` at the start of a line, capturing the value.
# No trailing `$` anchor: the match ends at the last digit, so CR/LF bytes
# after the value are untouched. `^attack = ` cannot match `attack_range = `
# because of the literal " = " immediately after the field name.
static func _value_line_regex(field: String) -> RegEx:
	return RegEx.create_from_string("(?m)^%s = (-?\\d+)" % field)
