class_name ItemUseContext
extends RefCounted

var is_in_dungeon: bool = false
var is_in_combat: bool = false
var party: Array = []


static func make(p_in_dungeon: bool, p_in_combat: bool, p_party: Array = []) -> ItemUseContext:
	var c := ItemUseContext.new()
	c.is_in_dungeon = p_in_dungeon
	c.is_in_combat = p_in_combat
	c.party = p_party.duplicate()
	return c
