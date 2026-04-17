class_name ExperienceCalculator
extends RefCounted


static func sum_experience(monsters: Array) -> int:
	var total := 0
	for m in monsters:
		if m == null:
			continue
		if m is Monster:
			if m.data != null:
				total += m.data.experience
		elif m is MonsterCombatant:
			if m.monster != null and m.monster.data != null:
				total += m.monster.data.experience
	return total


static func per_member_share(total: int, participant_count: int) -> int:
	if participant_count <= 0:
		return 0
	return total / participant_count


static func award(characters: Array, monsters: Array) -> int:
	var total := sum_experience(monsters)
	var share := per_member_share(total, characters.size())
	if share <= 0:
		return 0
	for ch in characters:
		if ch != null:
			ch.gain_experience(share)
	return share
