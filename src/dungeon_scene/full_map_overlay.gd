class_name FullMapOverlay
extends Control

# Stub: makes the test file compile so tests can fail clearly (Red phase).
func setup(_wiz_map: WizMap, _explored_map: ExploredMap, _player_state: PlayerState,
		_dungeon_data: DungeonData, _minimap_display: Control) -> void:
	pass

func open() -> void:
	pass

func close() -> void:
	pass

func is_open() -> bool:
	return false

func get_displayed_dungeon_name() -> String:
	return ""

func get_displayed_coordinates() -> String:
	return ""

func get_displayed_exploration_rate() -> String:
	return ""
