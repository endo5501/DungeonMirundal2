class_name BalanceRepoBuilder
extends RefCounted

# Builds the in-memory MonsterRepository the dashboard injects into
# ExpeditionRunner (design D6). Red-phase stub: not implemented yet.


static func build(_base_monsters: Array, _curve: MonsterCurve) -> MonsterRepository:
	return MonsterRepository.new()
