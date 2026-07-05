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
	var parts: Array[String] = []
	for cause in END_CAUSE_ORDER:
		var fraction := float(end_causes.get(cause, 0.0))
		parts.append("%s %d%%" % [cause, int(round(fraction * 100.0))])
	return "end cause: " + " / ".join(parts)
