class_name DashboardConfig
extends RefCounted

# Dashboard configuration loaded from a JSON file (design D7). Loading never
# crashes: unreadable files / invalid JSON return null; a structurally valid
# dictionary always produces a config object whose `errors` array lists every
# validation problem (the caller decides whether to abort) — the same pattern
# as ExpeditionConfig.
#
# The optional "sweep" object enables sweep mode:
#   {"knob": "curves.attack.growth", "from": 1.4, "to": 2.0, "steps": 4,
#    "scenarios": [{"level": 4, "floor": 2}]}
# Whether the knob path exists in the balance definition is checked when it is
# applied (DashboardRunner.apply_knob), because only the balance JSON knows
# its own keys.

const VALID_ROWS: Array[String] = ["front", "back"]
# Required template member keys; all plain strings. Race/job existence is
# PartyFactory's job (spec: party construction reuses PartyFactory.build).
const MEMBER_KEYS: Array[String] = ["race", "job", "row"]

var runs: int = 100
var max_battles: int = 10
var master_seed: int = 12345
# Array of member template dictionaries: {"race", "job", "row"} (+ optional
# "name"/"stats" passed through to PartyFactory).
var party_template: Array = []
# Party levels to evaluate (each level applied to every template member).
var levels: Array = []
# Dungeon floors to evaluate (encounter tables in "table" mode).
var floors: Array = []
# Sweep block: present only when the config declares "sweep".
var sweep_defined: bool = false
var sweep_knob: String = ""
var sweep_from: float = 0.0
var sweep_to: float = 0.0
var sweep_steps: int = 0
# Array of {"level": int, "floor": int} dictionaries.
var sweep_scenarios: Array = []
var errors: Array[String] = []


static func load_from_file(path: String) -> DashboardConfig:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	if not (json.data is Dictionary):
		return null
	return parse(json.data)


static func parse(dict: Dictionary) -> DashboardConfig:
	var cfg := DashboardConfig.new()
	cfg.runs = int(dict.get("runs", cfg.runs))
	cfg.max_battles = int(dict.get("max_battles", cfg.max_battles))
	cfg.master_seed = int(dict.get("master_seed", cfg.master_seed))
	cfg._parse_party_template(dict)
	cfg.levels = cfg._parse_positive_int_array(dict, "levels")
	cfg.floors = cfg._parse_positive_int_array(dict, "floors")
	cfg._parse_sweep(dict)
	cfg._validate()
	return cfg


# Expands the template into PartyFactory member specs, all at `level` (design
# D7: only the level varies between cells; the composition is shared).
func party_specs_at_level(level: int) -> Array:
	var specs: Array = []
	for i in range(party_template.size()):
		var raw: Variant = party_template[i]
		if not (raw is Dictionary):
			continue
		var member: Dictionary = raw
		var spec := {
			"name": String(member.get("name", "P%d" % (i + 1))),
			"race": String(member.get("race", "")),
			"job": String(member.get("job", "")),
			"level": level,
			"row": String(member.get("row", "front")),
		}
		if member.has("stats"):
			spec["stats"] = member["stats"]
		specs.append(spec)
	return specs


# --- parsing helpers ---

func _parse_party_template(dict: Dictionary) -> void:
	var raw: Variant = dict.get("party_template", [])
	if raw is Array:
		party_template = raw
	else:
		party_template = []
		errors.append("party_template: expected an array of member objects")


func _parse_positive_int_array(dict: Dictionary, key: String) -> Array:
	if not dict.has(key):
		errors.append("%s: required key is missing" % key)
		return []
	if not (dict[key] is Array):
		errors.append("%s: expected an array of positive integers" % key)
		return []
	var values: Array = []
	var raw: Array = dict[key]
	if raw.is_empty():
		errors.append("%s: must contain at least one entry" % key)
	for entry in raw:
		if not _is_positive_int(entry):
			errors.append("%s: entries must be positive integers (got %s)" % [key, str(entry)])
			continue
		values.append(int(entry))
	return values


func _parse_sweep(dict: Dictionary) -> void:
	if not dict.has("sweep"):
		return
	if not (dict["sweep"] is Dictionary):
		errors.append("sweep: expected an object")
		return
	sweep_defined = true
	var sweep: Dictionary = dict["sweep"]
	var knob: Variant = sweep.get("knob", "")
	if not (knob is String) or String(knob).is_empty():
		errors.append("sweep.knob: expected a non-empty dotted path string")
	else:
		sweep_knob = String(knob)
	for key in ["from", "to"]:
		if not sweep.has(key) or not _is_number(sweep[key]):
			errors.append("sweep.%s: expected a number" % key)
	sweep_from = float(sweep.get("from", 0.0)) if _is_number(sweep.get("from")) else 0.0
	sweep_to = float(sweep.get("to", 0.0)) if _is_number(sweep.get("to")) else 0.0
	if not _is_number(sweep.get("steps")) or int(sweep.get("steps")) < 2:
		errors.append("sweep.steps: expected an integer >= 2 (got %s)" % str(sweep.get("steps")))
	else:
		sweep_steps = int(sweep["steps"])
	_parse_scenarios(sweep)


func _parse_scenarios(sweep: Dictionary) -> void:
	var raw: Variant = sweep.get("scenarios", null)
	if not (raw is Array):
		errors.append("sweep.scenarios: expected an array of {level, floor} objects")
		return
	var scenarios: Array = raw
	if scenarios.is_empty():
		errors.append("sweep.scenarios: must contain at least one scenario")
		return
	for i in range(scenarios.size()):
		if not (scenarios[i] is Dictionary):
			errors.append("sweep.scenarios[%d]: expected an object" % i)
			continue
		var scenario: Dictionary = scenarios[i]
		var valid := true
		for key in ["level", "floor"]:
			if not scenario.has(key) or not _is_positive_int(scenario[key]):
				errors.append(
					"sweep.scenarios[%d].%s: expected a positive integer" % [i, key]
				)
				valid = false
		if valid:
			sweep_scenarios.append({"level": int(scenario["level"]), "floor": int(scenario["floor"])})


# --- validation ---

func _validate() -> void:
	if runs <= 0:
		errors.append("runs: must be positive (got %d)" % runs)
	if max_battles <= 0:
		errors.append("max_battles: must be positive (got %d)" % max_battles)
	if party_template.is_empty():
		errors.append("party_template: must contain at least one member")
	for i in range(party_template.size()):
		_validate_member(i)


func _validate_member(index: int) -> void:
	var raw: Variant = party_template[index]
	if not (raw is Dictionary):
		errors.append("party_template[%d]: expected a member object" % index)
		return
	var member: Dictionary = raw
	for key in MEMBER_KEYS:
		if not member.has(key):
			errors.append("party_template[%d].%s: required key is missing" % [index, key])
			continue
		if not (member[key] is String):
			errors.append("party_template[%d].%s: expected a string" % [index, key])
	if member.has("row") and member["row"] is String:
		if not VALID_ROWS.has(String(member["row"])):
			errors.append(
				"party_template[%d].row: unknown row '%s' (expected \"front\" or \"back\")"
				% [index, member["row"]]
			)


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


# JSON numbers always arrive as floats, so whole floats (2.0) count as
# integers, but fractional values (2.7) are rejected instead of silently
# truncating to 2.
func _is_positive_int(value: Variant) -> bool:
	return _is_number(value) and float(value) == float(int(value)) and int(value) >= 1
