extends SceneTree

# Headless CLI entry point for the balance dashboard (design D6/D7).
# Red-phase stub: not implemented yet.


func _initialize() -> void:
	quit(1)


static func _parse_args(_user_args: PackedStringArray) -> Dictionary:
	return {"ok": false, "args": {}, "error": "not implemented"}
