class_name ExpeditionConfig
extends RefCounted

# Simulation config loaded from a JSON file (design D5). Loading never crashes:
# unreadable files / invalid JSON return null; a structurally valid dictionary
# always produces a config object whose `errors` array lists every validation
# problem (the caller decides whether to abort).

const VALID_ENCOUNTER_MODES: Array[String] = ["table", "fixed"]
const VALID_ROWS: Array[String] = ["front", "back"]
# Required member keys and the Variant types accepted for each. JSON numbers
# always arrive as floats, so int-ish fields accept TYPE_FLOAT too.
const MEMBER_KEY_TYPES: Dictionary = {
	"name": [TYPE_STRING],
	"race": [TYPE_STRING],
	"job": [TYPE_STRING],
	"level": [TYPE_INT, TYPE_FLOAT],
	"row": [TYPE_STRING],
}

var runs: int = 100
var master_seed: int = 12345
var max_battles: int = 50
var csv_path: String = "tmp/simulation/result.csv"
# Raw member spec dictionaries: {"name", "race", "job", "level", "row",
# "stats"(optional)}. Validated for required keys/types; job/race existence is
# PartyFactory's job.
var party: Array = []
# AI knobs (design D2). Plain fields so this class has no dependency on the
# PartyAi implementation.
var ai_heal_hp_threshold: float = 0.6
var ai_attack_magic_min_enemies: int = 2
var ai_attack_magic_min_tier: int = 0
var encounter_mode: String = "table"
var encounter_floor: int = 1
# Fixed mode only: Array of Dictionaries mapping species id -> count.
var encounter_patterns: Array = []
var errors: Array[String] = []


static func load_from_file(path: String) -> ExpeditionConfig:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	if not (json.data is Dictionary):
		return null
	return parse(json.data)


static func parse(dict: Dictionary) -> ExpeditionConfig:
	var cfg := ExpeditionConfig.new()
	cfg.runs = int(dict.get("runs", cfg.runs))
	cfg.master_seed = int(dict.get("master_seed", cfg.master_seed))
	cfg.max_battles = int(dict.get("max_battles", cfg.max_battles))
	cfg.csv_path = String(dict.get("csv_path", cfg.csv_path))
	cfg._parse_party(dict)
	cfg._parse_ai(dict)
	cfg._parse_encounters(dict)
	cfg._validate()
	return cfg


func _parse_party(dict: Dictionary) -> void:
	var raw: Variant = dict.get("party", [])
	if raw is Array:
		party = raw
	else:
		party = []
		errors.append("party: expected an array of member objects")


func _parse_ai(dict: Dictionary) -> void:
	var raw: Variant = dict.get("ai", {})
	if not (raw is Dictionary):
		errors.append("ai: expected an object")
		return
	var ai: Dictionary = raw
	ai_heal_hp_threshold = float(ai.get("heal_hp_threshold", ai_heal_hp_threshold))
	ai_attack_magic_min_enemies = int(ai.get("attack_magic_min_enemies", ai_attack_magic_min_enemies))
	ai_attack_magic_min_tier = int(ai.get("attack_magic_min_tier", ai_attack_magic_min_tier))


func _parse_encounters(dict: Dictionary) -> void:
	var raw: Variant = dict.get("encounters", {})
	if not (raw is Dictionary):
		errors.append("encounters: expected an object")
		return
	var enc: Dictionary = raw
	encounter_mode = String(enc.get("mode", encounter_mode))
	encounter_floor = int(enc.get("floor", encounter_floor))
	encounter_patterns = []
	var patterns: Variant = enc.get("patterns", [])
	if not (patterns is Array):
		errors.append("encounters.patterns: expected an array")
		return
	for entry in patterns:
		if not (entry is Dictionary):
			errors.append("encounters.patterns: each pattern must be an object")
			continue
		# Design D5 nests the composition under a "species" key; the stored
		# pattern is the flat species -> count dictionary.
		var species: Variant = entry.get("species", entry)
		if not (species is Dictionary):
			errors.append("encounters.patterns: 'species' must be an object mapping species to counts")
			continue
		var normalized := {}
		for key in species:
			normalized[String(key)] = int(species[key])
		encounter_patterns.append(normalized)


func _validate() -> void:
	if runs <= 0:
		errors.append("runs: must be positive (got %d)" % runs)
	if max_battles <= 0:
		errors.append("max_battles: must be positive (got %d)" % max_battles)
	if party.is_empty():
		errors.append("party: must contain at least one member")
	for i in range(party.size()):
		_validate_member(i)
	if not VALID_ENCOUNTER_MODES.has(encounter_mode):
		errors.append("encounters.mode: unknown mode '%s' (expected \"table\" or \"fixed\")" % encounter_mode)
	elif encounter_mode == "fixed" and encounter_patterns.is_empty():
		errors.append("encounters.patterns: must contain at least one pattern in fixed mode")


func _validate_member(index: int) -> void:
	var raw: Variant = party[index]
	if not (raw is Dictionary):
		errors.append("party[%d]: expected a member object" % index)
		return
	var member: Dictionary = raw
	for key in MEMBER_KEY_TYPES:
		if not member.has(key):
			errors.append("party[%d].%s: required key is missing" % [index, key])
			continue
		var accepted: Array = MEMBER_KEY_TYPES[key]
		if not accepted.has(typeof(member[key])):
			errors.append("party[%d].%s: unexpected type" % [index, key])
	if member.has("level") and [TYPE_INT, TYPE_FLOAT].has(typeof(member["level"])):
		if int(member["level"]) < 1:
			errors.append("party[%d].level: must be at least 1 (got %d)" % [index, int(member["level"])])
	if member.has("row") and member["row"] is String:
		if not VALID_ROWS.has(String(member["row"])):
			errors.append("party[%d].row: unknown row '%s' (expected \"front\" or \"back\")" % [index, member["row"]])
	if member.has("stats") and not (member["stats"] is Dictionary):
		errors.append("party[%d].stats: expected an object" % index)
