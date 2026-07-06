class_name DashboardConfig
extends RefCounted

# Dashboard configuration loaded from a JSON file (design D7).
# Red-phase stub: parsing and validation are not implemented yet.

var runs: int = 100
var max_battles: int = 10
var master_seed: int = 12345
# Array of member template dictionaries: {"race", "job", "row"}.
var party_template: Array = []
# Party levels to evaluate (each level applied to every template member).
var levels: Array = []
# Dungeon floors to evaluate (encounter tables in "table" mode).
var floors: Array = []
# Sweep block (optional): present only when the config declares "sweep".
var sweep_defined: bool = false
var sweep_knob: String = ""
var sweep_from: float = 0.0
var sweep_to: float = 0.0
var sweep_steps: int = 0
var sweep_scenarios: Array = []
var errors: Array[String] = []


static func load_from_file(_path: String) -> DashboardConfig:
	return null


static func parse(_dict: Dictionary) -> DashboardConfig:
	return DashboardConfig.new()


# Expands the template into PartyFactory member specs, all at `level`.
func party_specs_at_level(_level: int) -> Array:
	return []
