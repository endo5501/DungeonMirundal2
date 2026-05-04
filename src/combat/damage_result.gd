class_name DamageResult
extends RefCounted

var hit: bool = true
var amount: int = 0


func _init(p_hit: bool = true, p_amount: int = 0) -> void:
	hit = p_hit
	amount = p_amount
