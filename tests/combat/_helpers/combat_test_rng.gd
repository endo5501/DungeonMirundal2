class_name CombatTestRng
extends RefCounted

# RNG factories for combat tests.
#
# Native methods on RandomNumberGenerator can't be overridden in script (the
# engine bypasses the override). To keep `DamageCalculator.calculate(rng)`'s
# behavior testable, these helpers calibrate a real RNG seed so the next
# randf() consumed by the engine falls below or above the hit-chance clamps.
# `extra_consumes` fast-forwards past TurnOrder's per-actor randi_range
# tiebreak draws so the FIRST hit roll is the guaranteed one.

static var _hit_seed_cache: Dictionary = {}
static var _miss_seed_cache: Dictionary = {}


# Returns an RNG whose hit-roll randf is < 0.04. At the floor hit_chance of
# 0.05 this still rolls a hit.
static func make_certain_hit_rng(extra_consumes: int = 0) -> RandomNumberGenerator:
	if not _hit_seed_cache.has(extra_consumes):
		_hit_seed_cache[extra_consumes] = _find_seed(extra_consumes, 5000, true)
	var seed_value: int = _hit_seed_cache[extra_consumes]
	if seed_value <= 0:
		push_error("CombatTestRng: no seed produced certain-hit roll for extra_consumes=%d" % extra_consumes)
		return null
	var fresh := RandomNumberGenerator.new()
	fresh.seed = seed_value
	return fresh


# Returns an RNG whose hit-roll randf is > 0.99. At the ceiling hit_chance of
# 0.99 this still rolls a miss because the hit comparison is strict less-than.
static func make_certain_miss_rng(extra_consumes: int = 0) -> RandomNumberGenerator:
	if not _miss_seed_cache.has(extra_consumes):
		_miss_seed_cache[extra_consumes] = _find_seed(extra_consumes, 20000, false)
	var seed_value: int = _miss_seed_cache[extra_consumes]
	if seed_value <= 0:
		push_error("CombatTestRng: no seed produced certain-miss roll for extra_consumes=%d" % extra_consumes)
		return null
	var fresh := RandomNumberGenerator.new()
	fresh.seed = seed_value
	return fresh


static func _find_seed(extra_consumes: int, search_limit: int, want_hit: bool) -> int:
	var probe := RandomNumberGenerator.new()
	for s in range(1, search_limit):
		probe.seed = s
		for i in range(extra_consumes):
			probe.randi_range(0, 999999)
		var r := probe.randf()
		if want_hit and r < 0.04:
			return s
		if not want_hit and r > 0.99:
			return s
	return -1
