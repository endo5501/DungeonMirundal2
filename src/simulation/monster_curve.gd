class_name MonsterCurve
extends RefCounted

# Monster balance curve definition loaded from a JSON file (design D1/D3/D4).
# Loading never crashes: unreadable files / invalid JSON return null; a
# structurally valid dictionary always produces a model object whose `errors`
# array lists every validation problem (the caller decides whether to abort).
# Role-modifier normalization issues go to `warnings` and never block.
#
# The same object doubles as the pure stat calculator shared by the generator
# and the dashboard: stat = curves[stat].base * growth^(tier-1) * modifier,
# with `overrides` taking absolute precedence per stat key.

const STAT_KEYS: Array[String] = ["hp", "attack", "defense", "agility"]
const OVERRIDE_KEYS: Array[String] = ["hp_min", "hp_max", "attack", "defense", "agility"]
# Warn when a species' modifier geometric mean drifts further than this from 1.0.
const NORMALIZATION_TOLERANCE := 0.15

# stat -> {"base": float, "growth": float}; only entries that validated.
var curves: Dictionary = {}
# Global half-width ratio of the HP range around the curve midpoint, in [0, 1).
var hp_spread: float = 0.25
# species id -> validated modifiers ({stat: float > 0, "hp_spread": float}).
var species: Dictionary = {}
# species id -> {stat: int} explicit values that bypass curve and modifiers.
var overrides: Dictionary = {}
var errors: Array[String] = []
var warnings: Array[String] = []


static func load_from_file(path: String) -> MonsterCurve:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	if not (json.data is Dictionary):
		return null
	return parse(json.data)


static func parse(dict: Dictionary) -> MonsterCurve:
	var curve := MonsterCurve.new()
	curve._parse_curves(dict)
	curve._parse_hp_spread(dict)
	curve._parse_species(dict)
	curve._parse_overrides(dict)
	curve._collect_normalization_warnings()
	return curve


# Computes the combat stats for one species at one tier. Deterministic: pure
# arithmetic on the parsed definition, no randomness. Species without an entry
# in `species` fall back to modifier 1.0 for every stat.
func compute_stats(species_id: String, tier: int) -> Dictionary:
	var mods: Dictionary = species.get(species_id, {})
	var hp_mid := _raw_stat("hp", tier, mods)
	var spread := float(mods.get("hp_spread", hp_spread))
	var result := {
		"hp_min": maxi(_round_half_up(hp_mid * (1.0 - spread)), 1),
		"hp_max": maxi(_round_half_up(hp_mid * (1.0 + spread)), 1),
		"attack": maxi(_round_half_up(_raw_stat("attack", tier, mods)), 1),
		"defense": maxi(_round_half_up(_raw_stat("defense", tier, mods)), 0),
		"agility": maxi(_round_half_up(_raw_stat("agility", tier, mods)), 0),
	}
	# Rounding and clamping preserve order for spread in [0, 1), but guard the
	# hp_min <= hp_max guarantee explicitly against future formula edits.
	if result["hp_min"] > result["hp_max"]:
		result["hp_min"] = result["hp_max"]
	var override_entry: Dictionary = overrides.get(species_id, {})
	for key in OVERRIDE_KEYS:
		if override_entry.has(key):
			result[key] = int(override_entry[key])
	return result


func _raw_stat(stat: String, tier: int, mods: Dictionary) -> float:
	var entry: Dictionary = curves.get(stat, {})
	var base := float(entry.get("base", 0.0))
	var growth := float(entry.get("growth", 1.0))
	return base * pow(growth, tier - 1) * float(mods.get(stat, 1.0))


# Round-half-up to the nearest int (0.5 always rounds toward +infinity).
func _round_half_up(value: float) -> int:
	return int(floorf(value + 0.5))


func _parse_curves(dict: Dictionary) -> void:
	var raw: Variant = dict.get("curves", {})
	if not (raw is Dictionary):
		errors.append("curves: expected an object")
		return
	var src: Dictionary = raw
	for stat in STAT_KEYS:
		if not src.has(stat):
			errors.append("curves.%s: required key is missing" % stat)
			continue
		if not (src[stat] is Dictionary):
			errors.append("curves.%s: expected an object with base/growth" % stat)
			continue
		var entry: Dictionary = src[stat]
		var parsed := {}
		for key in ["base", "growth"]:
			if not entry.has(key) or not _is_number(entry[key]):
				errors.append("curves.%s.%s: expected a positive number" % [stat, key])
				continue
			var value := float(entry[key])
			if value <= 0.0:
				errors.append("curves.%s.%s: must be positive (got %s)" % [stat, key, str(value)])
				continue
			parsed[key] = value
		if parsed.size() == 2:
			curves[stat] = parsed


func _parse_hp_spread(dict: Dictionary) -> void:
	if not dict.has("hp_spread"):
		return
	var spread := _parse_spread_value(dict["hp_spread"], "hp_spread")
	if spread >= 0.0:
		hp_spread = spread


# Shared validation for the global `hp_spread` and per-species overrides so the
# accepted range and error message cannot drift apart. Appends an error naming
# `field` and returns -1.0 when the value is invalid.
func _parse_spread_value(value: Variant, field: String) -> float:
	if not _is_number(value):
		errors.append("%s: expected a number in [0.0, 1.0)" % field)
		return -1.0
	var spread := float(value)
	if spread < 0.0 or spread >= 1.0:
		errors.append("%s: must be in [0.0, 1.0) (got %s)" % [field, str(spread)])
		return -1.0
	return spread


func _parse_species(dict: Dictionary) -> void:
	var raw: Variant = dict.get("species", {})
	if not (raw is Dictionary):
		errors.append("species: expected an object")
		return
	var src: Dictionary = raw
	for id in src:
		var species_id := String(id)
		if not (src[id] is Dictionary):
			errors.append("species.%s: expected an object" % species_id)
			continue
		var entry: Dictionary = src[id]
		var parsed := {}
		for key in entry:
			var key_name := String(key)
			if key_name == "hp_spread":
				var spread := _parse_spread_value(entry[key], "species.%s.hp_spread" % species_id)
				if spread >= 0.0:
					parsed["hp_spread"] = spread
			elif STAT_KEYS.has(key_name):
				if not _is_number(entry[key]):
					errors.append("species.%s.%s: expected a positive number" % [species_id, key_name])
					continue
				var modifier := float(entry[key])
				if modifier <= 0.0:
					errors.append(
						"species.%s.%s: must be positive (got %s)" % [species_id, key_name, str(modifier)]
					)
					continue
				parsed[key_name] = modifier
			else:
				errors.append("species.%s.%s: unknown key" % [species_id, key_name])
		species[species_id] = parsed


func _parse_overrides(dict: Dictionary) -> void:
	var raw: Variant = dict.get("overrides", {})
	if not (raw is Dictionary):
		errors.append("overrides: expected an object")
		return
	var src: Dictionary = raw
	for id in src:
		var species_id := String(id)
		if not (src[id] is Dictionary):
			errors.append("overrides.%s: expected an object" % species_id)
			continue
		var entry: Dictionary = src[id]
		var parsed := {}
		for key in entry:
			var key_name := String(key)
			if not OVERRIDE_KEYS.has(key_name):
				errors.append("overrides.%s.%s: unknown stat key" % [species_id, key_name])
				continue
			if not _is_number(entry[key]):
				errors.append("overrides.%s.%s: expected an integer" % [species_id, key_name])
				continue
			# JSON numbers arrive as floats; whole floats (25.0) are fine but
			# fractional values would silently truncate, so reject them.
			var value := float(entry[key])
			if value != floorf(value):
				errors.append(
					"overrides.%s.%s: expected an integer (got %s)" % [species_id, key_name, str(value)]
				)
				continue
			if value < 0.0:
				errors.append(
					"overrides.%s.%s: must be non-negative (got %d)" % [species_id, key_name, int(value)]
				)
				continue
			parsed[key_name] = int(value)
		if parsed.has("hp_min") and parsed.has("hp_max") and parsed["hp_min"] > parsed["hp_max"]:
			errors.append(
				"overrides.%s: hp_min (%d) must not exceed hp_max (%d)"
				% [species_id, parsed["hp_min"], parsed["hp_max"]]
			)
		overrides[species_id] = parsed


# Design D4: warn (never block) when a species' four effective modifiers
# (missing keys counted as 1.0) have a geometric mean outside 1.0 +- tolerance.
func _collect_normalization_warnings() -> void:
	for species_id in species:
		var entry: Dictionary = species[species_id]
		var product := 1.0
		for stat in STAT_KEYS:
			product *= float(entry.get(stat, 1.0))
		var mean := pow(product, 1.0 / STAT_KEYS.size())
		if absf(mean - 1.0) > NORMALIZATION_TOLERANCE:
			warnings.append(
				"species.%s: role modifier geometric mean %.2f deviates from 1.0 by more than %.2f"
				% [species_id, mean, NORMALIZATION_TOLERANCE]
			)


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
