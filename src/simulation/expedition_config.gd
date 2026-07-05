class_name ExpeditionConfig
extends RefCounted

var runs: int = 100
var master_seed: int = 12345
var max_battles: int = 50
var csv_path: String = "tmp/simulation/result.csv"
var party: Array = []
var ai_heal_hp_threshold: float = 0.6
var ai_attack_magic_min_enemies: int = 2
var ai_attack_magic_min_tier: int = 0
var encounter_mode: String = "table"
var encounter_floor: int = 1
var encounter_patterns: Array = []
var errors: Array[String] = []


static func load_from_file(_path: String) -> ExpeditionConfig:
	# Stub: not implemented yet (TDD red phase).
	return ExpeditionConfig.new()


static func parse(_dict: Dictionary) -> ExpeditionConfig:
	# Stub: not implemented yet (TDD red phase).
	var cfg := ExpeditionConfig.new()
	cfg.errors.append("not implemented")
	return cfg
