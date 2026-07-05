class_name SummaryFormatter
extends RefCounted
## Formats an aggregated expedition summary (ResultAggregator output) as a
## deterministic monospace table for console output.

const LABEL_WIDTH := 22
const VALUE_WIDTH := 8

const METRIC_ROWS: Array = [
	["battles survived", "battles_survived"],
	["total turns", "total_turns"],
	["first death at battle", "first_death_battle"],
	["MP exhausted at battle", "mp_exhausted_battle"],
]
const END_CAUSE_ORDER: Array[String] = ["WIPED", "MAX_BATTLES", "STALLED"]


static func format(summary: Dictionary, meta: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("runs=%d  seed=%d  encounters=%s" % [
		int(meta["runs"]), int(meta["master_seed"]), String(meta["encounters"]),
	])
	lines.append(_columns_line("", ["median", "p10", "p90"]))
	var metrics: Dictionary = summary["metrics"]
	for row in METRIC_ROWS:
		lines.append(_metric_line(String(row[0]), metrics[row[1]]))
	lines.append(_end_cause_line(summary["end_causes"]))
	return "\n".join(lines)


static func _columns_line(label: String, values: Array) -> String:
	var line := label.rpad(LABEL_WIDTH)
	for value in values:
		line += String(str(value)).lpad(VALUE_WIDTH)
	return line


static func _metric_line(label: String, metric: Dictionary) -> String:
	var line := _columns_line(label, [
		int(metric["median"]), int(metric["p10"]), int(metric["p90"]),
	])
	if int(metric.get("never_count", 0)) > 0:
		line += "  (never in %d runs)" % int(metric["never_count"])
	return line


static func _end_cause_line(end_causes: Dictionary) -> String:
	var percents := _end_cause_percents(end_causes)
	var parts: Array[String] = []
	for cause in END_CAUSE_ORDER:
		parts.append("%s %d%%" % [cause, int(percents[cause])])
	return "end cause: " + " / ".join(parts)


## Largest-remainder (Hamilton) rounding: floor each fraction*100, then hand
## the leftover points to the causes with the largest fractional remainders.
## Ties are broken by declaration order in END_CAUSE_ORDER. The target total
## is round(sum_of_fractions * 100), so zero runs (all fractions 0) yield
## 0/0/0 rather than inventing points.
static func _end_cause_percents(end_causes: Dictionary) -> Dictionary:
	var percents: Dictionary = {}
	var remainders: Array = []  # [fractional_remainder, declaration_index, cause]
	var total_fraction := 0.0
	var floor_sum := 0
	for i in END_CAUSE_ORDER.size():
		var cause: String = END_CAUSE_ORDER[i]
		var fraction := float(end_causes.get(cause, 0.0))
		total_fraction += fraction
		var exact := fraction * 100.0
		var whole := int(floor(exact))
		percents[cause] = whole
		floor_sum += whole
		remainders.append([exact - float(whole), i, cause])
	remainders.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return float(a[0]) > float(b[0])
		return int(a[1]) < int(b[1])
	)
	var remaining := int(round(total_fraction * 100.0)) - floor_sum
	for entry in remainders:
		if remaining <= 0:
			break
		percents[entry[2]] = int(percents[entry[2]]) + 1
		remaining -= 1
	return percents
