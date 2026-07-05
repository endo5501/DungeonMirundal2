class_name EncounterSource
extends RefCounted

# Strategy interface supplying one MonsterParty per battle to the expedition
# runner. Concrete sources override next() and describe(). Unlike walking
# encounters there is no trigger probability: every next() call is a battle.


func next(_rng: RandomNumberGenerator) -> MonsterParty:
	push_error("EncounterSource.next() must be overridden by a concrete source")
	return null


func describe() -> String:
	return ""
