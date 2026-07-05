class_name ExpeditionResult
extends RefCounted

# Result of one expedition (design D3/D7): per-battle rows in the exact CSV
# shape SimulationCsvWriter consumes, the end cause, and the final Character
# states (same instances the battles ran with, exposed for reporting/tests).
#
# battle_rows entry shape (battle is 1-based; pct floats in 0..1):
#   {"run": int, "battle": int, "encounter": String, "turns": int,
#    "hp_pct_before_heal": float, "party_hp_pct": float, "party_mp_pct": float,
#    "deaths_cum": int, "outcome": String}

var end_cause: String = ""  # "WIPED" | "MAX_BATTLES" | "STALLED"
var battle_rows: Array = []
var characters: Array = []  # Array[Character], final post-expedition state
# 1-based battle index at which the post-heal party total current_mp first hit
# 0 while total max_mp > 0; -1 when it never happened or the party has no
# casters. Tracked by the runner because rows alone cannot distinguish
# "MP exhausted" from "no casters" (both record party_mp_pct = 0.0).
var mp_exhausted_battle: int = -1


# Per-run statistics consumed by ResultAggregator.aggregate.
func to_run_stats() -> Dictionary:
	var total_turns := 0
	var first_death_battle := -1
	for row in battle_rows:
		total_turns += int(row["turns"])
		if first_death_battle == -1 and int(row["deaths_cum"]) > 0:
			first_death_battle = int(row["battle"])
	return {
		"battles_survived": battle_rows.size(),
		"total_turns": total_turns,
		"first_death_battle": first_death_battle,
		"mp_exhausted_battle": mp_exhausted_battle,
		"end_cause": end_cause,
	}
