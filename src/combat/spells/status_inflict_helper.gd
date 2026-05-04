class_name StatusInflictHelper
extends RefCounted

# Shared inflict-roll routine for any spell effect that applies a status with
# a chance/resistance check. Mutates `entry["events"]` and `target.statuses`.
#
# - `target` must expose `get_resist(StringName) -> float` and `statuses: StatusTrack`.
# - `data.scope == PERSISTENT` overrides duration with the sentinel.
# - On hit appends `{type: "inflict", status_id, success: true}`; on miss
#   appends `{type: "resist", status_id}`.
static func try_inflict(
	target,
	data: StatusData,
	chance: float,
	duration: int,
	spell_rng: SpellRng,
	entry: Dictionary
) -> bool:
	var resist: float = target.get_resist(data.resist_key)
	var effective: float = clamp(chance - resist, 0.0, 1.0)
	var threshold := int(effective * 100.0)
	var roll: int = spell_rng.roll(0, 99) if spell_rng != null else 0
	if roll < threshold:
		var dur := duration
		if data.scope == StatusData.Scope.PERSISTENT:
			dur = StatusTrack.PERSISTENT_DURATION
		target.statuses.apply(data.id, dur)
		(entry["events"] as Array).append({
			"type": "inflict",
			"status_id": data.id,
			"success": true,
		})
		return true
	(entry["events"] as Array).append({
		"type": "resist",
		"status_id": data.id,
	})
	return false
