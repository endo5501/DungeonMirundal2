class_name SpellRepository
extends RefCounted

var _by_id: Dictionary = {}  # StringName -> SpellData


func register(spell: SpellData) -> void:
	if spell == null:
		return
	if spell.id == &"":
		push_warning("SpellRepository.register: spell.id is empty; resource_path=%s" % spell.resource_path)
		return
	_by_id[spell.id] = spell


func find(id: StringName) -> SpellData:
	if not _by_id.has(id):
		return null
	return _by_id[id] as SpellData


func has_id(id: StringName) -> bool:
	return _by_id.has(id)


func size() -> int:
	return _by_id.size()


func all() -> Array:
	return _by_id.values()


func ids() -> Array:
	return _by_id.keys()
