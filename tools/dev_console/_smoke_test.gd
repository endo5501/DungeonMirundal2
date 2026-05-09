extends SceneTree

# Headless smoke test for the Dev Console scene. Loads main.tscn, lets it run
# one frame, then quits. If anything crashes during _ready (missing nodes,
# null resources, etc.) the process exits non-zero.
#
# Intentionally NOT registered as a GUT test — Godot's scene system doesn't
# play nicely with GUT for full-tree tests, and the SaveSession unit suite
# already has full coverage of the logic layer. This file's purpose is just
# "the UI scene is internally well-formed."


func _initialize() -> void:
	var packed: PackedScene = load("res://tools/dev_console/main.tscn") as PackedScene
	if packed == null:
		push_error("smoke_test: failed to load main.tscn")
		quit(1)
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		push_error("smoke_test: failed to instantiate main.tscn")
		quit(1)
		return
	root.add_child(instance)
	print("smoke_test: dev_console main.tscn instantiated successfully")
	# Let one frame run (signals/_ready connect).
	await physics_frame
	# Validate that the Saves tab made it in.
	var tabs := instance.get_node_or_null("Tabs")
	if tabs == null or tabs.get_tab_count() == 0:
		push_error("smoke_test: Tabs node has no children")
		quit(1)
		return
	print("smoke_test: Tabs has %d tab(s); current_tab=%d" % [tabs.get_tab_count(), tabs.current_tab])
	# project.godot autoloads PartyHud as a CanvasLayer that would otherwise
	# overlay the dev console. main._ready() must call hide_hud() on it.
	var hud: Node = root.get_node_or_null("PartyHud")
	if hud != null and "visible" in hud and hud.visible:
		push_error("smoke_test: PartyHud autoload was not hidden by Dev Console")
		quit(1)
		return
	print("smoke_test: PartyHud autoload hidden as expected")
	quit(0)
