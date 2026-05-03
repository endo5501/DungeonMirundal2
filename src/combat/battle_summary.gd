class_name BattleSummary
extends RefCounted

var gained_experience: int
var gained_gold: int
var level_ups: Array


func _init(p_gained_experience: int = 0, p_gained_gold: int = 0, p_level_ups: Array = []) -> void:
	gained_experience = p_gained_experience
	gained_gold = p_gained_gold
	level_ups = p_level_ups.duplicate()


static func empty() -> BattleSummary:
	return BattleSummary.new()
