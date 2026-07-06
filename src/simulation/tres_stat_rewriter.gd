class_name TresStatRewriter
extends RefCounted

# Stub for the red phase of TDD: shapes are correct so tests fail on
# assertions instead of parse/runtime errors. Real implementation follows.

const FIELD_NAMES: Array[String] = ["max_hp_min", "max_hp_max", "attack", "defense", "agility"]


static func rewrite(content: String, _stats: Dictionary) -> Dictionary:
	return {"ok": false, "content": content, "errors": [] as Array[String]}


static func extract_stats(_content: String) -> Dictionary:
	return {"ok": false, "stats": {}, "errors": [] as Array[String]}


static func extract_tier(_content: String) -> int:
	return -1


static func diff_stats(_current: Dictionary, _target: Dictionary) -> Array[Dictionary]:
	return []
