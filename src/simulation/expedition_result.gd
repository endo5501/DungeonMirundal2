class_name ExpeditionResult
extends RefCounted

# Result of one expedition (design D3/D7). Stub — implemented in task 5.3.

var end_cause: String = ""
var battle_rows: Array = []
var characters: Array = []
var mp_exhausted_battle: int = -1


func to_run_stats() -> Dictionary:
	return {
		"battles_survived": -999,
		"total_turns": -999,
		"first_death_battle": -999,
		"mp_exhausted_battle": -999,
		"end_cause": "",
	}
