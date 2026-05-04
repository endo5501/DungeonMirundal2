class_name StatusRepository
extends RefCounted

var _by_id: Dictionary = {}  # StringName -> StatusData


func register(status: StatusData) -> void:
	if status == null:
		return
	if status.id == &"":
		push_warning("StatusRepository.register: status.id is empty; resource_path=%s" % status.resource_path)
		return
	_by_id[status.id] = status


func find(id: StringName) -> StatusData:
	if not _by_id.has(id):
		return null
	return _by_id[id] as StatusData


func has_id(id: StringName) -> bool:
	return _by_id.has(id)


func size() -> int:
	return _by_id.size()


func all() -> Array:
	return _by_id.values()


func ids() -> Array:
	return _by_id.keys()


func get_display_name(id: StringName) -> String:
	var data := find(id)
	if data != null and data.display_name != "":
		return data.display_name
	return String(id)
