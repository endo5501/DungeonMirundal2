class_name ResultAggregator
extends RefCounted


static func aggregate(_run_stats: Array) -> Dictionary:
	return {
		"metrics": {
			"battles_survived": {"median": 0, "p10": 0, "p90": 0},
			"total_turns": {"median": 0, "p10": 0, "p90": 0},
			"first_death_battle": {"median": 0, "p10": 0, "p90": 0, "never_count": 0},
			"mp_exhausted_battle": {"median": 0, "p10": 0, "p90": 0, "never_count": 0},
		},
		"end_causes": {"WIPED": 0.0, "MAX_BATTLES": 0.0, "STALLED": 0.0},
	}
