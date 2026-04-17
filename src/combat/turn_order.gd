class_name TurnOrder
extends RefCounted


static func order(combatants: Array, rng: RandomNumberGenerator) -> Array:
	var pairs: Array = []
	for actor in combatants:
		if actor == null or not actor.is_alive():
			continue
		var tiebreak: int = rng.randi_range(0, 999999) if rng != null else 0
		pairs.append({"actor": actor, "agi": actor.get_agility(), "tie": tiebreak})
	pairs.sort_custom(_compare_pairs)
	var result: Array = []
	for pair in pairs:
		result.append(pair["actor"])
	return result


static func _compare_pairs(a: Dictionary, b: Dictionary) -> bool:
	if a["agi"] != b["agi"]:
		return a["agi"] > b["agi"]
	return a["tie"] < b["tie"]
