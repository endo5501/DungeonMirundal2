class_name BalanceRepoBuilder
extends RefCounted

# Builds the in-memory MonsterRepository the dashboard injects into
# ExpeditionRunner (design D6). With a curve, every species covered by the
# balance definition (a `species` or `overrides` entry) is registered as a
# duplicate() of the base resource with the five combat values overwritten
# from MonsterCurve.compute_stats; species not covered keep their .tres values
# (the same skip semantics as the generator, so old values never change
# silently). With a null curve (no --balance) the shipped resources are
# registered as-is. Nothing here ever writes a file.


static func build(base_monsters: Array, curve: MonsterCurve) -> MonsterRepository:
	var repo := MonsterRepository.new()
	for monster in base_monsters:
		var data := monster as MonsterData
		if data == null:
			continue
		repo.register(_apply_curve(data, curve))
	return repo


static func _apply_curve(data: MonsterData, curve: MonsterCurve) -> MonsterData:
	if curve == null:
		return data
	var species_id := String(data.monster_id)
	if not curve.species.has(species_id) and not curve.overrides.has(species_id):
		return data
	var stats := curve.compute_stats(species_id, data.tier)
	var copy := data.duplicate() as MonsterData
	copy.max_hp_min = int(stats["hp_min"])
	copy.max_hp_max = int(stats["hp_max"])
	copy.attack = int(stats["attack"])
	copy.defense = int(stats["defense"])
	copy.agility = int(stats["agility"])
	return copy
