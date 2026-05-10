class_name JobPortrait
extends RefCounted

const PORTRAIT_PATHS: Dictionary = {
	&"fighter": "res://assets/images/portraits/jobs/fighter.png",
	&"mage": "res://assets/images/portraits/jobs/mage.png",
	&"priest": "res://assets/images/portraits/jobs/priest.png",
	&"thief": "res://assets/images/portraits/jobs/thief.png",
	&"bishop": "res://assets/images/portraits/jobs/bishop.png",
	&"samurai": "res://assets/images/portraits/jobs/samurai.png",
	&"lord": "res://assets/images/portraits/jobs/lord.png",
	&"ninja": "res://assets/images/portraits/jobs/ninja.png",
}

static var _texture_cache: Dictionary = {}


static func path_for(job_id: StringName) -> String:
	return PORTRAIT_PATHS.get(job_id, "")


static func texture_for(job_id: StringName) -> Texture2D:
	if _texture_cache.has(job_id):
		return _texture_cache[job_id]
	var path := path_for(job_id)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var source_texture := load(path) as Texture2D
	if source_texture == null:
		return null
	var image := source_texture.get_image()
	if image == null:
		return source_texture
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[job_id] = texture
	return texture
