class_name ResultAggregator
extends RefCounted
## Pure aggregation of expedition run statistics (no I/O, no printing).
##
## Input: one Dictionary per run with keys battles_survived, total_turns,
## first_death_battle, mp_exhausted_battle (-1 = never occurred) and
## end_cause ("WIPED" / "MAX_BATTLES" / "STALLED").
## Percentiles use the nearest-rank method: rank = ceil(p/100 * N) clamped
## to [1, N], value = sorted[rank - 1]; the median is p50 by the same rule.

const END_CAUSES: Array[String] = ["WIPED", "MAX_BATTLES", "STALLED"]


static func aggregate(run_stats: Array) -> Dictionary:
	return {
		"metrics": {
			"battles_survived": _metric(run_stats, "battles_survived"),
			"total_turns": _metric(run_stats, "total_turns"),
			"first_death_battle": _optional_metric(run_stats, "first_death_battle"),
			"mp_exhausted_battle": _optional_metric(run_stats, "mp_exhausted_battle"),
		},
		"end_causes": _end_causes(run_stats),
	}


static func _metric(run_stats: Array, key: String) -> Dictionary:
	var values: Array[int] = []
	for stat in run_stats:
		values.append(int(stat[key]))
	return _percentile_summary(values)


static func _optional_metric(run_stats: Array, key: String) -> Dictionary:
	var values: Array[int] = []
	var never_count := 0
	for stat in run_stats:
		var value := int(stat[key])
		if value == -1:
			never_count += 1
		else:
			values.append(value)
	var result := _percentile_summary(values)
	result["never_count"] = never_count
	return result


static func _percentile_summary(values: Array[int]) -> Dictionary:
	if values.is_empty():
		return {"median": -1, "p10": -1, "p90": -1}
	var sorted := values.duplicate()
	sorted.sort()
	return {
		"median": _nearest_rank(sorted, 50),
		"p10": _nearest_rank(sorted, 10),
		"p90": _nearest_rank(sorted, 90),
	}


static func _nearest_rank(sorted_values: Array[int], p: int) -> int:
	var n := sorted_values.size()
	var rank := clampi(int(ceil(p / 100.0 * n)), 1, n)
	return sorted_values[rank - 1]


static func _end_causes(run_stats: Array) -> Dictionary:
	var counts: Dictionary = {}
	for cause in END_CAUSES:
		counts[cause] = 0
	for stat in run_stats:
		var cause := String(stat["end_cause"])
		counts[cause] = int(counts.get(cause, 0)) + 1
	var total := run_stats.size()
	var fractions: Dictionary = {}
	for cause in counts:
		fractions[cause] = float(counts[cause]) / float(total) if total > 0 else 0.0
	return fractions
