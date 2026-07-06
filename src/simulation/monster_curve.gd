class_name MonsterCurve
extends RefCounted

# Monster balance curve definition (design D1/D3/D4). Stub for the TDD red
# phase: signatures only, no behavior yet.

var curves: Dictionary = {}
var hp_spread: float = 0.25
var species: Dictionary = {}
var overrides: Dictionary = {}
var errors: Array[String] = []
var warnings: Array[String] = []


static func load_from_file(_path: String) -> MonsterCurve:
	return null


static func parse(_dict: Dictionary) -> MonsterCurve:
	return MonsterCurve.new()


func compute_stats(_species_id: String, _tier: int) -> Dictionary:
	return {"hp_min": 0, "hp_max": 0, "attack": 0, "defense": 0, "agility": 0}
